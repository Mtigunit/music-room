import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';
import { io, Socket } from 'socket.io-client';
import * as bcrypt from 'bcrypt';
import * as dotenv from 'dotenv';
import * as readline from 'readline';

dotenv.config();

const API_URL = 'http://localhost:3000';
const WS_URL  = 'http://localhost:3000';

const USER1_EMAIL   = 'vote-user1@example.com';
const USER2_EMAIL   = 'vote-user2@example.com';
const USER3_EMAIL   = 'vote-user3@example.com';
const TEST_PASSWORD = 'Password123!';
const EVENT_NAME    = 'Vote REPL Test Event';

const TRACKS = [
  { providerTrackId: 'wbsLMs3FvHM', title: 'TEST ME (feat. J.I.D.)',              artist: 'Kenny Mason' },
  { providerTrackId: '22izxhm315c', title: 'TEST',                                 artist: 'RazFlow' },
  { providerTrackId: '_TX--Fku9NQ', title: '5.1 Channel Audio Test',               artist: 'K Software Factory' },
  { providerTrackId: 'T8_kY3qejYI', title: 'Nhạc Căng Dồn Dập',                   artist: 'KÊNH NHẠC TEST LOA' },
  { providerTrackId: '-9OM3wfxipA', title: 'Nhạc Bolero Không Lời',                artist: 'Nhạc Test Loa Chuẩn Nhất' },
  { providerTrackId: 'x5tyUM-W-Eg', title: 'SOUNDCHECK VS speaker check',          artist: 'DjKrishna' },
  { providerTrackId: 'hQ4-H-nNNz4', title: 'TEST ME',                              artist: 'ちゃんみな [CHANMINA]' },
  { providerTrackId: 'wMzIHuWh_I0', title: 'Test & Recognise (Flume Re-Work)',     artist: 'Flume' },
  { providerTrackId: '6TWJaFD6R2s', title: 'Left and Right Stereo Sound Test',     artist: 'MasterStudy' },
  { providerTrackId: '2XXM0ONaesA', title: 'Violence Your System Headphone Test',  artist: 'COSMIC BASS' },
  { providerTrackId: 'UceaB4D0jpo', title: 'rockstar ft. 21 Savage',               artist: 'Post Malone' },
  { providerTrackId: 'wXhTHyIgQ_U', title: 'Circles',                              artist: 'Post Malone' },
  { providerTrackId: 'ApXoWvfEYVU', title: 'Sunflower (Spider-Man)',               artist: 'Post Malone' },
  { providerTrackId: 'ba7mB8oueCY', title: 'Goodbyes ft. Young Thug',              artist: 'Post Malone' },
  { providerTrackId: 'SC4xMk98Pdc', title: 'Congratulations ft. Quavo',            artist: 'Post Malone' },
  { providerTrackId: '393C3pr2ioY', title: 'Wow.',                                 artist: 'Post Malone' },
  { providerTrackId: 'SLsTskih7_I', title: 'White Iverson',                        artist: 'Post Malone' },
  { providerTrackId: 'au2n7VVGv_c', title: 'Psycho ft. Ty Dolla $ign',             artist: 'Post Malone' },
  { providerTrackId: '7aekxC_monc', title: 'I Like You ft. Doja Cat',              artist: 'Post Malone' },
  { providerTrackId: 'lCiV4wACZ8w', title: 'Motley Crew',                          artist: 'Post Malone' },
];

// ─── colour helpers ───────────────────────────────────────────────────────────
const c = {
  reset:  '\x1b[0m',
  green:  '\x1b[32m',
  red:    '\x1b[31m',
  yellow: '\x1b[33m',
  blue:   '\x1b[34m',
  cyan:   '\x1b[36m',
  purple: '\x1b[35m',
  bold:   '\x1b[1m',
  dim:    '\x1b[2m',
};

const pool    = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma  = new PrismaClient({ adapter });

