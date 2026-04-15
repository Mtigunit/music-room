// run-votes-simulation.js
const { io } = require('socket.io-client');
const { execSync } = require('child_process');

const TOKEN_1 = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIyYWU4ZDgwYy0yN2EyLTRiNDItODU3Zi00NTlmNjI2MDM5ZTkiLCJlbWFpbCI6ImF5b3VicmFjaGlkMjAyMkBnbWFpbC5jb20iLCJpYXQiOjE3NzYyNjM0MTAsImV4cCI6MTc3Njg2ODIxMH0.oSy0LV8ojMcI6NgjXbU2aGpsrkJ1ggw0VmLOTTriZrc';
const TOKEN_2 = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzMGVmNTZhYi1hMDc4LTRmOTMtYjRlZC0zNzg4Y2ZmNzgwZTEiLCJlbWFpbCI6ImF5b3VibWVudGFnMjFAZ21haWwuY29tIiwiaWF0IjoxNzc2MjYzNDY2LCJleHAiOjE3NzY4NjgyNjZ9.MPuYHbut8mOlV84EgUXFLviIwOzd4eVYEB5dxsLHaf8';

const ROOM_ID = 'room-123';
const TRACK_ID = 'track-1';
const SERVER_URL = 'http://localhost:3000';

function runRedisCommand(command) {
  try {
    // Drop the -it to avoid TTY allocation errors in automated scripts
    const output = execSync(`docker exec music_room_cache redis-cli ${command}`, { encoding: 'utf-8' });
    console.log(`\x1b[36m[REDIS OUTPUT]\x1b[0m\n${output.trim()}`);
  } catch (err) {
    console.error(`\x1b[31m[REDIS ERROR]\x1b[0m ${err.message}`);
  }
}

async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function connectClient(name, token) {
  const client = io(SERVER_URL, {
    path: '/ws',
    auth: { token },
  });

  client.on('connect', () => console.log(`\x1b[32m[${name}]\x1b[0m Connected!`));
  client.on('connect_error', err => console.log(`\x1b[31m[${name}]\x1b[0m Error:`, err.message));
  client.on('track:vote:updated', data => console.log(`\x1b[34m[${name}]\x1b[0m Received Broadcast:`, data));

  return client;
}

async function runTest() {
  console.log('--- STARTING VOTE SIMULATION ---\n');

  console.log('1. Clearing current votes in Redis...');
  runRedisCommand(`DEL track-votes:${ROOM_ID}:${TRACK_ID}`);

  console.log('\n2. Connecting Clients...');
  const client1 = connectClient('Client 1 (AyoubRachid)', TOKEN_1);
  const client2 = connectClient('Client 2 (AyoubMentag)', TOKEN_2);

  await sleep(1000); // give time to connect

  console.log(`\n3. Both clients joining room [${ROOM_ID}]...`);
  client1.emit('room:join', { roomId: ROOM_ID });
  client2.emit('room:join', { roomId: ROOM_ID });
  await sleep(500);

  // ---------- TEST SEQUENCE ---------- //
  
  console.log('\n--- ACTION 1: Client 1 votes UP ---');
  client1.emit('track:vote', { roomId: ROOM_ID, trackId: TRACK_ID, vote: 'up' });
  await sleep(500); // Wait for processing + broadcast
  runRedisCommand(`HGETALL track-votes:${ROOM_ID}:${TRACK_ID}`);

  console.log('\n--- ACTION 2: Client 2 votes DOWN (Dissenting Vote) ---');
  client2.emit('track:vote', { roomId: ROOM_ID, trackId: TRACK_ID, vote: 'down' });
  await sleep(500);
  runRedisCommand(`HGETALL track-votes:${ROOM_ID}:${TRACK_ID}`);

  console.log('\n--- ACTION 3: Client 1 changes vote to DOWN ---');
  client1.emit('track:vote', { roomId: ROOM_ID, trackId: TRACK_ID, vote: 'down' });
  await sleep(500);
  runRedisCommand(`HGETALL track-votes:${ROOM_ID}:${TRACK_ID}`);

  console.log('\n--- ACTION 4: Client 2 votes DOWN again (Testing Idempotency) ---');
  console.log('Expectation: Redis store should NOT increment downVotes since they already voted DOWN.');
  client2.emit('track:vote', { roomId: ROOM_ID, trackId: TRACK_ID, vote: 'down' });
  await sleep(500);
  runRedisCommand(`HGETALL track-votes:${ROOM_ID}:${TRACK_ID}`);

  console.log('\n--- ACTION 5: Client 1 and Client 2 both change to UP ---');
  client1.emit('track:vote', { roomId: ROOM_ID, trackId: TRACK_ID, vote: 'up' });
  client2.emit('track:vote', { roomId: ROOM_ID, trackId: TRACK_ID, vote: 'up' });
  await sleep(500);
  runRedisCommand(`HGETALL track-votes:${ROOM_ID}:${TRACK_ID}`);

  console.log('\n--- ACTION 6: Client 1 REMOVES their vote entirely ("none") ---');
  client1.emit('track:vote', { roomId: ROOM_ID, trackId: TRACK_ID, vote: 'none' });
  await sleep(500);
  runRedisCommand(`HGETALL track-votes:${ROOM_ID}:${TRACK_ID}`);

  console.log('\n--- TEST COMPLETE, disconnecting... ---');
  client1.disconnect();
  client2.disconnect();
  process.exit(0);
}

runTest();
