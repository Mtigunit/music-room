import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';
import { io, Socket } from 'socket.io-client';
import * as bcrypt from 'bcrypt';
import * as dotenv from 'dotenv';
import * as readline from 'readline';

dotenv.config();

const API_URL = process.env.API_URL || 'http://localhost:3000';
const WS_URL  = process.env.WS_URL  || 'http://localhost:3000';

const HOST_EMAIL  = 'playback-host@example.com';
const GUEST_EMAIL = 'playback-guest@example.com';
const TEST_PASSWORD = 'Password123!';
const EVENT_NAME    = 'Playback REPL Test Event';

const YOUTUBE_IDS = ['zaGHlRk1Aq0', 'dQw4w9WgXcQ', '9bZkp7q19f0'];

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
let eventId    = '';
let hostClient:  Socket;
let guestClient: Socket;

const trackMap = new Map<string, { id: string; title: string }>();

const lastStatus: {
  status?: string;
  currentStartedAt?: string | null;
  pausedPlaybackPositionMs?: number | null;
} = {};

// readline kept at module level so broadcast handlers can reprompt safely
let rl: readline.Interface;

// Print without corrupting the readline prompt:
// erase current input line → print message → rewrite prompt
function print(msg: string) {
  if (rl) {
    readline.clearLine(process.stdout, 0);
    readline.cursorTo(process.stdout, 0);
  }
  console.log(msg);
  if (rl) process.stdout.write(`\n${c.bold}playback>${c.reset} `);
}

// ─────────────────────────────────────────────────────────────────────────────
async function main() {
  console.log(`\n${c.bold}${c.cyan}▶  Playback REPL – Interactive Simulation${c.reset}\n`);

  // ── 1. Users ─────────────────────────────────────────────────────────────
  console.log(`${c.dim}── Users ──────────────────────────────────────${c.reset}`);
  const passwordHash = await bcrypt.hash(TEST_PASSWORD, 10);
  for (const [email, username] of [[HOST_EMAIL, 'playback_host'], [GUEST_EMAIL, 'playback_guest']]) {
    const existing = await prisma.user.findUnique({ where: { email } });
    console.log(existing
      ? `  ${c.dim}exists${c.reset}  ${email}`
      : `  ${c.green}created${c.reset} ${email}`);
    if (!existing) {
      await prisma.user.create({ data: { email, username, passwordHash, isEmailVerified: true } });
    }
  }

  // ── 2. Auth ───────────────────────────────────────────────────────────────
  console.log(`\n${c.dim}── Auth ───────────────────────────────────────${c.reset}`);
  const [hostToken, guestToken] = await Promise.all([
    login(HOST_EMAIL,  TEST_PASSWORD),
    login(GUEST_EMAIL, TEST_PASSWORD),
  ]);
  console.log('  tokens OK');

  // ── 3. Event ──────────────────────────────────────────────────────────────
  console.log(`\n${c.dim}── Event ──────────────────────────────────────${c.reset}`);
  const existing = await prisma.event.findFirst({
    where: { name: EVENT_NAME, host: { email: HOST_EMAIL } },
  });

  if (existing) {
    eventId = existing.id;
    console.log(`  ${c.dim}exists${c.reset}  "${EVENT_NAME}" (${eventId})`);
  } else {
    const created = await apiCallFormData('/events', 'POST', hostToken, {
      name:       EVENT_NAME,
      visibility: 'PUBLIC',
      tracks:     JSON.stringify(YOUTUBE_IDS),
      startDate:  new Date(Date.now() - 3600_000).toISOString(),
      tags:       JSON.stringify(['POP']),
    });
    eventId = created.id;
    console.log(`  ${c.green}created${c.reset} "${EVENT_NAME}" (${eventId})`);
  }

  // ── 4. Resolve tracks ─────────────────────────────────────────────────────
  console.log(`\n${c.dim}── Tracks ─────────────────────────────────────${c.reset}`);
  const tracksRes = await apiCallFormData(`/events/${eventId}/tracks`, 'GET', hostToken);
  const tracks: any[] = (tracksRes.data ?? tracksRes);
  tracks.forEach((t, i) => {
    const alias = `track-${i + 1}`;
    trackMap.set(alias, { id: t.id, title: t.title ?? t.trackId ?? t.id });
    console.log(`  ${c.cyan}${alias.padEnd(9)}${c.reset} ${(t.title ?? t.id).slice(0, 50)}  ${c.dim}${t.id}${c.reset}`);
  });

  // ── 5. Sockets ────────────────────────────────────────────────────────────
  console.log(`\n${c.dim}── Sockets ────────────────────────────────────${c.reset}`);
  [hostClient, guestClient] = await Promise.all([
    connectSocket('host',  hostToken,  true),
    connectSocket('guest', guestToken, false),
  ]);

  // ── 6. Start event & join ─────────────────────────────────────────────────
  console.log(`\n${c.dim}── Starting event ─────────────────────────────${c.reset}`);
  await startEvent(hostClient, eventId);
  guestClient.emit('event:join', { eventId });
  await sleep(500);
  console.log('  guest joined');

  // ── 7. REPL ───────────────────────────────────────────────────────────────
  printHelp();
  startREPL();
}

