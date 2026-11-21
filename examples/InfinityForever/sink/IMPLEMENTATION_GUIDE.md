# Infinity Forever Suite - Implementation Guide

## Overview

The **Infinity Forever Suite** is a unified addon collection for WoW Forever that consolidates 90+ individual addons into a single cohesive experience. The suite consists of **8 integrated addons** that feel like one product to the user.

## Suite Components

### 1. **InfinityCore** (Required Foundation)
The central hub providing:
- **Data Management**: Unified data aggregation, caching, and storage
- **Persistent Storage**: SavedVariables management with per-feature settings
- **Inter-Addon Communication**: Event-based messaging system
- **UI Framework**: Shared components and styling
- **Command Registry**: Centralized slash commands and keybinds
- **Event Routing**: Single event listener preventing conflicts

**Key Features**:
- `/infinity` - Toggle main window
- `/infinity debug` - Show system stats
- Unified settings interface
- Keybind management with conflict detection

---

### 2. **InfinityLoot** (Loot & Economy)
Consolidates:
- ClassicLootManager + modules
- SharpiesLootTracker
- CommissionsForever
- Finanzamt
- GuildTradeCenter

**Core Modules**:
- `LootManager.lua` - DKP/EPGP loot management
- `Tracking.lua` - Loot value and history tracking
- `Economy.lua` - Gold flow and market analysis
- `Commissions.lua` - Repeatable turn-in tracking

**Features**:
- Unified loot distribution system
- Automatic loot value calculation
- Commission and turn-in tracking
- Trading post integration

---

### 3. **InfinityGuild** (Guild Management)
Consolidates:
- GuildLadderDKP
- GuildPrideForever
- Guild_Roster_Manager

**Core Modules**:
- `RosterManager.lua` - Guild member management
- `DKPTracker.lua` - DKP ladder and history
- `MemberManagement.lua` - Member roles and permissions

**Features**:
- Real-time guild roster
- DKP ladder tracking
- Member achievement tracking
- Unified guild interface

---

### 4. **InfinityRaid** (Raiding & Combat)
Consolidates:
- DBM suite (all modules)
- MRT (Marksmanship Raid Tools)
- Decursive
- HealBot + modules
- Healer_LoS_Helper

**Core Modules**:
- `EncounterManager.lua` - DBM/encounter management
- `CombatAlerts.lua` - Real-time combat warnings
- `HealingManager.lua` - Healing assignments and LoS

**Features**:
- Encounter warnings and timers
- Raid composition management
- Healing assignments
- Curse tracking and dispelling
- Line of sight checking for healers

---

### 5. **InfinityGather** (Resource Gathering)
Consolidates:
- GatherMate2 + storage modules
- GatherPathForever
- TrokkosGatherMate2Helper
- SkillUpForever

**Core Modules**:
- `GatheringDatabase.lua` - Gathering node database
- `RouteOptimizer.lua` - Optimal route planning
- `SkillTracker.lua` - Skill-up progression

**Features**:
- Cross-expansion gathering database
- Optimal node routing
- Skill-up route generation
- Persistent gathering history

---

### 6. **InfinityGuide** (Quests & Information)
Consolidates:
- Questie + modules
- AdventureGuideForever
- FieldGuideForever
- ForeverDungeonJournal
- Atlas suite (all variants)
- InstanceAtlas

**Core Modules**:
- `QuestTracker.lua` - Quest tracking and planning
- `LootDatabase.lua` - Dungeon/raid loot info
- `ZoneGuide.lua` - Zone stories and adventures

**Features**:
- Unified quest tracking
- Adventure/zone guide integration
- Interactive loot information
- Dungeon journal viewer

---

### 7. **InfinityGear** (Character Progression)
Consolidates:
- SharpiesGearJudge + modules
- Attune
- Consumable-Connoisseur

