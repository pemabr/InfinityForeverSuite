# MISSING FEATURES IMPLEMENTATION GUIDE

This document lists all missing features identified in the audit, organized by InfinityForever suite.

---

## InfinityLoot Suite

### From ClassicLootManager (HIGH PRIORITY)

**Point Systems:**
- [ ] EPGP (Effort Points/Gear Points) implementation
- [ ] SK (Suicide Kings) point system
- [ ] Zero-Sum Bank system
- [ ] DKP point ledger with transactions

**Auction System:**
- [ ] Multi-item simultaneous auctions
- [ ] Open, closed, Vickrey bidding modes
- [ ] Anonymous bidding
- [ ] Tiered bidding
- [ ] Anti-snipe protection with configurable duration
- [ ] Bid increment configuration

**Roster & Teams:**
- [ ] Multi-roster support
- [ ] Cross-guild synchronization
- [ ] Main/alt linking system
- [ ] Profile locking mechanism

**Raid Management:**
- [ ] Automatic raid attendance tracking
- [ ] Interval awards (decay, taxation)
- [ ] Boss-kill awards
- [ ] Completion awards
- [ ] Weekly and hard caps
- [ ] Minimum GP thresholds

**Item Valuation:**
- [ ] Static item prices
- [ ] Ascending item valuation
- [ ] Per-slot min/max prices
- [ ] Per-item min/max prices
- [ ] Class-based award multipliers

**Data & Auditing:**
- [ ] Event-sourced operation history
- [ ] Point history auditing
- [ ] Time-travel corrections
- [ ] Loot history tracking
- [ ] XML/JSON export
- [ ] Tooltip price information

**Access Control:**
- [ ] Manager role definitions
- [ ] Assistant role definitions
- [ ] Access control enforcement

**Integrations:**
- [ ] Discord integration
- [ ] Gargul integration
- [ ] RCLootCouncil integration
- [ ] MonolithDKP migration
- [ ] EssentialDKP migration
- [ ] CommunityDKP migration
- [ ] BastionLoot migration
- [ ] CEPGP migration

### From GuildLadderDKP (HIGH PRIORITY)

**UI Components:**
- [ ] Live bid bars
- [ ] Bid popups
- [ ] Loot queue display
- [ ] Podium/leaderboard display

**Loot System:**
- [ ] Raid loot recording
- [ ] Live loot display
- [ ] Loot queue management
- [ ] Loot history

**Awards & Tracking:**
- [ ] Award and deduction tracking
- [ ] Award codes (MS, OS, offspec, etc.)
- [ ] Award color coding
- [ ] Multiple award types support

**Data:**
- [ ] BiS (Best-in-Slot) data storage
- [ ] BiS source information
- [ ] Raid statistics collection
- [ ] Player readiness status

**Features:**
- [ ] CLM import bridge
- [ ] DKP decay implementation
- [ ] Configurable award settings
- [ ] Slash commands (/gldkp, etc.)

### From SharpiesLootTracker (MEDIUM PRIORITY)

**Session Engine:**
- [ ] Session-based loot tracking
- [ ] Gold-per-hour calculation
- [ ] Session start/stop/pause
- [ ] Idle timer tracking
- [ ] AFK detection and pause

**Loot Categories:**
- [ ] All loot category
- [ ] Materials (Mats) category
- [ ] Gear category
- [ ] Junk category
- [ ] Other/misc category

**Pricing:**
- [ ] TSM price source integration
- [ ] Auctionator price integration
- [ ] Auctioneer price fallback
- [ ] Vendor price fallback
- [ ] Custom TSM price string support
- [ ] Stale price detection (Auctionator)

**Features:**
- [ ] Per-kill loot tracking
- [ ] Per-kill coin tracking
- [ ] Bag-space monitoring
- [ ] Full-bag alerts
- [ ] Big-drop threshold alerts
- [ ] Big-drop sound notifications
- [ ] Screen alert system
- [ ] Compact bar mode
- [ ] Full display mode

**Reporting:**
- [ ] Group reports
- [ ] Guild reports
- [ ] Raid reports
- [ ] Whisper reports
- [ ] Self reports

**Configuration:**
- [ ] Item ignore list
- [ ] Quest-item handling
- [ ] Disenchanting rules
- [ ] Prospecting rules
- [ ] Milling rules
- [ ] Clam opening rules
- [ ] Lockbox handling rules
- [ ] Vendor-cost inclusion option
- [ ] Quest-gold inclusion option
- [ ] Autostart option
- [ ] Idle timeout configuration
- [ ] Vendor-price floor setting
- [ ] Big-drop threshold setting

**Slash Commands:**
- [ ] /slt command variants
- [ ] /loottracker command variants
- [ ] Command help system

### From CommissionsForever (MEDIUM PRIORITY)

