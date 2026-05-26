/**
 * DETOA v2.10.0 — start.js
 * DB auto-init wrapper that runs before server.js
 *
 * This script ensures the database exists and is seeded before
 * starting the Next.js standalone server. It handles:
 *   1. Creating the db/ directory if missing
 *   2. Running prisma db push if tables don't exist
 *   3. Running the seed if no CenterConfig record exists
 *   4. Starting server.js
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const DB_DIR = path.join(__dirname, 'db');
const DB_FILE = path.join(DB_DIR, 'custom.db');
const PRISMA_SCHEMA = path.join(__dirname, 'prisma', 'schema.prisma');
const SEED_FILE = path.join(__dirname, 'prisma', 'seed.ts');

function run(cmd, label) {
  try {
    console.log(`[start.js] ${label}...`);
    execSync(cmd, { stdio: 'inherit', env: { ...process.env } });
    console.log(`[start.js] ${label} — OK`);
    return true;
  } catch (e) {
    console.warn(`[start.js] ${label} — FAILED (${e.message})`);
    return false;
  }
}

function isDbInitialized() {
  if (!fs.existsSync(DB_FILE)) return false;
  try {
    // Quick check: can we connect and find a CenterConfig?
    const { PrismaClient } = require('@prisma/client');
    const prisma = new PrismaClient();
    // Synchronous check using $queryRaw
    const result = prisma.$queryRawUnsafe('SELECT COUNT(*) as cnt FROM CenterConfig');
    // If we get here, tables exist
    return true;
  } catch {
    return false;
  }
}

// ── Main ──
console.log('[start.js] DETOA v2.10.0 — Auto-initializing...');

// 1. Ensure db directory exists
if (!fs.existsSync(DB_DIR)) {
  fs.mkdirSync(DB_DIR, { recursive: true });
  console.log('[start.js] Created db/ directory');
}

// 1b. Ensure upload directories exist
const UPLOAD_DIRS = [
  path.join(__dirname, 'public', 'uploads'),
  path.join(__dirname, 'public', 'uploads', 'products'),
];
for (const dir of UPLOAD_DIRS) {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
    console.log(`[start.js] Created ${path.relative(__dirname, dir)}/ directory`);
  }
}

// 2. ALWAYS set DATABASE_URL to absolute path.
//    Prisma cannot reliably resolve relative SQLite paths,
//    especially in standalone mode where the directory structure
//    differs from development. Absolute path = guaranteed correct.
const absDbPath = path.join(DB_DIR, 'custom.db').replace(/\\/g, '/');
process.env.DATABASE_URL = `file:${absDbPath}`;
console.log(`[start.js] DATABASE_URL=${process.env.DATABASE_URL}`);

// 3. If database file doesn't exist, run prisma db push
if (!fs.existsSync(DB_FILE)) {
  console.log('[start.js] Database not found — initializing...');

  // Try prisma db push
  let pushOk = false;
  if (fs.existsSync(path.join(__dirname, 'node_modules', '.bin', 'prisma'))) {
    pushOk = run('node node_modules/.bin/prisma db push --skip-generate', 'prisma db push');
  }
  if (!pushOk) {
    pushOk = run('npx prisma db push --skip-generate', 'prisma db push (npx)');
  }
  if (!pushOk) {
    // Last resort: try the prisma entrypoint directly
    const prismaEntry = path.join(__dirname, 'node_modules', 'prisma', 'entrypoint.js');
    if (fs.existsSync(prismaEntry)) {
      pushOk = run(`node "${prismaEntry}" db push --skip-generate`, 'prisma db push (entrypoint)');
    }
  }

  if (!pushOk) {
    console.warn('[start.js] WARNING: Could not create database tables.');
    console.warn('[start.js] The server may fail. Run INSTALAR.bat to fix.');
  }
}

// 3. If database exists but may not be seeded, run seed
if (fs.existsSync(DB_FILE)) {
  // Check if seed is needed by looking for CenterConfig
  try {
    const { PrismaClient } = require('@prisma/client');
    const prisma = new PrismaClient();
    // Use a simple raw query to check if tables exist and have data
    const tables = prisma.$queryRawUnsafe(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='CenterConfig'"
    );
    // If we can query without error, check if CenterConfig has records
    // This is async but we handle it below
  } catch {
    // Tables might not exist yet — try db push again
    run('npx prisma db push --skip-generate', 'prisma db push (retry)');
  }

  // Run seed if needed (using tsx or node+tsx/cjs)
  try {
    const { PrismaClient } = require('@prisma/client');
    const prisma = new PrismaClient();

    prisma.centerConfig.findFirst().then(async (config) => {
      if (!config) {
        console.log('[start.js] No CenterConfig found — running seed...');
        if (fs.existsSync(SEED_FILE)) {
          let seedOk = run('npx tsx prisma/seed.ts', 'seed');
          if (!seedOk) {
            run('node -e "require(\'tsx/cjs\'); require(\'./prisma/seed.ts\')"', 'seed (tsx/cjs)');
          }
        }
      } else {
        console.log('[start.js] Database already seeded — OK');
      }
      await prisma.$disconnect();
    }).catch(async () => {
      await prisma.$disconnect();
    });
  } catch {
    // Prisma client not available yet, skip seed check
  }
}

// 4. Auto-open browser after a delay (if DETOA_AUTO_OPEN is set)
if (process.env.DETOA_AUTO_OPEN === '1') {
  const port = process.env.PORT || '3000';
  const url = `http://localhost:${port}`;
  setTimeout(() => {
    try {
      const start = process.platform === 'win32' ? 'start' : process.platform === 'darwin' ? 'open' : 'xdg-open';
      require('child_process').exec(`${start} ${url}`);
    } catch {}
  }, 3000);
}

// 5. Start the Next.js standalone server
console.log('[start.js] Starting Next.js server...');
const serverPath = path.join(__dirname, 'server.js');
if (fs.existsSync(serverPath)) {
  require(serverPath);
} else {
  // Check if we're in project root and standalone exists elsewhere
  const standaloneServer = path.join(__dirname, '.next', 'standalone', 'server.js');
  if (fs.existsSync(standaloneServer)) {
    console.error('[start.js] server.js not found here, but .next/standalone/server.js exists.');
    console.error('[start.js] Run INICIAR.bat which will auto-detect the standalone directory.');
  } else {
    console.error('[start.js] ERROR: server.js not found!');
    console.error('[start.js] The production build has not been completed.');
    console.error('[start.js] Run INSTALAR.bat to build, or use INICIAR.bat for dev mode.');
  }
  process.exit(1);
}
