import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';
import { io, Socket } from 'socket.io-client';
import * as bcrypt from 'bcrypt';
import * as dotenv from 'dotenv';

dotenv.config();

const API_URL = 'http://localhost:3000';
const WS_URL  = 'http://localhost:3000';

const USER1_EMAIL   = 'vote-user1@example.com';
const USER2_EMAIL   = 'vote-user2@example.com';
const TEST_PASSWORD = 'Password123!';
const EVENT_NAME    = 'Concurrent Vote Test Event';

const TRACKS = [
  { providerTrackId: 'UceaB4D0jpo', title: 'rockstar ft. 21 Savage', artist: 'Post Malone' },
  { providerTrackId: 'wXhTHyIgQ_U', title: 'Circles',                 artist: 'Post Malone' },
  { providerTrackId: 'ApXoWvfEYVU', title: 'Sunflower (Spider-Man)',   artist: 'Post Malone' },
  { providerTrackId: 'ba7mB8oueCY', title: 'Goodbyes ft. Young Thug',  artist: 'Post Malone' },
];

const c = {
  reset:  '\x1b[0m',
  green:  '\x1b[32m',
  red:    '\x1b[31m',
  yellow: '\x1b[33m',
  cyan:   '\x1b[36m',
  purple: '\x1b[35m',
  bold:   '\x1b[1m',
  dim:    '\x1b[2m',
};

const log = {
  step: (msg: string)                => console.log(`\n${c.bold}${c.cyan}▶  ${msg}${c.reset}`),
  ok:   (msg: string)                => console.log(`  ${c.green}✔${c.reset}  ${msg}`),
  fail: (msg: string)                => console.log(`  ${c.red}✘${c.reset}  ${msg}`),
  info: (msg: string)                => console.log(`  ${c.dim}${msg}${c.reset}`),
  row:  (label: string, val: string) => console.log(`  ${label.padEnd(18)} ${val}`),
};

const pool    = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma  = new PrismaClient({ adapter });

// ─── cleanup ──────────────────────────────────────────────────────────────────
async function cleanup(phase: 'before' | 'after') {
  log.step(`Cleanup (${phase} run)`);

  const event = await prisma.event.findFirst({
    where: { name: EVENT_NAME, host: { email: USER1_EMAIL } },
    include: { tracks: true },
  });

  if (!event) {
    log.info('nothing to clean');
    return;
  }

  const trackIds = event.tracks.map(t => t.id);

  // delete votes first (FK dependency)
  const deletedVotes = await prisma.eventTrack.deleteMany({
    where: { eventId: event.id },
  });
  log.ok(`deleted ${deletedVotes.count} vote(s)`);

  // delete event tracks
  const deletedEventTracks = await prisma.eventTrack.deleteMany({
    where: { eventId: event.id },
  });
  log.ok(`deleted ${deletedEventTracks.count} event track(s)`);

  // delete orphaned tracks (created for this event)
  if (trackIds.length > 0) {
    const deletedTracks = await prisma.track.deleteMany({
      where: {
        id:          { in: trackIds },
        eventTracks: { none: {} },   // only if no other event references them
      },
    });
    log.ok(`deleted ${deletedTracks.count} track record(s)`);
  }

  // delete the event
  await prisma.event.delete({ where: { id: event.id } });
  log.ok(`deleted event "${EVENT_NAME}"`);
}

