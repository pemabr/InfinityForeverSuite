// Pure HiveMind Network Connectivity & Data-Sync Health Evaluator
// Decoupled from HTTP/UI so health grading is deterministic and unit-testable

export const EXPECTED_HIVE_MODULES = [
  "Hive/HiveComms.lua",
  "Hive/HiveNetworkDB.lua",
  "Hive/HiveInventory.lua",
  "Hive/HiveProfessions.lua",
  "Hive/HiveDistress.lua",
  "Hive/HiveCooldowns.lua",
  "Hive/HiveLFG.lua",
  "Hive/HiveAuction.lua",
  "Hive/HiveAuctionator.lua",
  "Hive/HiveMail.lua",
  "Hive/HiveTax.lua",
  "Hive/HiveCompute.lua",
  "Hive/HiveMentions.lua",
  "Hive/HiveGearJudge.lua",
  "Hive/HiveTooltips.lua",
  "Hive/HivePathfinder.lua",
  "Hive/HiveTerrainMesh.lua",
  "Hive/HiveRaidTools.lua",
  "Hive/HiveUI.lua",
  "Hive/HiveNativeTabs.lua",
];

/**
 * Compute overall connectivity and data-sync health for the guild HiveMind network.
 *
 * @param {object} input
 * @param {string[]} input.presentModules - Hive module paths found on disk
 * @param {string[]} input.registeredModules - Hive module paths wired in PluribusCore.toc
 * @param {boolean} input.cacheValid - Whether WowheadCache.lua exists and parses cleanly
 * @param {number} input.revision - Current WowheadCache revision number
 * @param {{ items: number, quests: number, npcs: number }} input.counts
 * @param {number} input.updatedAt - Unix epoch seconds of last cache update
 * @param {"connected"|"checking"|"degraded"|"offline"} [input.wowheadReachability]
 * @param {number|null} [input.latencyMs]
 * @param {number} [input.nowSec]
 */
export function evaluateHiveHealth(input) {
  const nowSec = typeof input.nowSec === "number" ? input.nowSec : Math.floor(Date.now() / 1000);
  const presentSet = new Set(input.presentModules || []);
  const registeredSet = new Set(input.registeredModules || []);

  const missingOnDisk = EXPECTED_HIVE_MODULES.filter((m) => !presentSet.has(m));
  const unregisteredInToc = EXPECTED_HIVE_MODULES.filter((m) => !registeredSet.has(m));
  const activeModuleCount = EXPECTED_HIVE_MODULES.filter((m) => presentSet.has(m) && registeredSet.has(m)).length;

  const totalExpected = EXPECTED_HIVE_MODULES.length;
  const cacheValid = Boolean(input.cacheValid);
  const revision = Number(input.revision) || 0;
  const counts = {
    items: Number(input.counts?.items) || 0,
    quests: Number(input.counts?.quests) || 0,
    npcs: Number(input.counts?.npcs) || 0,
  };
  const totalRecords = counts.items + counts.quests + counts.npcs;
  const updatedAt = Number(input.updatedAt) || 0;
  const cacheAgeSec = updatedAt > 0 ? Math.max(0, nowSec - updatedAt) : null;
  const wowheadReachability = input.wowheadReachability || "connected";
  const latencyMs = typeof input.latencyMs === "number" ? Math.round(input.latencyMs) : null;

  const issues = [];
  if (missingOnDisk.length > 0) {
    issues.push(`${missingOnDisk.length} Hive module(s) missing on disk`);
  }
  if (unregisteredInToc.length > 0) {
    issues.push(`${unregisteredInToc.length} Hive module(s) not wired in PluribusCore.toc`);
  }
  if (!cacheValid) {
    issues.push("WowheadCache.lua missing or unreadable");
  } else if (totalRecords === 0) {
    issues.push("WowheadCache.lua has 0 cached records");
  }
  if (wowheadReachability === "offline") {
    issues.push("Wowhead live sync endpoint unreachable");
  } else if (wowheadReachability === "degraded") {
    issues.push("Wowhead live sync experiencing high latency or errors");
  }

  // Determine overall status grade
  let status = "healthy";
  let label = "Connected & Synced";
  let summary = `PLBHIVE mesh ready · ${activeModuleCount}/${totalExpected} modules · Rev v${revision}`;

  if (activeModuleCount === 0 || (!cacheValid && missingOnDisk.length >= 3)) {
    status = "offline";
    label = "Offline";
    summary = "HiveMind core modules unavailable";
  } else if (wowheadReachability === "checking") {
    status = "syncing";
    label = "Syncing";
    summary = `Verifying Wowhead bridge & Rev v${revision} integrity...`;
  } else if (
    missingOnDisk.length > 0 ||
    unregisteredInToc.length > 0 ||
    !cacheValid ||
    totalRecords === 0 ||
    wowheadReachability === "offline" ||
    wowheadReachability === "degraded"
  ) {
    status = "degraded";
    label = "Degraded";
    summary = issues[0] || "Partial HiveMind sync issue detected";
  }

  // Connectivity score (0 - 100)
  const moduleScore = Math.round((activeModuleCount / totalExpected) * 60);
  const cacheScore = cacheValid && totalRecords > 0 ? 25 : (cacheValid ? 10 : 0);
  const bridgeScore =
    wowheadReachability === "connected" ? 15 :
    wowheadReachability === "checking" ? 10 :
    wowheadReachability === "degraded" ? 5 : 0;
  const healthScore = Math.max(0, Math.min(100, moduleScore + cacheScore + bridgeScore));

  return {
    status,
    label,
    summary,
    healthScore,
    connectivity: {
      protocol: "PLBHIVE",
      activeModules: activeModuleCount,
      totalModules: totalExpected,
      missingOnDisk,
      unregisteredInToc,
      wowheadBridge: wowheadReachability,
      latencyMs,
    },
    dataSync: {
      cacheValid,
      revision,
      counts,
      totalRecords,
      updatedAt,
      cacheAgeSec,
      p2pIntervalMin: 15,
    },
    issues,
    checkedAt: nowSec,
  };
}

