import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';
import { io, Socket } from 'socket.io-client';
import * as bcrypt from 'bcrypt';
import * as dotenv from 'dotenv';
import * as readline from 'readline';

dotenv.config();

// ===================== CONFIG ===================== //
const API_URL = 'http://localhost:3000';
const WS_URL = 'http://localhost:3000';

const HOST_EMAIL = 'sim-host@example.com';
const PARTICIPANT_1_EMAIL = 'sim-participant-1@example.com';
const PARTICIPANT_2_EMAIL = 'sim-participant-2@example.com';
const TEST_PASSWORD = 'Password123!';

// WS_EVENTS mirror
const WS_EVENTS = {
  // Emitted BY client (listener events on the server)
  START: 'event:start',
  END: 'event:end',
  HOST_JOIN: 'event:host_join',
  HOST_LEAVE: 'event:host_leave',
  JOIN: 'event:join',

  // Broadcasted BY server (emitted events)
  STATUS: 'event:status',
  STARTED: 'event:started',
  ENDED: 'event:ended',
  PLAYBACK_STATUS: 'playback:status',
  HOST_SOFT_DISCONNECT: 'event:host_soft_disconnect',
  HOST_RECONNECTED: 'event:host_reconnected',
  COUNT: 'event:count',
};

// ===================== STATE ===================== //
const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

// Named sockets map
const sockets: Record<string, Socket> = {};
let EVENT_ID = '';

// ===================== COLORS ===================== //
const C = {
  reset: '\x1b[0m',
  bold: '\x1b[1m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m',
  white: '\x1b[37m',
  gray: '\x1b[90m',
};

function tag(name: string) {
  const colors: Record<string, string> = {
    'host-1': C.magenta,
    'host-2': C.cyan,
    'host-3': C.blue,
    'participant-1': C.green,
    'participant-2': C.yellow,
  };
  const color = colors[name] ?? C.white;
  return `${color}[${name}]${C.reset}`;
}

function log(msg: string) {
  console.log(`${C.gray}[sim]${C.reset} ${msg}`);
}

function logBroadcast(socketName: string, event: string, data: any) {
  console.log(
    `\n  ${tag(socketName)} ${C.bold}← ${event}${C.reset}`,
    JSON.stringify(data, null, 2),
  );
}

// ===================== HELPERS ===================== //
async function login(identifier: string, password: string): Promise<string> {
  const res = await fetch(`${API_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ identifier, password }),
  });
  if (!res.ok) {
    const txt = await res.text();
    throw new Error(`Login failed for ${identifier}: ${res.status} ${txt}`);
  }
  const data: any = await res.json();
  return data.access_token;
}

async function apiCall(path: string, method: string, token: string, body?: any) {
  const res = await fetch(`${API_URL}${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!res.ok) {
    const errorText = await res.text();
    throw new Error(`API Error [${method} ${path}]: ${res.status} - ${errorText}`);
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
        "x-device-id": `${name}-device`, // Custom header to identify the device in server logs
      }
    });

    client.on('connect', () => {
      log(`${tag(name)} connected (id=${client.id})`);
      resolve(client);
    });

    client.on('connect_error', (err) => {
      log(`${tag(name)} ${C.red}connect error:${C.reset} ${err.message}`);
      reject(err);
    });

    // ---- Broadcast listeners ----
    client.on(WS_EVENTS.STATUS, (data) => logBroadcast(name, WS_EVENTS.STATUS, data));
    client.on(WS_EVENTS.STARTED, (data) => logBroadcast(name, WS_EVENTS.STARTED, data));
    client.on(WS_EVENTS.ENDED, (data) => logBroadcast(name, WS_EVENTS.ENDED, data));
    client.on(WS_EVENTS.COUNT, (data) => logBroadcast(name, WS_EVENTS.COUNT, data));
    client.on(WS_EVENTS.HOST_SOFT_DISCONNECT, (data) =>
      logBroadcast(name, WS_EVENTS.HOST_SOFT_DISCONNECT, data),
    );
    client.on(WS_EVENTS.HOST_RECONNECTED, (data) =>
      logBroadcast(name, WS_EVENTS.HOST_RECONNECTED, data),
    );
    client.on(WS_EVENTS.PLAYBACK_STATUS, (data) =>
      logBroadcast(name, WS_EVENTS.PLAYBACK_STATUS, data),
    );
    client.on('disconnect', (reason) => {
      log(`${tag(name)} disconnected — reason: ${reason}`);
    });

    client.on('exception', (data) => {
      log(`${tag(name)} ${C.red}exception:${C.reset} ${JSON.stringify(data)}`);
    });
  });
}