// ─── global state ─────────────────────────────────────────────────────────────
// trackIndex → { alias: 'track-1', trackId: uuid, score: number, title: string }
const trackMap = new Map<string, { trackId: string; score: number; title: string; artist: string }>();
// alias → trackId
const aliasMap = new Map<string, string>();

let eventId = '';
const clients: { label: string; socket: Socket }[] = [];

// ─────────────────────────────────────────────────────────────────────────────
async function main() {
  console.log(`\n${c.bold}${c.cyan}🎧  Vote REPL – Interactive Voting Simulation${c.reset}\n`);

  // ── 1. Users ─────────────────────────────────────────────────────────────
  console.log(`${c.dim}── Users ──────────────────────────────────────${c.reset}`);
  const passwordHash = await bcrypt.hash(TEST_PASSWORD, 10);
  for (const email of [USER1_EMAIL, USER2_EMAIL, USER3_EMAIL]) {
    const existing = await prisma.user.findUnique({ where: { email } });
    console.log(existing
      ? `  ${c.dim}exists${c.reset}  ${email}`
      : `  ${c.green}created${c.reset} ${email}`);
    if (!existing) {
      await prisma.user.create({
        data: { email, username: email.split('@')[0].replace(/-/g, '_'), passwordHash, isEmailVerified: true },
      });
    }
  }

  // ── 2. Auth ───────────────────────────────────────────────────────────────
  console.log(`\n${c.dim}── Auth ───────────────────────────────────────${c.reset}`);
  const [t1, t2, t3] = await Promise.all([
    login(USER1_EMAIL, TEST_PASSWORD),
    login(USER2_EMAIL, TEST_PASSWORD),
    login(USER3_EMAIL, TEST_PASSWORD),
  ]);
  console.log('  tokens OK');

  // ── 3. Event ──────────────────────────────────────────────────────────────
  console.log(`\n${c.dim}── Event ──────────────────────────────────────${c.reset}`);
  const existing = await prisma.event.findFirst({
    where: { name: EVENT_NAME, host: { email: USER1_EMAIL } },
  });

  if (existing) {
    eventId = existing.id;
    console.log(`  ${c.dim}exists${c.reset}  "${EVENT_NAME}" (${eventId})`);
  } else {
    const created = await apiCall('/events', 'POST', t1, {
      name: EVENT_NAME,
      visibility: 'PUBLIC',
      tags: ['POP'],
      invitingOnly: false,
      startDate: new Date(Date.now() - 3600_000).toISOString(),
      tracks: TRACKS.map(t => t.providerTrackId),
    });
    eventId = created.id;
    console.log(`  ${c.green}created${c.reset} "${EVENT_NAME}" (${eventId})`);
  }

  // ── 4. Resolve track IDs ──────────────────────────────────────────────────
  console.log(`\n${c.dim}── Tracks ─────────────────────────────────────${c.reset}`);
  const tracksRes = await apiCall(`/events/${eventId}/tracks`, 'GET', t1);
  const serverTracks: any[] = (tracksRes.data ?? tracksRes).sort((a: any, b: any) =>
    a.trackId.localeCompare(b.trackId),
  );

  serverTracks.forEach((st, i) => {
    const alias  = `track-${i + 1}`;
    const meta   = TRACKS.find(t => t.providerTrackId === st.providerTrackId) ??
                   { title: st.title ?? st.trackId, artist: st.artist ?? '' };
    trackMap.set(alias, { trackId: st.trackId, score: st.voteScore ?? 0, title: meta.title, artist: meta.artist });
    aliasMap.set(alias, st.trackId);
    console.log(`  ${c.cyan}${alias.padEnd(10)}${c.reset} ${meta.title.slice(0, 42).padEnd(42)} ${c.dim}${st.trackId}${c.reset}`);
  });

  // ── 5. Sockets ────────────────────────────────────────────────────────────
  console.log(`\n${c.dim}── Sockets ────────────────────────────────────${c.reset}`);
  const [s1, s2, s3] = await Promise.all([
    connectSocket('user1', t1),
    connectSocket('user2', t2),
    connectSocket('user3', t3),
  ]);
  clients.push({ label: 'user1', socket: s1 });
  clients.push({ label: 'user2', socket: s2 });
  clients.push({ label: 'user3', socket: s3 });

  // attach broadcast listener to all sockets
  for (const { label, socket } of clients) {
    socket.on('track:vote_updated', (data: any) => onBroadcast(label, data));
  }

  // ── 6. Start event & join ────────────────────────────────────────────────
  console.log(`\n${c.dim}── Starting event ─────────────────────────────${c.reset}`);
  await startEvent(s1, eventId);
  s2.emit('event:join', { eventId });
  s3.emit('event:join', { eventId });
  await sleep(500);
  console.log('  all joined');

  // ── 7. REPL ───────────────────────────────────────────────────────────────
  printBoard();
  printHelp();
  startREPL(s1, s2, s3);
}

