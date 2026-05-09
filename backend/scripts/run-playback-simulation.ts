import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';
import { io, Socket } from 'socket.io-client';
import * as bcrypt from 'bcrypt';
import * as dotenv from 'dotenv';

dotenv.config();

const API_URL = process.env.API_URL || 'http://localhost:3000';
const WS_URL = process.env.WS_URL || 'http://localhost:3000';

const HOST_EMAIL = 'playback-host@example.com';
const GUEST_EMAIL = 'playback-guest@example.com';
const TEST_PASSWORD = 'Password123!';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

// ─── colour helpers ───────────────────────────────────────────────────────────
const col = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m',
  purple: '\x1b[35m',
};
const ok = (msg: string) => console.log(`${col.green}✔  ${msg}${col.reset}`);
const fail = (msg: string) => console.log(`${col.red}✘  ${msg}${col.reset}`);
const info = (msg: string) => console.log(`${col.cyan}ℹ  ${msg}${col.reset}`);
const warn = (msg: string) => console.log(`${col.yellow}⚠  ${msg}${col.reset}`);
const step = (msg: string) => console.log(`\n${col.purple}━━ ${msg} ━━${col.reset}`);

// ─── test tracker ─────────────────────────────────────────────────────────────
let passed = 0, failed = 0;
function assert(condition: boolean, label: string) {
  if (condition) { ok(label); passed++; }
  else { fail(label); failed++; }
}

// ─── shared state ─────────────────────────────────────────────────────────────
let eventId = '';
let TRACK_ID_1 = '';
let TRACK_ID_2 = '';
let TRACK_ID_3 = '';

