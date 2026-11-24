// Pure JS models mirroring PluribusCore Lua algorithms so core invariants
// (Z-order bands, AH scanning/parsing, craft profit, side-tab placement,
// player deduplication, profession rollups, guild tax, printable LZ77,
// distributed zero-lag compute, @mention queue suppression, Sharpie's Gear Judge,
// reserved WoW slash-command guard, top-3 tooltip capping, and auto-sell gray trash)
// are deterministically unit-tested via `node --test`.

const B64 = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_";
const B64_INV = Object.fromEntries([...B64].map((ch, idx) => [ch, idx]));

// 1. Window Z-order bands (40-level stride prevents overlapping widgets across windows)
export const Z_ORDER_STRIDE = 40;
export function assignWindowZBand(baseLevel, windowIndex) {
  return Math.max(10, Number(baseLevel) || 20) + Math.max(0, Number(windowIndex) || 0) * Z_ORDER_STRIDE;
}

// 2. AH 20m scan cooldown & 1.12 vs 1.14+ GetAuctionItemInfo row parser (buyout + bid fallback)
export const AH_SCAN_COOLDOWN_SEC = 1200;
export function canAutoScanAH(lastScanAt, nowSec) {
  if (!lastScanAt || lastScanAt <= 0) return true;
  return (nowSec - lastScanAt) >= AH_SCAN_COOLDOWN_SEC;
}

export function parseClassicAuctionRow(row) {
  const count = Math.max(1, Number(row[2]) || 1);
  // 1.14+ Classic returns levelColHeader (string) at index 6 (1-indexed #7), buyout at index 9 (#10)
  // 1.12 clients return minBid (number) at index 6 (#7), buyout at index 8 (#9)
  const isModernSig = typeof row[6] === "string";
  const minBid = isModernSig ? Number(row[7]) || 0 : Number(row[6]) || 0;
  const buyout = isModernSig ? Number(row[9]) || 0 : Number(row[8]) || 0;
  const bidAmount = isModernSig ? Number(row[10]) || 0 : Number(row[9]) || 0;
  const effectiveTotal = buyout > 0 ? buyout : (bidAmount > 0 ? bidAmount : minBid);
  const unitCopper = effectiveTotal > 0 ? Math.floor(effectiveTotal / count) : 0;
  return { count, buyout, effectiveTotal, unitCopper, isModernSig };
}

// 3. Recipe craft profit math
export function computeCraftProfit(outputPriceCopper, outputQty, reagents, priceLookup) {
  const revenue = (Number(outputPriceCopper) || 0) * Math.max(1, Number(outputQty) || 1);
  let cost = 0;
  for (const r of reagents || []) {
    const unit = Number(priceLookup(r.itemID)) || 0;
    cost += unit * Math.max(1, Number(r.qty) || 1);
  }
  const ahFee = Math.floor(revenue * 0.05);
  return { revenue, cost, ahFee, netProfit: revenue - cost - ahFee };
}

// 4. Safe side-tab Y-offset below native Guild/Profession/Dungeon Finder tabs
export function findSafeSideTabStartY(nativeTabBottomOffsets, preferredY = -28, gap = 12) {
  let lowest = preferredY;
  for (const bottomY of nativeTabBottomOffsets || []) {
    if (typeof bottomY === "number" && bottomY < 0) {
      lowest = Math.min(lowest, bottomY - gap);
    }
  }
  return lowest;
}

// 5. Normalized player deduplication (strips "-Realm", case-insensitive)
export function normalizePlayerName(name) {
  return String(name || "").replace(/-.+$/, "").trim();
}

export function deduplicatePlayers(names) {
  const seen = new Set();
  const out = [];
  for (const raw of names || []) {
    const norm = normalizePlayerName(raw);
    const key = norm.toLowerCase();
    if (key && !seen.has(key)) {
      seen.add(key);
      out.push(norm);
    }
  }
  return out;
}