// ─── REPL ─────────────────────────────────────────────────────────────────────
function startREPL() {
  rl = readline.createInterface({ input: process.stdin, output: process.stdout });

  const prompt = () => {
    rl.question(`\n${c.bold}playback>${c.reset} `, async (raw) => {
      const line = raw.trim().toLowerCase();

      if (line === 'q' || line === 'quit') {
        await shutdown();
        return;
      }

      if (line === 'help' || line === '?') {
        printHelp();
        return prompt();
      }

      if (line === 'play') {
        hostClient.emit('playback:play', { eventId });
        return prompt();
      }

      if (line === 'pause') {
        hostClient.emit('playback:pause', { eventId });
        return prompt();
      }

      if (line === 'next' || line.startsWith('next ')) {
        const alias = line.split(/\s+/)[1];
        const payload: any = { eventId };
        if (alias) {
          const entry = trackMap.get(alias);
          if (!entry) {
            console.log(`${c.red}  ✘  unknown alias "${alias}"${c.reset}`);
            return prompt();
          }
          payload.trackId = entry.id;
          console.log(`  ${c.dim}staleness trackId: ${entry.id}${c.reset}`);
        }
        hostClient.emit('playback:next', payload);
        return prompt();
      }

      if (line === 'end') {
        hostClient.emit('event:end', { eventId });
        return prompt();
      }

      if (line === 'guest play') {
        console.log(`  ${c.dim}→ as guest (expect Forbidden)${c.reset}`);
        guestClient.emit('playback:play', { eventId });
        return prompt();
      }

      if (line === 'pos' || line === 'position') {
        console.log(`lastStatus: ${JSON.stringify(lastStatus)}`);
        const { status, currentStartedAt, pausedPlaybackPositionMs } = lastStatus;
        const paused  = pausedPlaybackPositionMs ?? 0;
        const startedAt = currentStartedAt ? new Date(currentStartedAt).getTime() : Date.now();
        const elapsed = Date.now() - startedAt;
        // position = (now - (currentTrackStartedAt ?? now)) + pausedPlaybackPositionMs
        const pos  = elapsed + paused;

        const mins = Math.floor(pos / 60_000);
        const secs = Math.floor((pos % 60_000) / 1000);
        const ms   = pos % 1000;
        console.log(
        `  ${c.cyan}position${c.reset}  ${mins}:${String(secs).padStart(2, '0')}.${String(ms).padStart(3, '0')}` +
        `  ${c.dim}(${pos} ms)${c.reset}  status=${c.bold}${status ?? '?'}${c.reset}`,
        );
        return prompt();
      }

      if (line === 'disconnect host') {
        hostClient.disconnect();
        console.log(`  ${c.yellow}host disconnected${c.reset}`);
        return prompt();
      }

      if (line === 'reconnect host') {
        const token = await login(HOST_EMAIL, TEST_PASSWORD);
        hostClient = await connectSocket('host (reconnected)', token, true);
        hostClient.emit('event:host_join', { eventId });
        await sleep(400);
        console.log(`  ${c.green}host reconnected and rejoined${c.reset}`);
        return prompt();
      }

      console.log(`${c.red}  ✘  unknown command — type "help"${c.reset}`);
      prompt();
    });
  };

  prompt();
}

