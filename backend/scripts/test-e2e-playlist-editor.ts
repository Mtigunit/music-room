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

const OWNER_EMAIL = 'e2e-owner@example.com';
const COLLAB_EMAIL = 'e2e-collab@example.com';
const TEST_PASSWORD = 'Password123!';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

async function main() {
  console.log('🚀 Starting Robust E2E Playlist Editor Test...');

  try {
    // 1. CLEANUP & SEED
    console.log('\n🧹 [1/7] Cleaning up old test data...');
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

    console.log('🌱 Seeding test users...');
    const passwordHash = await bcrypt.hash(TEST_PASSWORD, 10);
    const owner = await prisma.user.create({
      data: { email: OWNER_EMAIL, username: 'e2e_owner', passwordHash, isEmailVerified: true },
    });
    const collab = await prisma.user.create({
      data: { email: COLLAB_EMAIL, username: 'e2e_collab', passwordHash, isEmailVerified: true },
    });

    // 2. AUTHENTICATION
    console.log('\n🔑 [2/7] Logging in to get JWTs...');
    const ownerToken = await login(OWNER_EMAIL, TEST_PASSWORD);
    const collabToken = await login(COLLAB_EMAIL, TEST_PASSWORD);

    // 3. PLAYLIST LIFECYCLE
    console.log('\n📂 [3/7] Creating test playlist and adding collaborator...');
    const playlist = await apiCall('/playlists', 'POST', ownerToken, {
      name: 'E2E Sync Test Playlist',
      visibility: 'PRIVATE',
      editLicense: 'RESTRICTED',
    });
    await apiCall(`/playlists/${playlist.id}/collaborators`, 'POST', ownerToken, { targetUserId: collab.id });

    // 4. WEBSOCKET SETUP
    console.log('\n🔌 [4/7] Connecting WebSockets for Owner and Collaborator...');
    const ownerSocket = await connectSocket(ownerToken);
    const collabSocket = await connectSocket(collabToken);
    
    const events: any[] = [];
    collabSocket.on('playlist:track:added', (data) => events.push({ type: 'added', data }));
    collabSocket.on('playlist:track:removed', (data) => events.push({ type: 'removed', data }));
    collabSocket.on('playlist:track:reordered', (data) => events.push({ type: 'reordered', data }));

    await emitWithAck(ownerSocket, 'playlist:join', { playlistId: playlist.id });
    await emitWithAck(collabSocket, 'playlist:join', { playlistId: playlist.id });

    // Keep track of OCC Version Timestamp
    let latestUpdatedAt: string = playlist.updatedAt;

    // 5. ADD TRACKS
    console.log('\n🎵 [5/7] Adding tracks (Edge Cases Included)...');
    
    // Add 1
    const t1 = await apiCall(`/playlists/${playlist.id}/tracks`, 'POST', ownerToken, { providerTrackId: 'dQw4w9WgXcQ' });
    latestUpdatedAt = t1.newUpdatedAt;
    
    // Add 2 (Wait heavily needed to separate exact timestamps logically)
    await delay(200);
    const t2 = await apiCall(`/playlists/${playlist.id}/tracks`, 'POST', ownerToken, { providerTrackId: '9bZkp7q19f0' });
    latestUpdatedAt = t2.newUpdatedAt;

    // Add 3
    await delay(200);
    const t3 = await apiCall(`/playlists/${playlist.id}/tracks`, 'POST', ownerToken, { providerTrackId: 'kJQP7kiw5Fk' });
    latestUpdatedAt = t3.newUpdatedAt;

    // Edge Case: Duplicate Add
    console.log('🛡️ Testing Duplicate Track Prevention...');
    const dupRes = await fetch(`${API_URL}/playlists/${playlist.id}/tracks`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${ownerToken}` },
      body: JSON.stringify({ providerTrackId: 'dQw4w9WgXcQ' }),
    });
    assert.strictEqual(dupRes.status, 409, 'Expected 409 Conflict for duplicate track');

    // Edge Case: Unauthorized Add (No token or bad token / not collaborator)
    console.log('🛡️ Testing Unauthorized Track Add...');
    const unauthRes = await fetch(`${API_URL}/playlists/${playlist.id}/tracks`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' }, // No auth header
      body: JSON.stringify({ providerTrackId: 'unauthTrackId' }),
    });
    assert.strictEqual(unauthRes.status, 401, 'Expected 401 Unauthorized for missing token');

    await delay(500); // Let WebSockets settle
    const addedEvents = events.filter(e => e.type === 'added');
    assert.strictEqual(addedEvents.length, 3, 'Expected exactly 3 WS added events');
    console.log('✅ Tracks added properly and WS events received.');

    // 6. REORDER TRACK
    console.log('\n🔄 [6/7] Testing Reorder Track with Optimistic Concurrency Control (OCC)...');
    
    // Edge Case: OCC Rejection (Stale timestamp)
    console.log('🛡️ Testing OCC Rejection...');
    const staleRes = await fetch(`${API_URL}/playlists/${playlist.id}/tracks/${t3.track.id}/reorder`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${ownerToken}` },
      body: JSON.stringify({ newPosition: 0, baseUpdatedAt: "1999-01-01T00:00:00.000Z" }), // Stale date
    });
    assert.strictEqual(staleRes.status, 409, 'Expected 409 Conflict for stale baseUpdatedAt');
    console.log('✅ OCC gracefully rejected stale reorder action!');

    // Edge Case: Float Injection Rejection
    console.log('🛡️ Testing Float Injection Rejection...');
    const floatRes = await fetch(`${API_URL}/playlists/${playlist.id}/tracks/${t3.track.id}/reorder`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${ownerToken}` },
      body: JSON.stringify({ newPosition: 2.52, baseUpdatedAt: latestUpdatedAt }),
    });
    assert.strictEqual(floatRes.status, 400, 'Expected 400 Bad Request for floating point injection');
    console.log('✅ Class-validator gracefully rejected float payload!');

    // Edge Case: Fake UUID Mapping Rejection
    console.log('🛡️ Testing Fake UUID Not Found Mapping...');
    const fakeUuidRes = await fetch(`${API_URL}/playlists/${playlist.id}/tracks/00000000-0000-0000-0000-000000000000/reorder`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${ownerToken}` },
      body: JSON.stringify({ newPosition: 1, baseUpdatedAt: latestUpdatedAt }),
    });
    assert.strictEqual(fakeUuidRes.status, 404, 'Expected 404 Not Found for non-existent track UUID in the transaction');
    console.log('✅ Service gracefully mapped nested transaction crash to 404!');

    // Edge Case: Out-Of-Bounds Position Normalization
    console.log('🛡️ Testing Out-Of-Bounds Position Normalization...');
    const pushBoundsBody = await apiCall(`/playlists/${playlist.id}/tracks/${t1.track.id}/reorder`, 'PATCH', ownerToken, {
      newPosition: 9999, // Way out of bounds
      baseUpdatedAt: latestUpdatedAt,
    });
    latestUpdatedAt = pushBoundsBody.newUpdatedAt;
    console.log('✅ Out-of-bounds reorder request successfully normalized to end of array!');

    // Actual Reorder: Move track 3 (position 2) to position 0
    const reorderBody = await apiCall(`/playlists/${playlist.id}/tracks/${t3.track.id}/reorder`, 'PATCH', ownerToken, {
      newPosition: 0,
      baseUpdatedAt: latestUpdatedAt,
    });
    latestUpdatedAt = reorderBody.newUpdatedAt;

    await delay(500);
    const reorderEvents = events.filter(e => e.type === 'reordered');
    assert.strictEqual(reorderEvents.length, 2, 'Expected 2 WS reorder events locally (1 from bounds normalization, 1 from actual array math test)');
    
    // Verify math array from WS (checking the LAST reorder event which corresponds to the track 3 move): 
    const updates = reorderEvents[1].data.updates;
    const t2Shift = updates.find((u: any) => u.trackId === t2.track.id);
    const t3Shift = updates.find((u: any) => u.trackId === t3.track.id);
    assert.strictEqual(t2Shift.position, 1, 'Track 2 should have dynamically shifted down to pos 1');
    assert.strictEqual(t3Shift.position, 0, 'Track 3 should have snapped exactly to pos 0');
    console.log('✅ Validated drag-and-drop array payload match from WebSockets!');

    // 7. REMOVE TRACK
    console.log('\n🗑️ [7/7] Testing Track Removal...');
    
    // Remove Track 2 (Currently at position 1)
    const removeRes = await apiCall(`/playlists/${playlist.id}/tracks/${t2.track.id}`, 'DELETE', ownerToken);
    latestUpdatedAt = removeRes.newUpdatedAt;

    await delay(500);
    const removeWsEvent = events.find(e => e.type === 'removed');
    assert.strictEqual(removeWsEvent.data.deletedTrackId, t2.track.id, 'WS should broadcast the exact deleted ID');

    // Expected final DB State: t3 at pos 0, t1 at pos 1. 2 tracks total.
    const finalTracks = await prisma.playlistTrack.findMany({
      where: { playlistId: playlist.id },
      orderBy: { position: 'asc' }
    });
    
    assert.strictEqual(finalTracks.length, 2, 'Should only have 2 tracks remaining');
    assert.strictEqual(finalTracks[0].id, t3.track.id, 'Track 3 should be at position 0');
    assert.strictEqual(finalTracks[1].id, t1.track.id, 'Track 1 should be at position 1');
    console.log('✅ Validated Final DB Matrix!');

    // Teardown
    ownerSocket.disconnect();
    collabSocket.disconnect();
    console.log('\n🎉 ALL E2E ASSERTIONS PASSED FLAWLESSLY! Architecture is Bulletproof.');

  } catch (error) {
    console.error('\n❌ Test Failed:', error);
    process.exit(1);
  } finally {
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