export function formatRelativeAge(seconds) {
  if (seconds === null || seconds === undefined || Number.isNaN(seconds)) return "Never";
  const s = Math.max(0, Math.floor(seconds));
  if (s < 60) return `${s}s ago`;
  if (s < 3600) return `${Math.floor(s / 60)}m ago`;
  if (s < 86400) return `${Math.floor(s / 3600)}h ago`;
  return `${Math.floor(s / 86400)}d ago`;
}

// ============================================================================
// Client-side HiveMind Online Status & Guild Addon Version Roster (mirrors HiveComms.lua)
// ============================================================================

export function compareSemver(a, b) {
  const parse = (v) => {
    const m = String(v || "0.0.0").replace(/^v/i, "").match(/(\d+)\.?(\d*)\.?(\d*)/);
    return m ? [Number(m[1]) || 0, Number(m[2]) || 0, Number(m[3]) || 0] : [0, 0, 0];
  };
  const [a1, a2, a3] = parse(a);
  const [b1, b2, b3] = parse(b);
  if (a1 !== b1) return a1 > b1 ? 1 : -1;
  if (a2 !== b2) return a2 > b2 ? 1 : -1;
  if (a3 !== b3) return a3 > b3 ? 1 : -1;
  return 0;
}

// Handles WoW Classic boolean true, 1.15/1.60.1 Enum (0=Success, 1=DuplicatePrefix), and 1.12 nil when SendAddonMessage exists
export function isPrefixRegistrationOk(registerResult, hasSendApi = true) {
  if (registerResult === true || registerResult === 0 || registerResult === 1) return true;
  if (registerResult === undefined || registerResult === null) return Boolean(hasSendApi);
  return false;
}

export function evaluateClientHiveStatus({
  initialized = true,
  inGuild = true,
  prefixResult = 0,
  hasSendApi = true,
  otherPeers = 0,
  queued = 0,
  failedSends = 0,
}) {
  const prefixOk = isPrefixRegistrationOk(prefixResult, hasSendApi);
  const connectedNodes = inGuild ? 1 + Math.max(0, Number(otherPeers) || 0) : 1;

  if (!initialized || !prefixOk) {
    return { state: "OFFLINE", score: 0, connectedNodes: 0, prefixOk };
  }
  if (!inGuild) {
    return { state: "LOCAL", score: 65, connectedNodes: 1, prefixOk };
  }
  if ((Number(failedSends) || 0) >= 5) {
    return { state: "DEGRADED", score: 65, connectedNodes, prefixOk };
  }
  if ((Number(queued) || 0) > 0) {
    return { state: "SYNCING", score: 96, connectedNodes, prefixOk };
  }
  // Even with 0 other peers, self IS connected to the guild PLBHIVE channel (1/1 Online!)
  return { state: "HEALTHY", score: 100, connectedNodes, prefixOk };
}

function canonNameKey(raw) {
  const clean = String(raw || "").trim().replace(/-.+$/, "").replace(/\s+.+$/, "").trim();
  return clean.toLowerCase();
}

export function buildGuildAddonRoster({
  selfName,
  selfVersion = "2.2.0",
  guildRoster = [],
  livePeers = {},
  knownPeers = {},
}) {
  const meKey = canonNameKey(selfName);
  let latestVersion = selfVersion;

  const checkBest = (ver) => {
    if (ver && compareSemver(ver, latestVersion) > 0) latestVersion = ver;
  };
  Object.values(livePeers || {}).forEach((p) => checkBest(p?.version));
  Object.values(knownPeers || {}).forEach((p) => checkBest(p?.version));

  const byKey = new Map();
  for (const m of guildRoster || []) {
    const key = canonNameKey(m.name);
    if (!key) continue;
    const prev = byKey.get(key);
    if (!prev) {
      byKey.set(key, { ...m, canonKey: key, online: Boolean(m.online), isSelf: key === meKey });
    } else if (m.online) {
      prev.online = true;
    }
  }
  if (meKey && !byKey.has(meKey)) {
    byKey.set(meKey, { name: selfName, canonKey: meKey, online: true, isSelf: true });
  }

  const liveByKey = new Map(Object.entries(livePeers || {}).map(([k, v]) => [canonNameKey(v?.name || k), v]));
  const knownByKey = new Map(Object.entries(knownPeers || {}).map(([k, v]) => [canonNameKey(v?.name || k), v]));

  const stats = {
    total: 0, online: 0, withAddon: 0, current: 0, outdated: 0, none: 0,
    latestVersion,
    isSelfOutdated: compareSemver(selfVersion, latestVersion) < 0,
  };

  const members = [];
  for (const m of byKey.values()) {
    const live = liveByKey.get(m.canonKey);
    const known = knownByKey.get(m.canonKey);
    const ver = m.isSelf ? selfVersion : (live?.version || known?.version || null);
    let addonStatus = "NONE";
    if (ver) {
      addonStatus = compareSemver(ver, latestVersion) < 0 ? "OUTDATED" : "CURRENT";
      stats.withAddon++;
      if (addonStatus === "CURRENT") stats.current++;
      else stats.outdated++;
    } else {
      stats.none++;
    }
    stats.total++;
    if (m.online || m.isSelf) stats.online++;
    members.push({ ...m, online: Boolean(m.online || m.isSelf), addonVersion: ver, addonStatus });
  }

  return { members, stats };
}

