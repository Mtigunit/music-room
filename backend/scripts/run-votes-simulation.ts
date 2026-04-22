import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';
import { io, Socket } from 'socket.io-client';
import * as bcrypt from 'bcrypt';
import * as dotenv from 'dotenv';
import * as path from 'path';

// Note: If you run this script using `ts-node scripts/run-votes-simulation.ts`, __dirname is `scripts`
dotenv.config();

const API_URL = process.env.API_URL || 'http://localhost:3000';
const WS_URL = process.env.WS_URL || 'http://localhost:3000';

const USER1_EMAIL = 'vote-user1@example.com';
const USER2_EMAIL = 'vote-user2@example.com';
const TEST_PASSWORD = 'Password123!';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

let EVENT_ID = '';
let TRACK_ID_1 = '';
let TRACK_ID_2 = '';
let TRACK_ID_3 = '';

async function main() {
    console.log('🚀 Starting Real-time Votes Simulation Test...');

    let client1: Socket | null = null;
    let client2: Socket | null = null;

    try {
        // 1. CLEANUP & SEED
        console.log('🧹 Cleaning up old test data...');
        await prisma.vote.deleteMany({
            where: { user: { email: { in: [USER1_EMAIL, USER2_EMAIL] } } },
        });
        await prisma.eventTrack.deleteMany({
            where: { event: { host: { email: { in: [USER1_EMAIL, USER2_EMAIL] } } } },
        });
        await prisma.event.deleteMany({
            where: { host: { email: { in: [USER1_EMAIL, USER2_EMAIL] } } },
        });
        await prisma.user.deleteMany({
            where: { email: { in: [USER1_EMAIL, USER2_EMAIL] } },
        });

        console.log('🌱 Seeding test users...');
        const passwordHash = await bcrypt.hash(TEST_PASSWORD, 10);
        const user1 = await prisma.user.create({
            data: {
                email: USER1_EMAIL,
                username: 'vote_user1',
                passwordHash,
                isEmailVerified: true,
            },
        });
        const user2 = await prisma.user.create({
            data: {
                email: USER2_EMAIL,
                username: 'vote_user2',
                passwordHash,
                isEmailVerified: true,
            },
        });

        // 2. AUTHENTICATION
        console.log('🔑 Logging in to get JWTs...');
        const token1 = await login(USER1_EMAIL, TEST_PASSWORD);
        const token2 = await login(USER2_EMAIL, TEST_PASSWORD);

        // 3. EVENT CREATION VIA API
        console.log('🎉 Creating test event via API (User 1)...');
        const event = await apiCall('/events', 'POST', token1, {
            name: 'Votes Sync Event Test',
            visibility: 'PUBLIC',
            tags: ['POP'],
            invitingOnly: false,
            tracks: ['zaGHlRk1Aq0', 'dQw4w9WgXcQ', '9bZkp7q19f0'] // Add 3 youtube track ids directly
        });

        EVENT_ID = event.id;

        console.log('🎵 Fetching created tracks via API...');
        const tracksRes = await apiCall(`/events/${EVENT_ID}/tracks`, 'GET', token1);
        const tracks = tracksRes.data;
        if (tracks.length < 3) {
            throw new Error(`Expected at least 3 tracks, got ${tracks.length}`);
        }

        // Sort array safely by track ID for consistent test actions
        tracks.sort((a: any, b: any) => a.trackId.localeCompare(b.trackId));
        TRACK_ID_1 = tracks[0].trackId;
        TRACK_ID_2 = tracks[1].trackId;
        TRACK_ID_3 = tracks[2].trackId;

        console.log('\n--- STARTING VOTE SIMULATION ---');

        // 4. WEBSOCKET SETUP
        console.log('1. Connecting Clients...');
        client1 = await connectSocket('Client 1 (User 1)', token1);
        client2 = await connectSocket('Client 2 (User 2)', token2);

        console.log(`\n2. Both clients joining room [${EVENT_ID}]...`);
        client1.emit('room:join', { roomId: EVENT_ID });
        client2.emit('room:join', { roomId: EVENT_ID });
        await sleep(500); // Give connection standard room-join time

        // ---------- 5. TEST SEQUENCE ---------- //

        console.log('\n--- ACTION 1: Client 1 votes UP on Track 1 ---');
        client1.emit('track:vote', { eventId: EVENT_ID, trackId: TRACK_ID_1, vote: 'up' }, (ack: any) => console.log('Ack 1:', ack));
        await sleep(500); // Wait for processing + WS broadcast
        await showDbState();

        console.log('\n--- ACTION 2: Client 2 votes UP on Track 2 ---');
        client2.emit('track:vote', { eventId: EVENT_ID, trackId: TRACK_ID_2, vote: 'up' }, (ack: any) => console.log('Ack 2:', ack));
        await sleep(500);
        await showDbState();

        console.log('\n--- ACTION 3: Client 1 votes UP on Track 2 ---');
        client1.emit('track:vote', { eventId: EVENT_ID, trackId: TRACK_ID_2, vote: 'up' }, (ack: any) => console.log('Ack 3:', ack));
        await sleep(500);
        await showDbState();

        console.log('\n--- ACTION 4: Client 2 votes DOWN on Track 3 ---');
        client2.emit('track:vote', { eventId: EVENT_ID, trackId: TRACK_ID_3, vote: 'down' }, (ack: any) => console.log('Ack 4:', ack));
        await sleep(500);
        await showDbState();

        console.log('\n--- ACTION 5: CONCURRENCY TEST (Both clients emit instantly on same track) ---');
        await Promise.all([
            new Promise<void>(resolve => {
                client1!.emit('track:vote', { eventId: EVENT_ID, trackId: TRACK_ID_3, vote: 'up' }, (ack: any) => {
                    console.log('Ack 5.1 (Client 1):', ack);
                    resolve();
                });
            }),
            new Promise<void>(resolve => {
                client2!.emit('track:vote', { eventId: EVENT_ID, trackId: TRACK_ID_3, vote: 'up' }, (ack: any) => {
                    console.log('Ack 5.2 (Client 2):', ack);
                    resolve();
                });
            })
        ]);
        await sleep(500); // Small wait for DB to log outputs and flush
        await showDbState();

        console.log('\n--- ACTION 6: Client 1 REMOVES their vote entirely ("none") on Track 2 ---');
        client1.emit('track:vote', { eventId: EVENT_ID, trackId: TRACK_ID_2, vote: 'none' }, (ack: any) => console.log('Ack 6:', ack));
        await sleep(500);
        await showDbState();

        console.log('\n--- TEST COMPLETE, SUCCESS! ---');

    } catch (error) {
        console.error('❌ Test Failed:', error);
        process.exit(1);
    } finally {
        if (client1) client1.disconnect();
        if (client2) client2.disconnect();

        console.log('🧹 Final database clean up...');
        try {
            await prisma.vote.deleteMany({
                where: { user: { email: { in: [USER1_EMAIL, USER2_EMAIL] } } },
            });
            await prisma.eventTrack.deleteMany({
                where: { event: { host: { email: { in: [USER1_EMAIL, USER2_EMAIL] } } } },
            });
            await prisma.event.deleteMany({
                where: { host: { email: { in: [USER1_EMAIL, USER2_EMAIL] } } },
            });
            await prisma.user.deleteMany({
                where: { email: { in: [USER1_EMAIL, USER2_EMAIL] } },
            });
        } catch (e) {
            console.error('Cleanup error:', e);
        }
        await prisma.$disconnect();
        await sleep(500);
        process.exit(0);
    }
}

