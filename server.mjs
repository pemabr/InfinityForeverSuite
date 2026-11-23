import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PORT = Number(process.env.PORT) || 3000;
const HOST = "0.0.0.0";

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
    if (!entry.isDirectory() || !entry.name.startsWith("Infinity")) continue;
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
  if (normalized.includes("..") || !normalized.startsWith("Infinity")) return null;
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
  <title>Infinity Suite — Warcraft Forever Addon Suite</title>
  <meta name="description" content="Warcraft Forever 1.60.1 Lua Addon Suite Explorer for all 27 Infinity* addons." />
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
    .brand { display: flex; align-items: baseline; gap: 12px; }
    .brand h1 { margin: 0; font-size: 16px; font-weight: 700; color: var(--gold); letter-spacing: 0.3px; }
    .brand span { font-size: 12px; color: var(--muted); }
    .search {
      width: 260px;
      max-width: 40vw;
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
      <h1>InfinityForever WoW Addon Suite</h1>
      <span id="summary">Loading addons...</span>
    </div>
    <div class="actions">
      <input id="search" class="search" type="search" placeholder="Filter addons or files..." />
      <a class="btn-download" href="/api/download-zip" download="InfinityForever-AddOns.zip">Download AddOns (.zip)</a>
    </div>
  </header>
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
      <pre id="codeView">-- Copy all 27 Infinity* folders into your Warcraft Forever Interface/AddOns/ directory.
-- Use /infinity or click the minimap orb in-game to open the suite hub.</pre>
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
      const core = allAddons.find(a => a.name === "InfinityCore") || allAddons[0];
      if (core) selectAddon(core);
    }

    searchEl.addEventListener("input", () => {
      renderAddons();
      if (selectedAddon) selectAddon(selectedAddon);
    });

    boot();
  </script>
</body>
</html>`;
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url || "/", `http://${req.headers.host || "localhost"}`);

  if (url.pathname === "/health") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ status: "ok" }));
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
      const zipPath = path.join(os.tmpdir(), "InfinityForever-AddOns.zip");
      const pyScript = [
        "import os, sys, zipfile",
        "root, out = sys.argv[1], sys.argv[2]",
        "with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as zf:",
        "    for entry in sorted(os.listdir(root)):",
        "        full = os.path.join(root, entry)",
        "        if entry.startswith('Infinity') and os.path.isdir(full):",
        "            for dirpath, _, filenames in os.walk(full):",
        "                for fn in sorted(filenames):",
        "                    fp = os.path.join(dirpath, fn)",
        "                    arc = os.path.relpath(fp, root)",
        "                    zf.write(fp, arc)",
      ].join("\n");
      const proc = spawnSync("python3", ["-c", pyScript, __dirname, zipPath], { encoding: "utf8" });
      if (proc.status !== 0 || !fs.existsSync(zipPath)) {
        res.writeHead(500, { "Content-Type": "text/plain; charset=utf-8" });
        res.end("Failed to create archive: " + (proc.stderr || "unknown error"));
        return;
      }
      const stat = fs.statSync(zipPath);
      res.writeHead(200, {
        "Content-Type": "application/zip",
        "Content-Disposition": 'attachment; filename="InfinityForever-AddOns.zip"',
        "Content-Length": String(stat.size),
      });
      fs.createReadStream(zipPath).pipe(res);
    } catch (err) {
      res.writeHead(500, { "Content-Type": "text/plain; charset=utf-8" });
      res.end("Error creating zip: " + String(err));
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
  console.log(`InfinityForever WoW Addon Suite Explorer listening on http://${HOST}:${PORT}`);
});
