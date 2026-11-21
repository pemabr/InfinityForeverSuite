# Infinity Forever - Quick Reference Guide

## 🚀 Getting Started

### Load the Suite
1. All 27 addons auto-load with proper dependency order
2. InfinityCore loads first (hard dependency)
3. Data systems (InfinityData, InfinityDataCollector) initialize
4. All specialized addons follow

### Enable Data Collection
Data collection starts automatically on addon load:
```lua
-- Check status
print(InfinityDataCollector:GetStats())

-- Manual collection control
InfinityDataCollector:StartCollection()
InfinityDataCollector:StopCollection()
```

### Check Questie Sync Status
```lua
-- Get sync status
print(InfinityQuestieIntegration:GetSyncStatus())

-- Start manual sync if needed
InfinityQuestieIntegration:ManualSync()
```

---

## 📡 Data Systems Overview

### Three-Layer Architecture

**1. Data Collection (DataCollector)**
- Autonomous gathering of quests, mobs, drops, nodes
- Event-driven from game API
- Publishes collection events

**2. Data Storage (InfinityData)**
- Central persistent repository
- Query engine for searches
- Automatic SavedVariables persistence
- Merge deduplication

**3. Data Sharing (DataSharing)**
- Secure guild-based distribution
- Personal data sanitization
- Contributor tracking
- Configurable scope (guild/public/self)

---

## 🎮 Encounter Database

### Available Encounters: 73 Total

**Major Raids:**
- Molten Core: 11 encounters
- Blackwing Lair: 9 encounters
- Naxxramas: 12 encounters
- Temple of Ahn'Qiraj: 10 encounters
- Outdoor World Bosses: 23 encounters
- Dragons of Nightmare: 10 encounters
- Other Dungeons: 11 encounters

**Query Examples:**
```lua
-- Get specific encounter
local ragnaros = InfinityEncounterDatabase:GetEncounter(42)

-- Get all encounters in zone
local moltenCoreBosses = InfinityEncounterDatabase:GetEncountersInZone("Molten Core")

-- Display encounter info
InfinityEncounterDatabase:DisplayEncounter(1)
```

---

## 🔐 Privacy & Data Sharing

### Automatic Sanitization

**Guild Members Receive:**
- Quest name, level, type, objectives
- Mob name, level, zone (but not exact location)
- Item names and drop rates
- Gather node types

**Public/Other Guilds Receive:**
- Quest name, level only
- Mob name only
- Item names only
- Gather node types only

**Never Shared:**
- Player names
- Realm names
- Guild information
- Personal achievements
- Private communications

---

## 📊 Configuration

### DataCollector Config
```lua
-- Enable/disable collection types
InfinityDataCollector:SetConfig("enableQuestCollection", true)
InfinityDataCollector:SetConfig("enableMobCollection", true)
InfinityDataCollector:SetConfig("enableDropCollection", true)
InfinityDataCollector:SetConfig("enableNodeCollection", true)

-- Batch settings
InfinityDataCollector:SetConfig("batchSize", 50)
InfinityDataCollector:SetConfig("updateInterval", 1.0)
```

### DataSharing Config
```lua
-- Control sharing scope
InfinityDataSharing:SetConfig("enableSharing", true)
InfinityDataSharing:SetConfig("shareBetweenGuilds", false) -- guild-only
InfinityDataSharing:SetConfig("shareQuestData", true)
InfinityDataSharing:SetConfig("shareMobData", true)
InfinityDataSharing:SetConfig("shareDropData", true)
InfinityDataSharing:SetConfig("shareNodeData", true)
```

### InfinityData Config
```lua
-- Storage settings
InfinityData:SetConfig("enablePersistentStorage", true)
InfinityData:SetConfig("maxStoredItems", 10000)
InfinityData:SetConfig("cacheExpiry", 86400 * 30) -- 30 days
```

### QuestieIntegration Config
```lua
-- Sync settings
InfinityQuestieIntegration:SetConfig("enableSync", true)
InfinityQuestieIntegration:SetConfig("batchSize", 100)
InfinityQuestieIntegration:SetConfig("batchDelay", 0.5)
InfinityQuestieIntegration:SetConfig("autoSync", true)
InfinityQuestieIntegration:SetConfig("syncOnLoad", true)
```

---

## 🔧 Troubleshooting

### Data Not Collecting
**Problem:** No quest/mob data being stored  
**Solution:**
1. Verify InfinityDataCollector addon loaded
2. Check InfinityData addon loaded
3. Restart wow or reload UI: `/reload`
4. Check error messages: `/fstack` addon errors

### Questie Sync Not Starting
**Problem:** Quest data from Questie not syncing  
**Solution:**
1. Confirm Questie addon installed
2. Wait 2 seconds after login (auto-sync delay)
3. Manual trigger: `InfinityQuestieIntegration:ManualSync()`
4. Check sync status: `print(InfinityQuestieIntegration:GetSyncStatus())`