// ======================== HELPERS ======================== //

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
            'Authorization': `Bearer ${token}`,
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
        });

        client.on('connect', () => {
            console.log(`\x1b[32m[${name}]\x1b[0m Connected!`);
            resolve(client);
        });
        client.on('connect_error', (err) => {
            console.log(`\x1b[31m[${name}]\x1b[0m Error:`, err.message);
            reject(err);
        });

        client.on('track:vote:updated', (data) => console.log(`\x1b[34m[${name}]\x1b[0m Received Vote Broadcast:`, data));
        client.on('room:playlist:updated', (data) => console.log(`\x1b[35m[${name}]\x1b[0m Received Playlist Update Broadcast:`, JSON.stringify(data, null, 2)));
    });
}

function sleep(ms: number) {
    return new Promise((r) => setTimeout(r, ms));
}

async function showDbState() {
    const evTracks = await prisma.eventTrack.findMany({
        where: { eventId: EVENT_ID },
        include: { votes: true },
        orderBy: { trackId: 'asc' },
    });

    if (evTracks.length === 0) {
        console.log(`\x1b[31m[DB ERROR]\x1b[0m EventTracks not found.`);
        return;
    }

    for (const evTrack of evTracks) {
        console.log(`\x1b[36m[DB STATE]\x1b[0m Track [${evTrack.trackId}] Score: ${evTrack.voteScore}`);
        if (evTrack.votes.length > 0) {
            console.log(`\x1b[36m[DB STATE]\x1b[0m Cast Votes:`, evTrack.votes.map((v) => `User=${v.userId} Value=${v.voteValue}`));
        }
    }
}

main();