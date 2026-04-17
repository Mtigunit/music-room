const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

const repoRoot = path.resolve(__dirname, "..");
const mobileDir = path.join(repoRoot, "mobile");
const testDir = path.join(mobileDir, "test");

function hasDartTests(dirPath) {
  if (!fs.existsSync(dirPath)) {
    return false;
  }

  const entries = fs.readdirSync(dirPath, { withFileTypes: true });
  for (const entry of entries) {
    const entryPath = path.join(dirPath, entry.name);
    if (entry.isDirectory()) {
      if (hasDartTests(entryPath)) {
        return true;
      }
      continue;
    }

    if (entry.isFile() && entry.name.endsWith("_test.dart")) {
      return true;
    }
  }

  return false;
}

if (!hasDartTests(testDir)) {
  console.log("No Flutter tests found in mobile/test. Skipping mobile test.");
  process.exit(0);
}

const result = spawnSync("flutter", ["test"], {
  cwd: mobileDir,
  stdio: "inherit",
  shell: true,
});

process.exit(result.status ?? 1);
