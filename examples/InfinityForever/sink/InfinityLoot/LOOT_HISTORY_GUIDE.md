# Loot History & Analytics Module

## Overview

The **Loot History & Analytics Module** provides comprehensive tracking, analysis, and reporting of all loot awards. It automatically records every piece of loot given to players and generates detailed statistics for guild leadership and players.

## Features

### Core Features

1. **Complete Loot Logging**
   - Automatic logging of all loot awards
   - Timestamp tracking for each award
   - Item metadata (ID, name, link, value)
   - Award reason documentation
   - Raid ID association
   - Up to 50,000 historical entries

2. **Player Statistics**
   - Total awards count
   - Total loot value received
   - Average value per award
   - Maximum single award value
   - Minimum single award value
   - Last award timestamp

3. **Item Statistics**
   - Award count per item
   - Total value distributed via item
   - Average value per award
   - Last awarded timestamp
   - Which players have received it

4. **Analytics & Analysis**
   - Overall loot distribution metrics
   - Top loot recipients
   - Most awarded items
   - Most valuable items
   - Loot value analysis (total, average, high/low)

5. **Session Management**
   - Start/end raid sessions
   - Track loot within sessions
   - Session-based statistics
   - Session duration tracking

6. **Export & Reporting**
   - Loot history export (plain text)
   - Player comparison reports
   - Item popularity reports
   - JSON export for integration

### Cross-Addon Compatibility

- Works independently of other addons
- Integrates with EPGP system to track point changes
- Integrates with Decay system to track award history
- Can be used standalone for loot tracking only
- Graceful degradation if other modules missing

## Usage

### Slash Commands

#### Main History Command (`/lh` or `/loothistory`)

```
/lh                      - Show loot history summary
/lh player <name>        - Show loot for specific player (last 50 awards)
/lh top                  - Show top 10 loot recipients by total value
/lh items                - Show top 10 most awarded items
/lh export               - Export last 500 loot awards to chat
/lh comparison           - Show full player comparison report
```

### Examples

#### View overall loot distribution
```
/lh
```
Output:
```
=== Loot History ===
Total Loot Awards: 1250
Total Value: 125000
Average Value: 100
Highest Award: 500
```

#### Check a player's loot history
```
/lh player Thrall
```
Output:
```
[2026-11-20 19:45:22] Thrall received Perdition's Blade (Value: 250) - Boss Drop
[2026-11-20 19:12:11] Thrall received Sapphiron's Pendant (Value: 180) - Boss Drop
[2026-11-20 18:33:45] Thrall received Rune of Razorice (Value: 100) - Trash Drop
```

#### View top recipients
```
/lh top
```

#### Export detailed report
```
/lh export
```

## API Reference

### Logging Functions

#### LogLootAward(lootEntry)
Record a single loot award.

**Parameters:**
- `lootEntry` (table): Loot award information
  - `playerName` (string): **Required** - Player receiving loot
  - `itemName` (string): Item name
  - `itemId` (number): Item ID
  - `itemLink` (string): Item link (for WoW item info)
  - `value` (number): Point/gold value of award (default: 0)
  - `reason` (string): Why award given (default: "Loot Award")
  - `raidId` (string): Associated raid ID
  - `source` (string): Loot source (default: "unknown")
  - `timestamp` (number): Unix timestamp (auto-generated if omitted)

**Returns:** `success` (boolean)

**Example:**
```lua
InfinityLootHistory:LogLootAward({
    playerName = "Thrall",
    itemName = "Perdition's Blade",
    itemId = 19364,
    itemLink = "|cff1eff00|Hitem:19364::::::::60::::::|h[Perdition's Blade]|h|r",
    value = 250,
    reason = "Sapphiron Drop",
    raidId = "raid_123456",
    source = "boss_drop"
})
```

#### LogBatchLootAwards(lootEntries)
Record multiple loot awards at once (more efficient than calling LogLootAward multiple times).

**Parameters:**
- `lootEntries` (table): Array of loot entries

**Returns:** `success` (boolean)

**Example:**
```lua
InfinityLootHistory:LogBatchLootAwards({
    {playerName = "Thrall", itemName = "Item1", value = 100},
    {playerName = "Jaina", itemName = "Item2", value = 150},
    {playerName = "Arthus", itemName = "Item3", value = 200},
})
```

### Statistics Functions

#### GetPlayerStats(playerName)
Get statistics for a specific player.

**Parameters:**
- `playerName` (string): Player name

**Returns:** `stats` (table or nil)
- `name` (string)
- `totalAwards` (number): Count of loot awards
- `totalValue` (number): Total loot value received
- `averageValue` (number): Average value per award
- `maxSingleValue` (number): Highest single award
- `minSingleValue` (number): Lowest single award
- `lastAwardTime` (number): Timestamp of most recent award

