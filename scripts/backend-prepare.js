const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const COLOR_INFO = '\x1b[1;36m';
const COLOR_SUCCESS = '\x1b[1;32m';
const COLOR_WARN = '\x1b[1;33m';
const COLOR_CMD = '\x1b[1;34m';
const COLOR_RESET = '\x1b[0m';

const backendDir = path.join(__dirname, '..', 'backend');
const packageJsonPath = path.join(backendDir, 'package.json');

function run(cmd) {
  console.log(`${COLOR_CMD}> ${cmd}${COLOR_RESET}...`);
  try {
    execSync(cmd, {
      stdio: 'pipe',
      cwd: backendDir,
      maxBuffer: 10 * 1024 * 1024 // 10MB buffer to prevent ENOBUFS
    });
    console.log(`${COLOR_SUCCESS}  ✓ Success${COLOR_RESET}`);
  } catch (error) {
    console.error(`\x1b[1;31m  ✗ Failed\x1b[0m\n`);

    // Clean up npm error spam to show only the actual tool issues
    const cleanLogs = (buffer) => {
      if (!buffer) return '';
      return buffer.toString()
        .split('\n')
        .filter(line =>
          !line.startsWith('npm error') &&
          !line.startsWith('npm ERR!') &&
          !line.includes('Lifecycle script')
        )
        .join('\n').trim();
    };

    const outStr = cleanLogs(error.stdout);
    const errStr = cleanLogs(error.stderr);

    if (outStr) console.error(`${COLOR_WARN}${outStr}${COLOR_RESET}`);
    if (errStr) console.error(`${COLOR_WARN}${errStr}${COLOR_RESET}`);

    throw new Error(`Command failed: ${cmd}`);
  }
}

if (!fs.existsSync(packageJsonPath)) {
  console.log(`${COLOR_WARN}No backend found. Skipping prepare.${COLOR_RESET}`);
  process.exit(0);
}

try {
  console.log(`${COLOR_INFO}Preparing backend environment...${COLOR_RESET}`);

  // Use --silent to prevent npm from polluting the output with stacktraces
  run('npm run format --silent');
  run('npm run lint:fix --silent');
  run('npm run test --silent');

  console.log(`\n${COLOR_SUCCESS}Done: Backend environment prepared successfully.${COLOR_RESET}`);
} catch (error) {
  console.error(`\n\x1b[1;31mBackend preparation aborted.${COLOR_RESET}`);
  process.exit(1);
}