// ─────────────────────────────────────────────────────────────────────────────
async function main() {
  console.log(`\n${c.bold}${c.purple}══════════════════════════════════════════════════${c.reset}`);
  console.log(`${c.bold}${c.purple}   Concurrent Vote Test — user2 × 4 tracks × 1 tick${c.reset}`);
  console.log(`${c.bold}${c.purple}══════════════════════════════════════════════════${c.reset}`);

  // ── 0. Clean any leftovers from a previous run ────────────────────────────
  await cleanup('before');

  // ── 1. Users ──────────────────────────────────────────────────────────────
  log.step('Users');
  const passwordHash = await bcrypt.hash(TEST_PASSWORD, 10);
  for (const email of [USER1_EMAIL, USER2_EMAIL]) {
    const exists = await prisma.user.findUnique({ where: { email } });
    if (!exists) {
      await prisma.user.create({
        data: { email, username: email.split('@')[0].replace(/-/g, '_'), passwordHash, isEmailVerified: true },
      });
      log.ok(`created  ${email}`);
    } else {
      log.info(`exists   ${email}`);
    }
  }

  // ── 2. Auth ───────────────────────────────────────────────────────────────
  log.step('Auth');
  const [t1, t2] = await Promise.all([
    login(USER1_EMAIL, TEST_PASSWORD),
    login(USER2_EMAIL, TEST_PASSWORD),
  ]);
  log.ok('user1 token OK');
  log.ok('user2 token OK');

  // ── 3. Event (user1 creates) ──────────────────────────────────────────────
  log.step('Event');
  const created = await apiCall('/events', 'POST', t1, {
    name:         EVENT_NAME,
    visibility:   'PUBLIC',
    tags:         ['POP'],
    invitingOnly: false,
    startDate:    new Date(Date.now() - 3600_000).toISOString(),
    tracks:       TRACKS.map(t => t.providerTrackId),
  });
  const eventId = created.id;
  log.ok(`created  "${EVENT_NAME}"`);
  log.info(`eventId  ${eventId}`);

  // ── 4. Resolve track IDs from server ──────────────────────────────────────
  log.step('Tracks');
  const tracksRes    = await apiCall(`/events/${eventId}/tracks`, 'GET', t1);
  const serverTracks: any[] = tracksRes.data ?? tracksRes;

  for (let i = 0; i < serverTracks.length; i++) {
    const st   = serverTracks[i];
    const meta = TRACKS.find(t => t.providerTrackId === st.providerTrackId);
    log.ok(`track-${i + 1}  ${(meta?.title ?? st.trackId).slice(0, 28).padEnd(28)}  ${c.dim}${st.trackId}${c.reset}`);
  }

  // ── 5. Sockets ────────────────────────────────────────────────────────────
  log.step('Sockets');
  const [s1, s2] = await Promise.all([
    connectSocket('user1', t1),
    connectSocket('user2', t2),
  ]);
  log.ok('user1 connected');
  log.ok('user2 connected');

  // ── 6. user1 starts, user2 joins ──────────────────────────────────────────
  log.step('Start & Join');
  const startAck = await startEvent(s1, eventId);
  log.ok(`user1 started event  →  ${JSON.stringify(startAck)}`);
  s2.emit('event:join', { eventId });
  await sleep(300);
  log.ok('user2 joined event');

  // ── 7. Fire all 4 votes simultaneously ────────────────────────────────────
  log.step('Concurrent Votes  (user2 — all 4 emits fired in the same Promise.all tick)');

  const firedAt = Date.now();
  const results = await Promise.all(
    serverTracks.map(async (st, i) => {
      const meta  = TRACKS.find(t => t.providerTrackId === st.providerTrackId);
      const label = `track-${i + 1}`;
      const ack   = await emitVote(s2, eventId, st.trackId, 'up');
      const ms    = Date.now() - firedAt;
      return { label, title: meta?.title ?? st.trackId, trackId: st.trackId, ack, ms };
    }),
  );

  // ── 8. Per-vote result log ─────────────────────────────────────────────────
  log.step('Ack Results');
  for (const r of results) {
    const isTimeout = r.ack?.error === 'timeout';
    const isErr     = !r.ack || r.ack.error || r.ack.message || typeof r.ack.score === 'undefined';
    const scoreStr  = isErr ? '—' : `score=${c.green}${r.ack.score}${c.reset}`;
    const timeStr   = `${c.dim}+${r.ms}ms${c.reset}`;
    const status    = isTimeout
      ? `${c.yellow}⏱  TIMEOUT${c.reset}`
      : isErr
        ? `${c.red}✘  ERROR: ${JSON.stringify(r.ack)}${c.reset}`
        : `${c.green}✔  OK${c.reset}`;

    console.log(`  ${c.cyan}${r.label}${c.reset}  ${r.title.slice(0, 28).padEnd(28)}  ${scoreStr.padEnd(16)}  ${timeStr.padEnd(14)}  ${status}`);
  }

  // ── 9. Cleanup after run ──────────────────────────────────────────────────
  s1.disconnect();
  s2.disconnect();
  await cleanup('after');

  // ── 10. Final summary ─────────────────────────────────────────────────────
  const ok       = results.filter(r => !r.ack?.error && typeof r.ack?.score !== 'undefined');
  const timeouts = results.filter(r => r.ack?.error === 'timeout');
  const errors   = results.filter(r => r.ack?.error && r.ack.error !== 'timeout');

  console.log(`\n${c.bold}${c.purple}══════════════════════════════════════════════════${c.reset}`);
  console.log(`${c.bold}   Result Summary${c.reset}`);
  console.log(`${c.bold}${c.purple}══════════════════════════════════════════════════${c.reset}`);
  log.row('Votes fired:',  `${results.length} (simultaneously)`);
  log.row('Accepted:',     `${c.green}${ok.length}${c.reset}`);
  log.row('Timed out:',    `${timeouts.length > 0 ? c.yellow : c.dim}${timeouts.length}${c.reset}${timeouts.length > 0 ? `  →  ${timeouts.map(r => r.label).join(', ')}` : ''}`);
  log.row('Errored:',      `${errors.length > 0 ? c.red : c.dim}${errors.length}${c.reset}${errors.length > 0 ? `  →  ${errors.map(r => r.label).join(', ')}` : ''}`);
  log.row('Total time:',   `${Date.now() - firedAt}ms`);

  if (timeouts.length > 0 || errors.length > 0) {
    console.log(`\n  ${c.yellow}${c.bold}⚠  Some votes did not complete — likely a server-side concurrency issue.${c.reset}`);
  } else {
    console.log(`\n  ${c.green}${c.bold}✔  All 4 concurrent votes accepted successfully.${c.reset}`);
  }
  console.log(`${c.bold}${c.purple}══════════════════════════════════════════════════${c.reset}\n`);

  await prisma.$disconnect();
  process.exit(0);
}

