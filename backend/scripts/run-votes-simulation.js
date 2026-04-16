// run-votes-simulation.js
const { io } = require('socket.io-client');
const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');
require('dotenv').config({ path: require('path').resolve(__dirname, '../.env') });

const prisma = new PrismaClient({
  adapter: new PrismaPg(process.env.DATABASE_URL),
});


const TOKEN_1 = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJlMjAxNmE4ZC1lNTYxLTQxNDctOTgyYy05ZjNjZDY1ZDE4ZmIiLCJlbWFpbCI6ImF5b3VibWVudGFnMjFAZ21haWwuY29tIiwiaWF0IjoxNzc2MzM4MzY5LCJleHAiOjE3NzY5NDMxNjl9.GaYD-6bDpjJaGXLdU09nGUmbAmWqEV6TDmb8WnSQGIk';
const TOKEN_2 = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI0NzEwMTAzNi0yNzBhLTQzZDctYWQ4MS01NTU2YWZmZWM3NjEiLCJlbWFpbCI6ImF5b3VicmFjaGlkMjAyMkBnbWFpbC5jb20iLCJpYXQiOjE3NzYzMzg0NjgsImV4cCI6MTc3Njk0MzI2OH0.k8Fuam20fJRnus8j9PPvxZjoTP-7kiDUP32c6eahvHY';

const USER_1_ID = 'e2016a8d-e561-4147-982c-9f3cd65d18fb';
const USER_2_ID = '47101036-270a-43d7-ad81-5556affec761';

const EVENT_ID = 'event-test-123';
const TRACK_ID_1 = 'track-test-123';
const TRACK_ID_2 = 'track-test-456';
const TRACK_ID_3 = 'track-test-789';
const SERVER_URL = 'http://localhost:3000';

async function seedDatabase() {
  console.log('--- SEEDING DATABASE ---');
  
  // Clean up previous runs
  await prisma.vote.deleteMany({ where: { eventTrack: { eventId: EVENT_ID } } });
  await prisma.eventTrack.deleteMany({ where: { eventId: EVENT_ID } });
  await prisma.event.deleteMany({ where: { id: EVENT_ID } });
  await prisma.track.deleteMany({ where: { id: { in: [TRACK_ID_1, TRACK_ID_2, TRACK_ID_3] } } });

  // Users might exist, so use upsert
  await prisma.user.upsert({
    where: { id: USER_1_ID },
    update: {},
    create: { id: USER_1_ID, email: 'ayoubrachid2022@gmail.com', username: 'AyoubRachid' }
  });

  await prisma.user.upsert({
    where: { id: USER_2_ID },
    update: {},
    create: { id: USER_2_ID, email: 'ayoubmentag21@gmail.com', username: 'AyoubMentag' }
  });

  // Create Event
  await prisma.event.create({
    data: {
      id: EVENT_ID,
      name: 'Test Vote Event',
      hostId: USER_1_ID,
      status: 'active',
      visibility: 'public'
    }
  });

  // Create Tracks
  await prisma.track.createMany({
    data: [
      {
        id: TRACK_ID_1,
        providerTrackId: 'spotify:track:test1234',
        title: 'Test Track 1',
        artist: 'Test Artist',
        durationMs: 120000,
      },
      {
        id: TRACK_ID_2,
        providerTrackId: 'spotify:track:test5678',
        title: 'Test Track 2',
        artist: 'Test Artist',
        durationMs: 120000,
      },
      {
        id: TRACK_ID_3,
        providerTrackId: 'spotify:track:test9012',
        title: 'Test Track 3',
        artist: 'Test Artist',
        durationMs: 120000,
      }
    ]
  });

  // Create EventTracks
  await prisma.eventTrack.createMany({
    data: [
      {
        eventId: EVENT_ID,
        trackId: TRACK_ID_1,
        status: 'QUEUED',
        voteScore: 0
      },
      {
        eventId: EVENT_ID,
        trackId: TRACK_ID_2,
        status: 'QUEUED',
        voteScore: 0
      },
      {
        eventId: EVENT_ID,
        trackId: TRACK_ID_3,
        status: 'QUEUED',
        voteScore: 0
      }
    ]
  });

  console.log('Mock Data Seeded Successfully!\n');
}

