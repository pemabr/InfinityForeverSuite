import test from "node:test";
import assert from "node:assert/strict";
import {
  mergeAndFilterTransactions,
  summarizeTransactions,
  stripWowFormatting,
  selectTransactionsForExportScope,
  exportTransactionsToCSV,
} from "./officerTransactions.mjs";

const NOW = 1700000000;

const SAMPLE_OFFICER_LOG = [
  {
    id: "TX-0001",
    timestamp: NOW - 300,
    category: "DKP",
    action: "EP_AWARD",
    player: "Thrall-Realm",
    officer: "Jaina",
    amount: 50,
    unit: "EP",
    beforeVal: 100,
    afterVal: 150,
    reason: "Ragnaros Kill",
    source: "OfficerDashboard",
  },
  {
    id: "TX-0002",
    timestamp: NOW - 1800,
    category: "LOOT",
    action: "LOOT_DIST",
    player: "Thrall",
    officer: "Jaina",
    amount: 120,
    unit: "GP",
    itemName: "Perdition's Blade",
    reason: "Main Spec Upgrade",
    source: "LootHistory",
  },
  {
    id: "TX-0003",
    timestamp: NOW - 90000,
    category: "AUDIT",
    action: "DECAY",
    player: "All Raiders",
    officer: "Uther",
    amount: 10,
    unit: "%",
    reason: "Weekly 10% EP decay",
    source: "DKPEngine",
  },
  {
    id: "TX-0004",
    timestamp: NOW - 600,
    category: "TAX",
    action: "TAX_PAID",
    player: "Sylvanas",
    officer: "Treasury",
    amount: 50000,
    unit: "COPPER",
    reason: "Guild Vault Deposit",
    source: "GuildTax",
  },
];

// Duplicate entry from external PointAudit within same 5-second bucket should deduplicate cleanly
const SAMPLE_EXTERNAL_DUP = [
  {
    id: "PA-99",
    timestamp: NOW - 301,
    category: "DKP",
    action: "EP_AWARD",
    player: "thrall",
    officer: "System",
    amount: 50,
    unit: "EP",
    reason: "Ragnaros Kill",
    source: "PointAudit",
  },
];

test("merges multi-source logs, deduplicates same-bucket events, and sorts newest first", () => {
  const { filtered, totalAll } = mergeAndFilterTransactions([SAMPLE_OFFICER_LOG, SAMPLE_EXTERNAL_DUP], {}, NOW);
  assert.equal(totalAll, 4);
  assert.deepEqual(filtered.map((t) => t.id), ["TX-0001", "TX-0004", "TX-0002", "TX-0003"]);
  assert.equal(filtered[0].player, "Thrall");
  assert.equal(filtered[0].beforeVal, 100);
  assert.equal(filtered[0].afterVal, 150);
});

test("filters by category, timeframe window, and case-insensitive search query", () => {
  const dkpOnly = mergeAndFilterTransactions([SAMPLE_OFFICER_LOG], { category: "DKP" }, NOW);
  assert.equal(dkpOnly.filtered.length, 1);
  assert.equal(dkpOnly.filtered[0].action, "EP_AWARD");

  const last24h = mergeAndFilterTransactions([SAMPLE_OFFICER_LOG], { timeframeSec: 86400 }, NOW);
  assert.equal(last24h.filtered.length, 3);
  assert.ok(!last24h.filtered.some((t) => t.id === "TX-0003"));

  const byItem = mergeAndFilterTransactions([SAMPLE_OFFICER_LOG], { query: "perdition" }, NOW);
  assert.equal(byItem.filtered.length, 1);
  assert.equal(byItem.filtered[0].category, "LOOT");

  const byMember = mergeAndFilterTransactions([SAMPLE_OFFICER_LOG], { query: "thrall" }, NOW);
  assert.equal(byMember.filtered.length, 2);
});

test("summarizes filtered transaction stats accurately without counting Guild meta targets as members", () => {
  const { filtered } = mergeAndFilterTransactions([SAMPLE_OFFICER_LOG], {}, NOW);
  const s = summarizeTransactions(filtered);
  assert.equal(s.total, 4);
  assert.equal(s.dkpCount, 1);
  assert.equal(s.lootCount, 1);
  assert.equal(s.auditCount, 1);
  assert.equal(s.taxCount, 1);
  assert.equal(s.netEP, 50);
  assert.equal(s.netGP, 120);
  assert.equal(s.uniqueMembers, 2); // Thrall + Sylvanas (excludes "All Raiders")
});

test("exports CSV with proper RFC-4180 quoting for commas and quotes", () => {
  const csv = exportTransactionsToCSV([
    {
      id: "TX-0010",
      timestamp: NOW,
      category: "LOOT",
      action: "LOOT_DIST",
      player: "Thrall",
      amount: 80,
      unit: "GP",
      beforeVal: 20,
      afterVal: 100,
      itemName: 'Blade of "Fire", Heroic',
      reason: "Main Spec, BiS",
      officer: "Jaina",
      source: "OfficerDashboard",
    },
  ]);
  const lines = csv.split("\n");
  assert.equal(lines.length, 2);
  assert.ok(lines[0].startsWith("ID,Timestamp,Category,Action,Member,"));
  assert.ok(lines[1].includes('"Blade of ""Fire"", Heroic"'));
  assert.ok(lines[1].includes('"Main Spec, BiS"'));
});

test("strips WoW color codes and hyperlinks for clean external CSV/TSV export", () => {
  const wowLink = "|cffa335ee|Hitem:18816::::::::60:::::::|h[Perdition's Blade]|h|r";
  assert.equal(stripWowFormatting(wowLink), "[Perdition's Blade]");

  const tsv = exportTransactionsToCSV(
    [
      {
        id: "TX-0011",
        timestamp: NOW,
        category: "LOOT",
        action: "LOOT_DIST",
        player: "Thrall",
        amount: 120,
        unit: "GP",
        itemName: wowLink,
        reason: "|cff4ade80BiS Upgrade|r",
        officer: "Jaina",
        source: "OfficerDashboard",
      },
    ],
    { format: "TSV" }
  );
  const lines = tsv.split("\n");
  assert.ok(lines[0].includes("ID\tTimestamp\tCategory"));
  assert.ok(lines[1].includes("[Perdition's Blade]"));
  assert.ok(lines[1].includes("BiS Upgrade"));
  assert.equal(lines[1].includes("|cff"), false);
});

test("selectTransactionsForExportScope selects DKP+Decay, Loot, or per-member subsets cleanly", () => {
  const { filtered: all } = mergeAndFilterTransactions([SAMPLE_OFFICER_LOG], {}, NOW);
  const dkpAndDecay = selectTransactionsForExportScope(all, "DKP");
  assert.deepEqual(dkpAndDecay.map((t) => t.id), ["TX-0001", "TX-0003"]);

  const lootOnly = selectTransactionsForExportScope(all, "LOOT");
  assert.deepEqual(lootOnly.map((t) => t.id), ["TX-0002"]);

  const memberOnly = selectTransactionsForExportScope(all, "ALL", "Thrall-Realm");
  assert.deepEqual(memberOnly.map((t) => t.id), ["TX-0001", "TX-0002"]);
});