**Example:**
```lua
local stats = InfinityLootHistory:GetPlayerStats("Thrall")
if stats then
    print("Thrall received " .. stats.totalAwards .. " pieces of loot")
    print("Total value: " .. stats.totalValue)
end
```

#### GetItemStats(itemId)
Get statistics for a specific item.

**Parameters:**
- `itemId` (number or string): Item ID

**Returns:** `stats` (table or nil)
- `itemId` (string)
- `awardCount` (number): Times awarded
- `totalValue` (number): Total value distributed
- `averageValue` (number): Average per award
- `lastAwardedTime` (number): Last awarded timestamp
- `awardedTo` (table): {playerName = count}

**Example:**
```lua
local stats = InfinityLootHistory:GetItemStats(19364)
if stats then
    print("Item awarded " .. stats.awardCount .. " times")
end
```

#### GetTopLootRecipients(limit, sortBy)
Get top players by loot awards.

**Parameters:**
- `limit` (number, default: 10): How many to return
- `sortBy` (string, default: "value"): Sort metric
  - `"value"`: Sort by total loot value
  - `"count"`: Sort by number of awards
  - `"average"`: Sort by average award value

**Returns:** `topPlayers` (table): Array of player stats

**Example:**
```lua
-- Top 20 players by value
local topPlayers = InfinityLootHistory:GetTopLootRecipients(20, "value")
for rank, player in ipairs(topPlayers) do
    print(rank .. ". " .. player.name .. ": " .. player.totalValue .. " value")
end

-- Top 10 by award count
local topCount = InfinityLootHistory:GetTopLootRecipients(10, "count")
```

#### GetMostAwardedItems(limit)
Get most frequently awarded items.

**Parameters:**
- `limit` (number, default: 10): How many to return

**Returns:** `topItems` (table): Array of item stats

#### GetMostValuableItems(limit)
Get highest value items awarded.

**Parameters:**
- `limit` (number, default: 10): How many to return

**Returns:** `topItems` (table): Array of item stats

#### GetLootAnalysis()
Get overall loot distribution analysis.

**Returns:** `analysis` (table)
- `totalValue` (number): Total value of all loot
- `averageValue` (number): Average per award
- `highestAward` (number): Highest single award
- `lowestAward` (number): Lowest single award
- `totalAwards` (number): Total number of awards

**Example:**
```lua
local analysis = InfinityLootHistory:GetLootAnalysis()
print("Average award: " .. analysis.averageValue)
```

### Query Functions

#### GetPlayerLootHistory(playerName, limit)
Get loot awards for a specific player.

**Parameters:**
- `playerName` (string): Player name
- `limit` (number, default: 100): Max entries to return

**Returns:** `loot` (table): Array of loot entries (most recent first)

#### GetLootByDateRange(startTime, endTime)
Get loot awarded between two timestamps.

**Parameters:**
- `startTime` (number): Unix timestamp
- `endTime` (number): Unix timestamp

**Returns:** `loot` (table): Array of loot entries

**Example:**
```lua
-- Get loot from last 24 hours
local now = InfinityUtils:GetTimeStamp()
local yesterday = now - 86400
local recentLoot = InfinityLootHistory:GetLootByDateRange(yesterday, now)
```

#### GetRaidLoot(raidId)
Get all loot awarded in a specific raid.

**Parameters:**
- `raidId` (string): Raid ID

**Returns:** `loot` (table): Array of loot entries

#### GetItemAwardHistory(itemId, limit)
Get award history for a specific item.

**Parameters:**
- `itemId` (number or string): Item ID
- `limit` (number, default: 50): Max entries

**Returns:** `loot` (table): Array of awards (most recent first)

### Export Functions

#### ExportLootHistory(limit)
Export plain text loot history.

**Parameters:**
- `limit` (number, default: 500): Max entries to export

**Returns:** `historyString` (string): Formatted loot history

**Example:**
```lua
local export = InfinityLootHistory:ExportLootHistory(1000)
-- Can save to file or send to Discord webhook
```

#### ExportPlayerComparisonReport()
Export detailed player comparison report.

**Returns:** `reportString` (string): Ranked player comparison

**Example Output:**
```
LOOT DISTRIBUTION REPORT
========================

1. Thrall - 50 awards, Total: 5000, Avg: 100
2. Jaina - 48 awards, Total: 4800, Avg: 100
3. Arthus - 45 awards, Total: 4500, Avg: 100
...
```

#### ExportItemPopularityReport()
Export most popular items report.

**Returns:** `reportString` (string): Ranked item popularity

#### ExportAsJSON()
Export comprehensive JSON report.

**Returns:** `jsonString` (string): JSON formatted data

