import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import zlib from "node:zlib";
import { fileURLToPath } from "node:url";
import {
  EXPECTED_HIVE_MODULES,
  evaluateHiveHealth,
  formatRelativeAge,
} from "./lib/hiveHealth.mjs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PORT = Number(process.env.PORT) || 3000;
const HOST = "0.0.0.0";
const WOWHEAD_CACHE_PATH = path.join(__dirname, "PluribusData", "Data", "WowheadCache.lua");
const CORE_DIR = path.join(__dirname, "PluribusCore");
const CORE_TOC_PATH = path.join(CORE_DIR, "PluribusCore.toc");

let lastBridgeProbe = {
  status: "connected",
  latencyMs: null,
  checkedAt: 0,
};

async function collectHiveHealthReport(runLiveProbe = false) {
  const presentModules = EXPECTED_HIVE_MODULES.filter((rel) =>
    fs.existsSync(path.join(CORE_DIR, rel))
  );

  const registeredModules = [];
  if (fs.existsSync(CORE_TOC_PATH)) {
    const tocLines = fs.readFileSync(CORE_TOC_PATH, "utf8").split(/\r?\n/);
    const tocSet = new Set(
      tocLines
        .map((l) => l.trim().replace(/\\/g, "/"))
        .filter((l) => l && !l.startsWith("#"))
    );
    for (const rel of EXPECTED_HIVE_MODULES) {
      if (tocSet.has(rel)) registeredModules.push(rel);
    }
  }

  let cacheValid = false;
  let cache = { revision: 0, updatedAt: 0, items: {}, quests: {}, npcs: {} };
  try {
    if (fs.existsSync(WOWHEAD_CACHE_PATH)) {
      cache = parseWowheadCacheLua();
      cacheValid = cache.revision > 0;
    }
  } catch {
    cacheValid = false;
  }

  if (runLiveProbe) {
    const started = Date.now();
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), 5000);
    try {
      const resp = await fetch("https://nether.wowhead.com/classic/tooltip/item/19019?dataEnv=4&locale=0", {
        signal: ctrl.signal,
        headers: { "User-Agent": "Pluribus-HiveHealth/2.0" },
      });
      const elapsed = Date.now() - started;
      lastBridgeProbe = {
        status: resp.ok ? (elapsed > 2500 ? "degraded" : "connected") : "degraded",
        latencyMs: elapsed,
        checkedAt: Math.floor(Date.now() / 1000),
      };
    } catch {
      lastBridgeProbe = {
        status: "offline",
        latencyMs: Date.now() - started,
        checkedAt: Math.floor(Date.now() / 1000),
      };
    } finally {
      clearTimeout(timer);
    }
  }

  const report = evaluateHiveHealth({
    presentModules,
    registeredModules,
    cacheValid,
    revision: cache.revision,
    counts: {
      items: Object.keys(cache.items).length,
      quests: Object.keys(cache.quests).length,
      npcs: Object.keys(cache.npcs).length,
    },
    updatedAt: cache.updatedAt,
    wowheadReachability: lastBridgeProbe.status,
    latencyMs: lastBridgeProbe.latencyMs,
  });

  return {
    ...report,
    cacheAgeText: formatRelativeAge(report.dataSync.cacheAgeSec),
    lastProbeAt: lastBridgeProbe.checkedAt,
  };
}

const WOWHEAD_PRESETS = {
  "raid-consumables": {
    type: "item",
    ids: [13510, 13511, 13512, 13452, 13454, 13444, 13446, 13457, 13458, 13461, 20004, 20007, 12820, 20520],
  },
  "raid-crafting": {
    type: "item",
    ids: [12360, 12363, 12800, 12803, 12808, 7076, 7078, 7080, 7082, 14344, 15407, 18512, 17010, 17011],
  },
};