// ─── REPL ─────────────────────────────────────────────────────────────────────
function startREPL(s1: Socket, s2: Socket, s3: Socket) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });

  const prompt = () => rl.question(`\n${c.bold}vote>${c.reset} `, async (raw) => {
    const line = raw.trim().toLowerCase();

    if (line === 'q' || line === 'quit') {
      await shutdown();
      rl.close();
      return;
    }

    if (line === 'board' || line === 'b') {
      printBoard();
      return prompt();
    }

    if (line === 'help' || line === '?') {
      printHelp();
      return prompt();
    }

    // parse: [user] <up|down|none> <track-N>
    //   e.g. "up track-3"  or  "user2 down track-5"
    const parts = line.split(/\s+/);
    let userLabel = 'user1';
    let action: string;
    let alias: string;

    if (parts.length === 3) {
      [userLabel, action, alias] = parts;
    } else if (parts.length === 2) {
      [action, alias] = parts;
    } else {
      console.log(`${c.red}  ✘  unknown command — type "help"${c.reset}`);
      return prompt();
    }

    if (!['up', 'down', 'none'].includes(action)) {
      console.log(`${c.red}  ✘  action must be up | down | none${c.reset}`);
      return prompt();
    }

    const trackEntry = trackMap.get(alias);
    if (!trackEntry) {
      console.log(`${c.red}  ✘  unknown alias "${alias}" — try track-1 … track-${trackMap.size}${c.reset}`);
      return prompt();
    }

    const socketMap: Record<string, Socket> = { user1: s1, user2: s2, user3: s3 };
    const socket = socketMap[userLabel];
    if (!socket) {
      console.log(`${c.red}  ✘  unknown user "${userLabel}" — use user1 | user2 | user3${c.reset}`);
      return prompt();
    }

    console.log(`  ${c.dim}→ [${userLabel}] ${action} ${alias} (${trackEntry.trackId})${c.reset}`);
    const ack = await emitVote(socket, eventId, trackEntry.trackId, action as any);

    if (isError(ack)) {
      console.log(`  ${c.red}✘ ack error:${c.reset}`, JSON.stringify(ack));
    } else {
      // update local score from ack
      trackEntry.score = ack.score;
      console.log(`  ${c.green}✔ ack score: ${ack.score}${c.reset}`);
    }

    // board will auto-refresh after broadcast; give it a moment then prompt
    await sleep(300);
    printBoard();
    prompt();
  });

  prompt();
}

// ─── broadcast handler ────────────────────────────────────────────────────────
function onBroadcast(from: string, data: any) {
  // find alias for trackId
  let alias = '?';
  for (const [a, entry] of trackMap.entries()) {
    if (entry.trackId === data.trackId) {
      alias = a;
      entry.score = data.score; // update local cache
      break;
    }
  }

  console.log(
    `\n  ${c.purple}📡 [${from}] broadcast${c.reset}  ` +
    `${c.cyan}${alias}${c.reset}  score=${c.bold}${data.score}${c.reset}  ` +
    `updatedAt=${c.dim}${data.updatedAt ?? '—'}${c.reset}`,
  );
}

