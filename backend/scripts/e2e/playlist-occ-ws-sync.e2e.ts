import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';
import { io, Socket } from 'socket.io-client';
import * as bcrypt from 'bcrypt';
import * as dotenv from 'dotenv';
import assert from 'assert';

dotenv.config();

const API_URL = process.env.API_URL || 'http://127.0.0.1:3000';
const WS_URL = process.env.WS_URL || 'http://127.0.0.1:3000';

const OWNER_EMAIL = 'sync-owner@example.com';
const COLLAB_EMAIL = 'sync-collab@example.com';
const TEST_PASSWORD = 'Password123!';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

async function main() {
  console.log('🚀 Starting Full OCC WebSocket Sync Test...');

  try {
    // 1. CLEANUP & SEED
    console.log('\n🧹 [1/8] Cleaning up old test data...');
    await prisma.playlistTrack.deleteMany({
      where: { playlist: { owner: { email: { in: [OWNER_EMAIL, COLLAB_EMAIL] } } } },
    });
    await prisma.playlistCollaborator.deleteMany({
      where: { playlist: { owner: { email: { in: [OWNER_EMAIL, COLLAB_EMAIL] } } } },
    });
    await prisma.playlist.deleteMany({
      where: { owner: { email: { in: [OWNER_EMAIL, COLLAB_EMAIL] } } },
    });
    await prisma.user.deleteMany({
      where: { email: { in: [OWNER_EMAIL, COLLAB_EMAIL] } },
    });

    const passwordHash = await bcrypt.hash(TEST_PASSWORD, 10);
    const owner = await prisma.user.create({
      data: { email: OWNER_EMAIL, username: 'sync_owner', passwordHash, isEmailVerified: true },
    });
    const collab = await prisma.user.create({
      data: { email: COLLAB_EMAIL, username: 'sync_collab', passwordHash, isEmailVerified: true },
    });

    console.log('🌱 Seeding Audio Dictionary with mock tracks to bypass YouTube API...');
    const MOCK_TRACK_IDS = ['dQw4w9WgXcQ', '9bZkp7q19f0', 'kJQP7kiw5Fk'];
    for (const providerTrackId of MOCK_TRACK_IDS) {
      await prisma.track.upsert({
        where: { providerTrackId },
        update: {},
        create: {
          providerTrackId,
          title: `Mock Track ${providerTrackId}`,
          artist: 'Mock Artist',
          durationMs: 180000,
          thumbnailUrl: 'https://i.ytimg.com/vi/dQw4w9WgXcQ/default.jpg',
        },
      });
    }

    console.log('🔑 [2/8] Logging in...');
    const ownerToken = await login(OWNER_EMAIL, TEST_PASSWORD);
    const collabToken = await login(COLLAB_EMAIL, TEST_PASSWORD);

    console.log('📂 [3/8] Creating test playlist & connecting WebSockets...');
    const playlist = await apiCall('/playlists', 'POST', ownerToken, {
      name: 'WS OCC Sync Test', visibility: 'PRIVATE', editLicense: 'RESTRICTED',
    });
    await apiCall(`/playlists/${playlist.id}/collaborators`, 'POST', ownerToken, { targetUserId: collab.id });

    // Connect WS
    const ownerSocket = await connectSocket(ownerToken);
    const collabSocket = await connectSocket(collabToken);

    // Track Collab's "Local State" Timestamp
    let collabLocalUpdatedAt: string = playlist.updatedAt;

    collabSocket.on('playlist:track:added', (data) => {
      // Sync Collab's local stamp via WS!
      assert(data.newUpdatedAt, 'WS [added] missing newUpdatedAt');
      collabLocalUpdatedAt = data.newUpdatedAt;
    });
    collabSocket.on('playlist:track:removed', (data) => {
      assert(data.newUpdatedAt, 'WS [removed] missing newUpdatedAt');
      collabLocalUpdatedAt = data.newUpdatedAt;
    });
    collabSocket.on('playlist:track:reordered', (data) => {
      assert(data.newUpdatedAt, 'WS [reordered] missing newUpdatedAt');
      collabLocalUpdatedAt = data.newUpdatedAt;
    });

    await emitWithAck(ownerSocket, 'playlist:join', { playlistId: playlist.id });
    await emitWithAck(collabSocket, 'playlist:join', { playlistId: playlist.id });

    // 4. OWNER ADDS TRACKS
    console.log('\n🎵 [4/8] Owner adds tracks. Validating Collab WS Sync...');
    const t1 = await apiCall(`/playlists/${playlist.id}/tracks`, 'POST', ownerToken, { providerTrackId: 'dQw4w9WgXcQ' });
    await delay(300); // Wait for WS packet
    assert.strictEqual(collabLocalUpdatedAt, t1.newUpdatedAt, 'Collab did not sync newUpdatedAt on Add');

    const t2 = await apiCall(`/playlists/${playlist.id}/tracks`, 'POST', ownerToken, { providerTrackId: '9bZkp7q19f0' });
    await delay(300);
    assert.strictEqual(collabLocalUpdatedAt, t2.newUpdatedAt, 'Collab did not sync newUpdatedAt on Add');

    const t3 = await apiCall(`/playlists/${playlist.id}/tracks`, 'POST', ownerToken, { providerTrackId: 'kJQP7kiw5Fk' });
    await delay(300);
    assert.strictEqual(collabLocalUpdatedAt, t3.newUpdatedAt, 'Collab did not sync newUpdatedAt on Add');
    
    console.log('✅ Collab successfully syncing OCC via WS payloads!');

    // 5. COLLAB REORDERS USING WS TIMESTAMP
    console.log('\n🔄 [5/8] Collab attempts Reorder using ONLY the WS-synchronized timestamp...');
    const reorderRes1 = await apiCall(`/playlists/${playlist.id}/tracks/${t1.track.id}/reorder`, 'PATCH', collabToken, {
      newPosition: 2,
      baseUpdatedAt: collabLocalUpdatedAt,
    });
    
    // Note: since Collab initiated the REST call, they must manually sync from their REST response, 
    // exactly like the Flutter bloc `TrackReordered` behavior dictates.
    collabLocalUpdatedAt = reorderRes1.newUpdatedAt; 
    console.log('✅ Success! WS OCC timestamp was perfectly valid.');

    // 6. OWNER DELETES TRACK => COLLAB SYNCS VIA WS => COLLAB REORDERS
    console.log('\n🗑️ [6/8] Owner deletes track. Collab tests reordering afterwards...');
    await delay(500); // buffer
    const removeRes = await apiCall(`/playlists/${playlist.id}/tracks/${t3.track.id}`, 'DELETE', ownerToken);
    
    // Give Collab 500ms to receive the WS 'playlist:track:removed' and automatically update collabLocalUpdatedAt.
    await delay(500); 
    assert.strictEqual(collabLocalUpdatedAt, removeRes.newUpdatedAt, 'Collab did not sync newUpdatedAt on Remove');

    const reorderRes2 = await apiCall(`/playlists/${playlist.id}/tracks/${t2.track.id}/reorder`, 'PATCH', collabToken, {
      newPosition: 0,
      baseUpdatedAt: collabLocalUpdatedAt, // This timestamp came from the deletion WS event!
    });
    collabLocalUpdatedAt = reorderRes2.newUpdatedAt;
    console.log('✅ Success! WS [removed] OCC sync allowed Collab to bypass fetching!');

    // 7. PROVE OCC FAILURE ON PURE DESYNC
    console.log('\n🛡️ [7/8] Simulating hard WS failure (Desync). Verifying OCC strictly triggers 409...');
    
    const frozenOldStamp = collabLocalUpdatedAt; // Capture it BEFORE owner fires!
    
    // Owner moves something, WS event fires and updates `collabLocalUpdatedAt`.
    const ownerReorderRes = await apiCall(`/playlists/${playlist.id}/tracks/${t1.track.id}/reorder`, 'PATCH', ownerToken, {
      newPosition: 0,
      baseUpdatedAt: collabLocalUpdatedAt,
    });

    console.log('[DEBUG] DB stamp should be: ', ownerReorderRes.newUpdatedAt);
    console.log('[DEBUG] Collab sending stale stamp: ', frozenOldStamp);

    // Collab tries to mutate using the stale signature:
    const desyncRes = await fetch(`${API_URL}/playlists/${playlist.id}/tracks/${t2.track.id}/reorder`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${collabToken}` },
      body: JSON.stringify({ newPosition: 1, baseUpdatedAt: frozenOldStamp }),
    });

    assert.strictEqual(desyncRes.status, 409, 'Expected Collab pure desync payload to hit OCC wall');
    console.log('✅ 409 Conflict properly threw. OCC is heavily armed.');

    // Teardown
    ownerSocket.disconnect();
    collabSocket.disconnect();
    console.log('\n🎉 ALL WS/OCC SYNC ASSERTIONS PASSED! E2E Client-State Simulation holds true.');

  } catch (error) {
    console.error('\n❌ Test Failed:', error);
    process.exitCode = 1;
  } finally {
    await prisma.$disconnect();
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
    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
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
    const socket = io(WS_URL, { path: '/ws', auth: { token }, transports: ['websocket'] });
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
    setTimeout(() => resolve(null), 2000);
  });
}

function delay(ms: number) {
  return new Promise(r => setTimeout(r, ms));
}

main();