async function showDbState() {
  const evTracks = await prisma.eventTrack.findMany({
    where: { eventId: EVENT_ID },
    include: { votes: true },
    orderBy: { trackId: 'asc' }
  });

  if (evTracks.length === 0) {
    console.log(`\x1b[31m[DB ERROR]\x1b[0m EventTracks not found.`);
    return;
  }

  for (const evTrack of evTracks) {
    console.log(`\x1b[36m[DB STATE]\x1b[0m Track [${evTrack.trackId}] Score: ${evTrack.voteScore}`);
    if (evTrack.votes.length > 0) {
      console.log(`\x1b[36m[DB STATE]\x1b[0m Track [${evTrack.trackId}] Cast Votes:`, evTrack.votes.map(v => `User=${v.userId} Value=${v.voteValue}`));
    }
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
  client.on('track:vote:updated', data => console.log(`\x1b[34m[${name}]\x1b[0m Received Vote Broadcast:`, data));
  client.on('room:playlist:updated', data => console.log(`\x1b[35m[${name}]\x1b[0m Received Playlist Update Broadcast:`, JSON.stringify(data, null, 2)));

  return client;
}

async function runTest() {
  await seedDatabase();

  console.log('--- STARTING VOTE SIMULATION ---\n');

  console.log('1. Connecting Clients...');
  const client1 = connectClient('Client 1 (AyoubRachid)', TOKEN_1);
  const client2 = connectClient('Client 2 (AyoubMentag)', TOKEN_2);

  await sleep(1000); // give time to connect

  console.log(`\n2. Both clients joining room [${EVENT_ID}]...`);
  client1.emit('room:join', { roomId: EVENT_ID });
  client2.emit('room:join', { roomId: EVENT_ID });
  await sleep(500);

  // ---------- TEST SEQUENCE ---------- //
  
  console.log('\n--- ACTION 1: Client 1 votes UP on Track 1 ---');
  client1.emit('track:vote', { eventId: EVENT_ID, trackId: TRACK_ID_1, vote: 'up' }, (ack) => console.log('Ack 1:', ack.score));
  await sleep(500); // Wait for processing + broadcast
  await showDbState();

  console.log('\n--- ACTION 2: Client 2 votes UP on Track 2 ---');
  client2.emit('track:vote', { eventId: EVENT_ID, trackId: TRACK_ID_2, vote: 'up' }, (ack) => console.log('Ack 2:', ack.score));
  await sleep(500);
  await showDbState();

  console.log('\n--- ACTION 3: Client 1 votes UP on Track 2 ---');
  client1.emit('track:vote', { eventId: EVENT_ID, trackId: TRACK_ID_2, vote: 'up' }, (ack) => console.log('Ack 3:', ack.score));
  await sleep(500);
  await showDbState();

  console.log('\n--- ACTION 4: Client 2 votes DOWN on Track 3 ---');
  client2.emit('track:vote', { eventId: EVENT_ID, trackId: TRACK_ID_3, vote: 'down' }, (ack) => console.log('Ack 4:', ack.score));
  await sleep(500);
  await showDbState();

  console.log('\n--- ACTION 5: CONCURRENCY TEST (Both clients emit instantly on same track) ---');
  // We fire both promises at the exact same millisecond to physically test the PostgreSQL FOR UPDATE row locks
  await Promise.all([
    new Promise(resolve => {
      client1.emit('track:vote', { eventId: EVENT_ID, trackId: TRACK_ID_3, vote: 'up' }, (ack) => {
        console.log('Ack 5 (Client 1):', ack.score);
        resolve();
      });
    }),
    new Promise(resolve => {
      client2.emit('track:vote', { eventId: EVENT_ID, trackId: TRACK_ID_3, vote: 'up' }, (ack) => {
        console.log('Ack 5 (Client 2):', ack.score);
        resolve();
      });
    })
  ]);
  await sleep(100); // Just wait a moment for DB state read
  await showDbState();

  console.log('\n--- ACTION 6: Client 1 REMOVES their vote entirely ("none") on Track 2 ---');
  client1.emit('track:vote', { eventId: EVENT_ID, trackId: TRACK_ID_2, vote: 'none' }, (ack) => console.log('Ack 6:', ack.score));
  await sleep(500);
  await showDbState();

  console.log('\n--- TEST COMPLETE, cleaning up... ---');
  client1.disconnect();
  client2.disconnect();
  await prisma.$disconnect();
  process.exit(0);
}

runTest().catch(async (e) => {
  console.error(e);
  await prisma.$disconnect();
  process.exit(1);
});
