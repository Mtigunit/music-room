import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';
import { io, Socket } from 'socket.io-client';
import * as bcrypt from 'bcrypt';
import * as dotenv from 'dotenv';

dotenv.config();

const API_URL = process.env.API_URL || 'http://localhost:3000';
const WS_URL = process.env.WS_URL || 'http://localhost:3000';

const OWNER_EMAIL = 'integration-owner@example.com';
const COLLAB_EMAIL = 'integration-collab@example.com';
const TEST_PASSWORD = 'Password123!';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

async function main() {
  console.log('🚀 Starting Real-time Playlist Integration Test...');

  try {
    // 1. CLEANUP & SEED
    console.log('🧹 Cleaning up old test data...');
    await prisma.playlistTrack.deleteMany({
      where: { playlist: { owner: { email: OWNER_EMAIL } } },
    });
    await prisma.playlistCollaborator.deleteMany({
      where: { playlist: { owner: { email: OWNER_EMAIL } } },
    });
    await prisma.playlist.deleteMany({
      where: { owner: { email: OWNER_EMAIL } },
    });
    await prisma.user.deleteMany({
      where: { email: { in: [OWNER_EMAIL, COLLAB_EMAIL] } },
    });

    console.log('🌱 Seeding test users...');
    const passwordHash = await bcrypt.hash(TEST_PASSWORD, 10);
    const owner = await prisma.user.create({
      data: {
        email: OWNER_EMAIL,
        username: 'test_owner',
        passwordHash,
        isEmailVerified: true,
      },
    });
    const collab = await prisma.user.create({
      data: {
        email: COLLAB_EMAIL,
        username: 'test_collab',
        passwordHash,
        isEmailVerified: true,
      },
    });

    // 2. AUTHENTICATION
    console.log('🔑 Logging in to get JWTs...');
    const ownerToken = await login(OWNER_EMAIL, TEST_PASSWORD);
    const collabToken = await login(COLLAB_EMAIL, TEST_PASSWORD);

    // 3. PLAYLIST LIFECYCLE
    console.log('📂 Creating test playlist (Owner)...');
    const playlist = await apiCall('/playlists', 'POST', ownerToken, {
      name: 'Integration Sync Test',
      visibility: 'PRIVATE',
      editLicense: 'RESTRICTED',
    });

    console.log('🤝 Adding collaborator...');
    await apiCall(`/playlists/${playlist.id}/collaborators`, 'POST', ownerToken, {
      targetUserId: collab.id,
    });

    // 4. WEBSOCKET SETUP (Collaborator)
    console.log('🔌 Connecting WebSocket (Collaborator)...');
    const collabSocket = await connectSocket(collabToken);
    
    const events: any[] = [];
    collabSocket.on('playlist:track:added', (data) => {
      console.log('📥 Received: playlist:track:added', JSON.stringify(data, null, 2));
      events.push({ type: 'added', data });
    });
    collabSocket.on('playlist:track:removed', (data) => {
      console.log('📥 Received: playlist:track:removed', data.deletedTrackId);
      events.push({ type: 'removed', data });
    });

    console.log('🏠 Joining playlist room...');
    await emitWithAck(collabSocket, 'playlist:join', { playlistId: playlist.id });

    // 5. ADD TRACKS (Owner)
    console.log('🎵 Adding 3 tracks (Owner)...');
    const trackIds = ['dQw4w9WgXcQ', '9bZkp7q19f0', 'kJQP7kiw5Fk'];
    const playlistTracks: any[] = [];
    for (const tid of trackIds) {
      const pt = await apiCall(`/playlists/${playlist.id}/tracks`, 'POST', ownerToken, {
        providerTrackId: tid,
      });
      playlistTracks.push(pt);
      // Wait a bit to ensure event ordering
      await new Promise(r => setTimeout(r, 500));
    }

    // 6. REMOVE TRACK (The real test!)
    console.log('🗑️ Removing middle track (Owner)...');
    // playlistTracks[1] is the middle one (index 1, position 1)
    await apiCall(`/playlists/${playlist.id}/tracks/${playlistTracks[1].id}`, 'DELETE', ownerToken);

    // 7. VERIFICATION
    console.log('🧪 Verifying absolute-sync payload...');
    await new Promise(r => setTimeout(r, 1000)); // Wait for WS to catch up

    const removeEvent = events.find(e => e.type === 'removed');
    if (!removeEvent) throw new Error('Failed to receive playlist:track:removed event');

    const { deletedTrackId, updates } = removeEvent.data;
    console.log('✅ Received removal event with updates:', updates);

    if (deletedTrackId !== playlistTracks[1].id) {
       throw new Error(`Wrong track deleted! Expected ${playlistTracks[1].id}, got ${deletedTrackId}`);
    }

    // After deleting index 1:
    // Track 0 (pos 0) stays at 0.
    // Track 1 (pos 1) GONE.
    // Track 2 (pos 2) shifts to 1.
    const shiftedTrack = updates.find((u: any) => u.trackId === playlistTracks[2].id);
    if (!shiftedTrack || shiftedTrack.position !== 1) {
       throw new Error(`Sync Error: Track ${playlistTracks[2].id} should be at position 1, but got ${shiftedTrack?.position}`);
    }

    console.log('✨ All assertions passed! The database and WebSockets are perfectly in sync.');

  } catch (error) {
    console.error('❌ Test Failed:', error);
    process.exit(1);
  } finally {
    console.log('🏁 Integration Test Finished.');
    await prisma.$disconnect();
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
  if (!res.ok) throw new Error(`Login failed: ${res.statusText}`);
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
    const err = await res.json();
    throw new Error(`API Error [${path}]: ${err.message || res.statusText}`);
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
    socket.on('connect_error', (err) => reject(err));
  });
}

function emitWithAck(socket: Socket, event: string, payload: any): Promise<any> {
  return new Promise((resolve, reject) => {
    socket.emit(event, payload, (ack: any) => {
      if (ack && ack.error) reject(new Error(ack.error));
      else resolve(ack);
    });
    // Fallback if no ack is provided by gateway
    setTimeout(() => resolve(null), 2000);
  });
}

main();