**Commission System:**
- [ ] Quest commission tracking
- [ ] Commission rewards
- [ ] Commission history
- [ ] Commission reporting

---

## InfinityRaid Suite

### From Details (HIGH PRIORITY)

**Combat Engine:**
- [ ] Real-time combat log parsing
- [ ] Damage calculations
- [ ] Healing calculations
- [ ] Threat calculations
- [ ] Resource tracking
- [ ] Death tracking
- [ ] Segment management

**Analysis Features:**
- [ ] Damage per second (DPS) calculation
- [ ] Healing per second (HPS) calculation
- [ ] Player/actor breakdowns
- [ ] Spell-level analysis
- [ ] Target-level analysis
- [ ] Timeline analysis

**Display Windows:**
- [ ] Multiple independent windows
- [ ] Current window view
- [ ] Overall view
- [ ] Segment view
- [ ] Encounter view
- [ ] Window positioning and sizing
- [ ] Window profiles

**Visual Features:**
- [ ] Graphs and charts
- [ ] Bar representations
- [ ] Encounter timeline visualization
- [ ] Boss phase tracking

**Customization:**
- [ ] Custom display framework
- [ ] Skin system
- [ ] Multiple skins
- [ ] Color customization
- [ ] Font selection
- [ ] Texture selection
- [ ] Bar/icon display options
- [ ] Data-type filtering

**Data Persistence:**
- [ ] Segment history storage
- [ ] Encounter data storage
- [ ] Profile persistence
- [ ] Configuration profiles

**Advanced Features:**
- [ ] Plugin system
- [ ] Plugin registration API
- [ ] Data broker support
- [ ] Tooltip framework
- [ ] Boss mechanics data
- [ ] Threat tracking
- [ ] Resource breakdown (mana, energy, etc.)

**API Layer:**
- [ ] Segment retrieval APIs
- [ ] Actor data APIs
- [ ] Combat data access APIs
- [ ] Window management APIs
- [ ] Custom display registration APIs
- [ ] Plugin registration APIs
- [ ] Callback system

### From HealBot (HIGH PRIORITY)

**Unit Frame System:**
- [ ] Raid frame rendering
- [ ] Party frame rendering
- [ ] Individual unit frames
- [ ] Group-based frame layout
- [ ] Raid-wide frame grouping

**Click-Casting:**
- [ ] Click-cast binding system
- [ ] Modifiers (shift, ctrl, alt)
- [ ] Bind spell to frame click
- [ ] Action execution on click

**Healing Features:**
- [ ] Heal prediction system
- [ ] Incoming heal communication (LibHealComm)
- [ ] Heal prediction bars
- [ ] Incoming heal display
- [ ] HoT (Heal over Time) tracking
- [ ] HoT indicators on frames
- [ ] Remaining duration display

**Aura & Debuff System:**
- [ ] Aura indicator display
- [ ] Debuff highlighting
- [ ] Combat aura indicators
- [ ] Aggro indicators
- [ ] Buff filtering
- [ ] Debuff filtering
- [ ] Dispel-able debuff highlighting

**Awareness Features:**
- [ ] Range checking
- [ ] Range indicators
- [ ] Line-of-sight (LoS) checking
- [ ] LoS indicators
- [ ] Range-based frame transparency
- [ ] Range-based frame coloring

**Display Elements:**
- [ ] Healing bars
- [ ] Status text
- [ ] Action icons
- [ ] Cooldown indicators
- [ ] Target indicators
- [ ] Focus indicators
- [ ] Assist indicators

**Skins & Layouts:**
- [ ] Skin engine
- [ ] Multiple skin options
- [ ] Extra skin packages
- [ ] Skin import/export
- [ ] Shared skin system
- [ ] Layout templates
- [ ] Custom layout support

**Configuration:**
- [ ] Frame layout options
- [ ] Frame grouping options
- [ ] Click-cast binding UI
- [ ] Spell/target actions UI
- [ ] Bar display options
- [ ] Text display options
- [ ] Icon display options
- [ ] Aura configuration
- [ ] HoT configuration
- [ ] Aggro configuration
- [ ] Debuff configuration
- [ ] Dispel settings
- [ ] Skin selection
- [ ] Profile management
- [ ] Tooltip behavior options
- [ ] Communication options
- [ ] Prediction options
- [ ] Font selection
- [ ] Color customization
- [ ] Texture selection

**Communication:**
- [ ] LibHealComm integration
- [ ] Incoming heal announcements
- [ ] Heal prediction sharing
- [ ] Communication channel selection

**Tips & Enhancements:**
- [ ] HealBot_Tips support
- [ ] Tooltip enhancements
- [ ] Extra skins support (HealBot_ExtraSkins)

---

## InfinityGuide Suite

### From Questie (HIGH PRIORITY)

