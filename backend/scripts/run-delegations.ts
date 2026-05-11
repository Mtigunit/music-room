import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';
import { io, Socket } from 'socket.io-client';
import * as bcrypt from 'bcrypt';
import * as dotenv from 'dotenv';

dotenv.config();

const API_URL = 'http://localhost:3000';
const WS_URL = 'http://localhost:3000';

const HOST_EMAIL    = 'host-delegation@example.com';
const USER1_EMAIL   = 'user1-delegation@example.com';
const USER2_EMAIL   = 'user2-delegation@example.com';
const USER3_EMAIL   = 'user3-delegation@example.com';
const TEST_PASSWORD = 'Password123!';
const EVENT_NAME    = 'Delegation Simulation Event';

const pool    = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma  = new PrismaClient({ adapter });

// ─── unique device-id helper ────────────────────────────────────────────────
const usedNums = new Set<number>();
function uniqueRandom(): number {
    if (usedNums.size >= 100) throw new Error('All device slots used');
    let n: number;
    do { n = Math.floor(Math.random() * 100) + 1; } while (usedNums.has(n));
    usedNums.add(n);
    return n;
}

// ─── main ────────────────────────────────────────────────────────────────────
async function main() {
    console.log('🚀  Starting Persistent Delegation Simulation...');
    console.log('📋  DB:', process.env.DATABASE_URL);

    // ── 1. Ensure users exist ────────────────────────────────────────────────
    const emails = [HOST_EMAIL, USER1_EMAIL, USER2_EMAIL, USER3_EMAIL];
    const passwordHash = await bcrypt.hash(TEST_PASSWORD, 10);

    for (const email of emails) {
        const existing = await prisma.user.findUnique({ where: { email } });
        if (existing) {
            console.log(`✅  User already exists: ${email}`);
        } else {
            await prisma.user.create({
                data: {
                    email,
                    username: email.split('@')[0].replace(/-/g, '_'),
                    passwordHash,
                    isEmailVerified: true,
                },
            });
            console.log(`🌱  Created user: ${email}`);
        }
    }

    const host  = await prisma.user.findUniqueOrThrow({ where: { email: HOST_EMAIL } });
    const user1 = await prisma.user.findUniqueOrThrow({ where: { email: USER1_EMAIL } });
    const user2 = await prisma.user.findUniqueOrThrow({ where: { email: USER2_EMAIL } });
    const user3 = await prisma.user.findUniqueOrThrow({ where: { email: USER3_EMAIL } });

    console.log(`\n👤  Host   id: ${host.id}`);
    console.log(`👤  User1  id: ${user1.id}`);
    console.log(`👤  User2  id: ${user2.id}`);
    console.log(`👤  User3  id: ${user3.id}`);

    // ── 2. Ensure event exists ───────────────────────────────────────────────
    let event = await prisma.event.findFirst({
        where: { name: EVENT_NAME, hostId: host.id },
    });

    let eventId: string;

    if (event) {
        console.log(`\n✅  Event already exists: "${EVENT_NAME}" (id: ${event.id})`);
        eventId = event.id;
    } else {
        console.log(`\n🎉  Creating event: "${EVENT_NAME}"...`);
        const hostToken = await login(HOST_EMAIL, TEST_PASSWORD);
        const created = await apiCall('/events', 'POST', hostToken, {
            name: EVENT_NAME,
            visibility: 'PUBLIC',
            tags: ['POP'],
            invitingOnly: false,
            startDate: new Date().toISOString(),
        });
        eventId = created.id;
        console.log(`🆔  Event created with id: ${eventId}`);
    }

    // ── 3. Log in everyone ───────────────────────────────────────────────────
    console.log('\n🔑  Logging in all users...');
    const hostToken  = await login(HOST_EMAIL,  TEST_PASSWORD);
    const user1Token = await login(USER1_EMAIL,  TEST_PASSWORD);
    const user2Token = await login(USER2_EMAIL,  TEST_PASSWORD);
    const user3Token = await login(USER3_EMAIL,  TEST_PASSWORD);
    console.log('✅  All tokens obtained.');

    // ── 4. Connect sockets ───────────────────────────────────────────────────
    console.log('\n🔌  Connecting WebSockets...');
    const hostSocket    = await connectSocket('Host',         hostToken);
    const user1Device1  = await connectSocket('User1-Dev1',   user1Token);
    const user1Device2  = await connectSocket('User1-Dev2',   user1Token);
    const user1Device3  = await connectSocket('User1-Dev3',   user1Token);
    const user2Socket   = await connectSocket('User2',        user2Token);
    const user3Socket   = await connectSocket('User3',        user3Token);
    console.log('✅  All sockets connected.');

    // ── 5. Host starts event; others join ────────────────────────────────────
    console.log(`\n▶️   Host starting event ${eventId}...`);
    hostSocket.emit('event:start', { eventId });

    await sleep(500);

    console.log('🚪  Users joining event...');
    const joinPayload = { eventId };
    user1Device1.emit('event:join', joinPayload);
    user1Device2.emit('event:join', joinPayload);
    user1Device3.emit('event:join', joinPayload);
    user2Socket.emit('event:join', joinPayload);
    user3Socket.emit('event:join', joinPayload);

    await sleep(1000);
    console.log('✅  All users joined.');

    // ── 6. Listen for delegation invites ────────────────────────────────────
    console.log('\n👂  Listening for delegation events from server...');
    console.log('    (Send delegations from Postman — this process will stay alive)\n');

    // Generic handler factory
    function onDelegate(label: string, socket: Socket) {
    let receiveCount = 0;

    socket.on('event:delegate', (data: any) => {
        receiveCount++;
        const accept = receiveCount % 2 === 0; // 1st → false, 2nd → true, 3rd → false ...

        console.log(`\n📨  [${label}] Received delegation invite (#${receiveCount}):`);
        console.log(`    delegationId : ${data.delegationId}`);
        console.log(`    from         : ${data.delegatorId ?? data.hostId ?? JSON.stringify(data)}`);
        console.log(`    ➡️  Auto-responding with accept: ${accept}\n`);

        socket.emit(
            'event:delegation-response',
            { delegationId: data.delegationId, accept },
            (ack: any) => console.log(`    [${label}] Ack:`, ack),
        );
    });
}

    onDelegate('Host',       hostSocket);
    onDelegate('User1-Dev1', user1Device1);
    onDelegate('User1-Dev2', user1Device2);
    onDelegate('User1-Dev3', user1Device3);
    onDelegate('User2',      user2Socket);
    onDelegate('User3',      user3Socket);

    // ── 8. Keep process alive; clean disconnect on Ctrl+C ───────────────────
    const sockets = [hostSocket, user1Device1, user1Device2, user1Device3, user2Socket, user3Socket];

    async function shutdown() {
        console.log('\n\n🛑  Shutting down — disconnecting sockets...');
        sockets.forEach(s => s?.disconnect());
        await prisma.$disconnect();
        console.log('👋  Done. Data preserved in DB.');
        process.exit(0);
    }

    process.on('SIGINT',  shutdown);
    process.on('SIGTERM', shutdown);

    // keep alive
    await new Promise(() => {});
}

// ─── helpers ─────────────────────────────────────────────────────────────────

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
    const deviceId = `${name}-device-${uniqueRandom()}`;
    return new Promise((resolve, reject) => {
        const client = io(WS_URL, {
            path: '/ws',
            auth: { token },
            transports: ['websocket'],
            extraHeaders: { 'x-device-id': deviceId },
        });

        client.on('connect', () => {
            console.log(`  🔗  [${name}] connected  (deviceId: ${deviceId})`);
            resolve(client);
        });
        client.on('connect_error', (err) => {
            console.error(`  ❌  [${name}] connect error:`, err.message);
            reject(err);
        });
        client.on('exception',   (err)    => console.warn(`  ⚠️   [${name}] WsException:`, err));
        client.on('disconnect',  (reason) => console.log(`  🔌  [${name}] disconnected: ${reason}`));
    });
}

function sleep(ms: number) {
    return new Promise(r => setTimeout(r, ms));
}

main().catch(err => {
    console.error('Fatal error:', err);
    process.exit(1);
});