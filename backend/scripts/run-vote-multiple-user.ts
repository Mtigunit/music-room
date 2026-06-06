import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';
import { io, Socket } from 'socket.io-client';
import * as bcrypt from 'bcrypt';
import * as dotenv from 'dotenv';

dotenv.config();

const API_URL = 'http://localhost:3000';
const WS_URL  = 'http://localhost:3000';

const TEST_PASSWORD = 'Password123!';
const EVENT_NAME    = 'Concurrent Users Vote Test Event';

const USERS = [
  'vote-user1@example.com',
  'vote-user2@example.com',
  'vote-user3@example.com',
  'vote-user4@example.com',
  'vote-user5@example.com',
  'vote-user6@example.com',
  'user2@test.com',
  'user3@test.com',
  'user4@test.com',
  'user5@test.com',
  // 'user6@test.com',
  // 'user7@test.com',
  // 'user8@test.com',
  // 'user9@test.com',
  // 'user10@test.com',
  // 'user11@test.com',
  // 'user12@test.com',
];

// Only one track — all 6 users vote on it simultaneously
const TRACKS = [
{ providerTrackId: 'wXhTHyIgQ_U', title: 'Circles',                 artist: 'Post Malone' },
  { providerTrackId: 'UceaB4D0jpo', title: 'rockstar ft. 21 Savage', artist: 'Post Malone' },
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
  info: (msg: string)                => console.log(`  ${c.dim}${msg}${c.reset}`),
  row:  (label: string, val: string) => console.log(`  ${label.padEnd(20)} ${val}`),
};

const pool    = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma  = new PrismaClient({ adapter });

// ─── cleanup ──────────────────────────────────────────────────────────────────
async function cleanup(phase: 'before' | 'after') {
  log.step(`Cleanup (${phase} run)`);

  const event = await prisma.event.findFirst({
    where:   { name: EVENT_NAME, host: { email: USERS[0] } },
    include: { tracks: true },
  });

  if (!event) {
    log.info('nothing to clean');
    return;
  }

  const trackIds = event.tracks.map(t => t.id);

  const deletedVotes = await prisma.eventTrack.deleteMany({ where: { eventId: event.id } });
  log.ok(`deleted ${deletedVotes.count} vote(s)`);

  const deletedEventTracks = await prisma.eventTrack.deleteMany({ where: { eventId: event.id } });
  log.ok(`deleted ${deletedEventTracks.count} event track(s)`);

  if (trackIds.length > 0) {
    const deletedTracks = await prisma.track.deleteMany({
      where: { id: { in: trackIds }, eventTracks: { none: {} } },
    });
    log.ok(`deleted ${deletedTracks.count} track record(s)`);
  }

  await prisma.event.delete({ where: { id: event.id } });
  log.ok(`deleted event "${EVENT_NAME}"`);
}

