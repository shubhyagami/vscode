/**
 * Database Synchronization Daemon for Code-Server
 * Automatically syncs files between /home/coder/project and DATABASE_PUBLIC_URL
 */

const fs = require('fs');
const path = require('path');
const http = require('http');
const https = require('https');

const WORKSPACE_DIR = process.env.WORKSPACE_DIR || '/home/coder/project';
const DB_URL = process.env.DATABASE_PUBLIC_URL || '';
const DB_KEY = process.env.DATABASE_API_KEY || '';

// Files and folders to ignore during sync
const IGNORED_PATTERNS = [
  '.git',
  '.vscode',
  'node_modules',
  'target',
  '.class',
  '.DS_Store',
  '*.tmp'
];

function isIgnored(filePath) {
  const rel = path.relative(WORKSPACE_DIR, filePath);
  for (const pattern of IGNORED_PATTERNS) {
    if (pattern.startsWith('*.')) {
      const ext = pattern.slice(1);
      if (rel.endsWith(ext)) return true;
    } else {
      if (rel === pattern || rel.startsWith(pattern + path.sep) || rel.includes(path.sep + pattern + path.sep)) {
        return true;
      }
    }
  }
  return false;
}

function request(url, options = {}, data = null) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(url);
    const client = parsed.protocol === 'https:' ? https : http;

    const reqOptions = {
      hostname: parsed.hostname,
      port: parsed.port || (parsed.protocol === 'https:' ? 443 : 80),
      path: parsed.pathname + parsed.search,
      method: options.method || 'GET',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...(DB_KEY ? { 'Authorization': `Bearer ${DB_KEY}`, 'apikey': DB_KEY } : {}),
        ...(options.headers || {})
      },
      timeout: 10000
    };

    const req = client.request(reqOptions, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => {
        try {
          const json = body ? JSON.parse(body) : {};
          resolve({ status: res.statusCode, data: json, raw: body });
        } catch {
          resolve({ status: res.statusCode, data: body, raw: body });
        }
      });
    });

    req.on('error', reject);
    req.on('timeout', () => {
      req.destroy();
      reject(new Error('Request timeout'));
    });

    if (data) {
      req.write(typeof data === 'string' ? data : JSON.stringify(data));
    }
    req.end();
  });
}

/**
 * Pull all files from DATABASE_PUBLIC_URL into workspace
 */
async function pullFromDatabase() {
  if (!DB_URL) {
    console.log('[SyncDaemon] No DATABASE_PUBLIC_URL set. Running in local mode.');
    return;
  }

  console.log(`[SyncDaemon] Pulling files from database: ${DB_URL}...`);
  try {
    const endpoint = DB_URL.endsWith('/files') ? DB_URL : `${DB_URL.replace(/\/$/, '')}/files`;
    const res = await request(endpoint, { method: 'GET' });

    if (res.status >= 200 && res.status < 300) {
      let fileMap = {};
      if (Array.isArray(res.data)) {
        for (const f of res.data) {
          if (f.path) fileMap[f.path] = f.content || '';
        }
      } else if (res.data.files) {
        fileMap = res.data.files;
      } else if (typeof res.data === 'object') {
        fileMap = res.data;
      }

      let count = 0;
      for (const [relPath, fileObj] of Object.entries(fileMap)) {
        const content = typeof fileObj === 'string' ? fileObj : (fileObj.content ?? '');
        const targetPath = path.join(WORKSPACE_DIR, relPath);
        fs.mkdirSync(path.dirname(targetPath), { recursive: true });
        fs.writeFileSync(targetPath, content, 'utf8');
        count++;
      }
      console.log(`[SyncDaemon] Successfully pulled and restored ${count} files from database!`);
    } else {
      console.warn(`[SyncDaemon] Database responded with HTTP ${res.status}. Keeping existing workspace.`);
    }
  } catch (err) {
    console.error(`[SyncDaemon] Failed to pull files from database:`, err.message);
  }
}

/**
 * Push a single modified file to database
 */
const pendingSaves = new Map();

function queuePushFile(relPath) {
  if (!DB_URL || isIgnored(path.join(WORKSPACE_DIR, relPath))) return;

  if (pendingSaves.has(relPath)) {
    clearTimeout(pendingSaves.get(relPath));
  }

  // Debounce saves by 1.5 seconds
  const timer = setTimeout(async () => {
    pendingSaves.delete(relPath);
    await pushFile(relPath);
  }, 1500);

  pendingSaves.set(relPath, timer);
}

async function pushFile(relPath) {
  const fullPath = path.join(WORKSPACE_DIR, relPath);
  if (!fs.existsSync(fullPath)) return;

  try {
    const stat = fs.statSync(fullPath);
    if (stat.isDirectory()) return;

    const content = fs.readFileSync(fullPath, 'utf8');
    const endpoint = DB_URL.endsWith('/files') ? DB_URL : `${DB_URL.replace(/\/$/, '')}/files`;

    console.log(`[SyncDaemon] Auto-saving ${relPath} to database...`);
    const res = await request(endpoint, { method: 'POST' }, {
      path: relPath.replace(/\\/g, '/'),
      content,
      updatedAt: new Date().toISOString()
    });

    if (res.status >= 200 && res.status < 300) {
      console.log(`[SyncDaemon] ✓ Successfully saved ${relPath} to database.`);
    } else {
      console.warn(`[SyncDaemon] ⚠ Remote DB responded with HTTP ${res.status} for ${relPath}`);
    }
  } catch (err) {
    console.error(`[SyncDaemon] ✗ Error pushing ${relPath}:`, err.message);
  }
}

async function deleteFileFromDb(relPath) {
  if (!DB_URL || isIgnored(path.join(WORKSPACE_DIR, relPath))) return;

  console.log(`[SyncDaemon] Deleting ${relPath} from database...`);
  try {
    const normalized = relPath.replace(/\\/g, '/');
    const endpoint = `${DB_URL.replace(/\/$/, '')}/files?path=${encodeURIComponent(normalized)}`;
    const res = await request(endpoint, { method: 'DELETE' });
    console.log(`[SyncDaemon] ✓ Deleted ${relPath} from database (HTTP ${res.status}).`);
  } catch (err) {
    console.error(`[SyncDaemon] ✗ Error deleting ${relPath}:`, err.message);
  }
}

/**
 * Watch directory recursively for changes
 */
function startWatcher() {
  console.log(`[SyncDaemon] Watching workspace: ${WORKSPACE_DIR}`);

  try {
    fs.watch(WORKSPACE_DIR, { recursive: true }, (eventType, filename) => {
      if (!filename || isIgnored(path.join(WORKSPACE_DIR, filename))) return;

      const fullPath = path.join(WORKSPACE_DIR, filename);
      if (fs.existsSync(fullPath)) {
        queuePushFile(filename);
      } else {
        deleteFileFromDb(filename);
      }
    });
  } catch (err) {
    console.error('[SyncDaemon] Watch error:', err.message);
  }
}

async function main() {
  console.log('====================================================');
  console.log('⚡ Code-Server Database Sync Daemon Started');
  console.log(`📂 Workspace: ${WORKSPACE_DIR}`);
  console.log(`💾 Database: ${DB_URL || 'None (Local Storage)'}`);
  console.log('====================================================');

  // 1. Initial pull from database
  await pullFromDatabase();

  // 2. Start live file watcher
  startWatcher();
}

// Handle exports for CLI tool or standalone run
if (require.main === module) {
  main().catch(console.error);
}

module.exports = { pullFromDatabase, pushFile, deleteFileFromDb };
