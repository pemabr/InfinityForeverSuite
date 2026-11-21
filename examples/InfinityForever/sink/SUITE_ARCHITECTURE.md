# InfinityForever Suite Architecture

## Overview
This document outlines the unified addon suite structure that consolidates 90+ individual addons into a cohesive, integrated experience for WoW Forever.

## Core Philosophy
- **Single unified experience**: All addons feel like one integrated product
- **Modular architecture**: Core + Feature modules that can be enabled/disabled
- **Shared infrastructure**: Common data storage, communication, and UI framework
- **Zero conflicts**: Centralized keyboard shortcuts and event handling

## Suite Structure

### Core Addon: `InfinityCore`
**Purpose**: Central hub providing shared infrastructure for all suite addons.

**Responsibilities**:
- Data gathering, aggregation, and normalization
- Persistent storage (SavedVariables management)
- Inter-addon communication (messaging system)
- Shared UI framework and styling
- Keyboard shortcut registry and management
- Event subscription and routing
- Configuration persistence and synchronization

**Modules**:
- `Core/DataManager.lua` - Unified data aggregation
- `Core/Storage.lua` - Persistent storage interface
- `Core/Messaging.lua` - Addon-to-addon communication
- `Core/UIFramework.lua` - Shared UI components
- `Core/Config.lua` - Configuration management
- `Core/EventRouter.lua` - Centralized event handling
- `Core/CommandRegistry.lua` - Slash commands and keybinds

### Feature Addons

#### 1. **InfinityLoot** (Loot & Economy)
Consolidates:
- ClassicLootManager + modules (Alerts, Integrations, Tracker)
- SharpiesLootTracker
- CommissionsForever
- Finanzamt
- GuildTradeCenter

**Features**:
- Unified loot management (DKP/EPGP)
- Loot tracking and value calculation
- Commission tracking
- Trading post management
- Gold flow analysis

#### 2. **InfinityGather** (Resource Collection)
Consolidates:
- GatherMate2 + storage modules
- GatherPathForever
- TrokkosGatherMate2Helper
- SkillUpForever

**Features**:
- Unified gathering database
- Optimal route planning
- Skill-up route generation
- Cross-expansion gathering support

#### 3. **InfinityGear** (Character Progression)
Consolidates:
- SharpiesGearJudge + modules (Laboratory, Roadmap, Roster, Talents)
- Attune
- Consumable-Connoisseur

**Features**:
- Gear evaluation across characters
- Talent management
- Attunement tracking
- Consumable optimization

#### 4. **InfinityGuide** (Information & Quest)
Consolidates:
- Questie + modules (QuestieDB, QuestieTrace)
- AdventureGuideForever
- FieldGuideForever
- ForeverDungeonJournal
- Atlas suite (Atlas, Atlas_ClassicWoW, AtlasLoot*, AtlasBIStooltips)
- InstanceAtlas

**Features**:
- Unified quest tracking
- Adventure/zone guide integration
- Loot information from dungeons/raids
- Dungeon journal
- Interactive maps with loot data

#### 5. **InfinityRaid** (Raiding & Combat)
Consolidates:
- DBM suite (all modules)
- MRT
- Decursive
- HealBot + modules (ExtraSkins, Tips)
- Healer_LoS_Helper

**Features**:
- Encounter warnings and timers
- Raid composition management
- Healing assignments and LoS checking
- Curses tracking
- Real-time combat alerts

#### 6. **InfinityGuild** (Guild Management)
Consolidates:
- GuildLadderDKP
- GuildPrideForever
- Guild_Roster_Manager

**Features**:
- Guild roster and DKP ladder
- Guild pride/achievements tracking
- Member management interface

#### 7. **InfinityQoL** (Quality of Life)
Consolidates:
- TweaksForever
- MacroAssistForever
- LegacyForever
- idTip

**Features**:
- Quest auto-accept/turn-in
- NPC highlighting for special purposes
- Macro assistance
- Tooltip enhancements
- Auto-repair and sell junk

#### 8. **InfinityData** (Data & Storage)
Data-only addons (no UI):
- GatherMate2_Data
- AtlasLootClassic_Data
- QuestieDB

## Communication & Integration Points

### Keyboard Shortcuts
- Centralized registry to prevent conflicts
- Priority system (raid > dungeon > world)
- Customizable keybind UI

### Data Exchange
- Shared SavedVariables format
- DataManager exposes APIs for read/write
- Change notifications for reactive updates

### UI Consistency
- Shared theme and styling
- Unified minimap buttons
- Consistent window positioning

### Event Handling
- Global event router prevents duplicate listeners
- Filtered subscriptions by feature module
- Efficient event batching

## Configuration

**Single unified settings interface** (`InfinityCore` → Settings):
- Per-feature toggle (enable/disable entire modules)
- Per-feature sub-settings
- Keyboard shortcut customization
- Appearance preferences
- Data retention policies

## Development Phases

### Phase 1: Core Foundation
- Create `InfinityCore` addon
- Implement data manager and storage
- Build messaging system
- Establish UI framework

### Phase 2: Primary Feature Addons
- InfinityLoot (most used, highest integration needs)
- InfinityGuild (guild-centric)
- InfinityRaid (combat-centric)

### Phase 3: Secondary Feature Addons
- InfinityGather
- InfinityGuide
- InfinityGear

### Phase 4: QoL & Polish
- InfinityQoL
- InfinityData
- Cross-addon integration testing
- UI refinement
- Conflict resolution

## File Organization

```
sink/
├── InfinityCore/                    # Core addon
│   ├── InfinityCore.toc
│   ├── Core/
│   │   ├── DataManager.lua
│   │   ├── Storage.lua
│   │   ├── Messaging.lua
│   │   ├── UIFramework.lua
│   │   ├── Config.lua
│   │   ├── EventRouter.lua
│   │   └── CommandRegistry.lua
│   ├── UI/
│   │   ├── MainWindow.lua
│   │   ├── SettingsPanel.lua
│   │   └── Components/
│   └── Localization/
│
├── InfinityLoot/                    # Feature addon
│   ├── InfinityLoot.toc
│   ├── Modules/
│   │   ├── LootManager.lua
│   │   ├── Tracking.lua
│   │   └── Commissions.lua
│   └── UI/
│
├── InfinityGuild/
│   ├── InfinityGuild.toc
│   └── ...
│
├── InfinityRaid/
│   ├── InfinityRaid.toc
│   └── ...
│
├── InfinityGather/
├── InfinityGuide/
├── InfinityGear/
├── InfinityQoL/
└── InfinityData/
```

## Benefits of This Architecture

1. **User Experience**:
   - Single unified interface
   - No conflicting keybinds
   - Consistent look and feel
   - Easy enable/disable of features

2. **Developer Experience**:
   - Clear separation of concerns
   - Shared code reduces duplication
   - Easier testing and debugging
   - Standard communication patterns

3. **Performance**:
   - Single event listener per category
   - Efficient data deduplication
   - Reduced memory overhead
   - Lazy loading of features

4. **Maintainability**:
   - Centralized configuration
   - Version management simplified
   - Easier to refactor and improve
   - Clear dependency graph

## Migration Strategy

1. **Code analysis**: Map all functionality from source addons
2. **API creation**: Design InfinityCore APIs before development
3. **Feature extraction**: Pull code from each source addon
4. **Integration**: Wire into InfinityCore using standardized patterns
5. **Testing**: Verify each feature works independently and together
6. **UI consolidation**: Merge settings and interfaces
7. **Conflict resolution**: Test for keybind and event conflicts
8. **Performance optimization**: Profile and optimize data flow