// ─── board ────────────────────────────────────────────────────────────────────
function printBoard() {
  const entries = [...trackMap.entries()].sort((a, b) => b[1].score - a[1].score);
  console.log(`\n${c.bold}  ── Scoreboard ──────────────────────────────────────${c.reset}`);
  for (const [alias, { score, title, artist }] of entries) {
    const bar   = scoreBar(score);
    const label = `${alias.padEnd(9)} ${title.slice(0, 34).padEnd(34)} ${c.dim}${artist.slice(0, 16).padEnd(16)}${c.reset}`;
    const sc    = score > 0 ? `${c.green}[${score}]${c.reset}` : score < 0 ? `${c.red}[${score}]${c.reset}` : `${c.dim}[0]${c.reset}`;
    console.log(`  ${label}  ${bar}  ${sc}`);
  }
  console.log(`  ${'─'.repeat(54)}`);
}

function scoreBar(score: number): string {
  const MAX = 10;
  const filled = Math.min(Math.abs(score), MAX);
  if (score > 0) return `${c.green}${'▮'.repeat(filled)}${'▯'.repeat(MAX - filled)}${c.reset}`;
  if (score < 0) return `${c.red}  ${'▯'.repeat(MAX - filled)}${'▮'.repeat(filled)}${c.reset}`;
  return `${c.dim}${'▯'.repeat(MAX)}${c.reset}`;
}

function printHelp() {
  console.log(`
  ${c.bold}Commands:${c.reset}
    up track-N          vote UP as user1
    down track-N        vote DOWN as user1
    none track-N        remove vote as user1
    user2 up track-N    vote as user2 (user1 | user2 | user3)
    board / b           refresh scoreboard
    help / ?            show this
    quit / q            exit
`);
}

// ─── helpers ─────────────────────────────────────────────────────────────────

async function startEvent(socket: Socket, evId: string): Promise<any> {
  return new Promise((resolve) => {
    const t = setTimeout(() => resolve({ error: 'timeout' }), 5000);
    socket.emit('event:start', { eventId: evId }, (ack: any) => {
      clearTimeout(t);
      console.log(`  event:start ack: ${JSON.stringify(ack)}`);
      resolve(ack);
    });
  });
}

function emitVote(socket: Socket, evId: string, trackId: string, vote: 'up' | 'down' | 'none'): Promise<any> {
  return new Promise((resolve) => {
    const t = setTimeout(() => resolve(null), 4000);
    socket.emit('track:vote', { eventId: evId, trackId, vote }, (ack: any) => {
      clearTimeout(t);
      resolve(ack ?? null);
    });
  });
}

function isError(ack: any): boolean {
  if (ack === null || ack === undefined) return true;
  if (ack.error || ack.message || ack.status === 'error') return true;
  if (typeof ack.score === 'undefined') return true;
  return false;
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
    client.on('connect',       () => { console.log(`  🔗 [${name}] connected`); resolve(client); });
    client.on('connect_error', (e) => { console.error(`  ❌ [${name}] ${e.message}`); reject(e); });
    client.on('exception',     (e) => console.warn(`  ⚠️  [${name}] exception:`, e));
    client.on('disconnect',    (r) => console.log(`  🔌 [${name}] disconnected: ${r}`));
  });
}

function sleep(ms: number) { return new Promise(r => setTimeout(r, ms)); }

async function shutdown() {
  console.log('\n\n🛑  Shutting down...');
  clients.forEach(({ socket }) => socket.disconnect());
  await prisma.$disconnect();
  console.log('👋  Bye.');
  process.exit(0);
}

process.on('SIGINT',  shutdown);
process.on('SIGTERM', shutdown);

main().catch(err => { console.error('Fatal:', err); process.exit(1); });