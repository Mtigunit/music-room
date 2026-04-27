import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';
import { io, Socket } from 'socket.io-client';
import * as bcrypt from 'bcrypt';
import * as dotenv from 'dotenv';

// Note: If you run this script using `ts-node scripts/run-events-simulation.ts`, __dirname is `scripts`
dotenv.config();

const API_URL = process.env.API_URL || 'http://localhost:3000';
const WS_URL = process.env.WS_URL || 'http://localhost:3000';

const HOST_EMAIL = 'events-host@example.com';
const PARTICIPANT_EMAIL = 'events-participant@example.com';
const TEST_PASSWORD = 'Password123!';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

let EVENT_ID = '';

async function main() {
    console.log('🚀 Starting Event Lifecycle & Timeout Simulation Test...');

    let hostSocket: Socket | null = null;
    let participantSocket: Socket | null = null;

    try {
        // 1. CLEANUP & SEED
        console.log('🧹 Cleaning up old test data...');
        await prisma.vote.deleteMany({
            where: { user: { email: { in: [HOST_EMAIL, PARTICIPANT_EMAIL] } } },
        });
        await prisma.eventTrack.deleteMany({
            where: { event: { host: { email: { in: [HOST_EMAIL, PARTICIPANT_EMAIL] } } } },
        });
        await prisma.event.deleteMany({
            where: { host: { email: { in: [HOST_EMAIL, PARTICIPANT_EMAIL] } } },
        });
        await prisma.user.deleteMany({
            where: { email: { in: [HOST_EMAIL, PARTICIPANT_EMAIL] } },
        });

        console.log('🌱 Seeding test users...');
        const passwordHash = await bcrypt.hash(TEST_PASSWORD, 10);
        await prisma.user.create({
            data: {
                email: HOST_EMAIL,
                username: 'events_host',
                passwordHash,
                isEmailVerified: true,
            },
        });
        await prisma.user.create({
            data: {
                email: PARTICIPANT_EMAIL,
                username: 'events_participant',
                passwordHash,
                isEmailVerified: true,
            },
        });

        // 2. AUTHENTICATION
        console.log('🔑 Logging in to get JWTs...');
        const hostToken = await login(HOST_EMAIL, TEST_PASSWORD);
        const participantToken = await login(PARTICIPANT_EMAIL, TEST_PASSWORD);

        // 3. EVENT CREATION VIA API
        console.log('🎉 Creating test event via API (Host)...');
        const event = await apiCall('/events', 'POST', hostToken, {
            name: 'Event Lifecycle Simulation',
            visibility: 'PUBLIC',
            tags: ['POP'],
            invitingOnly: false,
            startDate: new Date().toISOString(),
            tracks: []
        });

        EVENT_ID = event.id;

        console.log('\n--- STARTING LIFECYCLE SIMULATION ---');

        // 4. WEBSOCKET SETUP
        console.log('1. Connecting Participant Socket...');
        participantSocket = await connectSocket('Participant', participantToken);

        console.log(`\n2. Participant joining event [${EVENT_ID}] BEFORE it starts...`);
        participantSocket.emit('event:join', { eventId: EVENT_ID }, (ack: any) => console.log('Participant Join Ack:', ack));
        await sleep(1500); // Wait for WS events to arrive

        console.log('\n3. Connecting Host Socket and joining...');
        hostSocket = await connectSocket('Host', hostToken);
        hostSocket.emit('host_join', { eventId: EVENT_ID }, (ack: any) => console.log('Host Join Ack:', ack));
        await sleep(1500);

        console.log('\n4. Host STARTS the event...');
        hostSocket.emit('event:start', { eventId: EVENT_ID }, (ack: any) => console.log('Host Start Ack:', ack));
        await sleep(1500); // Wait to see the broadcast on Participant

        console.log('\n5. Simulating Host Disconnection (Soft Timeout Test)...');
        hostSocket.disconnect();
        console.log('Waiting 6 seconds for Soft Timeout warning...');
        await sleep(6000); 

        console.log('\n6. Host Reconnects to cancel timeouts...');
        hostSocket = await connectSocket('Host (Reconnected)', hostToken);
        hostSocket.emit('host_join', { eventId: EVENT_ID }, (ack: any) => console.log('Host Rejoin Ack:', ack));
        await sleep(2000);

        console.log('\n7. Host explicitly leaves event (Hard Timeout Test)...');
        hostSocket.emit('host_leave', { eventId: EVENT_ID }, (ack: any) => console.log('Host Leave Ack:', ack));
        
        console.log('Waiting 92 seconds for Hard Timeout (Event should auto-end)...');
        for (let i = 1; i <= 9; i++) {
            await sleep(10000);
            console.log(`... waited ${i * 10} seconds`);
        }
        await sleep(2000);

        console.log('\n--- TEST COMPLETE, SUCCESS! ---');

    } catch (error) {
        console.error('❌ Test Failed:', error);
        process.exit(1);
    } finally {
        if (hostSocket) hostSocket.disconnect();
        if (participantSocket) participantSocket.disconnect();

        console.log('🧹 Final database clean up...');
        try {
            await prisma.vote.deleteMany({
                where: { user: { email: { in: [HOST_EMAIL, PARTICIPANT_EMAIL] } } },
            });
            await prisma.eventTrack.deleteMany({
                where: { event: { host: { email: { in: [HOST_EMAIL, PARTICIPANT_EMAIL] } } } },
            });
            await prisma.event.deleteMany({
                where: { host: { email: { in: [HOST_EMAIL, PARTICIPANT_EMAIL] } } },
            });
            await prisma.user.deleteMany({
                where: { email: { in: [HOST_EMAIL, PARTICIPANT_EMAIL] } },
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

        // Listen for all event-related broadcasts
        client.on('event:status', (data) => console.log(`\x1b[34m[${name}]\x1b[0m Received 'event:status':`, data));
        client.on('event:started', (data) => console.log(`\x1b[35m[${name}]\x1b[0m Received 'event:started':`, data));
        client.on('event:ended', (data) => console.log(`\x1b[31m[${name}]\x1b[0m Received 'event:ended':`, data));
        client.on('event:host_soft_disconnect', (data) => console.log(`\x1b[33m[${name}]\x1b[0m Received 'event:host_soft_disconnect':`, data));
        client.on('event:host_reconnected', (data) => console.log(`\x1b[32m[${name}]\x1b[0m Received 'event:host_reconnected':`, data));
        client.on('disconnect', (reason) => console.log(`\x1b[36m[${name}]\x1b[0m Disconnected. Reason:`, reason));
    });
}

function sleep(ms: number) {
    return new Promise((r) => setTimeout(r, ms));
}

main();