// 6. Profession-categorized recipe directory + Recipe/Item shopping list rollup
export function buildShoppingList(recipes, ownedCounts) {
  const totals = new Map();
  for (const rec of recipes || []) {
    const crafts = Math.max(1, Number(rec.crafts) || 1);
    for (const r of rec.reagents || []) {
      const prev = totals.get(r.itemID) || 0;
      totals.set(r.itemID, prev + (Number(r.qty) || 1) * crafts);
    }
  }
  const out = [];
  for (const [itemID, needed] of totals.entries()) {
    const owned = Number(ownedCounts?.[itemID]) || 0;
    out.push({ itemID, needed, owned, missing: Math.max(0, needed - owned) });
  }
  return out.sort((a, b) => b.missing - a.missing || a.itemID - b.itemID);
}

// 7. Guild Tax calculation & ledger balances
export function calculateGuildTax(grossCopper, ratePct) {
  const rate = Math.max(0, Math.min(50, Number(ratePct) || 0));
  const taxCopper = Math.floor((Math.max(0, Number(grossCopper) || 0) * rate) / 100);
  return { taxCopper, netCopper: Math.max(0, Number(grossCopper) || 0) - taxCopper };
}

// 8. Printable LZ77 compress/decompress (matches HiveComms.lua exact framing & WoW-safe ASCII)
export function compressLZ77(input) {
  if (typeof input !== "string" || input.length < 24) return { data: input, compressed: false };
  const len = input.length;
  const out = [];
  const lastSeen = new Map();
  let i = 0;

  while (i < len) {
    let bestDist = 0;
    let bestLen = 0;
    if (i + 5 <= len) {
      const key = input.slice(i, i + 4);
      const prev = lastSeen.get(key);
      lastSeen.set(key, i);
      if (prev !== undefined && i - prev <= 4095) {
        const dist = i - prev;
        const maxM = Math.min(67, len - i);
        let m = 4;
        while (m < maxM && input.charCodeAt(prev + m) === input.charCodeAt(i + m)) {
          m++;
        }
        if (m >= 5) {
          bestDist = dist;
          bestLen = m;
        }
      }
    }

    if (bestLen >= 5) {
      const hi = Math.floor(bestDist / 64);
      const lo = bestDist % 64;
      const lc = bestLen - 4;
      out.push("~" + B64[hi] + B64[lo] + B64[lc]);
      i += bestLen;
    } else {
      const ch = input[i];
      out.push(ch === "~" ? "~~" : ch);
      i += 1;
    }
  }

  const compressed = out.join("");
  if (compressed.length + 4 < len) {
    return { data: compressed, compressed: true };
  }
  return { data: input, compressed: false };
}

export function decompressLZ77(input) {
  if (typeof input !== "string") return "";
  let out = "";
  let i = 0;
  const len = input.length;
  while (i < len) {
    const ch = input[i];
    if (ch === "~") {
      if (i + 1 < len && input[i + 1] === "~") {
        out += "~";
        i += 2;
      } else if (i + 3 < len) {
        const hi = B64_INV[input[i + 1]];
        const lo = B64_INV[input[i + 2]];
        const lc = B64_INV[input[i + 3]];
        if (hi !== undefined && lo !== undefined && lc !== undefined) {
          const dist = hi * 64 + lo;
          const mlen = lc + 4;
          const start = out.length - dist;
          if (start >= 0) {
            for (let k = 0; k < mlen; k++) {
              out += out[start + k];
            }
          }
          i += 4;
        } else {
          out += ch;
          i += 1;
        }
      } else {
        out += ch;
        i += 1;
      }
    } else {
      out += ch;
      i += 1;
    }
  }
  return out;
}

// 9. Distributed Zero-Lag Hive Compute sharding + anti-lag guard
export function canRunComputeSlice({ enabled, inCombat, inInstance, pauseInInstances, fps, minFps, budgetMs }) {
  if (!enabled) return false;
  if (inCombat) return false;
  if (pauseInInstances && inInstance) return false;
  if ((Number(fps) || 0) < (Number(minFps) || 45)) return false;
  if ((Number(budgetMs) || 1.5) <= 0 || Number(budgetMs) > 5.0) return false;
  return true;
}

