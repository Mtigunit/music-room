import { PrismaClient } from '@prisma/client';
import { Pool } from 'pg';
import { PrismaPg } from '@prisma/adapter-pg';
import * as bcrypt from 'bcrypt';
import { io, Socket } from 'socket.io-client';
import * as dotenv from 'dotenv';
import { execSync } from 'child_process';

dotenv.config();

const API_URL = process.env.API_URL || 'http://localhost:3000';
const WS_URL = process.env.WS_URL || 'http://localhost:3000';

const OWNER_EMAIL = 'event-owner@example.com';
const PARTICIPANT_EMAIL = 'event-participant@example.com';
const TEST_PASSWORD = 'Password123!';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

async function main() {
    console.log('🚀 Starting Real-time Event Tracks Integration Test...');

    try {
        // 1. CLEANUP & SEED
        console.log('🧹 Cleaning up old test data...');
        await prisma.eventTrack.deleteMany({
            where: { event: { host: { email: OWNER_EMAIL } } },
        });
        await prisma.eventInvite.deleteMany({
            where: { event: { host: { email: OWNER_EMAIL } } },
        });
        await prisma.event.deleteMany({
            where: { host: { email: OWNER_EMAIL } },
        });
        await prisma.user.deleteMany({
            where: { email: { in: [OWNER_EMAIL, PARTICIPANT_EMAIL] } },
        });

        console.log('🌱 Seeding test users...');
        const passwordHash = await bcrypt.hash(TEST_PASSWORD, 10);
        const owner = await prisma.user.create({
            data: {
                email: OWNER_EMAIL,
                username: 'event_owner',
                passwordHash,
                isEmailVerified: true,
            },
        });
        const participant = await prisma.user.create({
            data: {
                email: PARTICIPANT_EMAIL,
                username: 'event_participant',
                passwordHash,
                isEmailVerified: true,
            },
        });

        // 2. AUTHENTICATION
        console.log('🔑 Logging in to get JWTs...');
        const ownerToken = await login(OWNER_EMAIL, TEST_PASSWORD);
        const participantToken = await login(PARTICIPANT_EMAIL, TEST_PASSWORD);

        // 3. EVENT CREATION & INVITATION
        console.log('🎉 Creating test event (Owner)...');
        const event = await apiCall('/events', 'POST', ownerToken, {
            name: 'Integration Sync Event Test',
            visibility: 'PRIVATE',
            tags: ['ROCK'],
            invitingOnly: false,
        });

        console.log('🤝 Inviting participant...');
        await apiCall(`/events/${event.id}/invites`, 'POST', ownerToken, {
            userId: participant.id,
        });

        // 4. WEBSOCKET SETUP (Participant)
        console.log('🔌 Connecting WebSocket (Participant)...');
        const participantSocket = await connectSocket(participantToken);

        const wsEvents: any[] = [];

        // Listen for room count updates
        participantSocket.on('room:count', (payload) => {
            wsEvents.push({ type: 'room:count', payload });
            console.log(`   👥 Web socket room count [${payload.room}]:`, payload.count);
        });

        // Listen for track added
        participantSocket.on('track:add', (payload) => {
            wsEvents.push({ type: 'track:add', payload });
            console.log('   🎵 WebSocket received track:add ->', payload.track.title);
        });

        // Listen for track removed
        participantSocket.on('track:remove', (payload) => {
            wsEvents.push({ type: 'track:remove', payload });
            console.log('   🗑️ WebSocket received track:remove ->', payload.providerTrackId);
        });

        // Let the participant join the event room
        console.log('🎧 Participant joining room:', event.id);
        participantSocket.emit('event:join', { eventId: event.id });
        await sleep(500); // Give time for join

        // 5. APPEND TRACK (Owner)
        console.log('➕ Appending track via API (Owner)...');
        const testProviderId = 'zaGHlRk1Aq0';
        const appendedTrack = await apiCall(`/events/${event.id}/tracks`, 'POST', ownerToken, {
            providerTrackId: testProviderId,
        });

        await sleep(1000); // Let WS propagation happen

        const trackAddedEvent = wsEvents.find((e) => e.type === 'track:add');
        if (!trackAddedEvent || trackAddedEvent.payload.track.providerTrackId !== testProviderId) {
            throw new Error('❌ Failed to receive correct track:add WS event!');
        }
        console.log('✅ Appended track event successfully caught via WS.');

        // 6. REMOVE TRACK (Owner)
        console.log('➖ Removing track via API (Owner)...');
        await apiCall(`/events/${event.id}/tracks/${testProviderId}`, 'DELETE', ownerToken);

        await sleep(1000); // Let WS propagation happen

        const trackRemovedEvent = wsEvents.find((e) => e.type === 'track:remove');
        if (!trackRemovedEvent || trackRemovedEvent.payload.providerTrackId !== testProviderId) {
            throw new Error('❌ Failed to receive correct track:remove WS event!');
        }
        console.log('✅ Removed track event successfully caught via WS.');

        console.log('🎉 Test Completed Successfully!');
        participantSocket.disconnect();

    } catch (error) {
        console.error('❌ Test Failed:', error);
        process.exit(1);
    } finally {
        console.log('🧹 Final database clean up...');
        try {
            await prisma.eventTrack.deleteMany({
                where: { event: { host: { email: OWNER_EMAIL } } },
            });
            await prisma.eventInvite.deleteMany({
                where: { event: { host: { email: OWNER_EMAIL } } },
            });
            await prisma.event.deleteMany({
                where: { host: { email: OWNER_EMAIL } },
            });
            await prisma.user.deleteMany({
                where: { email: { in: [OWNER_EMAIL, PARTICIPANT_EMAIL] } },
            });
        } catch (e) {
            console.error('Cleanup error:', e);
        }
        await prisma.$disconnect();
        // Wait a brief moment to ensure disconnect is flushed
        await sleep(500);
        process.exit(0);
    }
}

// HELPERS
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

function connectSocket(token: string): Promise<Socket> {
    return new Promise((resolve, reject) => {
        const socket = io(WS_URL, {
            path: '/ws',
            auth: { token },
            transports: ['websocket'],
        });

        socket.on('connect', () => resolve(socket));
        socket.on('connect_error', (err) => reject(new Error(`WebSocket connection failed: ${err.message}`)));
    });
}

function sleep(ms: number) {
    return new Promise((r) => setTimeout(r, ms));
}

main();
