import test from "node:test";
import assert from "node:assert/strict";
import {
  assignWindowZBand,
  canAutoScanAH,
  parseClassicAuctionRow,
  computeCraftProfit,
  findSafeSideTabStartY,
  deduplicatePlayers,
  buildShoppingList,
  calculateGuildTax,
  compressLZ77,
  decompressLZ77,
  canRunComputeSlice,
  shardComputeTasks,
  matchesGuildMention,
  shouldDeliverQueuedMentions,
  evaluateGearUpgrade,
  isCommandAllowed,
  formatTopHolders,
  filterAutoSellGrayTrash,
} from "./uiLayoutAndScan.mjs";

test("1. Window Z-order bands separate windows by 40-level stride", () => {
  assert.equal(assignWindowZBand(20, 0), 20);
  assert.equal(assignWindowZBand(20, 1), 60);
  assert.equal(assignWindowZBand(20, 2), 100);
});

test("2. AH cooldown enforces 20m interval and parses both 1.12 & 1.14+ rows with bid fallback", () => {
  assert.equal(canAutoScanAH(0, 5000), true);
  assert.equal(canAutoScanAH(4000, 5000), false);
  assert.equal(canAutoScanAH(3800, 5000), true);

  // 1.12 signature: [name, tex, count, quality, canUse, level, minBid, minInc, buyout, bidAmount]
  const row112 = ["Black Lotus", 1, 2, 1, true, 1, 500000, 10000, 1200000, 0];
  assert.equal(parseClassicAuctionRow(row112).unitCopper, 600000);
  assert.equal(parseClassicAuctionRow(row112).isModernSig, false);

  // 1.14+ signature with bid-only (buyout = 0, falls back to bidAmount / minBid)
  const row114BidOnly = ["Arcanite Bar", 1, 1, 2, true, 1, "REQ_LEVEL_ABBR", 400000, 10000, 0, 450000];
  assert.equal(parseClassicAuctionRow(row114BidOnly).unitCopper, 450000);
  assert.equal(parseClassicAuctionRow(row114BidOnly).isModernSig, true);
});

test("3. Recipe craft profit subtracts reagent costs and 5% AH cut", () => {
  const prices = { 13468: 500000, 13465: 20000 };
  const res = computeCraftProfit(700000, 1, [{ itemID: 13468, qty: 1 }, { itemID: 13465, qty: 3 }], (id) => prices[id]);
  assert.equal(res.cost, 560000);
  assert.equal(res.ahFee, 35000);
  assert.equal(res.netProfit, 105000);
});

test("4. Safe side-tab Y-offset places Guild/Profession tabs cleanly below native tabs", () => {
  assert.equal(findSafeSideTabStartY([-60, -110, -252], -30, 16), -268);
  assert.equal(findSafeSideTabStartY([], -30, 16), -30);
});

test("5. Normalized player deduplication removes Realm suffixes and case duplicates", () => {
  assert.deepEqual(deduplicatePlayers(["Thrall-Epoch", "thrall", "Jaina-Realm", "JAINA"]), ["Thrall", "Jaina"]);
});

test("6. Shopping list rolls up multi-recipe reagents and subtracts owned counts", () => {
  const list = buildShoppingList(
    [
      { crafts: 2, reagents: [{ itemID: 100, qty: 3 }, { itemID: 200, qty: 1 }] },
      { crafts: 1, reagents: [{ itemID: 100, qty: 4 }] },
    ],
    { 100: 5, 200: 3 }
  );
  assert.deepEqual(list, [
    { itemID: 100, needed: 10, owned: 5, missing: 5 },
    { itemID: 200, needed: 2, owned: 3, missing: 0 },
  ]);
});

test("7. Guild Tax calculation computes exact copper split", () => {
  assert.deepEqual(calculateGuildTax(100000, 10), { taxCopper: 10000, netCopper: 90000 });
});

test("8. Printable LZ77 compresses losslessly using only WoW-safe printable ASCII", () => {
  const sample = "ITEM:19019:Thunderfury|ITEM:19019:Thunderfury|ITEM:19019:Thunderfury|RAW~TILDE~TEST";
  const { data, compressed } = compressLZ77(sample);
  assert.equal(compressed, true);
  assert.ok(data.length < sample.length);
  assert.equal(/[\x00-\x1f]/.test(data), false);
  assert.equal(decompressLZ77(data), sample);
});