function emitWithAck(socket: Socket, event: string, payload: any, label: string) {
  log(`${tag(label)} → emitting ${C.bold}${event}${C.reset} ${JSON.stringify(payload)}`);
  socket.emit(event, payload, (ack: any) => {
    log(`${tag(label)} ack for ${event}: ${JSON.stringify(ack)}`);
  });
}

function sleep(ms: number) {
  return new Promise((r) => setTimeout(r, ms));
}

// ===================== SETUP ===================== //
async function setup() {
  log('🧹 Cleaning up old simulation data...');

  const emails = [HOST_EMAIL, PARTICIPANT_1_EMAIL, PARTICIPANT_2_EMAIL];

  await prisma.vote.deleteMany({ where: { user: { email: { in: emails } } } });
  await prisma.eventTrack.deleteMany({
    where: { event: { host: { email: { in: emails } } } },
  });
  await prisma.event.deleteMany({ where: { host: { email: { in: emails } } } });
  await prisma.user.deleteMany({ where: { email: { in: emails } } });

  log('🌱 Seeding users...');
  const passwordHash = await bcrypt.hash(TEST_PASSWORD, 10);

  await prisma.user.createMany({
    data: [
      { email: HOST_EMAIL, username: 'sim_host', passwordHash, isEmailVerified: true },
      {
        email: PARTICIPANT_1_EMAIL,
        username: 'sim_participant_1',
        passwordHash,
        isEmailVerified: true,
      },
      {
        email: PARTICIPANT_2_EMAIL,
        username: 'sim_participant_2',
        passwordHash,
        isEmailVerified: true,
      },
    ],
  });

  log('🔑 Logging in...');
  // Host logs in THREE TIMES — three separate tokens (same credentials, three devices)
  const hostToken1 = await login(HOST_EMAIL, TEST_PASSWORD);
  const hostToken2 = await login(HOST_EMAIL, TEST_PASSWORD);
  const hostToken3 = await login(HOST_EMAIL, TEST_PASSWORD);
  const p1Token = await login(PARTICIPANT_1_EMAIL, TEST_PASSWORD);
  const p2Token = await login(PARTICIPANT_2_EMAIL, TEST_PASSWORD);

  log('🎉 Creating event via API (using host-1 token)...');
  const event = await apiCall('/events', 'POST', hostToken1, {
    name: 'Interactive Simulation Event',
    visibility: 'PUBLIC',
    tags: ['POP'],
    invitingOnly: false,
    startDate: new Date().toISOString(),
    tracks: [],
  });

  EVENT_ID = event.id;
  log(`Event created → ID: ${C.bold}${EVENT_ID}${C.reset}`);

  log('🔌 Connecting all sockets...');
  sockets['host-1'] = await connectSocket('host-1', hostToken1);
  sockets['host-2'] = await connectSocket('host-2', hostToken2);
  sockets['host-3'] = await connectSocket('host-3', hostToken3);
  sockets['participant-1'] = await connectSocket('participant-1', p1Token);
  sockets['participant-2'] = await connectSocket('participant-2', p2Token);

  log(`\n${C.green}${C.bold}✅ All sockets connected.${C.reset}`);
}

// ===================== INTERACTIVE CLI ===================== //

