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

const TEST_EMAIL = 'rate-limit-tester@example.com';
const TEST_PASSWORD = 'Password123!';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

async function main() {
  console.log('🚀 Starting Robust Rate Limit Test Script...');

  if (process.env.NODE_ENV === 'test') {
    console.warn('⚠️ WARNING: NODE_ENV is set to "test". The throttler limits are bypassed in the test environment.');
    console.warn('⚠️ Please run this script against a development or production server.');
  }

  let ownerSocket: Socket | null = null;

  try {
    // 1. CLEANUP & SEED
    console.log('\n🧹 [1/5] Preparing test user...');
    await prisma.user.deleteMany({
      where: { email: TEST_EMAIL },
    });

    const passwordHash = await bcrypt.hash(TEST_PASSWORD, 10);
    const user = await prisma.user.create({
      data: { email: TEST_EMAIL, username: 'rate_limit_tester', passwordHash, isEmailVerified: true },
    });

    // We must grab the token FIRST before we burn our IP's auth rate limit
    console.log('\n🔑 [2/5] Grabbing JWT before hitting auth limits...');
    const loginRes = await fetch(`${API_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ identifier: TEST_EMAIL, password: TEST_PASSWORD }),
    });

    if (!loginRes.ok) throw new Error('Initial login failed. Make sure server is running and DB is accessible.');
    const { access_token } = await loginRes.json();

    // 2. HTTP AUTH RATE LIMIT TEST (Limit: 10 per minute)
    console.log('\n🛡️  [3/5] Testing HTTP Auth Rate Limit (Max 10 req/min)...');
    let auth429Hit = false;
    for (let i = 1; i <= 15; i++) {
      const res = await fetch(`${API_URL}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ identifier: TEST_EMAIL, password: TEST_PASSWORD }),
      });

      if (res.status === 429) {
        console.log(`✅ Auth endpoint correctly blocked request #${i + 1} with 429 Too Many Requests!`);
        auth429Hit = true;
        break;
      }
    }
    assert.strictEqual(auth429Hit, true, 'Auth rate limit (10 req/min) was not enforced!');

    // 3. HTTP SEARCH RATE LIMIT TEST (Limit: 30 per minute)
    console.log('\n🛡️  [4/5] Testing HTTP Search Rate Limit (Max 30 req/min)...');
    let search429Hit = false;
    for (let i = 1; i <= 35; i++) {
      const res = await fetch(`${API_URL}/tracks/search?q=test`, {
        method: 'GET',
        headers: { 'Authorization': `Bearer ${access_token}` },
      });

      if (res.status === 429) {
        console.log(`✅ Search endpoint correctly blocked request #${i} with 429 Too Many Requests!`);
        search429Hit = true;
        break;
      }
    }
    assert.strictEqual(search429Hit, true, 'Search rate limit (30 req/min) was not enforced!');

    // 4. WEBSOCKET RATE LIMIT TEST (Limit: 30 per minute)
    console.log('\n🔌 [5/5] Testing WebSocket Rate Limit (Max 30 msg/min)...');

    ownerSocket = await new Promise((resolve, reject) => {
      const socket = io(WS_URL, { path: '/ws', auth: { token: access_token }, transports: ['websocket'] });
      socket.on('connect', () => resolve(socket));
      socket.on('connect_error', (err) => reject(err));
    });

    let wsRateLimitHit = false;

    // Listen for the custom rate:limit event
    ownerSocket?.onAny((eventName, ...args) => {
      if (eventName === 'exception') {
        const payload = args[0];
        if (payload?.message === 'Too many requests. Please slow down.') {
          console.log(`✅ WebSocket correctly threw a rate limit exception! Payload:`, payload);
          wsRateLimitHit = true;
        }
      }
    });

    let messagesProcessed = 0;
    ownerSocket?.on('room:error', () => messagesProcessed++);
    ownerSocket?.on('room:joined', () => messagesProcessed++);

    console.log('Spamming WebSocket with dummy events...');
    // Rapidly fire 35 messages
    for (let i = 1; i <= 35; i++) {
      ownerSocket?.emit('room:join', { roomId: 'dummy-room' }); // Use an unreserved event
    }

    // Wait a bit for the async processing and event emission
    await new Promise(r => setTimeout(r, 3000));

    console.log(`Server processed at least ${messagesProcessed} normal messages.`);
    assert.strictEqual(wsRateLimitHit, true, 'WebSocket rate limit (30 msg/min) was not enforced!');

    console.log('\n🎉 ALL RATE LIMIT ASSERTIONS PASSED FLAWLESSLY! Architecture is Bulletproof.');

  } catch (error) {
    console.error('\n❌ Test Failed:', error);
    process.exitCode = 1;
  } finally {
    if (ownerSocket) ownerSocket.disconnect();
    await prisma.$disconnect();
    process.exit();
  }
}

main();
