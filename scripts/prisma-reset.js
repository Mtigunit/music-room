const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Define color codes for terminal output
const COLOR_INFO = '\x1b[1;36m';
const COLOR_SUCCESS = '\x1b[1;32m';
const COLOR_WARN = '\x1b[1;33m';
const COLOR_CMD = '\x1b[1;34m';
const COLOR_ERROR = '\x1b[1;31m';
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
  
  // 4a. Generate the new initial migration WITHOUT applying it
  run('npx prisma migrate dev --name init --create-only');
  
  // 4b. Inject the PostgreSQL DEFERRABLE constraint manually into the generated init migration
  console.log(`${COLOR_INFO}Injecting DEFERRABLE constraint logic into init migration...${COLOR_RESET}`);
  const migrationFolders = fs.readdirSync(migrationsDir).filter(f => fs.statSync(path.join(migrationsDir, f)).isDirectory());
  const initFolder = migrationFolders.find(f => f.endsWith('_init'));
  if (!initFolder) {
    console.error(`${COLOR_ERROR}FATAL: Generated init migration folder not found. Expected a migration directory ending with "_init", but none was created. Aborting to avoid applying a non-deferrable (playlistId, position) constraint that would break reorder functionality.${COLOR_RESET}`);
    process.exit(1);
  }

  const migrationSqlPath = path.join(migrationsDir, initFolder, 'migration.sql');
  let sqlContent = fs.readFileSync(migrationSqlPath, 'utf8');
  
  // Replace the default Prisma unique index with a mathematically identical Deferrable Constraint
  // Prisma sometimes emits different formatting/schema qualifiers, so we use a resilient regex
  const targetQueryRegex = /CREATE\s+UNIQUE\s+INDEX\s+"PlaylistTrack_playlistId_position_key"\s+ON\s+(?:"[^"]+"\.)?"PlaylistTrack"\s*\(\s*"playlistId"\s*,\s*"position"\s*\)\s*;/i;
  const replacementQuery = 'ALTER TABLE "PlaylistTrack" ADD CONSTRAINT "PlaylistTrack_playlistId_position_key" UNIQUE ("playlistId", "position") DEFERRABLE INITIALLY DEFERRED;';
  
  const updatedSqlContent = sqlContent.replace(targetQueryRegex, replacementQuery);
  
  if (updatedSqlContent !== sqlContent && updatedSqlContent.includes(replacementQuery)) {
    fs.writeFileSync(migrationSqlPath, updatedSqlContent);
    console.log(`${COLOR_SUCCESS}Successfully injected DEFERRABLE constraint!${COLOR_RESET}`);
  } else {
     console.error(`${COLOR_ERROR}FATAL: Target CREATE UNIQUE INDEX query not found in init migration, or DEFERRABLE constraint injection failed verification. The DEFERRABLE constraint is critical for reorder functionality.${COLOR_RESET}`);
     process.exit(1);
  }

  // 4c. Apply the strictly modified initial migration
  run('npx prisma migrate dev');

  // 5. Refresh Prisma client
  run('npx prisma generate');

  console.log(`${COLOR_SUCCESS}Done: prisma reset completed.${COLOR_RESET}`);
} catch (error) {
  console.error('\x1b[1;31mError during prisma reset:\x1b[0m\n', error.message);
  process.exit(1);
}