// ─── helpers ──────────────────────────────────────────────────────────────────

function startEvent(socket: Socket, eventId: string): Promise<any> {
  return new Promise(resolve => {
    const t = setTimeout(() => resolve({ error: 'timeout' }), 5000);
    socket.emit('event:start', { eventId }, (ack: any) => { clearTimeout(t); resolve(ack); });
  });
}

function emitVote(socket: Socket, eventId: string, trackId: string, vote: 'up' | 'down' | 'none'): Promise<any> {
  return new Promise(resolve => {
    const t = setTimeout(() => resolve({ error: 'timeout' }), 4000);
    socket.emit('track:vote', { eventId, trackId, vote }, (ack: any) => { clearTimeout(t); resolve(ack ?? null); });
  });
}

async function login(identifier: string, password: string): Promise<string> {
  const res = await fetch(`${API_URL}/auth/login`, {
    method:  'POST',
    headers: { 'Content-Type': 'application/json', 'x-platform': 'test-script', 'x-device-model': 'test-environment', 'x-app-version': '1.0.0' },
    body:    JSON.stringify({ identifier, password }),
  });
  if (!res.ok) throw new Error(`Login failed (${identifier}): ${res.status} ${await res.text()}`);
  return ((await res.json()) as any).access_token;
}

async function apiCall(path: string, method: string, token: string, body?: any) {
  let formData: FormData | undefined;
  if (body) {
    formData = new FormData();
    for (const [k, v] of Object.entries(body)) {
      formData.append(k, Array.isArray(v) || typeof v === 'object' ? JSON.stringify(v) : String(v));
    }
  }
  const res = await fetch(`${API_URL}${path}`, {
    method,
    headers: { Authorization: `Bearer ${token}`, 'x-platform': 'test-script', 'x-device-model': 'test-environment', 'x-app-version': '1.0.0' },
    body: formData,
  });
  if (!res.ok) throw new Error(`API [${method} ${path}]: ${res.status} – ${await res.text()}`);
  return res.json();
}

function connectSocket(name: string, token: string): Promise<Socket> {
  return new Promise((resolve, reject) => {
    const client = io(WS_URL, {
      path:         '/ws',
      auth:         { token },
      transports:   ['websocket'],
      extraHeaders: { 'x-platform': 'test-script', 'x-device-model': 'test-environment', 'x-app-version': '1.0.0' },
    });
    client.on('connect',       () => resolve(client));
    client.on('connect_error', (e) => reject(e));
  });
}

function sleep(ms: number) { return new Promise(r => setTimeout(r, ms)); }

main().catch(async err => {
  console.error('Fatal:', err);
  await prisma.$disconnect();
  process.exit(1);
});