**Core Modules**:
- `GearEvaluator.lua` - Gear comparison and ratings
- `TalentManager.lua` - Talent planning
- `ProgressionTracker.lua` - Character progression

**Features**:
- Cross-character gear evaluation
- Talent management and planning
- Attunement tracking
- Consumable optimization

---

### 8. **InfinityQoL** (Quality of Life)
Consolidates:
- TweaksForever
- MacroAssistForever
- LegacyForever
- idTip

**Core Modules**:
- `AutomationTools.lua` - Quest auto-accept/turn-in
- `TooltipEnhancements.lua` - Enhanced tooltips
- `MacroHelper.lua` - Macro assistance

**Features**:
- Automatic quest handling
- NPC highlighting
- Macro assistance
- Enhanced tooltips
- Auto-repair and sell junk

---

### 9. **InfinityData** (Data & Storage)
Data-only addon with:
- GatherMate2_Data
- AtlasLootClassic_Data
- QuestieDB

**Purpose**:
- Shared data files
- Cross-addon database
- Localization data

---

## Architecture Details

### Data Flow

```
Feature Addons
    ↓
InfinityDataManager (aggregation)
    ↓
InfinityStorageManager (persistence)
    ↓
SavedVariables (InfinityCoreDB)
```

### Communication Pattern

```
Feature 1 Module                Feature 2 Module
    ↓                               ↓
Publish Event via InfinityMessaging
    ↓
EventRouter → Routing → Delivery
    ↓
Subscribe & Handle
```

### Keybind Conflict Resolution

```
1. All keybinds registered in InfinityCommandRegistry
2. Central conflict detection before assignment
3. Priority system for raid/dungeon/world contexts
4. Per-character keybind storage
```

---

## Development Workflow

### Phase 1: Core Foundation ✅
- [x] InfinityCore addon structure
- [x] Data management system
- [x] Storage and persistence
- [x] Messaging framework
- [x] Event routing system
- [x] UI framework
- [x] Command registry

### Phase 2: Feature Integration (In Progress)
- [x] Feature addon scaffolding
- [ ] Extract code from source addons
- [ ] Adapt to core APIs
- [ ] Integration testing
- [ ] Conflict resolution

### Phase 3: UI Consolidation
- [ ] Unified main interface
- [ ] Feature-specific panels
- [ ] Settings management
- [ ] Theme system
- [ ] Minimap integration

### Phase 4: Optimization & Polish
- [ ] Performance profiling
- [ ] Code cleanup
- [ ] Documentation
- [ ] User testing
- [ ] Release preparation

---

## API Reference

### InfinityCore APIs

#### Data Management
```lua
-- Register a data source
InfinityDataManager:RegisterSource("my_data", updateCallback)

-- Update data
InfinityDataManager:UpdateSourceData("my_data", dataTable)

-- Get data
local data = InfinityDataManager:GetSourceData("my_data")

-- Subscribe to changes
InfinityDataManager:RegisterCallback("my_data", "UPDATED", function(data)
    -- Handle data update
end)
```

#### Storage & Settings
```lua
-- Global settings
InfinityStorageManager:SetGlobal("key", value)
InfinityStorageManager:GetGlobal("key", default)

-- Feature settings
InfinityStorageManager:SetFeatureSetting("MyFeature", "setting", value)
InfinityStorageManager:GetFeatureSetting("MyFeature", "setting", default)

-- Character-specific data
InfinityStorageManager:SetCharacter("key", value)
InfinityStorageManager:GetCharacter("key", default)
```

#### Messaging
```lua
-- Subscribe to an event
local unsub = InfinityMessaging:Subscribe("MY_EVENT", function(arg1, arg2)
    -- Handle event
end)

-- Publish an event
InfinityMessaging:Publish("MY_EVENT", arg1, arg2)

-- Unsubscribe
unsub()
```

