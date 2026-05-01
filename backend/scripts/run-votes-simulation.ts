import { PrismaClient, PolicyType } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';
import { io, Socket } from 'socket.io-client';
import * as bcrypt from 'bcrypt';
import * as dotenv from 'dotenv';

dotenv.config();

const API_URL = 'http://localhost:3000';
const WS_URL = 'http://localhost:3000';

const USER1_EMAIL = 'vote-user1@example.com';
const USER2_EMAIL = 'vote-user2@example.com';
const USER3_EMAIL = 'vote-user3@example.com';
const TEST_PASSWORD = 'Password123!';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

// ─── colour helpers ───────────────────────────────────────────────────────────
const col = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m',
  purple: '\x1b[35m',
};
const ok   = (msg: string) => console.log(`${col.green}✔  ${msg}${col.reset}`);
const fail = (msg: string) => console.log(`${col.red}✘  ${msg}${col.reset}`);
const info = (msg: string) => console.log(`${col.cyan}ℹ  ${msg}${col.reset}`);
const warn = (msg: string) => console.log(`${col.yellow}⚠  ${msg}${col.reset}`);
const step = (msg: string) => console.log(`\n${col.purple}━━ ${msg} ━━${col.reset}`);

// ─── test tracker ─────────────────────────────────────────────────────────────
let passed = 0, failed = 0;
function assert(condition: boolean, label: string) {
  if (condition) { ok(label); passed++; }
  else           { fail(label); failed++; }
}

// ─── shared state ─────────────────────────────────────────────────────────────
let publicEventId  = '';
let privateEventId = '';
let inviteEventId  = '';
let timeEventId    = '';
let geoEventId     = '';

let TRACK_ID_1 = '';
let TRACK_ID_2 = '';
let TRACK_ID_3 = '';