function printHelp() {
  console.log(`
${C.bold}━━━ AVAILABLE COMMANDS ━━━${C.reset}

  ${C.cyan}Socket Actors:${C.reset}  host-1, host-2, host-3, participant-1, participant-2

  ${C.yellow}Event Emit Commands:${C.reset}
    start <actor>            → emit ${WS_EVENTS.START}        e.g.  start host-1
    end <actor>              → emit ${WS_EVENTS.END}          e.g.  end host-2
    host-join <actor>        → emit ${WS_EVENTS.HOST_JOIN}    e.g.  host-join host-2
    host-leave <actor>       → emit ${WS_EVENTS.HOST_LEAVE}   e.g.  host-leave host-3
    join <actor>             → emit ${WS_EVENTS.JOIN}         e.g.  join participant-1

  ${C.yellow}Socket Control:${C.reset}
    disconnect <actor>       → forcibly disconnect socket     e.g.  disconnect host-1
    reconnect <actor>        → reconnect a disconnected socket (uses same token in memory)

  ${C.yellow}Utilities:${C.reset}
    status                   → show connection status of all sockets
    event                    → print current EVENT_ID
    sleep <ms>               → pause for N milliseconds       e.g.  sleep 3000
    help                     → show this menu
    exit / quit              → clean up and exit

${C.gray}Tip: Each emit includes an ack callback. Broadcasts appear on ALL connected sockets.${C.reset}
`);
}

// We keep tokens for reconnect support
const tokenMap: Record<string, string> = {};

async function handleCommand(line: string) {
  const parts = line.trim().split(/\s+/);
  const cmd = parts[0]?.toLowerCase();
  const actor = parts[1];

  switch (cmd) {
    // ---- emit commands ----
    case 'start': {
      const sock = requireSocket(actor);
      if (!sock) return;
      emitWithAck(sock, WS_EVENTS.START, { eventId: EVENT_ID }, actor);
      break;
    }
    case 'end': {
      const sock = requireSocket(actor);
      if (!sock) return;
      emitWithAck(sock, WS_EVENTS.END, { eventId: EVENT_ID }, actor);
      break;
    }
    case 'host-join': {
      const sock = requireSocket(actor);
      if (!sock) return;
      emitWithAck(sock, WS_EVENTS.HOST_JOIN, { eventId: EVENT_ID }, actor);
      break;
    }
    case 'host-leave': {
      const sock = requireSocket(actor);
      if (!sock) return;
      emitWithAck(sock, WS_EVENTS.HOST_LEAVE, { eventId: EVENT_ID }, actor);
      break;
    }
    case 'join': {
      const sock = requireSocket(actor);
      if (!sock) return;
      emitWithAck(sock, WS_EVENTS.JOIN, { eventId: EVENT_ID }, actor);
      break;
    }

    // ---- socket control ----
    case 'disconnect': {
      const sock = sockets[actor];
      if (!sock) {
        log(`${C.red}Unknown actor: ${actor}${C.reset}`);
        return;
      }
      log(`${tag(actor)} forcibly disconnecting...`);
      sock.disconnect();
      break;
    }
    case 'reconnect': {
      const token = tokenMap[actor];
      if (!token) {
        log(`${C.red}No stored token for actor: ${actor}. Cannot reconnect.${C.reset}`);
        return;
      }
      if (sockets[actor]?.connected) {
        log(`${tag(actor)} is already connected.`);
        return;
      }
      log(`${tag(actor)} reconnecting...`);
      try {
        sockets[actor] = await connectSocket(actor, token);
      } catch (e: any) {
        log(`${C.red}Reconnect failed: ${e.message}${C.reset}`);
      }
      break;
    }

    // ---- utilities ----
    case 'status': {
      console.log(`\n${C.bold}Socket Status:${C.reset}`);
      for (const [name, sock] of Object.entries(sockets)) {
        const state = sock.connected
          ? `${C.green}connected${C.reset} (id=${sock.id})`
          : `${C.red}disconnected${C.reset}`;
        console.log(`  ${tag(name)} ${state}`);
      }
      console.log(`  Event ID: ${C.bold}${EVENT_ID}${C.reset}\n`);
      break;
    }
    case 'event': {
      log(`Current EVENT_ID: ${C.bold}${EVENT_ID}${C.reset}`);
      break;
    }
    case 'sleep': {
      const ms = parseInt(parts[1], 10);
      if (isNaN(ms)) {
        log(`${C.red}Usage: sleep <milliseconds>${C.reset}`);
        return;
      }
      log(`Sleeping ${ms}ms...`);
      await sleep(ms);
      log('Done sleeping.');
      break;
    }
    case 'help':
      printHelp();
      break;

    case 'exit':
    case 'quit':
      await teardown();
      process.exit(0);

    case '':
    case undefined:
      break;

    default:
      log(`${C.red}Unknown command: ${cmd}${C.reset}. Type ${C.bold}help${C.reset} for the list.`);
  }
}