function luaEscape(str) {
  return String(str || "")
    .replace(/\\/g, "\\\\")
    .replace(/"/g, '\\"')
    .replace(/\r?\n/g, " ")
    .slice(0, 140);
}

function stripHtmlSummary(html) {
  if (!html || typeof html !== "string") return "";
  const text = html
    .replace(/<br\s*\/?>/gi, " · ")
    .replace(/<\/td>/gi, " ")
    .replace(/<\/tr>/gi, " · ")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&quot;/g, '"')
    .replace(/&#0?39;/g, "'")
    .replace(/\s+/g, " ")
    .trim();
  const parts = text.split(" · ").map((s) => s.trim()).filter((s) => s.length > 2);
  // Skip first element (usually item name) and join next 2 meaningful lines
  return (parts.slice(1, 3).join(" · ") || parts[0] || "").slice(0, 110);
}

function parseWowheadCacheLua() {
  const data = { revision: 1, updatedAt: Math.floor(Date.now() / 1000), items: {}, quests: {}, npcs: {} };
  if (!fs.existsSync(WOWHEAD_CACHE_PATH)) return data;
  const content = fs.readFileSync(WOWHEAD_CACHE_PATH, "utf8");
  const revM = content.match(/revision\s*=\s*(\d+)/);
  if (revM) data.revision = Number(revM[1]) || 1;
  const updM = content.match(/updatedAt\s*=\s*(\d+)/);
  if (updM) data.updatedAt = Number(updM[1]) || data.updatedAt;

  let section = null;
  for (const line of content.split(/\r?\n/)) {
    if (/^\s*items\s*=\s*\{/.test(line)) { section = "items"; continue; }
    if (/^\s*quests\s*=\s*\{/.test(line)) { section = "quests"; continue; }
    if (/^\s*npcs\s*=\s*\{/.test(line)) { section = "npcs"; continue; }
    if (!section) continue;
    const m = line.match(/^\s*\[(\d+)\]\s*=\s*\{(.+)\}/);
    if (!m) continue;
    const id = Number(m[1]);
    const body = m[2];
    const getStr = (k) => {
      const sm = body.match(new RegExp(k + '\\s*=\\s*"((?:[^"\\\\]|\\\\.)*)"'));
      return sm ? sm[1].replace(/\\"/g, '"').replace(/\\\\/g, "\\") : "";
    };
    const getNum = (k, def = 0) => {
      const nm = body.match(new RegExp(k + "\\s*=\\s*(\\d+)"));
      return nm ? Number(nm[1]) : def;
    };
    if (section === "items") {
      data.items[id] = { name: getStr("name"), quality: getNum("quality", 1), ilvl: getNum("ilvl", 0), source: getStr("source") };
    } else if (section === "quests") {
      data.quests[id] = { name: getStr("name"), level: getNum("level", 0), zone: getStr("zone"), summary: getStr("summary") };
    } else if (section === "npcs") {
      data.npcs[id] = { name: getStr("name"), zone: getStr("zone"), note: getStr("note") };
    }
  }
  return data;
}

function writeWowheadCacheLua(cache) {
  const lines = [
    "-- PluribusData Wowhead On-Demand Cache",
    "-- Pre-seeded Classic / Warcraft Forever item, quest & NPC reference data",
    "-- Updated live via the companion app's \"Sync from Wowhead\" tool and propagated P2P across the guild!",
    "",
    "_G.PluribusWowheadCache = {",
    `\trevision = ${Number(cache.revision) || 1},`,
    `\tupdatedAt = ${Number(cache.updatedAt) || Math.floor(Date.now() / 1000)},`,
    "\titems = {",
  ];
  for (const id of Object.keys(cache.items || {}).map(Number).sort((a, b) => a - b)) {
    const it = cache.items[id];
    lines.push(`\t\t[${id}] = { name = "${luaEscape(it.name)}", quality = ${Number(it.quality) || 1}, ilvl = ${Number(it.ilvl) || 0}, source = "${luaEscape(it.source)}" },`);
  }
  lines.push("\t},");
  lines.push("\tquests = {");
  for (const id of Object.keys(cache.quests || {}).map(Number).sort((a, b) => a - b)) {
    const q = cache.quests[id];
    lines.push(`\t\t[${id}] = { name = "${luaEscape(q.name)}", level = ${Number(q.level) || 0}, zone = "${luaEscape(q.zone)}", summary = "${luaEscape(q.summary)}" },`);
  }
  lines.push("\t},");
  lines.push("\tnpcs = {");
  for (const id of Object.keys(cache.npcs || {}).map(Number).sort((a, b) => a - b)) {
    const n = cache.npcs[id];
    lines.push(`\t\t[${id}] = { name = "${luaEscape(n.name)}", zone = "${luaEscape(n.zone)}", note = "${luaEscape(n.note)}" },`);
  }
  lines.push("\t},");
  lines.push("}");
  lines.push("");
  fs.mkdirSync(path.dirname(WOWHEAD_CACHE_PATH), { recursive: true });
  fs.writeFileSync(WOWHEAD_CACHE_PATH, lines.join("\n"), "utf8");
}

async function fetchWowheadEntry(type, id) {
  const allowed = { item: "item", quest: "quest", npc: "npc" };
  const kind = allowed[type] || "item";
  const numId = Number(id);
  if (!Number.isInteger(numId) || numId <= 0 || numId > 999999) {
    throw new Error("Invalid ID");
  }
  const url = `https://nether.wowhead.com/classic/tooltip/${kind}/${numId}?dataEnv=4&locale=0`;
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 8000);
  try {
    const resp = await fetch(url, {
      signal: ctrl.signal,
      headers: { "User-Agent": "Pluribus-Companion/2.0" },
    });
    if (!resp.ok) throw new Error(`Wowhead HTTP ${resp.status}`);
    const json = await resp.json();
    if (!json || !json.name) throw new Error("Entry not found on Wowhead");
    const summary = stripHtmlSummary(json.tooltip || "");
    if (kind === "item") {
      const ilvlM = String(json.tooltip || "").match(/Item Level\s*<!--ilvl-->(\d+)/i);
      return {
        id: numId,
        name: String(json.name),
        quality: Number(json.quality) || 1,
        ilvl: ilvlM ? Number(ilvlM[1]) : 0,
        source: summary || "Synced from Wowhead Classic",
      };
    } else if (kind === "quest") {
      return { id: numId, name: String(json.name), level: 0, zone: "Azeroth", summary: summary || "Synced from Wowhead Classic" };
    } else {
      return { id: numId, name: String(json.name), zone: "Azeroth", note: summary || "Synced from Wowhead Classic" };
    }
  } finally {
    clearTimeout(timer);
  }
}

function readJsonBody(req, maxBytes = 32768) {
  return new Promise((resolve, reject) => {
    let total = 0;
    const chunks = [];
    req.on("data", (chunk) => {
      total += chunk.length;
      if (total > maxBytes) {
        reject(new Error("Payload too large"));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on("end", () => {
      try {
        resolve(JSON.parse(Buffer.concat(chunks).toString("utf8") || "{}"));
      } catch (e) {
        reject(new Error("Invalid JSON body"));
      }
    });
    req.on("error", reject);
  });
}

// Precompute IEEE 802.3 CRC-32 table for standard PKZIP 2.0 archives
const CRC32_TABLE = new Uint32Array(256);
for (let i = 0; i < 256; i++) {
  let c = i;
  for (let k = 0; k < 8; k++) {
    c = (c & 1) ? (0xedb88320 ^ (c >>> 1)) : (c >>> 1);
  }
  CRC32_TABLE[i] = c >>> 0;
}

function crc32(buf) {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) {
    c = CRC32_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  }
  return (c ^ 0xffffffff) >>> 0;
}

function toDosTimeDate(date) {
  const d = date instanceof Date ? date : new Date();
  const year = Math.max(1980, Math.min(2107, d.getFullYear()));
  const dosTime =
    ((d.getHours() & 0x1f) << 11) |
    ((d.getMinutes() & 0x3f) << 5) |
    ((Math.floor(d.getSeconds() / 2)) & 0x1f);
  const dosDate =
    (((year - 1980) & 0x7f) << 9) |
    (((d.getMonth() + 1) & 0x0f) << 5) |
    (d.getDate() & 0x1f);
  return { dosTime, dosDate };
}

function collectAddonZipEntries(rootDir) {
  const dirs = new Set();
  const files = [];

  function walk(currentDir) {
    const entries = fs.readdirSync(currentDir, { withFileTypes: true })
      .sort((a, b) => a.name.localeCompare(b.name));
    for (const entry of entries) {
      if (entry.name.startsWith(".")) continue;
      const fullPath = path.join(currentDir, entry.name);
      const rel = path.relative(rootDir, fullPath).split(path.sep).join("/");
      if (entry.isDirectory()) {
        dirs.add(rel + "/");
        walk(fullPath);
      } else if (entry.isFile()) {
        const stat = fs.statSync(fullPath);
        files.push({ rel, fullPath, mtime: stat.mtime });
      }
    }
  }

  for (const entry of fs.readdirSync(rootDir, { withFileTypes: true })
    .sort((a, b) => a.name.localeCompare(b.name))) {
    if (entry.isDirectory() && entry.name.startsWith("Pluribus")) {
      dirs.add(entry.name + "/");
      walk(path.join(rootDir, entry.name));
    }
  }

  return { dirs: Array.from(dirs).sort(), files };
}

function buildAddonsZipBuffer(rootDir) {
  const { dirs, files } = collectAddonZipEntries(rootDir);
  const localParts = [];
  const centralParts = [];
  let offset = 0;

  const addEntry = (name, dataBuf, isDir, mtime) => {
    const nameBuf = Buffer.from(name, "utf8");
    const { dosTime, dosDate } = toDosTimeDate(mtime);
    const uncompressedSize = dataBuf.length;
    const crc = isDir ? 0 : crc32(dataBuf);

    let method = 0;
    let payload = dataBuf;
    if (!isDir && uncompressedSize > 0) {
      const deflated = zlib.deflateRawSync(dataBuf, { level: 6 });
      if (deflated.length < uncompressedSize) {
        method = 8;
        payload = deflated;
      }
    }
    const compressedSize = payload.length;
    const flags = 0x0800; // UTF-8 filename flag
    const extAttr = isDir ? 0x00000010 : 0x00000020; // MS-DOS directory / archive attributes

    // Local File Header (30 bytes + filename)
    const lfh = Buffer.alloc(30);
    lfh.writeUInt32LE(0x04034b50, 0);
    lfh.writeUInt16LE(20, 4); // Version needed to extract (2.0)
    lfh.writeUInt16LE(flags, 6);
    lfh.writeUInt16LE(method, 8);
    lfh.writeUInt16LE(dosTime, 10);
    lfh.writeUInt16LE(dosDate, 12);
    lfh.writeUInt32LE(crc, 14);
    lfh.writeUInt32LE(compressedSize, 18);
    lfh.writeUInt32LE(uncompressedSize, 22);
    lfh.writeUInt16LE(nameBuf.length, 26);
    lfh.writeUInt16LE(0, 28);

    localParts.push(lfh, nameBuf, payload);

    // Central Directory File Header (46 bytes + filename)
    const cdfh = Buffer.alloc(46);
    cdfh.writeUInt32LE(0x02014b50, 0);
    cdfh.writeUInt16LE(0x0014, 4); // Version made by: MS-DOS / PKZIP 2.0 (Windows Explorer native)
    cdfh.writeUInt16LE(20, 6);     // Version needed
    cdfh.writeUInt16LE(flags, 8);
    cdfh.writeUInt16LE(method, 10);
    cdfh.writeUInt16LE(dosTime, 12);
    cdfh.writeUInt16LE(dosDate, 14);
    cdfh.writeUInt32LE(crc, 16);
    cdfh.writeUInt32LE(compressedSize, 20);
    cdfh.writeUInt32LE(uncompressedSize, 24);
    cdfh.writeUInt16LE(nameBuf.length, 28);
    cdfh.writeUInt16LE(0, 30);
    cdfh.writeUInt16LE(0, 32);
    cdfh.writeUInt16LE(0, 34);
    cdfh.writeUInt16LE(0, 36);
    cdfh.writeUInt32LE(extAttr, 38);
    cdfh.writeUInt32LE(offset, 42);

    centralParts.push(cdfh, nameBuf);
    offset += lfh.length + nameBuf.length + payload.length;
  };

  const now = new Date();
  for (const dirName of dirs) {
    addEntry(dirName, Buffer.alloc(0), true, now);
  }
  for (const f of files) {
    const content = fs.readFileSync(f.fullPath);
    addEntry(f.rel, content, false, f.mtime);
  }

  const centralDir = Buffer.concat(centralParts);
  const totalEntries = dirs.length + files.length;

  // End of Central Directory Record (22 bytes)
  const eocd = Buffer.alloc(22);
  eocd.writeUInt32LE(0x06054b50, 0);
  eocd.writeUInt16LE(0, 4);
  eocd.writeUInt16LE(0, 6);
  eocd.writeUInt16LE(totalEntries, 8);
  eocd.writeUInt16LE(totalEntries, 10);
  eocd.writeUInt32LE(centralDir.length, 12);
  eocd.writeUInt32LE(offset, 16);
  eocd.writeUInt16LE(0, 20);

  return {
    buffer: Buffer.concat([...localParts, centralDir, eocd]),
    fileCount: files.length,
    dirCount: dirs.length,
  };
}

function walkFiles(dir, baseDir) {
  const results = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      results.push(...walkFiles(fullPath, baseDir));
    } else if (entry.name.endsWith(".lua") || entry.name.endsWith(".toc")) {
      const rel = path.relative(baseDir, fullPath).split(path.sep).join("/");
      const stat = fs.statSync(fullPath);
      results.push({ path: rel, size: stat.size });
    }
  }
  return results.sort((a, b) => a.path.localeCompare(b.path));
}

function parseToc(tocPath) {
  const meta = {
    title: "",
    notes: "",
    version: "",
    interfaceVersion: "",
    dependencies: "",
  };
  if (!fs.existsSync(tocPath)) return meta;
  const content = fs.readFileSync(tocPath, "utf8");
  for (const line of content.split(/\r?\n/)) {
    const m = line.match(/^##\s*([^:]+):\s*(.*)$/);
    if (!m) continue;
    const key = m[1].trim().toLowerCase();
    const val = m[2].trim().replace(/\|c[0-9a-fA-F]{8}/g, "").replace(/\|r/g, "");
    if (key === "title") meta.title = val;
    else if (key === "notes") meta.notes = val;
    else if (key === "version") meta.version = val;
    else if (key === "interface") meta.interfaceVersion = val;
    else if (key === "dependencies" || key === "requireddeps") meta.dependencies = val;
  }
  return meta;
}

function getAddonInventory() {
  const entries = fs.readdirSync(__dirname, { withFileTypes: true });
  const addons = [];

  for (const entry of entries) {
    if (!entry.isDirectory() || !entry.name.startsWith("Pluribus")) continue;
    const addonDir = path.join(__dirname, entry.name);
    const tocPath = path.join(addonDir, `${entry.name}.toc`);
    const meta = parseToc(tocPath);
    const files = walkFiles(addonDir, __dirname);
    const luaCount = files.filter((f) => f.path.endsWith(".lua")).length;

    addons.push({
      name: entry.name,
      title: meta.title || entry.name,
      notes: meta.notes || "Warcraft Forever addon module",
      version: meta.version || "1.0.0",
      interfaceVersion: meta.interfaceVersion || "16001",
      dependencies: meta.dependencies || "",
      luaCount,
      files,
    });
  }

  return addons.sort((a, b) => a.name.localeCompare(b.name));
}

function safeResolveAddonFile(relPath) {
  if (!relPath || typeof relPath !== "string") return null;
  const normalized = path.posix.normalize(relPath).replace(/^\/+/, "");
  if (normalized.includes("..") || !normalized.startsWith("Pluribus")) return null;
  if (!normalized.endsWith(".lua") && !normalized.endsWith(".toc")) return null;
  const full = path.resolve(__dirname, normalized);
  if (!full.startsWith(__dirname + path.sep)) return null;
  if (!fs.existsSync(full) || !fs.statSync(full).isFile()) return null;
  return { full, normalized };
}

function renderHtml() {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Pluribus Suite — Warcraft Forever Addon Suite</title>
  <meta name="description" content="Warcraft Forever 1.60.1 Lua Addon Suite Explorer for all 27 Pluribus* addons." />
  <style>
    :root {
      --bg: #0c0e14;
      --panel: #131722;
      --panel-2: #191f2e;
      --border: #252e42;
      --text: #e6ebf5;
      --muted: #8f9bb3;
      --gold: #eab308;
      --accent: #38bdf8;
      --ok: #22c55e;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      background: var(--bg);
      color: var(--text);
      height: 100vh;
      display: flex;
      flex-direction: column;
      overflow: hidden;
    }
    header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 16px;
      padding: 14px 20px;
      background: var(--panel);
      border-bottom: 1px solid var(--border);
    }
    .brand { display: flex; align-items: center; gap: 11px; min-width: 0; }
    .brand-crest { width: 32px; height: 32px; flex-shrink: 0; filter: drop-shadow(0 0 8px rgba(56, 189, 248, 0.35)); }
    .brand-copy { display: flex; align-items: baseline; gap: 10px; min-width: 0; }
    .brand h1 { margin: 0; font-size: 15.5px; font-weight: 700; color: var(--gold); letter-spacing: 0.3px; white-space: nowrap; }
    .brand span { font-size: 12px; color: var(--muted); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    .suite-strip {
      display: flex;
      align-items: center;
      gap: 14px;
      padding: 7px 20px;
      background: linear-gradient(90deg, #0f1422 0%, #131b2c 50%, #0f1422 100%);
      border-bottom: 1px solid var(--border);
      overflow-x: auto;
      scrollbar-width: none;
    }
    .suite-strip::-webkit-scrollbar { display: none; }
    .strip-item {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      font-size: 11.5px;
      color: #cbd5e1;
      white-space: nowrap;
      flex-shrink: 0;
    }
    .strip-item svg { width: 14px; height: 14px; flex-shrink: 0; }
    .strip-sep { width: 1px; height: 14px; background: var(--border); flex-shrink: 0; }
    .search {
      width: 210px;
      max-width: 30vw;
      padding: 7px 12px;
      border-radius: 6px;
      border: 1px solid var(--border);
      background: var(--bg);
      color: var(--text);
      font-size: 13px;
    }
    .search:focus { outline: none; border-color: var(--accent); }
    .actions { display: flex; align-items: center; gap: 10px; }
    .btn-download {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 7px 14px;
      border-radius: 6px;
      border: 1px solid #ca8a04;
      background: #eab308;
      color: #0c0e14;
      font-size: 13px;
      font-weight: 700;
      text-decoration: none;
      white-space: nowrap;
      cursor: pointer;
    }
    .btn-download:hover { background: #facc15; }
    .btn-sync {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 7px 13px;
      border-radius: 6px;
      border: 1px solid #0284c7;
      background: #162235;
      color: #38bdf8;
      font-size: 13px;
      font-weight: 600;
      white-space: nowrap;
      cursor: pointer;
    }
    .btn-sync:hover { background: #1e314d; }
    .modal-backdrop {
      position: fixed;
      inset: 0;
      background: rgba(6, 8, 14, 0.78);
      display: none;
      align-items: center;
      justify-content: center;
      z-index: 100;
    }
    .modal-backdrop.open { display: flex; }
    .modal {
      width: 500px;
      max-width: 92vw;
      background: var(--panel);
      border: 1px solid var(--border);
      border-radius: 10px;
      padding: 18px 20px;
      box-shadow: 0 20px 60px rgba(0, 0, 0, 0.6);
    }
    .modal h2 { margin: 0 0 6px; font-size: 16px; color: var(--accent); }
    .modal p { margin: 0 0 14px; font-size: 12.5px; color: var(--muted); line-height: 1.5; }
    .modal-row { display: flex; gap: 8px; margin-bottom: 10px; }
    .modal select, .modal input {
      padding: 8px 10px;
      border-radius: 6px;
      border: 1px solid var(--border);
      background: var(--bg);
      color: var(--text);
      font-size: 13px;
    }
    .modal input { flex: 1; }
    .modal-status {
      margin-top: 10px;
      padding: 10px;
      border-radius: 6px;
      background: #090b10;
      border: 1px solid var(--border);
      font-size: 12px;
      color: #cbd5e1;
      max-height: 140px;
      overflow-y: auto;
      white-space: pre-wrap;
    }
    .modal-footer { display: flex; justify-content: flex-end; gap: 8px; margin-top: 14px; }
    .hive-status-wrap { position: relative; }
    .hive-status-btn {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 6px 12px;
      border-radius: 6px;
      border: 1px solid var(--border);
      background: #101521;
      color: var(--text);
      font-size: 12.5px;
      font-weight: 600;
      cursor: pointer;
      white-space: nowrap;
      transition: border-color 0.15s ease, background 0.15s ease;
    }
    .hive-status-btn:hover { background: var(--panel-2); border-color: var(--accent); }
    .hive-status-btn[data-status="healthy"] { border-color: rgba(34, 197, 94, 0.45); }
    .hive-status-btn[data-status="syncing"] { border-color: rgba(56, 189, 248, 0.55); }
    .hive-status-btn[data-status="degraded"] { border-color: rgba(234, 179, 8, 0.55); }
    .hive-status-btn[data-status="offline"] { border-color: rgba(248, 113, 113, 0.55); }
    .hive-dot {
      width: 9px;
      height: 9px;
      border-radius: 50%;
      flex-shrink: 0;
      background: #22c55e;
      box-shadow: 0 0 0 3px rgba(34, 197, 94, 0.18);
    }
    .hive-status-btn[data-status="syncing"] .hive-dot {
      background: #38bdf8;
      box-shadow: 0 0 0 3px rgba(56, 189, 248, 0.24);
      animation: hivePulse 1.2s ease-in-out infinite;
    }
    .hive-status-btn[data-status="degraded"] .hive-dot {
      background: #eab308;
      box-shadow: 0 0 0 3px rgba(234, 179, 8, 0.2);
    }
    .hive-status-btn[data-status="offline"] .hive-dot {
      background: #f87171;
      box-shadow: 0 0 0 3px rgba(248, 113, 113, 0.2);
    }
    @keyframes hivePulse {
      0%, 100% { transform: scale(1); opacity: 1; }
      50% { transform: scale(1.25); opacity: 0.65; }
    }
    .hive-status-meta { color: var(--muted); font-weight: 500; font-size: 11.5px; }
    .hive-popover {
      position: absolute;
      top: calc(100% + 8px);
      right: 0;
      width: 348px;
      background: var(--panel);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 14px 16px;
      box-shadow: 0 18px 46px rgba(0, 0, 0, 0.65);
      z-index: 90;
      display: none;
    }
    .hive-popover.open { display: block; }
    .hive-pop-hdr {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 10px;
      padding-bottom: 8px;
      border-bottom: 1px solid var(--border);
    }
    .hive-pop-title { font-size: 13.5px; font-weight: 700; color: var(--text); }
    .hive-pop-score { font-size: 12px; font-weight: 700; color: var(--ok); }
    .hive-bar-track {
      width: 100%;
      height: 6px;
      border-radius: 3px;
      background: #090b10;
      overflow: hidden;
      margin-bottom: 12px;
      border: 1px solid var(--border);
    }
    .hive-bar-fill {
      height: 100%;
      width: 100%;
      background: #22c55e;
      transition: width 0.25s ease, background 0.25s ease;
    }
    .hive-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 8px;
      margin-bottom: 12px;
    }
    .hive-stat {
      background: #0c1019;
      border: 1px solid var(--border);
      border-radius: 6px;
      padding: 8px 10px;
    }
    .hive-stat-k { font-size: 10.5px; text-transform: uppercase; letter-spacing: 0.06em; color: var(--muted); }
    .hive-stat-v { font-size: 12.5px; font-weight: 600; color: var(--text); margin-top: 3px; }
    .hive-issues {
      font-size: 11.5px;
      color: #fcd34d;
      background: rgba(234, 179, 8, 0.08);
      border: 1px solid rgba(234, 179, 8, 0.28);
      border-radius: 6px;
      padding: 7px 9px;
      margin-bottom: 10px;
      display: none;
    }
    .hive-issues.visible { display: block; }
    .hive-pop-actions { display: flex; justify-content: space-between; gap: 8px; }
    .hive-pop-actions button { flex: 1; justify-content: center; font-size: 12px; padding: 6px 10px; }
    main {
      flex: 1;
      display: grid;
      grid-template-columns: 320px 300px 1fr;
      min-height: 0;
    }
    @media (max-width: 960px) {
      main { grid-template-columns: 240px 1fr; }
      .col-files { display: none; }
    }
    .col {
      border-right: 1px solid var(--border);
      display: flex;
      flex-direction: column;
      min-height: 0;
      min-width: 0;
    }
    .col:last-child { border-right: none; }
    .col-header {
      padding: 10px 14px;
      font-size: 11px;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.08em;
      color: var(--muted);
      background: var(--panel);
      border-bottom: 1px solid var(--border);
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .scroll { flex: 1; overflow-y: auto; padding: 8px; }
    .addon-item, .file-item {
      width: 100%;
      text-align: left;
      background: transparent;
      border: 1px solid transparent;
      border-radius: 6px;
      padding: 9px 10px;
      margin-bottom: 4px;
      color: var(--text);
      cursor: pointer;
      display: block;
    }
    .addon-item:hover, .file-item:hover { background: var(--panel-2); }
    .addon-item.active, .file-item.active {
      background: var(--panel-2);
      border-color: var(--accent);
    }
    .addon-name { font-size: 13px; font-weight: 600; display: flex; justify-content: space-between; }
    .addon-meta { font-size: 11px; color: var(--muted); margin-top: 3px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    .tag { font-size: 11px; color: var(--gold); font-weight: 500; }
    .file-item { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 12px; padding: 7px 10px; }
    .viewer-bar {
      padding: 10px 16px;
      background: var(--panel);
      border-bottom: 1px solid var(--border);
      display: flex;
      justify-content: space-between;
      align-items: center;
      font-size: 12px;
      color: var(--muted);
    }
    .viewer-path { color: var(--text); font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-weight: 600; }
    pre {
      margin: 0;
      padding: 16px;
      overflow: auto;
      flex: 1;
      font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
      font-size: 12.5px;
      line-height: 1.55;
      color: #dbe4f0;
      background: #090b10;
      tab-size: 4;
    }
    .empty { padding: 24px 16px; color: var(--muted); font-size: 13px; }
  </style>
</head>
<body>
  <header>
    <div class="brand">
      <svg class="brand-crest" viewBox="0 0 40 40" fill="none" aria-hidden="true">
        <defs>
          <linearGradient id="plbCrestG" x1="4" y1="4" x2="36" y2="36" gradientUnits="userSpaceOnUse">
            <stop offset="0%" stop-color="#38bdf8"/>
            <stop offset="55%" stop-color="#818cf8"/>
            <stop offset="100%" stop-color="#eab308"/>
          </linearGradient>
        </defs>
        <circle cx="20" cy="20" r="17.5" fill="#0d1322" stroke="url(#plbCrestG)" stroke-width="2"/>
        <circle cx="20" cy="20" r="13.5" stroke="#38bdf8" stroke-opacity="0.22" stroke-width="1" stroke-dasharray="2.5 2.5"/>
        <path d="M12.5 20c0-2.6 2-4.6 4.4-4.6 2.8 0 4.4 2.7 6.2 4.6 1.8 1.9 3.4 4.6 6.2 4.6 2.4 0 4.4-2 4.4-4.6s-2-4.6-4.4-4.6c-2.8 0-4.4 2.7-6.2 4.6-1.8 1.9-3.4 4.6-6.2 4.6-2.4 0-4.4-2-4.4-4.6Z" transform="translate(-3.1 0)" stroke="url(#plbCrestG)" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>
      </svg>
      <div class="brand-copy">
        <h1>Pluribus WoW Addon Suite</h1>
        <span id="summary">Loading addons...</span>
      </div>
    </div>
    <div class="actions">
      <div class="hive-status-wrap">
        <button id="hiveHealthBtn" class="hive-status-btn" type="button" data-status="syncing" aria-expanded="false" aria-controls="hiveHealthPopover" aria-label="HiveMind network connectivity and data-sync health">
          <span class="hive-dot" aria-hidden="true"></span>
          <span id="hiveHealthLabel">HiveMind: Checking...</span>
          <span id="hiveHealthMeta" class="hive-status-meta"></span>
        </button>
        <section id="hiveHealthPopover" class="hive-popover" aria-label="HiveMind Network Health Details">
          <div class="hive-pop-hdr">
            <span class="hive-pop-title">Guild HiveMind Health</span>
            <span id="hivePopScore" class="hive-pop-score">--%</span>
          </div>
          <div class="hive-bar-track" aria-hidden="true">
            <div id="hiveBarFill" class="hive-bar-fill"></div>
          </div>
          <div class="hive-grid">
            <div class="hive-stat">
              <div class="hive-stat-k">Connectivity</div>
              <div id="hiveConnVal" class="hive-stat-v">--</div>
            </div>
            <div class="hive-stat">
              <div class="hive-stat-k">Hive Modules</div>
              <div id="hiveModVal" class="hive-stat-v">--</div>
            </div>
            <div class="hive-stat">
              <div class="hive-stat-k">Data Sync DB</div>
              <div id="hiveDbVal" class="hive-stat-v">--</div>
            </div>
            <div class="hive-stat">
              <div class="hive-stat-k">Wowhead Bridge</div>
              <div id="hiveBridgeVal" class="hive-stat-v">--</div>
            </div>
          </div>
          <div id="hiveIssuesBox" class="hive-issues"></div>
          <div class="hive-pop-actions">
            <button id="hiveCheckNowBtn" class="btn-sync" type="button">Check Sync Health</button>
            <button id="hiveOpenSyncBtn" class="btn-download" type="button">Sync Wowhead DB</button>
          </div>
        </section>
      </div>
      <input id="search" class="search" type="search" placeholder="Filter addons or files..." />
      <button id="wowheadSyncBtn" class="btn-sync" type="button">Sync Wowhead DB</button>
      <button id="downloadBtn" class="btn-download" type="button">Download AddOns (.zip)</button>
    </div>
  </header>
  <nav class="suite-strip" aria-label="Included HiveMind Capabilities">
    <span class="strip-item"><svg viewBox="0 0 16 16" fill="none"><path d="M8 1.5l5.5 3.2v6.6L8 14.5l-5.5-3.2V4.7L8 1.5z" stroke="#38bdf8" stroke-width="1.4"/><circle cx="8" cy="8" r="2" fill="#38bdf8"/></svg>Distributed Zero-Lag Compute</span>
    <span class="strip-sep" aria-hidden="true"></span>
    <span class="strip-item"><svg viewBox="0 0 16 16" fill="none"><path d="M8 2a4.5 4.5 0 014.5 4.5v2.7l1.2 1.8H2.3l1.2-1.8V6.5A4.5 4.5 0 018 2z" stroke="#facc15" stroke-width="1.4"/><path d="M6.3 12.8a1.9 1.9 0 003.4 0" stroke="#facc15" stroke-width="1.4" stroke-linecap="round"/></svg>Smart Guild @Mentions</span>
    <span class="strip-sep" aria-hidden="true"></span>
    <span class="strip-item"><svg viewBox="0 0 16 16" fill="none"><path d="M8 1.8l5 2.1v4.2c0 3.2-2.2 5.4-5 6.3-2.8-.9-5-3.1-5-6.3V3.9l5-2.1z" stroke="#4ade80" stroke-width="1.4"/><path d="M5.7 8.1l1.6 1.6 3.2-3.4" stroke="#4ade80" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"/></svg>Pluribus GearAdvisor + /xpbar &amp; Pathfinder</span>
    <span class="strip-sep" aria-hidden="true"></span>
    <span class="strip-item"><svg viewBox="0 0 16 16" fill="none"><circle cx="8" cy="8" r="6" stroke="#eab308" stroke-width="1.4"/><path d="M8 4.8v6.4M6.2 6.8c0-.8.8-1.3 1.8-1.3s1.8.5 1.8 1.2c0 1.6-3.6.9-3.6 2.6 0 .8.8 1.3 1.8 1.3s1.8-.5 1.8-1.3" stroke="#eab308" stroke-width="1.3" stroke-linecap="round"/></svg>Fast AH, To-Do Routes &amp; DE/EN Localization</span>
    <span class="strip-sep" aria-hidden="true"></span>
    <span class="strip-item"><svg viewBox="0 0 16 16" fill="none"><rect x="2.2" y="3" width="11.6" height="10" rx="2" stroke="#c084fc" stroke-width="1.4"/><path d="M5.5 8h5M8 5.5v5" stroke="#c084fc" stroke-width="1.4" stroke-linecap="round"/></svg>Dungeon Finder LFG &amp; Guild Side Tabs</span>
  </nav>
  <div id="syncModal" class="modal-backdrop">
    <div class="modal">
      <h2>On-Demand Wowhead Classic Data Sync</h2>
      <p>Pull live item, quest, or NPC data directly from Wowhead into <code>PluribusData/Data/WowheadCache.lua</code>. Once updated and installed by any guild member, the in-game Guild Hive P2P network automatically distributes the new revision to the whole guild.</p>
      <div class="modal-row">
        <select id="whType">
          <option value="item">Item IDs</option>
          <option value="quest">Quest IDs</option>
          <option value="npc">NPC IDs</option>
        </select>
        <input id="whIds" type="text" placeholder="e.g. 19019, 17182, 13510, 12360" />
      </div>
      <div class="modal-row">
        <button id="whFetchBtn" class="btn-download" type="button">Fetch from Wowhead</button>
        <button id="whPresetCons" class="btn-sync" type="button">Preset: Raid Consumables</button>
        <button id="whPresetCraft" class="btn-sync" type="button">Preset: Raid Mats</button>
      </div>
      <div id="whStatus" class="modal-status">Checking current cache status...</div>
      <div class="modal-footer">
        <button id="whCloseBtn" class="btn-sync" type="button">Close</button>
      </div>
    </div>
  </div>
  <main>
    <section class="col">
      <div class="col-header"><span>Addons</span><span id="addonCount">0</span></div>
      <div id="addonList" class="scroll"></div>
    </section>
    <section class="col col-files">
      <div class="col-header"><span>Lua &amp; TOC Files</span><span id="fileCount">0</span></div>
      <div id="fileList" class="scroll"></div>
    </section>
    <section class="col">
      <div class="viewer-bar">
        <span id="viewerPath" class="viewer-path">Select a file to inspect</span>
        <span id="viewerInfo">Warcraft Forever 1.60.1 (Lua 5.1)</span>
      </div>
      <pre id="codeView">-- Copy all 27 Pluribus* folders into your Warcraft Forever Interface/AddOns/ directory.
-- Use /pluribus, /hive, /bags, /sos, or click the minimap orb in-game to open the Guild Hive Hub.</pre>
    </section>
  </main>
  <script>
    let allAddons = [];
    let selectedAddon = null;
    let selectedFile = null;

    const addonListEl = document.getElementById("addonList");
    const fileListEl = document.getElementById("fileList");
    const codeViewEl = document.getElementById("codeView");
    const viewerPathEl = document.getElementById("viewerPath");
    const viewerInfoEl = document.getElementById("viewerInfo");
    const summaryEl = document.getElementById("summary");
    const addonCountEl = document.getElementById("addonCount");
    const fileCountEl = document.getElementById("fileCount");
    const searchEl = document.getElementById("search");

    function escapeHtml(s) {
      return String(s).replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
    }

    function renderAddons() {
      const q = searchEl.value.trim().toLowerCase();
      const filtered = allAddons.filter(a =>
        !q ||
        a.name.toLowerCase().includes(q) ||
        a.notes.toLowerCase().includes(q) ||
        a.files.some(f => f.path.toLowerCase().includes(q))
      );
      addonCountEl.textContent = filtered.length;
      addonListEl.innerHTML = filtered.map(a => \`
        <button class="addon-item \${selectedAddon && selectedAddon.name === a.name ? "active" : ""}" data-addon="\${escapeHtml(a.name)}">
          <div class="addon-name">
            <span>\${escapeHtml(a.name)}</span>
            <span class="tag">\${a.luaCount} lua</span>
          </div>
          <div class="addon-meta">v\${escapeHtml(a.version)} · \${escapeHtml(a.notes)}</div>
        </button>
      \`).join("") || '<div class="empty">No matching addons</div>';

      addonListEl.querySelectorAll(".addon-item").forEach(btn => {
        btn.addEventListener("click", () => {
          const found = allAddons.find(x => x.name === btn.dataset.addon);
          if (found) selectAddon(found);
        });
      });
    }

    function selectAddon(addon) {
      selectedAddon = addon;
      renderAddons();
      const q = searchEl.value.trim().toLowerCase();
      const files = addon.files.filter(f => !q || f.path.toLowerCase().includes(q) || addon.name.toLowerCase().includes(q));
      fileCountEl.textContent = files.length;
      fileListEl.innerHTML = files.map(f => {
        const shortPath = f.path.slice(addon.name.length + 1);
        return \`
          <button class="file-item \${selectedFile === f.path ? "active" : ""}" data-path="\${escapeHtml(f.path)}">
            \${escapeHtml(shortPath)}
          </button>
        \`;
      }).join("");

      fileListEl.querySelectorAll(".file-item").forEach(btn => {
        btn.addEventListener("click", () => loadFile(btn.dataset.path));
      });

      if (files.length > 0 && (!selectedFile || !selectedFile.startsWith(addon.name + "/"))) {
        const preferred = files.find(f => f.path.endsWith("/Init.lua")) || files[0];
        loadFile(preferred.path);
      }
    }

    async function loadFile(filePath) {
      selectedFile = filePath;
      fileListEl.querySelectorAll(".file-item").forEach(el => {
        el.classList.toggle("active", el.dataset.path === filePath);
      });
      viewerPathEl.textContent = filePath;
      codeViewEl.textContent = "Loading...";
      const res = await fetch("/api/file?path=" + encodeURIComponent(filePath));
      if (!res.ok) {
        codeViewEl.textContent = "-- Unable to load file";
        return;
      }
      const text = await res.text();
      const lines = text.split("\\n").length;
      viewerInfoEl.textContent = lines + " lines · Warcraft Forever 1.60.1";
      codeViewEl.textContent = text;
    }

    async function boot() {
      const res = await fetch("/api/addons");
      const data = await res.json();
      allAddons = data.addons;
      const totalLua = allAddons.reduce((sum, a) => sum + a.luaCount, 0);
      summaryEl.textContent = allAddons.length + " Addons · " + totalLua + " Lua Files · Interface 16001";
      renderAddons();
      const core = allAddons.find(a => a.name === "PluribusCore") || allAddons[0];
      if (core) selectAddon(core);
    }

    const downloadBtn = document.getElementById("downloadBtn");

    function verifyZipBytes(bytes, expectedSize) {
      if (!bytes || bytes.length < 22) return false;
      if (expectedSize && bytes.length !== expectedSize) return false;
      // PK\x03\x04 local header at start
      if (bytes[0] !== 0x50 || bytes[1] !== 0x4b || bytes[2] !== 0x03 || bytes[3] !== 0x04) return false;
      // PK\x05\x06 EOCD at end (no archive comment)
      const eocd = bytes.length - 22;
      if (bytes[eocd] !== 0x50 || bytes[eocd + 1] !== 0x4b || bytes[eocd + 2] !== 0x05 || bytes[eocd + 3] !== 0x06) return false;
      return true;
    }

    async function downloadVerifiedZip() {
      if (!downloadBtn || downloadBtn.disabled) return;
      const origText = "Download AddOns (.zip)";
      downloadBtn.disabled = true;
      downloadBtn.textContent = "Packing ZIP...";
      try {
        const res = await fetch("/api/download-zip-b64", {
          credentials: "same-origin",
          cache: "no-store",
        });
        if (!res.ok) throw new Error("HTTP " + res.status);
        const data = await res.json();
        const bin = atob(data.base64);
        const bytes = new Uint8Array(bin.length);
        for (let i = 0; i < bin.length; i++) {
          bytes[i] = bin.charCodeAt(i);
        }
        if (!verifyZipBytes(bytes, data.size)) {
          throw new Error("ZIP integrity check failed");
        }
        const blob = new Blob([bytes], { type: "application/zip" });
        const url = URL.createObjectURL(blob);
        const a = document.createElement("a");
        a.href = url;
        a.download = data.filename || "PluribusSuite-WoWForever-1.60.1.zip";
        document.body.appendChild(a);
        a.click();
        a.remove();
        setTimeout(() => URL.revokeObjectURL(url), 15000);
        const kb = Math.round(bytes.length / 1024);
        downloadBtn.textContent = "Downloaded (" + data.fileCount + " files · " + kb + " KB)";
        setTimeout(() => { downloadBtn.textContent = origText; }, 4000);
      } catch (err) {
        downloadBtn.textContent = "Download failed — Retry";
        setTimeout(() => { downloadBtn.textContent = origText; }, 4000);
      } finally {
        downloadBtn.disabled = false;
      }
    }

    if (downloadBtn) {
      downloadBtn.addEventListener("click", downloadVerifiedZip);
    }

    const syncModal = document.getElementById("syncModal");
    const whStatus = document.getElementById("whStatus");
    const whType = document.getElementById("whType");
    const whIds = document.getElementById("whIds");

    async function refreshWowheadStatus() {
      try {
        const res = await fetch("/api/wowhead-status", { cache: "no-store" });
        const st = await res.json();
        whStatus.textContent = "Current WowheadCache.lua: Revision v" + st.revision +
          " · " + st.counts.items + " items, " + st.counts.quests + " quests, " + st.counts.npcs + " NPCs.";
      } catch (e) {
        whStatus.textContent = "Unable to read cache status.";
      }
    }

    async function runWowheadFetch(payload) {
      whStatus.textContent = "Fetching live data from Wowhead Classic...";
      try {
        const res = await fetch("/api/wowhead-fetch", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
        });
        const data = await res.json();
        if (!res.ok) throw new Error(data.error || ("HTTP " + res.status));
        const okList = (data.fetched || []).map(x => "✓ #" + x.id + " " + x.name).join("\\n");
        const errList = (data.errors || []).map(x => "✗ #" + x.id + ": " + x.error).join("\\n");
        whStatus.textContent = "Updated WowheadCache.lua to Revision v" + data.revision +
          " (" + data.counts.items + " items, " + data.counts.quests + " quests, " + data.counts.npcs + " NPCs)\\n" +
          (okList ? okList + "\\n" : "") + (errList || "") +
          "\\nReady! Click 'Download AddOns (.zip)' to pack the updated database.";
        boot();
        refreshHiveHealth(false);
      } catch (err) {
        whStatus.textContent = "Sync error: " + err.message;
      }
    }

    // HiveMind Connectivity & Data-Sync Health Indicator
    const hiveHealthBtn = document.getElementById("hiveHealthBtn");
    const hiveHealthLabel = document.getElementById("hiveHealthLabel");
    const hiveHealthMeta = document.getElementById("hiveHealthMeta");
    const hiveHealthPopover = document.getElementById("hiveHealthPopover");
    const hivePopScore = document.getElementById("hivePopScore");
    const hiveBarFill = document.getElementById("hiveBarFill");
    const hiveConnVal = document.getElementById("hiveConnVal");
    const hiveModVal = document.getElementById("hiveModVal");
    const hiveDbVal = document.getElementById("hiveDbVal");
    const hiveBridgeVal = document.getElementById("hiveBridgeVal");
    const hiveIssuesBox = document.getElementById("hiveIssuesBox");
    const hiveCheckNowBtn = document.getElementById("hiveCheckNowBtn");
    const hiveOpenSyncBtn = document.getElementById("hiveOpenSyncBtn");

    function renderHiveHealth(h) {
      if (!h) return;
      const status = h.status || "offline";
      hiveHealthBtn.dataset.status = status;
      hiveHealthLabel.textContent = "HiveMind: " + (h.label || status);
      hiveHealthMeta.textContent = "· " + h.connectivity.activeModules + "/" + h.connectivity.totalModules + " · v" + h.dataSync.revision;

      const scoreColors = {
        healthy: "#22c55e",
        syncing: "#38bdf8",
        degraded: "#eab308",
        offline: "#f87171",
      };
      const accent = scoreColors[status] || "#22c55e";
      hivePopScore.textContent = h.healthScore + "% · " + h.label;
      hivePopScore.style.color = accent;
      hiveBarFill.style.width = h.healthScore + "%";
      hiveBarFill.style.background = accent;

      hiveConnVal.textContent = h.connectivity.protocol + " Ready (" + h.dataSync.p2pIntervalMin + "m P2P)";
      hiveModVal.textContent = h.connectivity.activeModules + " / " + h.connectivity.totalModules + " wired";
      hiveDbVal.textContent = "Rev v" + h.dataSync.revision + " (" + h.dataSync.totalRecords + " recs)";
      const lat = h.connectivity.latencyMs !== null ? (" · " + h.connectivity.latencyMs + "ms") : "";
      hiveBridgeVal.textContent = h.connectivity.wowheadBridge.toUpperCase() + lat;

      if (h.issues && h.issues.length > 0) {
        hiveIssuesBox.textContent = h.issues.join(" · ");
        hiveIssuesBox.classList.add("visible");
      } else {
        hiveIssuesBox.textContent = "";
        hiveIssuesBox.classList.remove("visible");
      }
    }

    async function refreshHiveHealth(runLiveProbe) {
      if (runLiveProbe) {
        hiveHealthBtn.dataset.status = "syncing";
        hiveHealthLabel.textContent = "HiveMind: Syncing...";
        hiveCheckNowBtn.disabled = true;
        hiveCheckNowBtn.textContent = "Checking...";
      }
      try {
        const res = await fetch(runLiveProbe ? "/api/hive-health/check" : "/api/hive-health", {
          method: runLiveProbe ? "POST" : "GET",
          cache: "no-store",
        });
        if (!res.ok) throw new Error("HTTP " + res.status);
        const report = await res.json();
        renderHiveHealth(report);
      } catch (err) {
        hiveHealthBtn.dataset.status = "offline";
        hiveHealthLabel.textContent = "HiveMind: Offline";
        hiveHealthMeta.textContent = "";
      } finally {
        hiveCheckNowBtn.disabled = false;
        hiveCheckNowBtn.textContent = "Check Sync Health";
      }
    }

    function setHivePopoverOpen(open) {
      hiveHealthPopover.classList.toggle("open", open);
      hiveHealthBtn.setAttribute("aria-expanded", open ? "true" : "false");
    }

    hiveHealthBtn.addEventListener("click", (e) => {
      e.stopPropagation();
      const willOpen = !hiveHealthPopover.classList.contains("open");
      setHivePopoverOpen(willOpen);
      if (willOpen) refreshHiveHealth(false);
    });
    hiveCheckNowBtn.addEventListener("click", () => refreshHiveHealth(true));
    hiveOpenSyncBtn.addEventListener("click", () => {
      setHivePopoverOpen(false);
      syncModal.classList.add("open");
      refreshWowheadStatus();
    });
    document.addEventListener("click", (e) => {
      if (!hiveHealthPopover.contains(e.target) && !hiveHealthBtn.contains(e.target)) {
        setHivePopoverOpen(false);
      }
    });
    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape") {
        setHivePopoverOpen(false);
        syncModal.classList.remove("open");
      }
    });

    document.getElementById("wowheadSyncBtn").addEventListener("click", () => {
      setHivePopoverOpen(false);
      syncModal.classList.add("open");
      refreshWowheadStatus();
    });
    document.getElementById("whCloseBtn").addEventListener("click", () => {
      syncModal.classList.remove("open");
    });
    document.getElementById("whFetchBtn").addEventListener("click", () => {
      const ids = whIds.value.split(/[^0-9]+/).map(Number).filter(n => n > 0);
      if (!ids.length) {
        whStatus.textContent = "Enter one or more comma-separated Wowhead IDs (e.g. 19019, 17182).";
        return;
      }
      runWowheadFetch({ type: whType.value, ids });
    });
    document.getElementById("whPresetCons").addEventListener("click", () => {
      runWowheadFetch({ preset: "raid-consumables" });
    });
    document.getElementById("whPresetCraft").addEventListener("click", () => {
      runWowheadFetch({ preset: "raid-crafting" });
    });

    searchEl.addEventListener("input", () => {
      renderAddons();
      if (selectedAddon) selectAddon(selectedAddon);
    });

    boot();
    refreshHiveHealth(false);
  </script>
</body>
</html>`;
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url || "/", `http://${req.headers.host || "localhost"}`);

  if (url.pathname === "/health") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ status: "ok" }));
    return;
  }

  if (url.pathname === "/api/hive-health" && req.method === "GET") {
    try {
      const report = await collectHiveHealthReport(false);
      res.writeHead(200, { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" });
      res.end(JSON.stringify(report));
    } catch (err) {
      res.writeHead(500, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: String(err) }));
    }
    return;
  }

  if (url.pathname === "/api/hive-health/check" && req.method === "POST") {
    try {
      const report = await collectHiveHealthReport(true);
      res.writeHead(200, { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" });
      res.end(JSON.stringify(report));
    } catch (err) {
      res.writeHead(500, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: String(err) }));
    }
    return;
  }

  if (url.pathname === "/api/wowhead-status") {
    try {
      const cache = parseWowheadCacheLua();
      res.writeHead(200, { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" });
      res.end(JSON.stringify({
        revision: cache.revision,
        updatedAt: cache.updatedAt,
        counts: {
          items: Object.keys(cache.items).length,
          quests: Object.keys(cache.quests).length,
          npcs: Object.keys(cache.npcs).length,
        },
      }));
    } catch (err) {
      res.writeHead(500, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: String(err) }));
    }
    return;
  }

  if (url.pathname === "/api/wowhead-fetch" && req.method === "POST") {
    try {
      const body = await readJsonBody(req);
      let kind = body.type || "item";
      let ids = Array.isArray(body.ids) ? body.ids : [];
      if (body.preset && WOWHEAD_PRESETS[body.preset]) {
        kind = WOWHEAD_PRESETS[body.preset].type;
        ids = WOWHEAD_PRESETS[body.preset].ids;
      }
      ids = [...new Set(ids.map(Number).filter((n) => Number.isInteger(n) && n > 0))].slice(0, 25);
      if (ids.length === 0) {
        res.writeHead(400, { "Content-Type": "application/json; charset=utf-8" });
        res.end(JSON.stringify({ error: "Provide at least one valid positive integer ID or preset." }));
        return;
      }

      const cache = parseWowheadCacheLua();
      const bucket = kind === "quest" ? cache.quests : (kind === "npc" ? cache.npcs : cache.items);
      const fetched = [];
      const errors = [];

      for (const id of ids) {
        try {
          const entry = await fetchWowheadEntry(kind, id);
          bucket[id] = entry;
          fetched.push(entry);
        } catch (err) {
          errors.push({ id, error: err.message || String(err) });
        }
      }

      if (fetched.length > 0) {
        cache.revision = (Number(cache.revision) || 1) + 1;
        cache.updatedAt = Math.floor(Date.now() / 1000);
        writeWowheadCacheLua(cache);
      }

      res.writeHead(200, { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" });
      res.end(JSON.stringify({
        revision: cache.revision,
        fetched,
        errors,
        counts: {
          items: Object.keys(cache.items).length,
          quests: Object.keys(cache.quests).length,
          npcs: Object.keys(cache.npcs).length,
        },
      }));
    } catch (err) {
      res.writeHead(500, { "Content-Type": "application/json; charset=utf-8" });
      res.end(JSON.stringify({ error: err.message || String(err) }));
    }
    return;
  }

  if (url.pathname === "/api/addons") {
    try {
      const addons = getAddonInventory();
      res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
      res.end(JSON.stringify({ addons }));
    } catch (err) {
      res.writeHead(500, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: String(err) }));
    }
    return;
  }

  if (url.pathname === "/api/file") {
    const target = safeResolveAddonFile(url.searchParams.get("path"));
    if (!target) {
      res.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
      res.end("Not found");
      return;
    }
    const content = fs.readFileSync(target.full, "utf8");
    res.writeHead(200, { "Content-Type": "text/plain; charset=utf-8" });
    res.end(content);
    return;
  }

  if (url.pathname === "/api/download-zip") {
    try {
      const { buffer } = buildAddonsZipBuffer(__dirname);
      res.writeHead(200, {
        "Content-Type": "application/zip",
        "Content-Disposition": 'attachment; filename="PluribusSuite-WoWForever-1.60.1.zip"',
        "Content-Length": String(buffer.length),
        "Content-Encoding": "identity",
        "Cache-Control": "no-store, no-transform",
        "X-Content-Type-Options": "nosniff",
      });
      if (req.method === "HEAD") {
        res.end();
      } else {
        res.end(buffer);
      }
    } catch (err) {
      res.writeHead(500, { "Content-Type": "text/plain; charset=utf-8" });
      res.end("Error creating zip: " + String(err));
    }
    return;
  }

  if (url.pathname === "/api/download-zip-b64") {
    try {
      const { buffer, fileCount, dirCount } = buildAddonsZipBuffer(__dirname);
      const payload = JSON.stringify({
        filename: "PluribusSuite-WoWForever-1.60.1.zip",
        size: buffer.length,
        fileCount,
        dirCount,
        base64: buffer.toString("base64"),
      });
      res.writeHead(200, {
        "Content-Type": "application/json; charset=utf-8",
        "Cache-Control": "no-store",
      });
      res.end(payload);
    } catch (err) {
      res.writeHead(500, { "Content-Type": "application/json; charset=utf-8" });
      res.end(JSON.stringify({ error: String(err) }));
    }
    return;
  }

  if (url.pathname === "/" || url.pathname === "/index.html") {
    res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
    res.end(renderHtml());
    return;
  }

  res.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
  res.end("Not found");
});

server.listen(PORT, HOST, () => {
  console.log(`Pluribus WoW Addon Suite Explorer listening on http://${HOST}:${PORT}`);
});