test("9. Distributed Compute enforces anti-lag guards and evenly shards work across peers", () => {
  assert.equal(canRunComputeSlice({ enabled: true, inCombat: false, inInstance: false, pauseInInstances: true, fps: 60, minFps: 45, budgetMs: 1.5 }), true);
  assert.equal(canRunComputeSlice({ enabled: true, inCombat: true, inInstance: false, pauseInInstances: true, fps: 60, minFps: 45, budgetMs: 1.5 }), false);
  assert.equal(canRunComputeSlice({ enabled: true, inCombat: false, inInstance: true, pauseInInstances: true, fps: 60, minFps: 45, budgetMs: 1.5 }), false);
  assert.equal(canRunComputeSlice({ enabled: true, inCombat: false, inInstance: false, pauseInInstances: true, fps: 38, minFps: 45, budgetMs: 1.5 }), false);

  const shards = shardComputeTasks(["z1", "z2", "z3", "z4", "z5"], ["Bob-Realm", "Alice", "bob"]);
  assert.deepEqual(shards, { Alice: ["z1", "z3", "z5"], Bob: ["z2", "z4"] });
});

test("10. Guild Chat @Mentions match targets and suppress queued pings if player wrote in guild chat", () => {
  const me = { name: "Kael-Realm", class: "MAGE", race: "GNOME", role: "DPS", professions: ["Alchemy", "Herbalism"] };
  assert.equal(matchesGuildMention("LF @alchemy for flask craft!", me), true);
  assert.equal(matchesGuildMention("Any @mage online for water?", me), true);
  assert.equal(matchesGuildMention("Need a @tank for Strat", me), false);

  const queued = [
    { id: 1, timestamp: 100, text: "@mage summon" },
    { id: 2, timestamp: 150, text: "@kael check bags" },
  ];
  // Player replied in /g at t=120 -> only t=150 remains undelivered; if player replied at t=200 -> 0 pings!
  assert.equal(shouldDeliverQueuedMentions(queued, 120).length, 1);
  assert.equal(shouldDeliverQueuedMentions(queued, 200).length, 0);
});

test("11. Gear Judge upgrade/cap math, reserved chat commands, top-3 tooltip cap & auto-sell trash", () => {
  const evalRes = evaluateGearUpgrade(
    { sp: 30, hit: 16 },
    { sp: 55, hit: 14 },
    { sp: 1.0, hit: 2.0 },
    { hit: 16 }
  );
  assert.ok(evalRes.pctDelta > 0);
  assert.ok(evalRes.capWarning.includes("hit"));

  // Reserved WoW chat commands must never be hijacked
  assert.equal(isCommandAllowed("/g"), false);
  assert.equal(isCommandAllowed("/r"), false);
  assert.equal(isCommandAllowed("/raid"), false);
  assert.equal(isCommandAllowed("/inv"), false);
  assert.equal(isCommandAllowed("/plb"), true);
  assert.equal(isCommandAllowed("/sgj"), true);

  // Tooltip holder capping shows strictly Top 3 highest counts + overflow
  const formatted = formatTopHolders([
    { name: "Dan", total: 2 },
    { name: "Alice", total: 40 },
    { name: "Eve", total: 1 },
    { name: "Carol", total: 15 },
    { name: "Bob", total: 25 },
  ], 3);
  assert.equal(formatted, "Alice(40), Bob(25), Carol(15), +2 more");

  // Auto-sell gray trash sells only unlocked Poor (quality 0) items with sellPrice > 0 unless Shift held
  const slots = [
    { itemID: 1, quality: 0, sellPrice: 120, isLocked: false },
    { itemID: 2, quality: 0, sellPrice: 0, isLocked: false },
    { itemID: 3, quality: 0, sellPrice: 90, isLocked: true },
    { itemID: 4, quality: 1, sellPrice: 500, isLocked: false },
  ];
  assert.deepEqual(filterAutoSellGrayTrash(slots, false).map((s) => s.itemID), [1]);
  assert.deepEqual(filterAutoSellGrayTrash(slots, true), []);
});