**Example:**
```lua
local json = InfinityLootHistory:ExportAsJSON()
-- Send to web integration, bot, or save to file
```

### Session Management

#### StartSession(sessionName, sessionId)
Start a loot tracking session (usually for a raid).

**Parameters:**
- `sessionName` (string): Name of session (e.g., "MC Raid 2026-11-20")
- `sessionId` (string, optional): ID (auto-generated if omitted)

**Returns:** `sessionId` (string)

**Example:**
```lua
local sessionId = InfinityLootHistory:StartSession("Molten Core - 2026-11-20")
```

#### EndSession(sessionId)
End a loot tracking session.

**Parameters:**
- `sessionId` (string): Session ID to end

**Returns:** `success` (boolean)

#### AddToSession(sessionId, lootEntry)
Add loot award to a session.

**Parameters:**
- `sessionId` (string): Session ID
- `lootEntry` (table): Loot entry data

**Returns:** `success` (boolean)

#### GetSessionStats(sessionId)
Get statistics for a session.

**Parameters:**
- `sessionId` (string): Session ID

**Returns:** `stats` (table or nil)
- `name` (string): Session name
- `startTime` (number): Start timestamp
- `endTime` (number): End timestamp
- `duration` (number): Duration in seconds
- `lootCount` (number): Items awarded
- `totalValue` (number): Total value
- `averageValue` (number): Average per item

**Example:**
```lua
local sessionId = InfinityLootHistory:StartSession("MC Raid")
-- Award some loot...
InfinityLootHistory:EndSession(sessionId)
local stats = InfinityLootHistory:GetSessionStats(sessionId)
print("Session duration: " .. math.floor(stats.duration / 60) .. " minutes")
```

## Configuration

### Default Configuration

```lua
InfinityLootHistory.config = {
    maxHistoryEntries = 50000,  -- Keep last 50k awards
    enableAnalytics = true,      -- Enable statistics
    enableExport = true,         -- Enable export functions
    adminOnly = true,            -- Require admin for some functions
}
```

### Customizing Configuration

```lua
-- Increase history size
InfinityLootHistory.config.maxHistoryEntries = 100000

-- Disable export if concerned about data
InfinityLootHistory.config.enableExport = false

-- Allow all players to access stats
InfinityLootHistory.config.adminOnly = false
```

## Integration Examples

### Integration with Decay System

```lua
-- When decay is applied, can track it via loot history
InfinityLootHistory:LogLootAward({
    playerName = playerName,
    itemName = "Decay: " .. oldValue .. " → " .. newValue,
    value = -(oldValue - newValue),
    reason = "Automatic Decay",
    source = "decay_system"
})
```

### Integration with EPGP System

```lua
-- Track EPGP awards in loot history
InfinityLootHistory:LogLootAward({
    playerName = playerName,
    itemName = itemName,
    itemId = itemId,
    value = itemValue,
    reason = "EPGP Award - " .. epAwarded .. " EP",
    source = "epgp_system"
})
```

### Discord Integration

```lua
local export = InfinityLootHistory:ExportPlayerComparisonReport()
-- Send via InfinityDiscordBridge or similar addon
InfinityDiscordBridge:SendMessage(export, "#loot-history")
```

### Web Dashboard

```lua
-- Generate JSON for web dashboard
local json = InfinityLootHistory:ExportAsJSON()
-- Send to web server for visualization
SendToWebDashboard(json)
```

## Performance Considerations

### Memory Usage
- **50,000 entries:** ~5-8 MB (each entry ~100-150 bytes)
- Automatically trims oldest entries when max reached
- Player stats cached in-memory for O(1) lookup

### CPU Usage
- Logging: <1ms per award
- Queries: <5ms for top N results
- Export: <50ms for 500 entries
- Statistics calculation: <10ms

### Best Practices
1. Use batch logging when awarding multiple items
2. Query by player name for fastest lookups
3. Export less frequently (not every award)
4. Prune old data monthly if memory constrained

## Troubleshooting

### No data appears
- Check addon is loaded: `/lh` should show summary
- Verify loot is being logged: Check Init.lua is initialized
- Ensure EPGP/Decay systems are logging: Check their callbacks

### Statistics seem wrong
- Remember: Last 50,000 entries only (oldest dropped)
- Use session management for per-raid tracking
- Verify timestamp sync across clients

### Export is too large
- Use smaller limit: `/lh export` uses 500, try 100
- Use GetPlayerLootHistory() for single player
- Use GetLootByDateRange() for time-based export

## Future Enhancements

Possible additions:
- Loot distribution fairness scoring
- Predictive loot allocation
- Multi-spec loot tracking
- Loot trading history
- Loot value inflation tracking
- Comparative metrics (Thrall vs others)
- Automated reports
- Integration with guild banks
