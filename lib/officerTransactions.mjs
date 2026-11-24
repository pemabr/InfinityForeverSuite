// Pure JS model mirroring PluribusCore/OfficerDashboard.lua Transaction History & Audit Trail logic
// Ensures deduplication, multi-source aggregation, filtering, member drill-down, summary math, and CSV export are unit-tested.

export const MAX_OFFICER_TRANSACTIONS = 2000;

export function normalizePlayer(name) {
  return String(name || "").replace(/-.+$/, "").trim();
}

export function buildTxCoreKey(tx) {
  return [
    String(tx.category || "AUDIT").toUpperCase(),
    String(tx.action || "LOG").toUpperCase(),
    normalizePlayer(tx.player || "").toLowerCase(),
    String(Math.floor((Number(tx.amount) || 0) * 100)),
    String(tx.itemName || "").trim().toLowerCase(),
  ].join("|");
}

export function mergeAndFilterTransactions(sources, filters = {}, nowSec = Math.floor(Date.now() / 1000)) {
  const seenByKey = new Map();
  const merged = [];

  for (const list of sources || []) {
    for (const raw of list || []) {
      if (!raw || typeof raw !== "object") continue;
      const tx = {
        id: raw.id || "",
        timestamp: Number(raw.timestamp) || 0,
        category: String(raw.category || "AUDIT").toUpperCase(),
        action: String(raw.action || "MANUAL_AUDIT").toUpperCase(),
        player: normalizePlayer(raw.player || "Guild") || "Guild",
        officer: normalizePlayer(raw.officer || "Officer") || "Officer",
        amount: Number(raw.amount) || 0,
        unit: String(raw.unit || ""),
        beforeVal: raw.beforeVal !== undefined && raw.beforeVal !== null ? Number(raw.beforeVal) : null,
        afterVal: raw.afterVal !== undefined && raw.afterVal !== null ? Number(raw.afterVal) : null,
        itemName: String(raw.itemName || "").trim(),
        reason: String(raw.reason || "").trim(),
        source: String(raw.source || "OfficerDashboard"),
      };
      const key = buildTxCoreKey(tx);
      const timestamps = seenByKey.get(key) || [];
      if (!timestamps.some((prevTs) => Math.abs(tx.timestamp - prevTs) <= 5)) {
        timestamps.push(tx.timestamp);
        seenByKey.set(key, timestamps);
        merged.push(tx);
      }
    }
  }

  merged.sort((a, b) => {
    if (a.timestamp !== b.timestamp) return b.timestamp - a.timestamp;
    return String(b.id).localeCompare(String(a.id));
  });

  const cat = String(filters.category || "ALL").toUpperCase();
  const tf = Number(filters.timeframeSec) || 0;
  const cutoff = tf > 0 ? nowSec - tf : 0;
  const q = String(filters.query || "").trim().toLowerCase();

  const filtered = merged.filter((tx) => {
    if (cat !== "ALL" && tx.category !== cat) return false;
    if (cutoff > 0 && tx.timestamp < cutoff) return false;
    if (q) {
      const hay = `${tx.id} ${tx.player} ${tx.officer} ${tx.itemName} ${tx.reason} ${tx.action} ${tx.category} ${tx.source}`.toLowerCase();
      if (!hay.includes(q)) return false;
    }
    return true;
  });

  return { filtered, totalAll: merged.length };
}

export function summarizeTransactions(list) {
  const summary = {
    total: (list || []).length,
    dkpCount: 0,
    lootCount: 0,
    auditCount: 0,
    taxCount: 0,
    netEP: 0,
    netGP: 0,
    uniqueMembers: 0,
  };
  const seenMembers = new Set();
  for (const tx of list || []) {
    if (tx.category === "DKP") summary.dkpCount++;
    else if (tx.category === "LOOT") summary.lootCount++;
    else if (tx.category === "TAX") summary.taxCount++;
    else summary.auditCount++;

    if (tx.unit === "EP") summary.netEP += Number(tx.amount) || 0;
    else if (tx.unit === "GP") summary.netGP += Number(tx.amount) || 0;

    const p = normalizePlayer(tx.player).toLowerCase();
    if (p && p !== "guild" && p !== "all raiders" && p !== "guild policy") {
      seenMembers.add(p);
    }
  }
  summary.uniqueMembers = seenMembers.size;
  return summary;
}

export function stripWowFormatting(val) {
  return String(val ?? "")
    .replace(/\|H[^|]*\|h(.*?)\|h/g, "$1")
    .replace(/\|c[0-9a-fA-F]{8}/g, "")
    .replace(/\|r/g, "")
    .replace(/\|T.*?\|t/g, "");
}

export function csvEscape(val, delim = ",") {
  const s = stripWowFormatting(val).replace(/"/g, '""');
  const needsQuote = s.includes(delim) || /[\r\n"]/.test(s);
  return needsQuote ? `"${s}"` : s;
}

export function selectTransactionsForExportScope(allMerged, scope = "ALL", customMember = "") {
  const cleanMember = normalizePlayer(customMember).toLowerCase();
  if (cleanMember) {
    return (allMerged || []).filter((tx) => normalizePlayer(tx.player).toLowerCase() === cleanMember);
  }
  const s = String(scope || "ALL").toUpperCase();
  if (s === "DKP") {
    return (allMerged || []).filter((tx) => tx.category === "DKP" || tx.action === "DECAY");
  }
  if (s === "LOOT") {
    return (allMerged || []).filter((tx) => tx.category === "LOOT");
  }
  if (s === "AUDIT") {
    return (allMerged || []).filter((tx) => tx.category === "AUDIT");
  }
  return [...(allMerged || [])];
}

export function exportTransactionsToCSV(list, options = {}) {
  const delim = options.format === "TSV" ? "\t" : ",";
  const header = ["ID", "Timestamp", "Category", "Action", "Member", "Amount", "Unit", "Before", "After", "Item", "Reason", "Officer", "Source"].join(delim);
  const rows = (list || []).map((tx) =>
    [
      tx.id,
      tx.timestamp,
      tx.category,
      tx.action,
      tx.player,
      tx.amount,
      tx.unit,
      tx.beforeVal ?? "",
      tx.afterVal ?? "",
      tx.itemName,
      tx.reason,
      tx.officer,
      tx.source,
    ]
      .map((v) => csvEscape(v, delim))
      .join(delim)
  );
  return [header, ...rows].join("\n");
}