**Quest Database:**
- [ ] Complete quest data storage
- [ ] Quest ID indexing
- [ ] Quest metadata (level, rewards, etc.)
- [ ] Quest objective data
- [ ] Quest prerequisite chains
- [ ] Quest reward tables

**Tracking System:**
- [ ] Available quests display
- [ ] Active quests display
- [ ] Completed quests display
- [ ] Quest objective tracking
- [ ] Objective completion detection
- [ ] Quest progress tracking

**Map Integration:**
- [ ] World map quest markers
- [ ] Quest icon rendering
- [ ] Quest objective icons
- [ ] Minimap quest markers
- [ ] Icon positioning system
- [ ] Icon filtering

**Routing & Guidance:**
- [ ] Quest routing calculation
- [ ] Objective routing
- [ ] Zone routing
- [ ] NPC location coordinates
- [ ] Objective location coordinates
- [ ] Distance calculation
- [ ] Waypoint generation

**Tooltips:**
- [ ] Quest tooltip display
- [ ] Quest information in tooltips
- [ ] Related quest linking
- [ ] Quest reward preview

**Public API:**
- [ ] OnReady callback registration
- [ ] Quest update callback registration
- [ ] Quest icon query API
- [ ] Quest objective unit query API
- [ ] Callback propagation system

**Features:**
- [ ] Quest chain visualization
- [ ] Quest prerequisite display
- [ ] Related quest suggestions
- [ ] Zone-specific quest filtering

**QuestieDB Module:**
- [ ] Quest data loading
- [ ] Expansion-specific data
- [ ] Data versioning
- [ ] Localization data

**QuestieTrace Module:**
- [ ] Debug tracing support
- [ ] Profiling support
- [ ] Diagnostic output

**Configuration:**
- [ ] Quest icon visibility toggle
- [ ] Map/minimap display toggle
- [ ] Objective tracking toggle
- [ ] Quest-level filtering
- [ ] Completed quest visibility
- [ ] Available quest visibility
- [ ] Debug mode toggle
- [ ] Database update behavior

### From ForeverDungeonJournal (HIGH PRIORITY)

**Dungeon Data:**
- [ ] Dungeon/raid listing
- [ ] Dungeon-specific loot tables
- [ ] Boss information storage
- [ ] Boss mechanics data
- [ ] Encounter difficulty levels

**Boss Information:**
- [ ] Boss name and lore
- [ ] Boss health/stats
- [ ] Boss ability descriptions
- [ ] Mechanic phase tracking
- [ ] Difficulty scaling

**Loot System:**
- [ ] Item drop tables
- [ ] Item slot assignment
- [ ] Item rarity categorization
- [ ] Item class filtering
- [ ] Item level calculation

**UI Display:**
- [ ] Journal window
- [ ] Dungeon selection view
- [ ] Boss encounter view
- [ ] Loot list display
- [ ] Mechanic display

**Features:**
- [ ] Search functionality
- [ ] Filtering options
- [ ] Sorting options
- [ ] Export loot lists
- [ ] Copy-to-clipboard functionality

### From FieldGuideForever (MEDIUM PRIORITY)

**Reference Data:**
- [ ] Zone information
- [ ] Location coordinates
- [ ] NPC spawn locations
- [ ] Quest hub locations
- [ ] Vendor locations
- [ ] Trainer locations

**Loot Tables:**
- [ ] Creature drop tables
- [ ] Quest reward tables
- [ ] Vendor inventory tables
- [ ] Faction reward tables

**Spawn Information:**
- [ ] Respawn timers
- [ ] Multiple spawn locations
- [ ] Rarity/frequency data
- [ ] Related creatures/NPCs

**UI Display:**
- [ ] Field guide window
- [ ] Category browsing
- [ ] Search functionality
- [ ] Location map integration
- [ ] Coordinate display

### From AdventureGuideForever (HIGH PRIORITY)

**Story Data:**
- [ ] Story progression tracking
- [ ] Story phase information
- [ ] Lore integration

**Zone Guides:**
- [ ] Zone progression order
- [ ] Recommended level ranges
- [ ] Zone connections/routes
- [ ] Important locations per zone
- [ ] Zone events

**Objective Tracking:**
- [ ] Story objective tracking
- [ ] Zone objective tracking
- [ ] Achievement objectives
- [ ] Milestone tracking

**Features:**
- [ ] Adventure path display
- [ ] Completion tracking
- [ ] Skip/resume options
- [ ] Suggested progression

---

## InfinityGather Suite

### From GatherMate2 (HIGH PRIORITY)

**Node Database:**
- [ ] Herb node storage
- [ ] Ore node storage
- [ ] Treasure node storage
- [ ] Fishing node storage
- [ ] Other gathering node types
- [ ] Node coordinate storage
- [ ] Node rarity/frequency data

