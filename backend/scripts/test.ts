import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';
import { io, Socket } from 'socket.io-client';
import * as bcrypt from 'bcrypt';
import * as dotenv from 'dotenv';

dotenv.config();

const API_URL = process.env.API_URL || 'http://localhost:3000';
const WS_URL  = process.env.WS_URL  || 'http://localhost:3000';

const HOST_EMAIL      = 'user3@test.com';
const GUEST_EMAIL     = 'user4@test.com';
const TEST_PASSWORD   = 'Password123!';
const EVENT_NAME      = 'Delegation Test Event';
const YOUTUBE_IDS     = ['zaGHlRk1Aq0', 'dQw4w9WgXcQ'];

const pool    = new Pool({ connectionString: 'postgresql://admin:admin123@64.227.119.126:5432/music_room_dev?schema=public' });
const adapter = new PrismaPg(pool);
const prisma  = new PrismaClient({ adapter });

async function login(identifier: string, password: string): Promise<string> {
  const res = await fetch(`${API_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-platform': 'test-script', 'x-device-model': 'test-environment', 'x-app-version': '1.0.0' },
    body: JSON.stringify({ identifier, password }),
  });
  if (!res.ok) throw new Error(`Login failed: ${res.status} ${await res.text()}`);
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

async function apiCall(path: string, method: string, token: string, body?: Record<string, any>) {
  const res = await fetch(`${API_URL}${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
      'x-platform': 'test-script',
      'x-device-model': 'test-environment',
      'x-app-version': '1.0.0',
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!res.ok) throw new Error(`API [${method} ${path}]: ${res.status} – ${await res.text()}`);
  return res.json();
}

function connectSocket(token: string): Promise<Socket> {
  return new Promise((resolve, reject) => {
    const client = io(WS_URL, {
      path: '/ws',
      auth: { token },
      transports: ['websocket'],
      extraHeaders: { 'x-platform': 'test-script', 'x-device-model': 'test-environment', 'x-app-version': '1.0.0' },
    });
    client.on('connect', () => resolve(client));
    client.on('connect_error', reject);
  });
}

function sleep(ms: number) { return new Promise(r => setTimeout(r, ms)); }

async function main() {
  // ── ensure host user exists ───────────────────────────────────────────
  const passwordHash = await bcrypt.hash(TEST_PASSWORD, 10);

  const existingHost = await prisma.user.findUnique({ where: { email: HOST_EMAIL } });
  if (!existingHost) {
    await prisma.user.create({
      data: { email: HOST_EMAIL, username: 'delegation_host', passwordHash, isEmailVerified: true },
    });
  }

  // ── ensure guest user exists ──────────────────────────────────────────
  const existingGuest = await prisma.user.findUnique({ where: { email: GUEST_EMAIL } });
  let guestId: string;
  if (!existingGuest) {
    const guest = await prisma.user.create({
      data: { email: GUEST_EMAIL, username: 'delegation_guest', passwordHash, isEmailVerified: true },
    });
    guestId = guest.id;
  } else {
    guestId = existingGuest.id;
  }

  const hostToken  = await login(HOST_EMAIL, TEST_PASSWORD);
  const guestToken = await login(GUEST_EMAIL, TEST_PASSWORD);

  // ── 0. create event ───────────────────────────────────────────────────
  console.log('\n── 0. Creating event ────────────────────────────────');
  const created = await apiCallFormData('/events', 'POST', hostToken, {
    name: EVENT_NAME,
    visibility: 'PUBLIC',
    tracks: JSON.stringify(YOUTUBE_IDS),
    startDate: new Date(Date.now() - 3600_000).toISOString(),
    tags: JSON.stringify(['POP']),
  });
  const eventId = created.id;
  console.log(`✅ Event created: ${eventId}`);

  // ── 1. host connects + starts event (websocket) ───────────────────────
  console.log('\n── 1. Host starts event (websocket) ─────────────────');
  const hostSocket = await connectSocket(hostToken);
  hostSocket.on('playback:status', (d: any) => console.log('📡 [host] playback:status', JSON.stringify(d)));
  hostSocket.on('exception',       (d: any) => console.log('⚠️  [host] exception',       JSON.stringify(d)));

  await new Promise((resolve) => {
    const t = setTimeout(() => {
      console.log('event:start ack: ⚠️  TIMEOUT');
      resolve(null);
    }, 5000);
    hostSocket.emit('event:start', { eventId }, (ack: any) => {
      clearTimeout(t);
      console.log('✅ event:start ack:', JSON.stringify(ack));
      resolve(ack);
    });
  });
  await sleep(500);

  // ── 2. guest joins event (websocket) ─────────────────────────────────
  console.log('\n── 2. Guest joins event (websocket) ─────────────────');
  const guestSocket = await connectSocket(guestToken);
  guestSocket.on('playback:status', (d: any) => console.log('📡 [guest] playback:status', JSON.stringify(d)));
  guestSocket.on('exception',       (d: any) => console.log('⚠️  [guest] exception',       JSON.stringify(d)));

  await new Promise((resolve) => {
    const t = setTimeout(() => {
      console.log('event:join ack: ⚠️  TIMEOUT');
      resolve(null);
    }, 5000);
    guestSocket.emit('event:join', { eventId }, (ack: any) => {
      clearTimeout(t);
      console.log('✅ event:join ack:', JSON.stringify(ack));
      resolve(ack);
    });
  });
  await sleep(500);

  // ── 3. host delegates control to guest (endpoint) ─────────────────────
  console.log('\n── 3. Host delegates control to guest (endpoint) ────');
  const delegation = await apiCall(`/events/${eventId}/delegations`, 'POST', hostToken, { delegateeId: guestId });
  console.log('✅ Delegation response:', JSON.stringify(delegation));
  await sleep(500);

  // ── 4. host disconnects ───────────────────────────────────────────────
  console.log('\n── 4. Host disconnects ──────────────────────────────');
  hostSocket.disconnect();
  console.log('✅ Host socket disconnected');
  await sleep(500);

  // ── 5. delegated guest plays the track ───────────────────────────────
  console.log('\n── 5. Delegated guest plays the track ───────────────');
  guestSocket.emit('playback:play', { eventId });
  console.log('→ playback:play emitted by guest');
  await sleep(1000);

  // ── cleanup ───────────────────────────────────────────────────────────
  guestSocket.emit('event:end', { eventId });
  await sleep(500);
  guestSocket.disconnect();

  await prisma.eventTrack.deleteMany({ where: { eventId } });
  await prisma.event.delete({ where: { id: eventId } });

  await prisma.$disconnect();
  console.log('\n👋 Done.');
  process.exit(0);
}

main().catch(err => { console.error('Fatal:', err); process.exit(1); });