// ─── broadcast listeners ──────────────────────────────────────────────────────
function attachListeners(socket: Socket, label: string, isHost: boolean) {
  socket.on('playback:status', (data: any) => {
    const ct = data?.currentTrack ?? null;
    // only the host socket updates lastStatus (single source of truth)
    lastStatus.status = data?.status;
    lastStatus.currentStartedAt = data?.currentTrack?.currentTrackStartedAt;
    lastStatus.pausedPlaybackPositionMs = data?.currentTrack?.pausedPlaybackPositionMs;
    const track = ct ? findAlias(ct.id) + `  (${ct.id})` : 'null';

    print(
      `  ${c.purple}📡 [${label}] playback:status${c.reset}` +
      `  status=${c.bold}${data?.status}${c.reset}` +
      `  track=${c.cyan}${track}${c.reset}` +
      (ct?.pausedPlaybackPositionMs != null
        ? `  pausedAt=${c.dim}${ct.pausedPlaybackPositionMs}ms${c.reset}`
        : ''),
    );
  });

  socket.on('event:started', (data: any) =>
    print(`  ${c.yellow}📡 [${label}] event:started${c.reset}  status=${data?.status}`));

  socket.on('event:host_reconnected', (data: any) =>
    print(`  ${c.cyan}📡 [${label}] event:host_reconnected${c.reset}  hostId=${data?.hostId}`));

  socket.on('exception', (data: any) =>
    print(`  ${c.red}⚠  [${label}] exception${c.reset}  ${data?.message ?? JSON.stringify(data)}`));
}

function findAlias(trackId: string): string {
  for (const [alias, entry] of trackMap.entries()) {
    if (entry.id === trackId) return alias;
  }
  return '?';
}

// ─── helpers ──────────────────────────────────────────────────────────────────
function printHelp() {
  console.log(`
  ${c.bold}Commands:${c.reset}
    play                  host → playback:play
    pause                 host → playback:pause
    next                  host → playback:next (no staleness check)
    next track-N          host → playback:next with trackId staleness check
    end                   host → event:end
    guest play            guest → playback:play  (expect Forbidden)
    pos / position        calculate current position from last broadcast
    disconnect host       disconnect the host socket
    reconnect host        reconnect host and rejoin
    help / ?              show this
    quit / q              exit
`);
}

function startEvent(socket: Socket, evId: string): Promise<any> {
  return new Promise((resolve) => {
    const t = setTimeout(() => resolve({ error: 'Timeout' }), 5000);
    socket.emit('event:start', { eventId: evId }, (ack: any) => {
      clearTimeout(t);
      console.log(`  event:start ack: ${JSON.stringify(ack)}`);
      resolve(ack ?? null);
    });
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

async function apiCallFormData(path: string, method: string, token: string, body?: Record<string, any>) {
  let formData: FormData | undefined;
  if (body) {
    formData = new FormData();
    for (const [k, v] of Object.entries(body)) {
      formData.append(k, typeof v === 'string' ? v : JSON.stringify(v));
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

function connectSocket(name: string, token: string, isHost = false): Promise<Socket> {
  return new Promise((resolve, reject) => {
    const client = io(WS_URL, {
      path:         '/ws',
      auth:         { token },
      transports:   ['websocket'],
      extraHeaders: { 'x-platform': 'test-script', 'x-device-model': 'test-environment', 'x-app-version': '1.0.0' },
    });
    client.on('connect', () => {
      console.log(`  🔗 [${name}] connected`);
      attachListeners(client, name, isHost);
      resolve(client);
    });
    client.on('connect_error', (e) => { console.error(`  ❌ [${name}] ${e.message}`); reject(e); });
    client.on('disconnect',    (r) => print(`  🔌 [${name}] disconnected: ${r}`));
  });
}

function sleep(ms: number) { return new Promise(r => setTimeout(r, ms)); }

async function shutdown() {
  console.log('\n🛑  Shutting down...');
  rl?.close();
  hostClient.emit('event:end', { eventId });
  await sleep(2000);
  hostClient?.disconnect();
  guestClient?.disconnect();

    console.log('🗑️  Cleaning up event and tracks...');
    await prisma.eventTrack.deleteMany();
    await prisma.track.deleteMany();
    await prisma.event.deleteMany();
    console.log('✅  Event and tracks deleted.');

  await prisma.$disconnect();
  console.log('👋  Bye.');
  process.exit(0);
}

process.on('SIGINT',  shutdown);
process.on('SIGTERM', shutdown);

main().catch(err => { console.error('Fatal:', err); process.exit(1); });