**Node Display:**
- [ ] World map node markers
- [ ] Minimap node markers
- [ ] Node icon rendering
- [ ] Node distance calculation
- [ ] Distance-based filtering

**Filtering System:**
- [ ] Filter by profession
- [ ] Filter by resource type
- [ ] Filter by expansion
- [ ] Filter by zone
- [ ] Filter by level requirement
- [ ] Multiple filter combination

**Collection:**
- [ ] Collect nodes from gameplay
- [ ] User-added node database
- [ ] Node deduplication
- [ ] Node accuracy management

**Data Management:**
- [ ] Database persistence
- [ ] Database cleanup
- [ ] Database compaction
- [ ] Data import/export
- [ ] Backup creation
- [ ] Version management

**Storage Modules:**
- [ ] GatherMate2Storage_Dragonflight data
- [ ] GatherMate2Storage_Midnight data
- [ ] GatherMate2Storage_TheWarWithin data
- [ ] GatherMate2_Data core data
- [ ] Data update mechanism

**Configuration:**
- [ ] Display on/off toggle
- [ ] Distance threshold setting
- [ ] Minimap/worldmap toggle
- [ ] Node type visibility
- [ ] Filter presets

### From GatherPathForever (MEDIUM PRIORITY)

**Pathfinding Engine:**
- [ ] Route calculation algorithm
- [ ] Waypoint generation
- [ ] Distance optimization
- [ ] Circular routes
- [ ] Zone-to-zone routing

**Optimization:**
- [ ] TSP (Traveling Salesman) solver
- [ ] Nearest-neighbor calculation
- [ ] Route visualization
- [ ] Distance calculation
- [ ] Time estimation

**Features:**
- [ ] Saved routes
- [ ] Route sharing
- [ ] Auto-pathing
- [ ] GPS/navigation UI
- [ ] Waypoint markers

**Configuration:**
- [ ] Route difficulty (simple/medium/advanced)
- [ ] Distance tolerance
- [ ] Waypoint density
- [ ] Export route format

---

## InfinityGear Suite

### From Attune (HIGH PRIORITY)

**Tracking System:**
- [ ] Attunement status per character
- [ ] Multiple attunement types
- [ ] Attunement expiry tracking
- [ ] Attunement queue/chains
- [ ] Cross-character attunement sync

**Data Storage:**
- [ ] Character attunement data
- [ ] Guild-wide attunement status
- [ ] Attunement timeline/history
- [ ] Attunement completion tracking

**UI Display:**
- [ ] Attunement status window
- [ ] Per-character view
- [ ] Per-raid view
- [ ] Missing attunement highlighting
- [ ] Attunement progress bars

**Features:**
- [ ] Reminder system
- [ ] Completion notifications
- [ ] Group readiness check
- [ ] Attunement shortfall alerts
- [ ] Suggested attunement quests

**Integration:**
- [ ] Guild calendar integration
- [ ] Raid planning integration
- [ ] Chat notifications
- [ ] Tooltip information

---

## InfinityQoL Suite

### From TweaksForever (MEDIUM PRIORITY)

**QoL Features (each is a module):**
- [ ] Individual tweak modules
- [ ] Enable/disable per tweak
- [ ] Persistent configuration
- [ ] Slash commands for tweaks

[Note: Individual tweaks not yet documented - requires detailed source review]

### From MacroAssistForever (MEDIUM PRIORITY)

**Macro System:**
- [ ] Macro generation engine
- [ ] Macro template library
- [ ] Macro storage and management
- [ ] Macro execution helpers
- [ ] Macro suggestions based on spec

**Features:**
- [ ] Generate macros from templates
- [ ] Class-specific macros
- [ ] Spec-specific macros
- [ ] Common utility macros
- [ ] Custom macro creation
- [ ] Macro sharing
- [ ] Macro import/export

**UI:**
- [ ] Macro assistant window
- [ ] Suggestion display
- [ ] Template selection
- [ ] Generated macro preview
- [ ] Clipboard copy

---

## Cross-Cutting Concerns

### Missing from All Suites

**Public API:**
- [ ] Documented API for each suite
- [ ] API version compatibility
- [ ] Callback registration system
- [ ] Event broadcast system

**Data Exchange:**
- [ ] Cross-suite communication protocol
- [ ] Shared data formats
- [ ] Cache invalidation
- [ ] Sync mechanisms

**Documentation:**
- [ ] API documentation (like Details and Questie)
- [ ] Configuration guide
- [ ] Integration guide
- [ ] Developer documentation

**Testing:**
- [ ] Unit tests
- [ ] Integration tests
- [ ] Performance benchmarks

**Error Handling:**
- [ ] Consistent error codes
- [ ] Error logging
- [ ] User-facing error messages
- [ ] Recovery mechanisms

---

Generated: 2026-11-20 17:28:00
