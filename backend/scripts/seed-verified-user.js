require('dotenv').config();
const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');
const jwt = require('jsonwebtoken');

async function main() {
  const adapter = new PrismaPg(process.env.DATABASE_URL);
  const prisma = new PrismaClient({ adapter });

  const randomSuffix = Math.floor(Math.random() * 10000);
  const userEmail = `verified-user-${randomSuffix}@example.com`;
  const username = `verified_user_${randomSuffix}`;

  console.log(`🚀 Seeding verified user: ${userEmail}...`);

  const user = await prisma.user.create({
    data: {
      email: userEmail,
      username: username,
      isEmailVerified: true,
      publicInfo: {},
      preferences: {},
    },
  });

  console.log('✅ User created successfully!');

  const payload = { sub: user.id, email: user.email };
  const token = jwt.sign(payload, process.env.JWT_SECRET, { expiresIn: '7d' });

  console.log('\n--- AUTH CREDENTIALS ---');
  console.log(`User ID:      ${user.id}`);
  console.log(`Email:        ${user.email}`);
  console.log(`Access Token: ${token}`);
  console.log('------------------------\n');

  await prisma.$disconnect();
}

main().catch((err) => {
  console.error('❌ Error seeding user:', err);
  process.exit(1);
});
