const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Define color codes for terminal output
const COLOR_INFO = '\x1b[1;36m';
const COLOR_SUCCESS = '\x1b[1;32m';
const COLOR_WARN = '\x1b[1;33m';
const COLOR_CMD = '\x1b[1;34m';
const COLOR_RESET = '\x1b[0m';

const backendDir = path.join(__dirname, '..', 'backend');
const packageJsonPath = path.join(backendDir, 'package.json');
const migrationsDir = path.join(backendDir, 'prisma', 'migrations');

function run(cmd) {
  console.log(`${COLOR_CMD}> ${cmd}${COLOR_RESET}`);
  execSync(cmd, { stdio: 'inherit', cwd: backendDir });
}

if (!fs.existsSync(packageJsonPath)) {
  console.log(`${COLOR_WARN}No backend yet${COLOR_RESET}`);
  process.exit(0);
}

try {
  console.log(`${COLOR_INFO}Starting prisma reset...${COLOR_RESET}`);

  // 1. Wipe local migrations so we start fresh
  if (fs.existsSync(migrationsDir)) {
    console.log(`${COLOR_INFO}Deleting migration files...${COLOR_RESET}`);
    fs.rmSync(migrationsDir, { recursive: true, force: true });
  }

  // 2. Recreate an empty migrations folder explicitly. 
  // This ensures `prisma migrate reset` doesn't crash on fresh checkouts complaining about the missing folder,
  // but importantly forces it to apply ZERO migrations, leaving the DB completely empty.
  if (!fs.existsSync(migrationsDir)) {
    fs.mkdirSync(migrationsDir, { recursive: true });
  }

  // 3. Drop and reset the database. Because the migrations folder is empty, the DB is left naked.
  run('npx prisma migrate reset --force');
  
  // 4. Generate the new initial migration from the Prisma schema against our empty DB. No drift errors!
  run('npx prisma migrate dev --name init');
  
  // 5. Refresh Prisma client
  run('npx prisma generate');

  console.log(`${COLOR_SUCCESS}Done: prisma reset completed.${COLOR_RESET}`);
} catch (error) {
  console.error('\x1b[1;31mError during prisma reset:\x1b[0m\n', error.message);
  process.exit(1);
}