// ─────────────────────────────────────────────────────────────────────────────
async function main() {
  console.log(`\n${c.bold}${c.purple}══════════════════════════════════════════════════${c.reset}`);
  console.log(`${c.bold}${c.purple}   Concurrent Vote Test — 6 users × 1 track × 1 tick${c.reset}`);
  console.log(`${c.bold}${c.purple}══════════════════════════════════════════════════${c.reset}`);

  // ── 0. Clean leftovers ────────────────────────────────────────────────────
  await cleanup('before');

  // ── 1. Users ──────────────────────────────────────────────────────────────
  log.step('Users');
  const passwordHash = await bcrypt.hash(TEST_PASSWORD, 10);
  for (const email of USERS) {
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

  // ── 2. Auth — all 6 in parallel ──────────────────────────────────────────
  log.step('Auth');
  const DELAY_MS = 5000; // change gap here
  const tokens: any[] = [];

  for (const [i, email] of USERS.entries()) {
    const token = await login(email, TEST_PASSWORD);
    tokens.push(token);

    log.ok(`user${i + 1} token OK  ${c.dim}(${email})${c.reset}`);

    // gap between requests (skip after last one)
    if (i < USERS.length - 1) {
      await new Promise(resolve => setTimeout(resolve, DELAY_MS));
    }
  }

  // ── 3. Event (user1 creates with the single track) ────────────────────────
  log.step('Event');
  const created = await apiCall('/events', 'POST', tokens[0], {
    name:         EVENT_NAME,
    visibility:   'PUBLIC',
    tags:         ['POP'],
    invitingOnly: false,
    startDate:    new Date(Date.now() - 3600_000).toISOString(),
    tracks:       TRACKS,
  });
  const eventId = created.id;
  log.ok(`created  "${EVENT_NAME}"`);
  log.info(`eventId  ${eventId}`);

  // ── 4. Resolve the track ID from server ───────────────────────────────────
  log.step('Track');
  const tracksRes  = await apiCall(`/events/${eventId}/tracks`, 'GET', tokens[0]);
  const serverTrack = (tracksRes.data ?? tracksRes)[1];
  log.ok(`"${TRACKS[1].title}"  ${c.dim}${serverTrack.trackId}${c.reset}`);

  // ── 5. Sockets — all 6 in parallel ───────────────────────────────────────
  log.step('Sockets');
  const sockets = await Promise.all(
    USERS.map((_, i) => connectSocket(`user${i + 1}`, tokens[i])),
  );
  USERS.forEach((_, i) => log.ok(`user${i + 1} connected`));

  // ── 6. user1 starts, users 2-6 join ──────────────────────────────────────
  log.step('Start & Join');
  const startAck = await startEvent(sockets[0], eventId);
  log.ok(`user1 started event  →  ${JSON.stringify(startAck)}`);

  await Promise.all(
    sockets.slice(1).map(s => new Promise<void>(resolve => {
      s.emit('event:join', { eventId });
      resolve();
    })),
  );
  await sleep(300);
  log.ok('users 2-6 joined event');

  // ── 7. All 6 vote UP on the same track — simultaneously ───────────────────
  log.step('Concurrent Votes  (all 6 users vote on the same track in the same Promise.all tick)');

  const firedAt = Date.now();
  const results = await Promise.all(
    sockets.map(async (socket, i) => {
      const label = `user${i + 1}`;
      const ack   = await emitVote(socket, eventId, serverTrack.trackId, 'up');
      const ms    = Date.now() - firedAt;
      return { label, ack, ms };
    }),
  );

  // ── 8. Per-user ack log ───────────────────────────────────────────────────
  log.step('Ack Results');
  for (const r of results) {
    const isTimeout = r.ack?.error === 'timeout';
    const isErr     = !r.ack || r.ack.error || r.ack.message || typeof r.ack.score === 'undefined';
    const scoreStr  = isErr ? `${c.dim}score=—${c.reset}` : `score=${c.green}${r.ack.score}${c.reset}`;
    const timeStr   = `${c.dim}+${r.ms}ms${c.reset}`;
    const status    = isTimeout
      ? `${c.yellow}⏱  TIMEOUT${c.reset}`
      : isErr
        ? `${c.red}✘  ERROR: ${JSON.stringify(r.ack)}${c.reset}`
        : `${c.green}✔  OK${c.reset}`;

    console.log(`  ${c.cyan}${r.label.padEnd(8)}${c.reset}  ${scoreStr.padEnd(20)}  ${timeStr.padEnd(12)}  ${status}`);
  }

  // ── 9. Read final score from DB ───────────────────────────────────────────
  log.step('Final DB State');
  const dbTrack = await prisma.eventTrack.findFirst({
    where: { eventId, trackId: serverTrack.trackId },
  });
  const dbVotes = await prisma.eventTrack
  .findMany({
    where: { eventId, trackId: serverTrack.trackId },
  });

  log.info(`track    "${TRACKS[1].title}"`);
  log.ok(`score in DB      : ${c.bold}${dbTrack?.voteScore ?? '?'}${c.reset}  (expected: ${c.bold}${results.filter(r => !r.ack?.error && typeof r.ack?.score !== 'undefined').length}${c.reset})`);
  log.ok(`vote rows in DB  : ${c.bold}${dbVotes.length}${c.reset}  (expected: ${c.bold}6${c.reset})`);

  // ── 10. Cleanup ───────────────────────────────────────────────────────────
  sockets.forEach(s => s.disconnect());
//   await cleanup('after');

  // ── 11. Final summary ─────────────────────────────────────────────────────
  const ok       = results.filter(r => !r.ack?.error && typeof r.ack?.score !== 'undefined');
  const timeouts = results.filter(r => r.ack?.error === 'timeout');
  const errors   = results.filter(r => r.ack?.error && r.ack.error !== 'timeout');

  console.log(`\n${c.bold}${c.purple}══════════════════════════════════════════════════${c.reset}`);
  console.log(`${c.bold}   Result Summary${c.reset}`);
  console.log(`${c.bold}${c.purple}══════════════════════════════════════════════════${c.reset}`);
  log.row('Track:',           `"${TRACKS[1].title}"`);
  log.row('Votes fired:',     `6 (simultaneously)`);
  log.row('Accepted:',        `${c.green}${ok.length}${c.reset}`);
  log.row('Timed out:',       `${timeouts.length > 0 ? c.yellow : c.dim}${timeouts.length}${c.reset}${timeouts.length > 0 ? `  →  ${timeouts.map(r => r.label).join(', ')}` : ''}`);
  log.row('Errored:',         `${errors.length > 0 ? c.red : c.dim}${errors.length}${c.reset}${errors.length > 0 ? `  →  ${errors.map(r => r.label).join(', ')}` : ''}`);
  log.row('Score (ack):',     ok.length > 0 ? `${c.green}${ok[ok.length - 1].ack.score}${c.reset}  (last ack received)` : `${c.dim}—${c.reset}`);
  log.row('Score (DB):',      `${c.bold}${dbTrack?.voteScore ?? '?'}${c.reset}`);
  log.row('Vote rows (DB):',  `${c.bold}${dbVotes.length}${c.reset}`);
  log.row('Total time:',      `${Date.now() - firedAt}ms`);

  const scoreMatch = dbTrack?.voteScore === ok.length;
  const rowsMatch  = dbVotes.length === 6;

  console.log('');
  if (!scoreMatch)  console.log(`  ${c.red}${c.bold}⚠  Score mismatch — DB has ${dbTrack?.voteScore}, expected ${ok.length}. Race condition on write.${c.reset}`);
  if (!rowsMatch)   console.log(`  ${c.red}${c.bold}⚠  Vote row count mismatch — DB has ${dbVotes.length}, expected 6. Some writes were lost or duplicated.${c.reset}`);
  if (timeouts.length > 0) console.log(`  ${c.yellow}${c.bold}⚠  ${timeouts.length} vote(s) timed out — server may have dropped concurrent requests.${c.reset}`);

  if (scoreMatch && rowsMatch && timeouts.length === 0 && errors.length === 0) {
    console.log(`  ${c.green}${c.bold}✔  All 6 concurrent votes accepted and persisted correctly.${c.reset}`);
    console.log(`  ${c.green}${c.bold}✔  Final score = ${dbTrack?.voteScore} ✓${c.reset}`);
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