// ─────────────────────────────────────────────────────────────────────────────
async function main() {
  console.log(`\n${col.green}🚀  Real-time Playback Simulation – Test Suite${col.reset}\n`);

  const clients: Socket[] = [];

  try {
    // ── 1. SETUP ─────────────────────────────────────────────────────────────
    step('SETUP – Cleaning & Seeding');
    await cleanupAll();

    const passwordHash = await bcrypt.hash(TEST_PASSWORD, 10);
    await Promise.all([
      prisma.user.create({ data: { email: HOST_EMAIL, username: 'playback_host', passwordHash, isEmailVerified: true } }),
      prisma.user.create({ data: { email: GUEST_EMAIL, username: 'playback_guest', passwordHash, isEmailVerified: true } }),
    ]);
    ok('Host and Guest users created');

    // ── 2. AUTH ──────────────────────────────────────────────────────────────
    step('AUTH – Getting JWTs');
    const [hostToken, guestToken] = await Promise.all([
      login(HOST_EMAIL, TEST_PASSWORD),
      login(GUEST_EMAIL, TEST_PASSWORD),
    ]);
    ok('Users authenticated');

    // ── 3. CREATE EVENT ──────────────────────────────────────────────────────
    step('CREATE EVENT – Public Event with Tracks');
    const YOUTUBE_IDS = ['zaGHlRk1Aq0', 'dQw4w9WgXcQ', '9bZkp7q19f0'];
    const event = await apiCallFormData('/events', 'POST', hostToken, {
      name: 'Playback Test Event',
      visibility: 'PUBLIC',
      tracks: YOUTUBE_IDS,
      startDate: new Date(Date.now() - 3600_000).toISOString(),
      tags: ["POP"]
    });
    eventId = event.id;

    // Resolve track IDs
    const tracksRes = await apiCallFormData(`/events/${eventId}/tracks`, 'GET', hostToken);
    const tracks = (tracksRes.data as any[]);
    TRACK_ID_1 = tracks[0].id; // These are EventTrack IDs
    TRACK_ID_2 = tracks[1].id;
    TRACK_ID_3 = tracks[2].id;
    info(`EventTrack IDs: ${TRACK_ID_1} | ${TRACK_ID_2} | ${TRACK_ID_3}`);
    ok('Event created with 3 tracks');

    // ── 4. WEBSOCKETS ────────────────────────────────────────────────────────
    step('WEBSOCKET – Connecting clients');
    const [hostClient, guestClient] = await Promise.all([
      connectSocket('Host-Client', hostToken),
      connectSocket('Guest-Client', guestToken),
    ]);
    clients.push(hostClient, guestClient);
    ok('Clients connected');

    // ── 5. START EVENT ───────────────────────────────────────────────────────
    step('START EVENT – Transition to LIVE');
    startEvent(hostClient, eventId);
    joinEvent(guestClient, eventId);
    {
      const [hostBcast, guestBcast, statusBcast] = await Promise.all([
          waitForBroadcast(hostClient, 'event:started'),
          waitForBroadcast(guestClient, 'event:started'),
          waitForBroadcast(guestClient, 'playback:status'),
      ]);
      assert(hostBcast?.status === 'LIVE', 'Host received event:started');
      assert(guestBcast?.status === 'LIVE', 'Guest received event:started');
      assert(statusBcast?.status === 'PAUSED', 'Initial status is PAUSED');
      console.log(statusBcast);
      console.log(TRACK_ID_1);
      assert(statusBcast?.currentTrack.id === TRACK_ID_1, 'Initial track is Track 1');
    }

    // ════════════════════════════════════════════════════════════════════════
    //  SUITE A – Basic Playback Controls
    // ════════════════════════════════════════════════════════════════════════
    step('SUITE A – Basic Playback Controls (Play/Pause/Resume)');

    // A-1: Host plays
    {
      const [bcast] = await Promise.all([
        waitForBroadcast(guestClient, 'playback:status'),
        emitEvent(hostClient, 'playback:play', { eventId }),
      ]);
      assert(bcast?.status === 'PLAYING', 'A-1 bcast – Guest sees PLAYING');
      assert(bcast?.currentTrack.id === TRACK_ID_1, 'A-1 bcast – Track 1 playing');
      ok('Playback started');
    }

    // A-2: Host pauses
    {
      const [bcast] = await Promise.all([
        waitForBroadcast(guestClient, 'playback:status'),
        emitEvent(hostClient, 'playback:pause', { eventId }),
      ]);
      assert(bcast?.status === 'PAUSED', 'A-2 bcast – Guest sees PAUSED');
      assert(typeof bcast?.pausedPlaybackPositionMs === 'number', 'A-2 bcast – Has paused position');
      ok('Playback paused');
    }

    // A-3: Host resumes
    {
      const [bcast] = await Promise.all([
        waitForBroadcast(guestClient, 'playback:status'),
        emitEvent(hostClient, 'playback:play', { eventId }),
      ]);
      assert(bcast?.status === 'PLAYING', 'A-3 bcast – Resumed to PLAYING');
      ok('Playback resumed');
    }

    // ════════════════════════════════════════════════════════════════════════
    //  SUITE B – Queue Management (Next/Skip)
    // ════════════════════════════════════════════════════════════════════════
    step('SUITE B – Queue Management (Next/Skip)');

    // B-1: Host skips to next (Track 2)
    {
      const [bcast] = await Promise.all([
        waitForBroadcast(guestClient, 'playback:status'),
        emitEvent(hostClient, 'playback:next', { eventId }),
      ]);
      assert(bcast?.currentTrack.id === TRACK_ID_2, 'B-1 bcast – Now playing Track 2');
      assert(bcast?.status === 'PLAYING', 'B-1 bcast – Automatically starts playing');
      ok('Skipped to Track 2');
    }

    // B-2: Host skips with staleness check (matching trackId)
    {
      const [bcast] = await Promise.all([
        waitForBroadcast(guestClient, 'playback:status'),
        emitEvent(hostClient, 'playback:next', { eventId, trackId: TRACK_ID_2 }),
      ]);
      assert(bcast?.currentTrack.id === TRACK_ID_3, 'B-2 bcast – Now playing Track 3');
      ok('Skipped to Track 3 with valid staleness check');
    }

    // B-3: Host skips at the end of queue
    {
      const [bcast] = await Promise.all([
        waitForBroadcast(guestClient, 'playback:status'),
        emitEvent(hostClient, 'playback:next', { eventId }),
      ]);
      assert(bcast?.currentTrack === null, 'B-3 bcast – Queue empty, currentTrackId null');
      assert(bcast?.status === 'PAUSED', 'B-3 bcast – Status PAUSED at end of queue');
      ok('Reached end of queue');
    }

    // ════════════════════════════════════════════════════════════════════════
    //  SUITE C – Security & Edge Cases
    // ════════════════════════════════════════════════════════════════════════
    step('SUITE C – Security & Edge Cases');

    // C-1: Guest tries to play (Forbidden)
    {
      const ack = await emitEvent(guestClient, 'playback:play', { eventId });
      assert(isError(ack), 'C-1 ack – Guest blocked from playing → Forbidden');
      printAck('C-1 (Guest play error)', ack);
    }

    // C-2: Host tries to skip with stale trackId
    {
       // First add a track to have something to skip
       await apiCallJson(`/events/${eventId}/tracks`, 'POST', hostToken, { providerTrackId: '_9yq0xJX-Q8' });
       // advancing to that track
       await emitEvent(hostClient, 'playback:next', { eventId });
       const status = await getEventStatus(eventId);
       const currentTrackId = status!.currentTrackId;

       // Attempt skip with WRONG trackId
       const ack = await emitEvent(hostClient, 'playback:next', { eventId, trackId: 'wrong-id' });
       assert(isError(ack), 'C-2 ack – Stale skip ignored');
       printAck('C-2 (Stale skip error)', ack);
       ok('Stale skip prevented');
    }

    // ════════════════════════════════════════════════════════════════════════
    //  SUITE D – Host Connectivity (Grace Period)
    // ════════════════════════════════════════════════════════════════════════
    step('SUITE D – Host Connectivity (Grace Period)');

    // D-1: Host disconnects
    {
      const [bcast] = await Promise.all([
        waitForBroadcast(guestClient, 'playback:status'),
        new Promise(resolve => {
            hostClient.disconnect();
            setTimeout(resolve, 500);
        })
      ]);
      assert(bcast?.status === 'PAUSED', 'D-1 bcast – Guest sees PAUSED after host disconnect');
      ok('Playback paused automatically on host disconnect');
    }

    // D-2: Host reconnects
    {
      const newHostClient = await connectSocket('Host-Client (Reconnected)', hostToken);
      clients.push(newHostClient);
      const [bcast] = await Promise.all([
        waitForBroadcast(guestClient, 'event:host_reconnected'),
        joinEvent(newHostClient, eventId , true),
      ]);
      console.log('D-2 ack', bcast);
      assert(bcast?.hostId !== undefined, 'D-2 bcast – Guest notified of host reconnect');
      ok('Host reconnected and status broadcasted');
    }

    // ════════════════════════════════════════════════════════════════════════
    //  SUMMARY
    // ════════════════════════════════════════════════════════════════════════
    step('TEST SUMMARY');
    const total = passed + failed;
    console.log(
      `${col.green}PASSED: ${passed}/${total}${col.reset}  ` +
      `${failed > 0 ? col.red : col.green}FAILED: ${failed}/${total}${col.reset}`,
    );
    if (failed > 0) process.exitCode = 1;

  } catch (err) {
    console.error(`${col.red}❌ Unexpected error:${col.reset}`, err);
    process.exitCode = 1;
  } finally {
    clients.forEach(c => c.disconnect());
    step('CLEANUP');
    await cleanupAll();
    await prisma.$disconnect();
    await sleep(500);
    process.exit(process.exitCode ?? 0);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HELPERS
// ─────────────────────────────────────────────────────────────────────────────

async function getEventStatus(id: string) {
    return prisma.event.findUnique({ where: { id } });
}

function emitEvent(client: Socket, event: string, payload: any): Promise<any> {
  return new Promise((resolve) => {
    const timer = setTimeout(() => resolve({ error: 'Timeout' }), 3000);
    client.emit(event, payload, (ack: any) => {
      clearTimeout(timer);
      resolve(ack ?? null);
    });
  });
}

/**
 * Emit event:start and await the ack.
 * Must be called once per event before the host does event:host_join.
 * Subsequent rejoins (after host_leave / disconnect) skip this step.
 */
function startEvent(client: Socket, eventId: string): Promise<any> {
  return new Promise((resolve) => {
    console.log(`[${client.id}] Starting event ${eventId}`);
    const timer = setTimeout(() => resolve({ error: 'Timeout' }), 5000);
    client.emit('event:start', { eventId }, (ack: any) => {
      clearTimeout(timer);
      console.log(`[${client.id}] event:start ack`, ack);
      resolve(ack ?? null);
    });
  });
}

function endEvent(client: Socket, eventId: string): Promise<any> {
  return new Promise((resolve) => {
    console.log(`[${client.id}] Ending event ${eventId}`);
    const timer = setTimeout(() => resolve({ error: 'Timeout' }), 5000);
    client.emit('event:end', { eventId }, (ack: any) => {
      clearTimeout(timer);
      console.log(`[${client.id}] event:end ack`, ack);
      resolve(ack ?? null);
    });
  });
}

/** Join an event room via the correct WS event. */
function joinEvent(client: Socket, eventId: string, isHost = false) {
  if (isHost) {
    client.emit('event:host_join', { eventId });
  } else {
    client.emit('event:join', { eventId });
  }
}

function waitForBroadcast(client: Socket, event: string, ms = 5000): Promise<any> {
  return new Promise((resolve) => {
    const timer = setTimeout(() => resolve(null), ms);
    client.once(event, (data: any) => {
      clearTimeout(timer);
      resolve(data);
    });
  });
}

function isError(ack: any): boolean {
  if (ack === null || ack === undefined) return true;
  if (ack.error || ack.status === 'error') return true;
  // Service responses with 'message' but no 'error' are not actually errors
  if (ack.message && !ack.error && ack.status !== 'error') return false;
  return false;
}

function printAck(label: string, ack: any) {
  const colour = isError(ack) ? col.red : col.blue;
  console.log(`${colour}  [ACK   ${label}]${col.reset}`, JSON.stringify(ack, null, 2));
}

async function cleanupAll() {
  const emails = [HOST_EMAIL, GUEST_EMAIL];
  await prisma.vote.deleteMany({ where: { user: { email: { in: emails } } } });
  await prisma.eventTrack.deleteMany({ where: { event: { host: { email: { in: emails } } } } });
  await prisma.event.deleteMany({ where: { host: { email: { in: emails } } } });
  await prisma.user.deleteMany({ where: { email: { in: emails } } });
}

async function login(identifier: string, password: string): Promise<string> {
  const res = await fetch(`${API_URL}/auth/login`, {
    method: 'POST',
    headers: { 
      'Content-Type': 'application/json',
      'x-platform': 'test-script',
      'x-device-model': 'test-environment',
      'x-app-version': '1.0.0'
    },
    body: JSON.stringify({ identifier, password }),
  });
  if (!res.ok) throw new Error(`Login failed for ${identifier}: ${res.status} ${await res.text()}`);
  return ((await res.json()) as any).access_token;
}

async function apiCallJson(
  path: string,
  method: string,
  token: string,
  body?: Record<string, any>
) {
  const res = await fetch(`${API_URL}${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      "x-platform": "test-script",
      "x-device-model": "test-environment",
      "x-app-version": "1.0.0",
    },
    body: body ? JSON.stringify(body) : undefined,
  });

  if (!res.ok) {
    throw new Error(
      `API Error [${method} ${path}]: ${res.status} – ${await res.text()}`
    );
  }

  return res.json();
}

async function apiCallFormData(
  path: string,
  method: string,
  token: string,
  body?: Record<string, any>
) {
  let formData: FormData | undefined;

  if (body) {
    formData = new FormData();

    Object.entries(body).forEach(([key, value]) => {
      if (Array.isArray(value) || typeof value === "object") {
        formData!.append(key, JSON.stringify(value));
      } else {
        formData!.append(key, String(value));
      }
    });
  }

  const res = await fetch(`${API_URL}${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      'x-platform': 'test-script',
      'x-device-model': 'test-environment',
      'x-app-version': '1.0.0'
    },
    body: formData,
  });

  if (!res.ok) {
    throw new Error(
      `API Error [${method} ${path}]: ${res.status} – ${await res.text()}`
    );
  }

  return res.json();
}

function connectSocket(name: string, token: string): Promise<Socket> {
  return new Promise((resolve, reject) => {
    const client = io(WS_URL, { 
      path: '/ws', 
      auth: { token }, 
      transports: ['websocket'],
      extraHeaders: {
        'x-platform': 'test-script',
        'x-device-model': 'test-environment',
        'x-app-version': '1.0.0'
      }
    });
    client.on('connect', () => {
      console.log(`${col.green}  [${name}]${col.reset} connected (id=${client.id})`);
      resolve(client);
    });
    client.on('connect_error', (err) => {
      console.log(`${col.red}  [${name}]${col.reset} connection error: ${err.message}`);
      reject(err);
    });
    // Passive logger
    client.on('playback:status', (data) => console.log(`${col.purple}  [${name}] ← playback:status${col.reset}`, JSON.stringify(data)));
    client.on('event:started', (data) => console.log(`${col.yellow}  [${name}] ← event:started${col.reset}`, JSON.stringify(data)));
    client.on('event:host_reconnected', (data) => console.log(`${col.cyan}  [${name}] ← event:host_reconnected${col.reset}`, JSON.stringify(data)));
    client.on('exception', (data: any) =>
      console.log(`${col.red}  [${name}] ← exception${col.reset}`, JSON.stringify(data)),
    );
  });
}

function sleep(ms: number) { return new Promise(r => setTimeout(r, ms)); }

main();