export function shardComputeTasks(items, peers) {
  const activePeers = deduplicatePlayers(peers).sort();
  if (activePeers.length === 0) return {};
  const assignments = Object.fromEntries(activePeers.map((p) => [p, []]));
  items.forEach((item, idx) => {
    const peer = activePeers[idx % activePeers.length];
    assignments[peer].push(item);
  });
  return assignments;
}

// 10. Guild Chat @Mention matching & combat/instance smart queue suppression
export function matchesGuildMention(message, profile) {
  const tokens = [...String(message || "").toLowerCase().matchAll(/@([a-z0-9_]+)/g)].map((m) => m[1]);
  if (tokens.length === 0) return false;
  const targets = new Set(
    [
      "guild",
      "all",
      "everyone",
      normalizePlayerName(profile.name).toLowerCase(),
      String(profile.class || "").toLowerCase(),
      String(profile.race || "").toLowerCase(),
      String(profile.role || "").toLowerCase(),
      ...(profile.professions || []).map((p) => String(p).toLowerCase()),
    ].filter(Boolean)
  );
  return tokens.some((t) => targets.has(t));
}

export function shouldDeliverQueuedMentions(queuedMentions, lastSelfGuildChatAt) {
  return (queuedMentions || []).filter((m) => (Number(m.timestamp) || 0) > (Number(lastSelfGuildChatAt) || 0));
}

// 11. Sharpie's Gear Judge (% upgrade + Cap Guardian), Reserved WoW commands, Top-3 Tooltips, Auto-Sell Trash
export function evaluateGearUpgrade(currentStats, candidateStats, weights, caps = {}) {
  const score = (stats) =>
    Object.entries(weights || {}).reduce((acc, [stat, w]) => acc + (Number(stats?.[stat]) || 0) * Number(w), 0);
  const curScore = score(currentStats);
  const candScore = score(candidateStats);
  const pctDelta = curScore > 0 ? ((candScore - curScore) / curScore) * 100 : (candScore > 0 ? 100 : 0);

  let capWarning = "";
  for (const [stat, capVal] of Object.entries(caps || {})) {
    const curVal = Number(currentStats?.[stat]) || 0;
    const nextVal = Number(candidateStats?.[stat]) || 0;
    if (curVal >= capVal && nextVal < capVal) {
      capWarning = `Drops ${stat} below cap (${nextVal}/${capVal})`;
      break;
    }
  }
  return { curScore, candScore, pctDelta, capWarning };
}

export const RESERVED_WOW_COMMANDS = new Set([
  "/g", "/guild", "/p", "/party", "/r", "/raid", "/rw", "/bg", "/i", "/instance",
  "/s", "/say", "/y", "/yell", "/w", "/whisper", "/t", "/tell", "/o", "/officer",
  "/inv", "/invite", "/who", "/trade", "/dance", "/sit", "/reload", "/rl",
]);

export function isCommandAllowed(cmd) {
  return !RESERVED_WOW_COMMANDS.has(String(cmd || "").trim().toLowerCase());
}

export function formatTopHolders(holders, limit = 3) {
  const sorted = [...(holders || [])].sort((a, b) => (b.total || 0) - (a.total || 0));
  const top = sorted.slice(0, limit).map((h) => `${h.name}(${h.total})`);
  if (sorted.length > limit) {
    top.push(`+${sorted.length - limit} more`);
  }
  return top.join(", ");
}

export function filterAutoSellGrayTrash(bagSlots, shiftHeld = false) {
  if (shiftHeld) return [];
  return (bagSlots || []).filter((s) => s && s.quality === 0 && (Number(s.sellPrice) || 0) > 0 && !s.isLocked);
}
