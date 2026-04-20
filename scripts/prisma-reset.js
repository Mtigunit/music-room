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

  if (fs.existsSync(migrationsDir)) {
    console.log(`${COLOR_INFO}Deleting migration files...${COLOR_RESET}`);
    // fs.rmSync is available in Node 14.14.0+
    fs.rmSync(migrationsDir, { recursive: true, force: true });
  }

  // Drop the database and push current schema state without relying on migrations history
  run('npx prisma db push --force-reset');
  
  // Re-initialize the migration file cleanly
  run('npx prisma migrate dev --name init');
  
  // Refresh Prisma client
  run('npx prisma generate');

  console.log(`${COLOR_SUCCESS}Done: prisma reset completed.${COLOR_RESET}`);
} catch (error) {
  console.error('\x1b[1;31mError during prisma reset:\x1b[0m\n', error.message);
  process.exit(1);
}