function requireSocket(actor: string): Socket | null {
  if (!actor) {
    log(`${C.red}Please specify an actor (host-1, host-2, host-3, participant-1, participant-2).${C.reset}`);
    return null;
  }
  const sock = sockets[actor];
  if (!sock) {
    log(`${C.red}Unknown actor: ${actor}${C.reset}`);
    return null;
  }
  if (!sock.connected) {
    log(`${C.yellow}Warning: ${actor} is currently disconnected. Emit may not work.${C.reset}`);
  }
  return sock;
}

// ===================== TEARDOWN ===================== //
async function teardown() {
  log('Disconnecting all sockets...');
  for (const sock of Object.values(sockets)) {
    if (sock.connected) sock.disconnect();
  }

  log('🧹 Cleaning up database...');
  const emails = [HOST_EMAIL, PARTICIPANT_1_EMAIL, PARTICIPANT_2_EMAIL];
  try {
    await prisma.vote.deleteMany({ where: { user: { email: { in: emails } } } });
    await prisma.eventTrack.deleteMany({
      where: { event: { host: { email: { in: emails } } } },
    });
    await prisma.event.deleteMany({ where: { host: { email: { in: emails } } } });
    await prisma.user.deleteMany({ where: { email: { in: emails } } });
  } catch (e) {
    log(`Cleanup error: ${e}`);
  }

  await prisma.$disconnect();
  await pool.end();
  log('Goodbye 👋');
}

// ===================== MAIN ===================== //
async function main() {
  console.log(`\n${C.bold}${C.cyan}🎛  Interactive Event Simulation${C.reset}\n`);

  try {
    await setup();
  } catch (err) {
    console.error(`${C.red}Setup failed:${C.reset}`, err);
    await teardown();
    process.exit(1);
  }

  // Store tokens for reconnect support (re-login to get fresh tokens)
  // Since we already have tokens inside setup() but they're local there,
  // we do another login set here specifically for reconnect map.
  const tHost = await login(HOST_EMAIL, TEST_PASSWORD);
  const tP1 = await login(PARTICIPANT_1_EMAIL, TEST_PASSWORD);
  const tP2 = await login(PARTICIPANT_2_EMAIL, TEST_PASSWORD);
  tokenMap['host-1'] = tHost;
  tokenMap['host-2'] = tHost;
  tokenMap['host-3'] = tHost;
  tokenMap['participant-1'] = tP1;
  tokenMap['participant-2'] = tP2;

  printHelp();

  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
    prompt: `${C.bold}${C.cyan}sim>${C.reset} `,
  });

  rl.prompt();

  rl.on('line', async (line) => {
    try {
      await handleCommand(line);
    } catch (err: any) {
      log(`${C.red}Command error: ${err.message}${C.reset}`);
    }
    rl.prompt();
  });

  rl.on('close', async () => {
    log('stdin closed. Exiting...');
    await teardown();
    process.exit(0);
  });

  // Handle Ctrl+C gracefully
  process.on('SIGINT', async () => {
    console.log('');
    log('SIGINT received. Cleaning up...');
    await teardown();
    process.exit(0);
  });
}

main();