#### Commands & Keybinds
```lua
-- Register a command
InfinityCommandRegistry:RegisterCommand("mycommand", function(args, msg)
    -- Handle command
end, {"alias1", "alias2"})

-- Register a keybind
InfinityCommandRegistry:RegisterKeybind("MY_ACTION", "Description", function()
    -- Handle keybind
end, "CTRL+SHIFT+M")

-- Get current keybind
local key = InfinityCommandRegistry:GetKeybind("MY_ACTION")
```

#### UI Framework
```lua
-- Create a standard frame
local frame = InfinityUIFramework:CreateFrame("MyFrame", UIParent, 400, 300)

-- Create UI elements
local btn = InfinityUIFramework:CreateButton(frame, "Click Me", 100, 25, function()
    -- Handle click
end)

local label = InfinityUIFramework:CreateLabel(frame, "Hello")

-- Show notification
InfinityUIFramework:ShowNotification("Event occurred!", 3)

-- Show dialog
InfinityUIFramework:ShowDialog("Title", "Message", "OK", function()
    -- Handle close
end)
```

---

## Configuration

### Per-Feature Settings
Each feature addon stores settings via:
```lua
InfinityStorageManager:SetFeatureSetting(INFINITY_FEATURES.LOOT, "auto_roll", true)
```

### Keybind Customization
Access via `/infinity` → Keybinds tab

### Profile-Specific Options
```lua
InfinityStorageManager:SetProfile("theme", "dark")
InfinityStorageManager:SetProfile("minimap.enabled", true)
```

---

## Migration from Source Addons

### For Each Source Addon:

1. **Code Analysis**
   - Identify core functionality
   - Find data structures
   - Map event handlers

2. **Modularization**
   - Extract into feature addon module
   - Adapt to InfinityCore APIs
   - Replace custom storage with InfinityStorageManager

3. **UI Integration**
   - Replace slash commands with InfinityCommandRegistry
   - Use InfinityUIFramework for UI elements
   - Consolidate settings panel

4. **Testing**
   - Verify data migration
   - Test keybind conflicts
   - Validate feature interactions

---

## Keyboard Shortcut Policy

### Existing Conflicts in Source Addons:
- Multiple addons using similar keybinds
- Addon-specific command prefixes (causing chaos)
- No centralized conflict detection

### Solution in Infinity Suite:
1. **Centralized Registry**: All keybinds registered to InfinityCommandRegistry
2. **Conflict Detection**: Automatic detection before assignment
3. **Priority System**: Raid > Dungeon > World context
4. **User Customization**: Easy rebinding via UI

---

## Project Status

**Current**: Core infrastructure complete, feature addons scaffolded
**Next Steps**: Extract and integrate source addon code
**Timeline**: Phase-based development as described above

---

## Testing Checklist

- [ ] All core systems initialize without errors
- [ ] Data persists correctly across reloads
- [ ] Keybind conflicts are detected
- [ ] Events propagate to all subscribers
- [ ] UI framework renders correctly
- [ ] Each feature addon initializes properly
- [ ] Cross-addon communication works
- [ ] No duplicate event listeners
- [ ] Settings save and load correctly
- [ ] Performance is acceptable

---

## Troubleshooting

### Addons not loading
- Verify TOC dependencies
- Check Interface version compatibility
- Run `/infinity debug` for status

### Data not persisting
- Verify SavedVariables declaration in TOC
- Check InfinityCoreDB initialization
- Look for storage manager errors

### Keybind conflicts
- Run conflict detection
- Use `/infinity` → Keybinds tab
- Reset to defaults if needed

### Performance issues
- Check data manager statistics
- Review event subscription count
- Profile with performance tools

---

## Support & Documentation

For more information:
- Main architecture: [SUITE_ARCHITECTURE.md](./SUITE_ARCHITECTURE.md)
- Source addons location: `../src/`
- Core addon implementation: `InfinityCore/`

---

**Version**: 1.0.0  
**Last Updated**: 2026-11-20  
**Status**: Active Development
