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
  "Hive/HiveMail.lua",
  "Hive/HiveTax.lua",
  "Hive/HiveCompute.lua",
  "Hive/HiveMentions.lua",
  "Hive/HiveGearJudge.lua",
  "Hive/HiveTooltips.lua",
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
