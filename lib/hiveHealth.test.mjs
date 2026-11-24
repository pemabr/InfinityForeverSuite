import test from "node:test";
import assert from "node:assert/strict";
import {
  EXPECTED_HIVE_MODULES,
  evaluateHiveHealth,
  formatRelativeAge,
} from "./hiveHealth.mjs";

test("reports healthy when all 10 Hive modules are present, registered, and cache is valid", () => {
  const result = evaluateHiveHealth({
    presentModules: [...EXPECTED_HIVE_MODULES],
    registeredModules: [...EXPECTED_HIVE_MODULES],
    cacheValid: true,
    revision: 2,
    counts: { items: 56, quests: 4, npcs: 2 },
    updatedAt: 1000,
    wowheadReachability: "connected",
    latencyMs: 142,
    nowSec: 1060,
  });

  assert.equal(result.status, "healthy");
  assert.equal(result.label, "Connected & Synced");
  assert.equal(result.healthScore, 100);
  assert.equal(result.connectivity.activeModules, 10);
  assert.equal(result.dataSync.totalRecords, 62);
  assert.equal(result.dataSync.cacheAgeSec, 60);
  assert.equal(result.issues.length, 0);
});

test("reports syncing when Wowhead bridge probe is in flight", () => {
  const result = evaluateHiveHealth({
    presentModules: [...EXPECTED_HIVE_MODULES],
    registeredModules: [...EXPECTED_HIVE_MODULES],
    cacheValid: true,
    revision: 3,
    counts: { items: 56, quests: 0, npcs: 0 },
    updatedAt: 1000,
    wowheadReachability: "checking",
    nowSec: 1010,
  });

  assert.equal(result.status, "syncing");
  assert.equal(result.label, "Syncing");
  assert.equal(result.healthScore, 95);
});

test("reports degraded when a Hive module is unregistered or Wowhead endpoint is offline", () => {
  const result = evaluateHiveHealth({
    presentModules: [...EXPECTED_HIVE_MODULES],
    registeredModules: EXPECTED_HIVE_MODULES.slice(0, 9),
    cacheValid: true,
    revision: 2,
    counts: { items: 56, quests: 0, npcs: 0 },
    updatedAt: 1000,
    wowheadReachability: "offline",
    nowSec: 1120,
  });

  assert.equal(result.status, "degraded");
  assert.equal(result.connectivity.activeModules, 9);
  assert.equal(result.connectivity.unregisteredInToc.length, 1);
  assert.ok(result.issues.some((msg) => msg.includes("not wired")));
  assert.ok(result.issues.some((msg) => msg.includes("unreachable")));
});

test("reports offline when no Hive modules are active", () => {
  const result = evaluateHiveHealth({
    presentModules: [],
    registeredModules: [],
    cacheValid: false,
    revision: 0,
    counts: { items: 0, quests: 0, npcs: 0 },
    updatedAt: 0,
    wowheadReachability: "offline",
    nowSec: 2000,
  });

  assert.equal(result.status, "offline");
  assert.equal(result.label, "Offline");
  assert.equal(result.healthScore, 0);
});

test("formatRelativeAge formats seconds, minutes, hours, days, and null", () => {
  assert.equal(formatRelativeAge(null), "Never");
  assert.equal(formatRelativeAge(18), "18s ago");
  assert.equal(formatRelativeAge(125), "2m ago");
  assert.equal(formatRelativeAge(7300), "2h ago");
  assert.equal(formatRelativeAge(90000), "1d ago");
});
