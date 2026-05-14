import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';
import * as bcrypt from 'bcrypt';
import * as dotenv from 'dotenv';

dotenv.config();

// ===================== CONFIG ===================== //
const BASE_URL = 'http://localhost:3000';
const PASSWORD = 'Password123!';

const USERS = [
  { email: 'seed-user1@example.com', username: 'seed_user1' },
  { email: 'seed-user2@example.com', username: 'seed_user2' },
  { email: 'seed-user3@example.com', username: 'seed_user3' },
  { email: 'seed-user4@example.com', username: 'seed_user4' },
];

// ===================== PRISMA ===================== //
const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

// ===================== HELPERS ===================== //
async function login(email: string): Promise<string> {
  const res = await fetch(`${BASE_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ identifier: email, password: PASSWORD }),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Login failed for ${email} [${res.status}]: ${text}`);
  }
  const data: any = await res.json();
  return data.access_token;
}

async function post(path: string, body: any, token: string) {
  const res = await fetch(`${BASE_URL}${path}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`POST ${path} failed [${res.status}]: ${text}`);
  }
  return res.json();
}

// ===================== MAIN ===================== //
async function main() {
  console.log('🌱 Starting event seed...\n');

  // ── 1. Clean up any previous seed data ────────────────────────────────────
  console.log('🧹 Cleaning up old seed data...');
  const emails = USERS.map((u) => u.email);
  await prisma.vote.deleteMany({ where: { user: { email: { in: emails } } } });
  await prisma.eventTrack.deleteMany({ where: { event: { host: { email: { in: emails } } } } });
  await prisma.event.deleteMany({ where: { host: { email: { in: emails } } } });
  await prisma.user.deleteMany({ where: { email: { in: emails } } });
  console.log('  ✅ Done\n');

  // ── 2. Create users directly via Prisma ───────────────────────────────────
  console.log('👤 Creating users...');
  const passwordHash = await bcrypt.hash(PASSWORD, 10);
  const createdUsers = await Promise.all(
    USERS.map((u) =>
      prisma.user.create({
        data: { ...u, passwordHash, isEmailVerified: true },
      }),
    ),
  );

  const userMap: Record<string, { id: string; email: string }> = {};
  for (const u of createdUsers) {
    userMap[u.username] = { id: u.id, email: u.email };
    console.log(`  ✅ Created ${u.username} → id: ${u.id}`);
  }

  // ── 3. Log in to get tokens (needed for event/invite API calls) ────────────
  console.log('\n🔑 Logging in...');
  const tokens: Record<string, string> = {};
  for (const u of createdUsers) {
    tokens[u.username] = await login(u.email);
    console.log(`  ✅ ${u.username} logged in`);
  }

  // ── 4. user1 creates two events ────────────────────────────────────────────
  console.log('\n🎉 seed_user1 creating events...');
  const user1Events: string[] = [];
  for (let i = 1; i <= 2; i++) {
    const event = await post(
      '/events',
      {
        name: `User1 Event ${i}`,
        visibility: 'PUBLIC',
        tags: ['POP'],
        invitingOnly: false,
        startDate: new Date().toISOString(),
        tracks: [],
      },
      tokens['seed_user1'],
    );
    user1Events.push(event.id);
    console.log(`  ✅ "${event.name}" → id: ${event.id}`);
  }

  // ── 5. user1 invites user2 and user3 ──────────────────────────────────────
  console.log('\n📨 seed_user1 inviting seed_user2 and seed_user3...');
  for (const eventId of user1Events) {
    for (const invitee of ['seed_user2', 'seed_user3']) {
      await post(`/events/${eventId}/invites`, { userId: userMap[invitee].id }, tokens['seed_user1']);
      console.log(`  ✅ Invited ${invitee} to event ${eventId}`);
    }
  }

  // ── 6. user4 creates two events ────────────────────────────────────────────
  console.log('\n🎉 seed_user4 creating events...');
  const user4Events: string[] = [];
  for (let i = 1; i <= 2; i++) {
    const event = await post(
      '/events',
      {
        name: `User4 Event ${i}`,
        visibility: 'PUBLIC',
        tags: ['POP'],
        invitingOnly: false,
        startDate: new Date().toISOString(),
        tracks: [],
      },
      tokens['seed_user4'],
    );
    user4Events.push(event.id);
    console.log(`  ✅ "${event.name}" → id: ${event.id}`);
  }

  // ── 7. user4 invites user1, user2, user3 ──────────────────────────────────
  console.log('\n📨 seed_user4 inviting seed_user1, seed_user2, seed_user3...');
  for (const eventId of user4Events) {
    for (const invitee of ['seed_user1', 'seed_user2', 'seed_user3']) {
      await post(`/events/${eventId}/invites`, { userId: userMap[invitee].id }, tokens['seed_user4']);
      console.log(`  ✅ Invited ${invitee} to event ${eventId}`);
    }
  }

  // ── Summary ────────────────────────────────────────────────────────────────
  console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('✅ Seed complete!\n');
  console.log('User IDs:');
  for (const [name, { id }] of Object.entries(userMap)) {
    console.log(`  ${name}: ${id}`);
  }
  console.log('\nEvents by seed_user1:', user1Events);
  console.log('Events by seed_user4:', user4Events);
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  await prisma.$disconnect();
  await pool.end();
}

main().catch(async (err) => {
  console.error('\n❌ Seed failed:', err.message);
  await prisma.$disconnect();
  await pool.end();
  process.exit(1);
});