// ─────────────────────────────────────────────────────────────────────────────
async function main() {
  console.log(`\n${col.green}🚀  Real-time Votes Simulation – Extended Test Suite${col.reset}\n`);

  const clients: Socket[] = [];

  try {
    // ── 1. SEED ─────────────────────────────────────────────────────────────
    step('SETUP – Cleaning & Seeding');
    await cleanupAll();

    const passwordHash = await bcrypt.hash(TEST_PASSWORD, 10);
    await Promise.all([
      prisma.user.create({ data: { email: USER1_EMAIL, username: 'vote_user1', passwordHash, isEmailVerified: true } }),
      prisma.user.create({ data: { email: USER2_EMAIL, username: 'vote_user2', passwordHash, isEmailVerified: true } }),
      prisma.user.create({ data: { email: USER3_EMAIL, username: 'vote_user3', passwordHash, isEmailVerified: true } }),
    ]);
    ok('3 test users created');

    // ── 2. AUTH ──────────────────────────────────────────────────────────────
    step('AUTH – Getting JWTs');
    const [token1, token2, token3] = await Promise.all([
      login(USER1_EMAIL, TEST_PASSWORD),
      login(USER2_EMAIL, TEST_PASSWORD),
      login(USER3_EMAIL, TEST_PASSWORD),
    ]);
    ok('All three users authenticated');

    // ── 3. EVENTS ────────────────────────────────────────────────────────────
    step('CREATE EVENTS – Public / Private / Invite-only / Time-window / Geofence');

    const YOUTUBE_IDS = ['zaGHlRk1Aq0', 'dQw4w9WgXcQ', '9bZkp7q19f0'];

    // 3a. Public open event
    const publicEvent = await apiCall('/events', 'POST', token1, {
      name: 'Public Vote Test Event',
      visibility: 'PUBLIC',
      tracks: YOUTUBE_IDS,
      tags: ['POP'],
      startDate: new Date(Date.now() - 3600_000).toISOString(),
    });
    publicEventId = publicEvent.id;

    // 3b. Private event – user3 has no access
    const privateEvent = await apiCall('/events', 'POST', token1, {
      name: 'Private Vote Test Event',
      visibility: 'PRIVATE',
      tracks: YOUTUBE_IDS,
      tags: ['POP'],
      startDate: new Date(Date.now() - 3600_000).toISOString(),
    });
    privateEventId = privateEvent.id;

    // 3b-invite: Create EventInvite for User3 to test private event access
    const user3 = await prisma.user.findUnique({ where: { email: USER3_EMAIL } });
    await prisma.eventInvite.create({
      data: {
        eventId: privateEventId,
        userId: user3!.id,
      },
    });
    ok('EventInvite created for User3 to test private event');

    // 3c. Public but invite-only – user3 has no access
    const inviteEvent = await apiCall('/events', 'POST', token1, {
      name: 'Invite-only Vote Test Event',
      visibility: 'PUBLIC',
      invitingOnly: true,
      tracks: YOUTUBE_IDS,
      tags: ['POP'],
      startDate: new Date(Date.now() - 3600_000).toISOString(),
    });
    inviteEventId = inviteEvent.id;

    // 3d. Time-window: voting window already CLOSED (both times in the past)
    const timeEvent = await apiCall('/events', 'POST', token1, {
      name: 'Time-Window Vote Test Event',
      visibility: 'PUBLIC',
      tracks: YOUTUBE_IDS,
      tags: ['POP'],
      startDate: new Date(Date.now() - 3600_000).toISOString(),
      policies: [{
        policyType: PolicyType.TIME_WINDOW,
        config: {
          startDate: new Date(Date.now() - 2 * 3600_000).toISOString(),
          endDate:   new Date(Date.now() - 1 * 3600_000).toISOString(),
        },
      }],
    });
    timeEventId = timeEvent.id;

    // 3e. Geofence: centred on Eiffel Tower, radius 100 m
    const geoEvent = await apiCall('/events', 'POST', token1, {
      name: 'Geofence Vote Test Event',
      visibility: 'PUBLIC',
      tracks: YOUTUBE_IDS,
      locationLat: 48.8584,
      locationLng: 2.2945,
      tags: ['POP'],
      policies: [{
        policyType: PolicyType.GEOFENCE,
        config: { distance: 100 },
      }],
      startDate: new Date(Date.now() - 3600_000).toISOString(),
    });
    geoEventId = geoEvent.id;
    ok('5 test events created');

    // Resolve track IDs from the public event
    const tracksRes = await apiCall(`/events/${publicEventId}/tracks`, 'GET', token1);
    const tracks = (tracksRes.data as any[]).sort((a, b) => a.trackId.localeCompare(b.trackId));
    if (tracks.length < 3) throw new Error(`Expected ≥3 tracks, got ${tracks.length}`);
    TRACK_ID_1 = tracks[0].trackId;
    TRACK_ID_2 = tracks[1].trackId;
    TRACK_ID_3 = tracks[2].trackId;
    info(`Track IDs: ${TRACK_ID_1} | ${TRACK_ID_2} | ${TRACK_ID_3}`);

    // ── 4. WEBSOCKETS ────────────────────────────────────────────────────────
    step('WEBSOCKET – Connecting clients');
    const [client1, client2, client3] = await Promise.all([
      connectSocket('Client-1 (User1/Host)', token1),
      connectSocket('Client-2 (User2)', token2),
      connectSocket('Client-3 (User3/Outsider)', token3),
    ]);
    clients.push(client1, client2, client3);
    ok('All 3 clients connected');

    // ════════════════════════════════════════════════════════════════════════
    //  SUITE A – Multi-user voting on a PUBLIC event
    // ════════════════════════════════════════════════════════════════════════
    step('SUITE A – Multi-user voting on public event');

    // Host must start the event before joining as host
    step("starting event !!")
    await startEvent(client1, publicEventId);
     
    // Host is already joined to room by event:start, guests join normally
    joinEvent(client2, publicEventId);
    joinEvent(client3, publicEventId);
    await sleep(400);

    // A-1: User1 votes UP on Track1  →  score 1
    {
      const [bcastSelf, bcast2, bcast3, ack] = await Promise.all([
        waitForBroadcast(client1, TRACK_ID_1),
        waitForBroadcast(client2, TRACK_ID_1),
        waitForBroadcast(client3, TRACK_ID_1),
        emitVote(client1, publicEventId, TRACK_ID_1, 'up'),
      ]);
      assert(ack?.score === 1,                                       'A-1 ack        – User1 UP Track1 → score 1');
      assert(isValidResult(bcastSelf, publicEventId, TRACK_ID_1),   'A-1 self-bcast  – voter (Client1) received track:vote_updated');
      assert(bcastSelf?.score === 1,                                 'A-1 self-bcast  – voter sees score 1');
      assert(isValidResult(bcast2, publicEventId, TRACK_ID_1),      'A-1 peer-bcast  – Client2 received track:vote_updated');
      assert(bcast2?.score === 1,                                    'A-1 peer-bcast  – Client2 sees score 1');
      assert(isValidResult(bcast3, publicEventId, TRACK_ID_1),      'A-1 peer-bcast  – Client3 received track:vote_updated');
      printAck('A-1 ack         (User1)', ack);
      printBcast('A-1 self-bcast  (Client1)', bcastSelf);
      printBcast('A-1 peer-bcast  (Client2)', bcast2);
      printBcast('A-1 peer-bcast  (Client3)', bcast3);
    }

    // A-2: User2 votes UP on Track1  →  score 2
    {
      const [bcast1, bcastSelf, bcast3, ack] = await Promise.all([
        waitForBroadcast(client1, TRACK_ID_1),
        waitForBroadcast(client2, TRACK_ID_1),
        waitForBroadcast(client3, TRACK_ID_1),
        emitVote(client2, publicEventId, TRACK_ID_1, 'up'),
      ]);
      assert(ack?.score === 2,       'A-2 ack        – User2 UP Track1 → score 2');
      assert(bcastSelf?.score === 2, 'A-2 self-bcast  – voter (Client2) sees score 2');
      assert(bcast1?.score === 2,    'A-2 peer-bcast  – Client1 sees score 2');
      assert(bcast3?.score === 2,    'A-2 peer-bcast  – Client3 sees score 2');
      printAck('A-2 ack         (User2)', ack);
      printBcast('A-2 self-bcast  (Client2)', bcastSelf);
      printBcast('A-2 peer-bcast  (Client1)', bcast1);
      printBcast('A-2 peer-bcast  (Client3)', bcast3);
    }

    // A-3: User3 votes UP on Track1 (outsider on public event → allowed)  →  score 3
    {
      const [bcast1, bcast2, bcastSelf, ack] = await Promise.all([
        waitForBroadcast(client1, TRACK_ID_1),
        waitForBroadcast(client2, TRACK_ID_1),
        waitForBroadcast(client3, TRACK_ID_1),
        emitVote(client3, publicEventId, TRACK_ID_1, 'up'),
      ]);
      assert(ack?.score === 3,       'A-3 ack        – User3 UP Track1 → score 3 (public, outsider allowed)');
      assert(bcastSelf?.score === 3, 'A-3 self-bcast  – voter (Client3) sees score 3');
      assert(bcast1?.score === 3,    'A-3 peer-bcast  – Client1 sees score 3');
      assert(bcast2?.score === 3,    'A-3 peer-bcast  – Client2 sees score 3');
      printAck('A-3 ack         (User3)', ack);
      printBcast('A-3 self-bcast  (Client3)', bcastSelf);
      printBcast('A-3 peer-bcast  (Client1)', bcast1);
      printBcast('A-3 peer-bcast  (Client2)', bcast2);
    }

    // A-4: User1 votes DOWN on Track2  →  score -1
    {
      const [bcastSelf, bcast2, ack] = await Promise.all([
        waitForBroadcast(client1, TRACK_ID_2),
        waitForBroadcast(client2, TRACK_ID_2),
        emitVote(client1, publicEventId, TRACK_ID_2, 'down'),
      ]);
      assert(ack?.score === -1,       'A-4 ack        – User1 DOWN Track2 → score -1');
      assert(bcastSelf?.score === -1, 'A-4 self-bcast  – voter (Client1) sees score -1');
      assert(bcast2?.score === -1,    'A-4 peer-bcast  – Client2 sees score -1');
      printAck('A-4 ack         (User1)', ack);
      printBcast('A-4 self-bcast  (Client1)', bcastSelf);
      printBcast('A-4 peer-bcast  (Client2)', bcast2);
    }

    // A-5: User2 votes DOWN on Track2  →  score -2
    {
      const [bcast1, bcastSelf, ack] = await Promise.all([
        waitForBroadcast(client1, TRACK_ID_2),
        waitForBroadcast(client2, TRACK_ID_2),
        emitVote(client2, publicEventId, TRACK_ID_2, 'down'),
      ]);
      assert(ack?.score === -2,       'A-5 ack        – User2 DOWN Track2 → score -2');
      assert(bcastSelf?.score === -2, 'A-5 self-bcast  – voter (Client2) sees score -2');
      assert(bcast1?.score === -2,    'A-5 peer-bcast  – Client1 sees score -2');
      printAck('A-5 ack         (User2)', ack);
      printBcast('A-5 self-bcast  (Client2)', bcastSelf);
      printBcast('A-5 peer-bcast  (Client1)', bcast1);
    }

    // A-6: User1 flips UP→DOWN on Track1  →  score 1
    {
      const [bcastSelf, bcast2, ack] = await Promise.all([
        waitForBroadcast(client1, TRACK_ID_1),
        waitForBroadcast(client2, TRACK_ID_1),
        emitVote(client1, publicEventId, TRACK_ID_1, 'down'),
      ]);
      assert(ack?.score === 1,       'A-6 ack        – User1 flips to DOWN Track1 → score 1');
      assert(bcastSelf?.score === 1, 'A-6 self-bcast  – voter (Client1) sees score 1');
      assert(bcast2?.score === 1,    'A-6 peer-bcast  – Client2 sees score 1');
      printAck('A-6 ack         (User1 flip)', ack);
      printBcast('A-6 self-bcast  (Client1)', bcastSelf);
      printBcast('A-6 peer-bcast  (Client2)', bcast2);
    }

    // A-7: User1 removes vote (none) on Track1  →  score 2
    {
      const [bcastSelf, bcast2, ack] = await Promise.all([
        waitForBroadcast(client1, TRACK_ID_1),
        waitForBroadcast(client2, TRACK_ID_1),
        emitVote(client1, publicEventId, TRACK_ID_1, 'none'),
      ]);
      assert(ack?.score === 2,       'A-7 ack        – User1 removes vote Track1 → score 2');
      assert(bcastSelf?.score === 2, 'A-7 self-bcast  – voter (Client1) sees score 2');
      assert(bcast2?.score === 2,    'A-7 peer-bcast  – Client2 sees score 2');
      printAck('A-7 ack         (User1 none)', ack);
      printBcast('A-7 self-bcast  (Client1)', bcastSelf);
      printBcast('A-7 peer-bcast  (Client2)', bcast2);
    }

    // A-8: "none" with no prior vote → idempotent, score stays 0
    {
      const ack = await emitVote(client1, publicEventId, TRACK_ID_3, 'none');
      assert(ack?.score === 0, 'A-8 ack – User1 removes non-existent vote Track3 → score 0 (no-op)');
      printAck('A-8 ack (User1 none/no-op)', ack);
    }

    // A-9: CONCURRENCY – two clients vote simultaneously on Track3
    step('SUITE A-9 – Concurrency (simultaneous votes on Track3)');
    {
      const [bcastSelf1, bcastSelf2, bcast3, ack1, ack2] = await Promise.all([
        waitForBroadcast(client1, TRACK_ID_3),
        waitForBroadcast(client2, TRACK_ID_3),
        waitForBroadcast(client3, TRACK_ID_3),
        emitVote(client1, publicEventId, TRACK_ID_3, 'up'),
        emitVote(client2, publicEventId, TRACK_ID_3, 'up'),
      ]);
      await sleep(300);
      const dbScore = await getDbScore(publicEventId, TRACK_ID_3);
      assert(dbScore === 2,           `A-9 DB         – concurrent votes settle to score 2 (got ${dbScore})`);
      assert(!isError(ack1),          'A-9 ack         – User1 received a valid ack');
      assert(!isError(ack2),          'A-9 ack         – User2 received a valid ack');
      assert(bcastSelf1 !== null,     'A-9 self-bcast  – Client1 received broadcast');
      assert(bcastSelf2 !== null,     'A-9 self-bcast  – Client2 received broadcast');
      assert(bcast3 !== null,         'A-9 peer-bcast  – Client3 received broadcast');
      printAck('A-9 ack (User1)', ack1);
      printAck('A-9 ack (User2)', ack2);
      printBcast('A-9 bcast (Client3)', bcast3);
    }

    await showDbState(publicEventId, 'Public Event – after Suite A');

    // End the public event before starting a new one
    step('ENDING PUBLIC EVENT');
    await endEvent(client1, publicEventId);

    // ════════════════════════════════════════════════════════════════════════
    //  SUITE B – PRIVATE event (user3 rejected)
    // ════════════════════════════════════════════════════════════════════════
    step('SUITE B – Private event access control');

    const startAckB = await startEvent(client1, privateEventId);
    step('B-0 – Host started private event → event:start ack OK');
    // Host is already joined to room by event:start, guest joins normally
    joinEvent(client3, privateEventId);
    await sleep(400);

    // B-1: Host can vote on their own private event
    {
      const ack = await emitVote(client1, privateEventId, TRACK_ID_1, 'up');
      assert(!isError(ack), 'B-1 ack – Host votes on private event → allowed');
      printAck('B-1 ack (User1/Host)', ack);
    }

    // B-2: Invited user3 can now vote on private event
    {
      const ack = await emitVote(client3, privateEventId, TRACK_ID_1, 'up');
      assert(!isError(ack), 'B-2 ack – Invited User3 can vote on private event → Success');
      printAck('B-2 ack (User3 – invited user)', ack);
    }

    // End the private event before starting a new one
    step('ENDING PRIVATE EVENT');
    await endEvent(client1, privateEventId);

    // ════════════════════════════════════════════════════════════════════════
    //  SUITE C – INVITE-ONLY event (user3 rejected)
    // ════════════════════════════════════════════════════════════════════════
    step('SUITE C – Invite-only event access control');

    const startAckC = await startEvent(client1, inviteEventId);
    step('C-0 – Host started invite-only event → event:start ack OK');
    // Host is already joined to room by event:start, guest joins normally
    joinEvent(client3, inviteEventId);
    await sleep(400);

    // C-1: Host can vote
    {
      const ack = await emitVote(client1, inviteEventId, TRACK_ID_1, 'up');
      assert(!isError(ack), 'C-1 ack – Host votes on invite-only event → allowed');
      printAck('C-1 ack (User1/Host)', ack);
    }

    // C-2: Uninvited user3 is rejected
    {
      const ack = await emitVote(client3, inviteEventId, TRACK_ID_1, 'up');
      assert(isError(ack), 'C-2 ack – Uninvited user blocked on invite-only event → ForbiddenException');
      printAck('C-2 ack (User3 – expect error)', ack);
    }

    // End the invite-only event before starting a new one
    step('ENDING INVITE-ONLY EVENT');
    await endEvent(client1, inviteEventId);

    // ════════════════════════════════════════════════════════════════════════
    //  SUITE D – TIME-WINDOW policy (window already CLOSED)
    // ════════════════════════════════════════════════════════════════════════
    step('SUITE D – Time-window policy (voting window already closed)');

    const startAckD = await startEvent(client1, timeEventId);
    step('D-0 – Host started time-window event → event:start ack OK');
    // Host is already joined to room by event:start, guest joins normally
    joinEvent(client2, timeEventId);
    await sleep(400);

    // D-1: Host is still blocked – the window is closed for everyone
    {
      const ack = await emitVote(client1, timeEventId, TRACK_ID_1, 'up');
      assert(isError(ack), 'D-1 ack – Vote rejected (voting window closed) → ForbiddenException');
      printAck('D-1 ack (User1 – expect error: voting closed)', ack);
    }

    // D-2: User2 also blocked
    {
      const ack = await emitVote(client2, timeEventId, TRACK_ID_2, 'down');
      assert(isError(ack), 'D-2 ack – User2 also blocked by closed time window → ForbiddenException');
      printAck('D-2 ack (User2 – expect error: voting closed)', ack);
    }

    // End the time-window event before starting a new one
    step('ENDING TIME-WINDOW EVENT');
    await endEvent(client1, timeEventId);

    // ════════════════════════════════════════════════════════════════════════
    //  SUITE E – GEOFENCE policy (event at Eiffel Tower, radius 100 m)
    // ════════════════════════════════════════════════════════════════════════
    step('SUITE E – Geofence policy (event at Eiffel Tower, radius 100 m)');

    const startAckE = await startEvent(client1, geoEventId);
    step('E-0 – Host started geo event → event:start ack OK');
    // Host is already joined to room by event:start, guest joins normally
    joinEvent(client2, geoEventId);
    await sleep(400);

    // E-1: No location sent → BadRequestException
    {
      const ack = await emitVote(client1, geoEventId, TRACK_ID_1, 'up');
      assert(isError(ack), 'E-1 ack – Vote without location → BadRequestException');
      printAck('E-1 ack (User1 – expect error: no location)', ack);
    }

    // E-2: Location in Casablanca – clearly outside the 100 m fence
    {
      const ack = await emitVoteWithLocation(client1, geoEventId, TRACK_ID_1, 'up', 33.5731, -7.5898);
      assert(isError(ack), 'E-2 ack – Vote from Casablanca → outside geofence → ForbiddenException');
      printAck('E-2 ack (User1 – expect error: outside geofence)', ack);
    }

    // E-3: Location at the Eiffel Tower → inside fence → allowed
    {
      const [bcastSelf, bcast2, ack] = await Promise.all([
        waitForBroadcast(client1, TRACK_ID_1),
        waitForBroadcast(client2, TRACK_ID_1),
        emitVoteWithLocation(client1, geoEventId, TRACK_ID_1, 'up', 48.8584, 2.2945),
      ]);
      assert(!isError(ack),       'E-3 ack        – Vote inside geofence (Eiffel Tower) → allowed');
      assert(bcastSelf !== null,  'E-3 self-bcast  – voter (Client1) received track:vote_updated');
      assert(bcast2 !== null,     'E-3 peer-bcast  – Client2 received track:vote_updated');
      printAck('E-3 ack         (User1 inside fence)', ack);
      printBcast('E-3 self-bcast  (Client1)', bcastSelf);
      printBcast('E-3 peer-bcast  (Client2)', bcast2);
    }

    // E-4: User2 a few metres away – still inside the fence
    {
      const [bcast1, bcastSelf, ack] = await Promise.all([
        waitForBroadcast(client1, TRACK_ID_1),
        waitForBroadcast(client2, TRACK_ID_1),
        emitVoteWithLocation(client2, geoEventId, TRACK_ID_1, 'up', 48.8585, 2.2946),
      ]);
      assert(!isError(ack),      'E-4 ack        – User2 inside geofence → allowed');
      assert(bcastSelf !== null, 'E-4 self-bcast  – voter (Client2) received track:vote_updated');
      assert(bcast1 !== null,    'E-4 peer-bcast  – Client1 received track:vote_updated');
      printAck('E-4 ack         (User2 inside fence)', ack);
      printBcast('E-4 self-bcast  (Client2)', bcastSelf);
      printBcast('E-4 peer-bcast  (Client1)', bcast1);
    }

    await showDbState(geoEventId, 'Geo Event – after Suite E');

    // ════════════════════════════════════════════════════════════════════════
    //  SUITE F – Room membership guard
    // ════════════════════════════════════════════════════════════════════════
    step('SUITE F – Room membership guard (client connected but never joined room)');

    const standaloneClient = await connectSocket('Client-Standalone (no room)', token3);
    clients.push(standaloneClient);
    // Deliberately skip startEvent + joinEvent – WS connected but socket in no room
    {
      const ack = await emitVote(standaloneClient, publicEventId, TRACK_ID_1, 'up');
      assert(isError(ack), 'F-1 ack – Vote without joining room → WsException "must join room"');
      printAck('F-1 ack (Standalone – expect error: not in room)', ack);
    }

    // ════════════════════════════════════════════════════════════════════════
    //  SUMMARY
    // ════════════════════════════════════════════════════════════════════════
    step('TEST SUMMARY');
    const total = passed + failed;
    console.log(
      `${col.green}PASSED: ${passed}/${total}${col.reset}  ` +
      `${failed > 0 ? col.red : col.green}FAILED: ${failed}/${total}${col.reset}`,
    );
    if (failed > 0) process.exitCode = 1;

  } catch (err) {
    console.error(`${col.red}❌ Unexpected error:${col.reset}`, err);
    process.exitCode = 1;
  } finally {
    clients.forEach(c => c.disconnect());
    step('CLEANUP');
    await cleanupAll();
    await prisma.$disconnect();
    await sleep(500);
    process.exit(process.exitCode ?? 0);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HELPERS
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Emit event:start and await the ack.
 * Must be called once per event before the host does event:host_join.
 * Subsequent rejoins (after host_leave / disconnect) skip this step.
 */
function startEvent(client: Socket, eventId: string): Promise<any> {
  return new Promise((resolve) => {
    console.log(`[${client.id}] Starting event ${eventId}`);
    const timer = setTimeout(() => resolve({ error: 'Timeout' }), 5000);
    client.emit('event:start', { eventId }, (ack: any) => {
      clearTimeout(timer);
      console.log(`[${client.id}] event:start ack`, ack);
      resolve(ack ?? null);
    });
  });
}

function endEvent(client: Socket, eventId: string): Promise<any> {
  return new Promise((resolve) => {
    console.log(`[${client.id}] Ending event ${eventId}`);
    const timer = setTimeout(() => resolve({ error: 'Timeout' }), 5000);
    client.emit('event:end', { eventId }, (ack: any) => {
      clearTimeout(timer);
      console.log(`[${client.id}] event:end ack`, ack);
      resolve(ack ?? null);
    });
  });
}

/** Join an event room via the correct WS event. */
function joinEvent(client: Socket, eventId: string, isHost = false) {
  if (isHost) {
    client.emit('event:host_join', { eventId });
  } else {
    client.emit('event:join', { eventId });
  }
}

/**
 * Emit track:vote and resolve with the ack payload.
 * Resolves null after 3 s if the server never acks.
 */
function emitVote(
  client: Socket,
  eventId: string,
  trackId: string,
  vote: 'up' | 'down' | 'none',
): Promise<any> {
  return new Promise((resolve) => {
    const timer = setTimeout(() => resolve(null), 3000);
    client.emit('track:vote', { eventId, trackId, vote }, (ack: any) => {
      clearTimeout(timer);
      resolve(ack ?? null);
    });
  });
}

function emitVoteWithLocation(
  client: Socket,
  eventId: string,
  trackId: string,
  vote: 'up' | 'down' | 'none',
  locationLat: number,
  locationLng: number,
): Promise<any> {
  return new Promise((resolve) => {
    const timer = setTimeout(() => resolve(null), 3000);
    client.emit('track:vote', { eventId, trackId, vote, locationLat, locationLng }, (ack: any) => {
      clearTimeout(timer);
      resolve(ack ?? null);
    });
  });
}

/**
 * Resolves with the first track:vote_updated broadcast matching trackId.
 * Resolves null after `ms` ms.
 */
function waitForBroadcast(client: Socket, trackId: string, ms = 5000): Promise<any> {
  return new Promise((resolve) => {
    const timer = setTimeout(() => resolve(null), ms);
    const handler = (data: any) => {
      if (data?.trackId === trackId) {
        clearTimeout(timer);
        client.off('track:vote_updated', handler);
        resolve(data);
      }
    };
    client.on('track:vote_updated', handler);
  });
}

/** True when the payload is a WsException (not a VoteResult). */
function isError(ack: any): boolean {
  if (ack === null || ack === undefined) return true;
  if (ack.error || ack.message || ack.status === 'error') return true;
  if (typeof ack.score === 'undefined') return true;
  return false;
}

/** True when the payload is a well-formed TrackVoteResultDto. */
function isValidResult(data: any, eventId: string, trackId: string): boolean {
  return (
    data !== null &&
    data?.eventId === eventId &&
    data?.trackId === trackId &&
    typeof data?.score === 'number' &&
    typeof data?.updatedAt === 'string'
  );
}

function printAck(label: string, ack: any) {
  const colour = isError(ack) ? col.red : col.blue;
  console.log(`${colour}  [ACK   ${label}]${col.reset}`, JSON.stringify(ack, null, 2));
}

function printBcast(label: string, data: any) {
  const colour = data === null ? col.yellow : col.purple;
  console.log(`${colour}  [BCAST ${label}]${col.reset}`, JSON.stringify(data, null, 2));
}

async function getDbScore(eventId: string, trackId: string): Promise<number> {
  const et = await prisma.eventTrack.findUnique({
    where: { eventId_trackId: { eventId, trackId } },
  });
  return et?.voteScore ?? 0;
}

async function showDbState(eventId: string, label: string) {
  info(`DB STATE — ${label}`);
  const evTracks = await prisma.eventTrack.findMany({
    where: { eventId },
    include: { votes: true },
    orderBy: { trackId: 'asc' },
  });
  if (evTracks.length === 0) { warn('No eventTracks found.'); return; }
  for (const et of evTracks) {
    console.log(
      `${col.cyan}  Track [${et.trackId}]${col.reset}  score=${et.voteScore}` +
      `  votes=[${et.votes.map(v => `userId=${v.userId} val=${v.voteValue}`).join(', ')}]`,
    );
  }
}

async function cleanupAll() {
  const emails = [USER1_EMAIL, USER2_EMAIL, USER3_EMAIL];
  await prisma.vote.deleteMany({ where: { user: { email: { in: emails } } } });
  await prisma.eventTrack.deleteMany({ where: { event: { host: { email: { in: emails } } } } });
  await prisma.event.deleteMany({ where: { host: { email: { in: emails } } } });
  await prisma.user.deleteMany({ where: { email: { in: emails } } });
}

async function login(identifier: string, password: string): Promise<string> {
  const res = await fetch(`${API_URL}/auth/login`, {
    method: 'POST',
    headers: { 
      'Content-Type': 'application/json',
      'x-platform': 'test-script',
      'x-device-model': 'test-environment',
      'x-app-version': '1.0.0'
    },
    body: JSON.stringify({ identifier, password }),
  });
  if (!res.ok) throw new Error(`Login failed for ${identifier}: ${res.status} ${await res.text()}`);
  return ((await res.json()) as any).access_token;
}

async function apiCall(
  path: string,
  method: string,
  token: string,
  body?: Record<string, any>,
) {
  let formData: FormData | undefined;

  if (body) {
    formData = new FormData();
    Object.entries(body).forEach(([key, value]) => {
      if (Array.isArray(value) || typeof value === 'object') {
        formData!.append(key, JSON.stringify(value));
      } else {
        formData!.append(key, String(value));
      }
    });
  }

  const res = await fetch(`${API_URL}${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      'x-platform': 'test-script',
      'x-device-model': 'test-environment',
      'x-app-version': '1.0.0'
    },
    body: formData,
  });

  if (!res.ok) {
    throw new Error(`API Error [${method} ${path}]: ${res.status} – ${await res.text()}`);
  }

  return res.json();
}

function connectSocket(name: string, token: string): Promise<Socket> {
  return new Promise((resolve, reject) => {
    const client = io(WS_URL, { 
      path: '/ws', 
      auth: { token }, 
      transports: ['websocket'],
      extraHeaders: {
        'x-platform': 'test-script',
        'x-device-model': 'test-environment',
        'x-app-version': '1.0.0'
      }
    });

    client.on('connect', () => {
      console.log(`${col.green}  [${name}]${col.reset} connected (id=${client.id})`);
      resolve(client);
    });
    client.on('connect_error', (err) => {
      console.log(`${col.red}  [${name}]${col.reset} connection error: ${err.message}`);
      reject(err);
    });

    client.on('track:vote_updated', (data: any) =>
      console.log(`${col.purple}  [${name}] ← track:vote_updated${col.reset}`, JSON.stringify(data)),
    );
    client.on('exception', (data: any) =>
      console.log(`${col.red}  [${name}] ← exception${col.reset}`, JSON.stringify(data)),
    );
    client.on('room:playlist:updated', (data: any) =>
      console.log(`${col.yellow}  [${name}] ← room:playlist:updated${col.reset}`, JSON.stringify(data)),
    );
  });
}

function sleep(ms: number) {
  return new Promise(r => setTimeout(r, ms));
}

main();