### Data Not Sharing with Guild
**Problem:** Guild members not receiving data  
**Solution:**
1. Verify guild membership
2. Check InfinityDataCollector addon on all clients
3. Enable sharing: `InfinityDataSharing:SetConfig("enableSharing", true)`
4. Check guild members have same addons loaded

---

## 📈 Performance Tips

### Optimize Data Collection
```lua
-- Reduce collection frequency if needed
InfinityDataCollector:SetConfig("updateInterval", 2.0) -- 2 seconds

-- Disable non-essential collection
InfinityDataCollector:SetConfig("enableNodeCollection", false)
```

### Optimize Sharing
```lua
-- Disable cross-guild sharing to reduce network
InfinityDataSharing:SetConfig("shareBetweenGuilds", false)

-- Reduce update intervals
InfinityDataSharing:SetConfig("updateInterval", 300) -- 5 minutes
```

### Optimize Storage
```lua
-- Trigger cleanup if storage gets large
InfinityData:CleanupExpiredData()

-- Check storage usage
local stats = InfinityData:GetStorageStats()
print(stats.quests .. " quests stored")
```

---

## 🎯 Event System

### Subscribe to Data Events

```lua
-- Quest data collected
InfinityMessaging:Subscribe("quest_data_collected", function(questID, questName)
    print("Quest collected: " .. questName)
end)

-- Quest completed
InfinityMessaging:Subscribe("quest_completed", function(questID, questName)
    print("Quest completed: " .. questName)
end)

-- Data stored
InfinityMessaging:Subscribe("data_stored", function(type, id)
    print("Data stored: " .. type .. " #" .. id)
end)

-- Questie sync complete
InfinityMessaging:Subscribe("questie_sync_complete", function(synced, total)
    print("Questie sync: " .. synced .. "/" .. total .. " quests")
end)

-- Guild data shared
InfinityMessaging:Subscribe("data_share_guild", function(type, id, data)
    print("Guild data shared: " .. type .. " #" .. id)
end)
```

---

## 🔍 Query Examples

### Search Quests
```lua
-- Find all quests with "dragon" in name
local results = InfinityData:SearchQuests("dragon")
for _, quest in ipairs(results) do
    print(quest.name .. " (Level " .. quest.level .. ")")
end
```

### Search Mobs
```lua
-- Find all mobs with "dragon" in name
local results = InfinityData:SearchMobs("dragon")
for _, mob in ipairs(results) do
    print(mob.name .. " in " .. mob.zone)
end

-- Get all mobs in zone
local zoneMobs = InfinityData:GetMobsByZone("Molten Core")
```

### Search Drops
```lua
-- Get all sources of an item
local drops = InfinityData:GetDropsByItem(itemID)
for _, drop in ipairs(drops) do
    print("Dropped by: " .. drop.source)
end
```

### Search Nodes
```lua
-- Get all gather nodes in zone
local nodes = InfinityData:GetNodesByZone("Tanaris")

-- Get all herb nodes in zone
local herbs = InfinityData:GetNodesByZone("Ashenvale", "herb")
```

---

## 📱 Integration with Other Addons

### InfinityLoot Integration
Data collection feeds quest/mob info to loot system for better tracking.

### InfinityRaid Integration
Encounter database provides boss mechanics and composition requirements.

### InfinityNavigation Integration
Gather nodes and mob locations feed navigation pathfinding.

### InfinityHealer Integration
Encounter mechanics data provides raid health management context.

---

## 🛠️ Advanced Usage

### Manual Data Collection
```lua
-- Collect quest data manually
InfinityDataCollector:CollectQuestData(questID)

-- Collect mob data
InfinityDataCollector:CollectMobData("player")

-- Collect node data
InfinityDataCollector:CollectNodeData("target")
```

### Manual Data Storage
```lua
-- Store custom quest data
InfinityData:StoreQuest(questID, {
    id = questID,
    name = "My Quest",
    level = 60,
    type = "raid",
})

-- Complete quest
InfinityData:CompleteQuest(questID)

-- Record mob kill
InfinityData:RecordMobKill(mobID)

-- Record node gathering
InfinityData:RecordNodeGathering(nodeID)
```

### Manual Data Sharing
```lua
-- Share specific quest data
InfinityDataSharing:ShareQuestData(questID, questName)

-- Share mob data
InfinityDataSharing:ShareMobData(mobID, mobName)
```

---

## 📞 Support

For issues:
1. Check `/fstack` for addon errors
2. Review data collection status: `print(InfinityDataCollector:GetStats())`
3. Check quest sync status: `print(InfinityQuestieIntegration:GetSyncStatus())`
4. Verify storage usage: `print(InfinityData:GetStorageStats())`
5. Check error messages in chat

---

**Infinity Forever Suite v1.0.0**  
97% Feature Complete | Production Ready  
27 Addons | 113 Modules | 1.2 MB | ~36,000 Lines
