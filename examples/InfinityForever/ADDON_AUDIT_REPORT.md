# InfinityForever Priority Addon Audit

**Scope:** `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\InfinityForever`  
**Comparison:** `src\` source addons versus `sink\` InfinityForever suites.  
**Important finding:** The sink is currently a consolidation scaffold. It contains suite/module names and partial abstractions, but does not contain the source addon implementations or their complete APIs.

## Sink mapping

| Source suites | Sink target |
|---|---|
| ClassicLootManager, SharpiesLootTracker, CommissionsForever | `sink\InfinityLoot` |
| GuildLadderDKP | `sink\InfinityGuild` |
| Details, HealBot | `sink\InfinityRaid` |
| Questie, QuestieDB, QuestieTrace, ForeverDungeonJournal, FieldGuideForever, AdventureGuideForever | `sink\InfinityGuide` |
| GatherMate2, GatherPathForever | `sink\InfinityGather` |
| Attune | `sink\InfinityGear` |
| TweaksForever, MacroAssistForever | `sink\InfinityQoL` |

The intended mappings are documented in `sink\SUITE_ARCHITECTURE.md`, especially the consolidation sections around lines 31–94.

---

# 1. ClassicLootManager

**Category:** Advanced loot distribution  
**Source:** `src\ClassicLootManager\`  
**Sink:** `sink\InfinityLoot\`

### Core functionality and features

Source README identifies a full DKP/EPGP loot-management system:

- DKP, EPGP, SK and Zero-Sum Bank point systems.
- Automatic guild and cross-guild synchronization.
- Multiple rosters/teams.
- Loot auctions and simultaneous multi-item auctions.
- Open, closed, Vickrey, anonymous and tiered bidding.
- Anti-snipe protection and configurable bid increments.
- Static and ascending item valuation.
- Per-slot/per-item min/max prices.
- Class-based award multipliers.
- Raid attendance, interval, boss-kill and completion awards.
- Point decay, taxation, weekly/hard caps and minimum GP.
- Main/alt linking and profile locking.
- Access-control roles for managers and assistants.
- Loot history, point history and auditing.
- Time-travel corrections.
- Tooltip price information.
- Migration from MonolithDKP, EssentialDKP, CommunityDKP, BastionLoot and CEPGP.
- Discord, Gargul and RCLootCouncil integrations.
- XML/JSON export.

Source documentation: `src\ClassicLootManager\README.md`.

### Public API/functions

Main source files expose utility and addon functions including:

- `UTILS.GetNumClasses()`
- `UTILS.GetClassList()`
- `UTILS.GetServer(name)`
- `UTILS.whoamiGUID()`
- `UTILS.mergeLists(t1, t2, t)`
- `UTILS.round(number, decimals)`
- `UTILS.SendChatMessage(message, channel, target)`
- `UTILS.IsGroupLootMethod()`
- `StorageQualifiedObject:New(storage)`

The implementation also exposes event, auction, storage, roster, profile, synchronization and UI functions across the CLM modules.

### Data structures

- Event-sourced operation/history records.
- Player profiles and roster tables.
- DKP/EPGP point ledgers.
- Auction and bid records.
- Raid/attendance records.
- Item-price and item-award records.
- Configuration/profile tables.
- SavedVariables and serialized synchronization payloads.

### Configuration

- Point-system type and award rules.
- Decay, caps, taxation and inflation.
- Auction mode and bid increments.
- Item/slot min/max prices.
- Anti-snipe duration.
- Announcements and bid channels.
- Access roles and profile locking.
- Raid-award values.
- Integrations and exports.

### Missing from sink

`InfinityLoot` has `LootManager.lua`, `Tracking.lua`, `Commissions.lua` and `Economy.lua`, but the following source functionality is not represented as a complete implementation:

- EPGP/SK/Zero-Sum point engines.
- Multi-roster support.
- Event-sourced audit/history model.
- Auction modes and bid handling.
- Anti-snipe and tiered pricing.
- Raid attendance and automated awards.
- Access control and profile locking.
- Main/alt linking.
- CLM migration tools.
- Discord/Gargul/RCLootCouncil integrations.
- XML/JSON export.
- CLM synchronization protocol.

**Priority:** HIGH

---

# 2. GuildLadderDKP

**Category:** Guild DKP management  
**Source:** `src\GuildLadderDKP\`  
**Sink:** `sink\InfinityGuild\`

### Core functionality and features

- Guild DKP ledger.
- Loot queue and live loot display.
- Bid bars and bid popups.
- Raid loot recording.
- Award and deduction tracking.
- Podium/leaderboard display.
- Player readiness and roster status.
- Best-in-slot data and source information.
- Raid statistics.
- CLM import bridge.
- DKP decay and configurable award settings.

Source files include `Core.lua`, `Config.lua`, `Loot.lua`, `Podium.lua`, `Readiness.lua`, `Stats.lua`, `UI.lua` and BiS data modules.

### Public API/functions

Examples found in source:

- `D.ShowMenu(anchor, title, items)`
- `D.AskImportCLM()`
- `D.RefreshDock()`
- `D.HideBidBar(aid)`
- `D.HideBidPopup(aid)`
- `D.ShowRaidLoot(zone, auto)`
- `D.ToggleGems(show)`
- `D.RefreshLive()`
- `D.InitUI()`
- `D.PodiumAwardName(code)`
- `D.AwardKind(code)`
- `D.AwardColor(code)`
- `S.Cur()`
- `S.MyRecord()`
- `S.Finish()`
- `S.Redo()`
- `D.ShowPodiumAwardTip(owner, name)`
- `D.PodiumSlash(rest)`

### Data structures

- `GuildLadderDKPDB`.
- DKP ledger and transaction records.
- Loot queue and auction records.
- Bid/award records.
- Raid and player statistics.
- BiS item/source tables.
- Readiness and roster tables.
- Award-code lookup tables.

### Configuration

- DKP decay.
- Award values and award types.
- Loot and bid UI.
- Gem display.
- Raid/zone filters.
- Podium/statistics presentation.
- CLM import behavior.

### Missing from sink

`InfinityGuild` has roster, DKP and event modules, but lacks evidence of:

- Live bid bars/popups.
- Loot queue and auction workflow.
- Podium awards and historical statistics.
- BiS data and readiness display.
- CLM import.
- Full DKP transaction semantics.
- Source’s slash-command and UI behavior.

**Priority:** HIGH

---

# 3. SharpiesLootTracker

**Category:** Loot tracking and farming economics  
**Source:** `src\SharpiesLootTracker\`  
**Sink:** `sink\InfinityLoot`

### Core functionality and features

From `src\SharpiesLootTracker\README.md`:

- Session-based loot tracking.
- Gold-per-hour calculation.
- All/Mats/Gear/Junk/Other tabs.
- TSM, Auctionator, Auctioneer and vendor pricing.
- Vendor cost deduction.
- Idle and AFK timer pause.
- Bag-space monitoring and full-bag alert.
- Big-drop sound and screen alert.
- Per-kill loot and coin tracking.
- Compact bar mode.
- Group/guild/raid/whisper/self reports.
- Item ignore list.
- Quest-item handling.
- Disenchanting, prospecting, milling, clam and lockbox handling.
- Slash commands under `/slt` and `/loottracker`.

### Public API/functions

The addon is primarily event/UI driven. Main public surfaces include command handlers and tracker/session functions in:

- `Core.lua`
- `Tracker.lua`
- `Pricing.lua`
- `Categories.lua`
- `UI.lua`

The source does not present a formal documented external API comparable to Questie or Details.

### Data structures

- `SharpiesLootTrackerCharDB`.
- Current session state.
- Per-item loot records.
- Category totals.
- Price-source metadata.
- Ignored-item table.
- Kill/loot timestamps.
- Bag-space and expenditure counters.

### Configuration

- Price source.
- Custom TSM price string.
- Vendor-price floor.
- Quest-gold inclusion.
- Autostart.
- Idle timeout.
- Vendor-cost inclusion.
- Big-drop threshold.
- Auctionator stale-price threshold.
- Quest-item policy.
- Ignore list.
- Compact/full display mode.

### Missing from sink

`InfinityLoot\Modules\Tracking.lua` is only a generic tracking placeholder compared with the source:

- Gold-per-hour session engine.
- Idle/AFK pause behavior.
- Price-source fallback chain.
- Per-kill metrics.
- Bag forecast.
- Compact bar.
- Reports.
- Ignore list.
- Big-drop alerts.
- Full `/slt` command compatibility.
- Item-processing rules.

**Priority:** MEDIUM

---

# 4. Details

**Category:** DPS meters and combat analytics  
**Source:** `src\Details\`  
**Sink:** `sink\InfinityRaid`

### Core functionality and features

- Real-time combat logging.
- Damage, healing, threat, deaths and resource analysis.
- Multiple independently configurable windows.
- Current, overall, segment and encounter views.
- Player/actor breakdowns.
- Spell, target, source and timeline analysis.
- Graphs and charts.
- Custom displays.
- Encounter and boss analysis.
- Data persistence and segment history.
- Plugins, skins, tooltips and data broker support.
- Extensive API and UI framework.

The source contains dedicated API documentation such as `src\Details\API.txt`, `API General.txt`, `API UI.txt` and `API Custom Displays.txt`.

### Public API/functions

Examples include:

- `Details:GetTextureAtlas(atlasName)`
- Startup and profile/window APIs in `startup.lua`.
- Segment and actor retrieval APIs.
- Custom display registration APIs.
- Plugin registration APIs.
- Combat data access APIs.
- UI/window management APIs.

`Details` has a substantially larger public API than can be safely reduced to a few functions; the authoritative API is in the source API text files.

### Data structures

- Combat segments.
- Actor/container tables.
- Spell, target and damage-type subtables.
- Window and display instances.
- Profiles and saved settings.
- Encounter/timeline records.
- Plugin and skin registries.
- Custom display definitions.

### Configuration

- Window count, size and layout.
- Display modes and data types.
- Segment retention.
- Update frequency.
- Colors, fonts, textures and skins.
- Profiles.
- Graph/chart settings.
- Plugins and custom displays.
- Encounter tracking.

### Missing from sink

`InfinityRaid` currently provides encounter, alert, assignment and healing-oriented modules, but no equivalent of:

- Combat-log parser.
- Damage/healing actor model.
- Segment management.
- Breakdown windows.
- Graphs/charts.
- Custom displays.
- Details plugin API.
- Profile and skin system.
- Details slash commands and broker integration.

**Priority:** HIGH

---

# 5. HealBot and sub-addons

**Category:** Healer functionality  
**Source:** `src\HealBot\`, `src\HealBot_ExtraSkins\`, `src\HealBot_Tips\`  
**Sink:** `sink\InfinityRaid`

### Core functionality and features

- Raid/party healing unit frames.
- Click-casting.
- Heal prediction and incoming-heal communication.
- HoT, aura, aggro and combat-aura indicators.
- Range and line-of-sight awareness.
- Dispel/debuff highlighting.
- Action icons and cooldown indicators.
- Healing bars and status text.
- Target, focus and assist controls.
- Skin and layout management.
- Shared skin import/export.
- LibHealComm communications.
- Tooltip enhancements.
- Extra skin packages.

### Public API/functions

The source is largely global/table based and exposes HealBot-specific frame, action, skin, communication, tooltip, timer and update functions across:

- `HealBot.lua`
- `HealBot_Action.lua`
- `HealBot_Events.lua`
- `HealBot_Skins.lua`
- `HealBot_Options.lua`
- `HealBot_Share.lua`
- `HealBot_Tooltip.lua`

There is no small stable public API comparable to Questie’s documented API.

### Data structures

- HealBot configuration and per-character saved variables.
- Unit-frame tables.
- Skin/layout tables.
- Spell/action bindings.
- Aura and debuff state.
- Incoming-heal communication records.
- Timer and cooldown tables.
- Shared skin serialization data.

### Configuration

- Frame layout and grouping.
- Click-cast bindings.
- Spell/target actions.
- Bars, text and icons.
- Range/visibility behavior.
- Auras, HoTs, aggro and debuffs.
- Dispel settings.
- Skins and profiles.
- Tooltip behavior.
- Communications and prediction.
- Fonts, colors and textures.

### Missing from sink

`InfinityRaid\Modules\HealingManager.lua` is not a HealBot replacement. Missing:

- Unit-frame system.
- Click-casting.
- Incoming-heal prediction.
- LibHealComm compatibility.
- Aura/debuff/HoT indicators.
- Skin engine and extra skins.
- HealBot share/import/export.
- Action icons and cooldown display.
- HealBot tips/tooltips.
- Extensive healer configuration UI.

**Priority:** HIGH

---

# 6. Questie, QuestieDB and QuestieTrace

**Category:** Quest tracking  
**Source:** `src\Questie\`, `src\QuestieDB\`, `src\QuestieTrace\`  
**Sink:** `sink\InfinityGuide`

### Core functionality and features

- Quest database.
- Quest objectives and progress tracking.
- Map and minimap quest icons.
- Quest chains and prerequisites.
- Available, active and completed quest states.
- Quest tooltips.
- Quest levels, rewards and coordinates.
- Quest routing and objective guidance.
- Debug/profiling/tracing support.
- Public callback registration for quest updates and addon readiness.

### Public API/functions

Documented source functions include:

- `Questie:OnInitialize()`
- `Questie:OnEnable()`
- `Questie:OnDisable()`
- `Questie:RefreshConfig(event, database, profileName)`
- `Questie:Colorize(str, color)`
- `Questie:ColorizeRGB(color)`
- `Questie:GetClassColor(class)`
- `Questie.Error(...)`
- `Questie.Warning(...)`
- `Questie.Debug(level, ...)`
- `Questie.SetIcons()`
- `Questie:GetIconNameFromPath(path)`
- `Questie.API.RegisterOnReady(callback)`
- `Questie.API.RegisterForQuestUpdates(callback)`
- `Questie.API.GetQuestObjectiveIconForUnit(guid)`
- `QuestieAPI.PropagateOnReady()`
- `QuestieAPI.PropagateQuestUpdate(questId, objectiveIndices, triggerReason)`

### Data structures

- Quest database indexed by quest ID.
- Objective and prerequisite tables.
- Quest-chain relationships.
- NPC/objective coordinate tables.
- Reward and faction data.
- Active/completed quest state.
- Icon and map-marker registries.
- Callback lists.

### Configuration

- Quest icon visibility.
- Map/minimap display.
- Objective tracking.
- Quest-level filtering.
- Completed/available quest visibility.
- Debug/profiling.
- Localization and database version behavior.

### Missing from sink

`InfinityGuide` has `QuestTracker.lua`, `Quests.lua` and `ZoneGuide.lua`, but lacks the source database and complete behavior:

- QuestieDB data.
- Quest-chain/prerequisite graph.
- Objective/NPC coordinate data.
- Map/minimap icon engine.
- Questie public callback API.
- Quest tooltip integration.
- QuestieTrace diagnostics.
- Versioned expansion data.

**Priority:** HIGH

---

# 7. GatherMate2

**Category:** Advanced gathering database  
**Source:** `src\GatherMate2\`  
**Sink:** `sink\InfinityGather`

### Core functionality and features

- Collection of herb, ore, treasure, fishing and other gathering nodes.
- Node display on world map and minimap.
- Node import/storage modules.
- Per-expansion gathering data.
- Node filtering by profession/type.
- Node collection from gameplay.
- Distance and display controls.
- Database cleanup and configuration.

### Public API/functions

Main modules include:

- `GatherMate2.lua`
- `Collector.lua`
- `Display.lua`
- `Config.lua`
- `LoadAddonStorage.lua`

The addon uses a central GatherMate database and display/collector APIs rather than a concise documented external API.

### Data structures

- `GatherMate2DB`.
- Node tables indexed by map/zone and resource type.
- Coordinate/metadata records.
- Display/filter settings.
- Storage/import tables.
- Collection timestamps and source data.

### Configuration

- Node types.
- Map/minimap visibility.
- Resource filters.
- Icon size/transparency.
- Database import and cleanup.
- Collection behavior.
- Per-zone/per-profession display settings.

### Missing from sink

`InfinityGather` has database, node, route and skill modules, but lacks:

- Full GatherMate node database.
- Storage addon compatibility.
- Node collector behavior.
- Map/minimap rendering parity.
- Import/export/cleanup.
- Resource-type filtering.
- GatherMate-compatible APIs.

**Priority:** HIGH

---

# 8. GatherPathForever

**Category:** Optimized gathering routes  
**Source:** `src\GatherPathForever\`  
**Sink:** `sink\InfinityGather`

### Core functionality and features

- Shortest/optimized route through GatherMate herb and ore nodes.
- World-map and minimap route lines.
- Route refresh and optimization.
- Minimap button.
- Route visibility toggle.
- `/gpf hide` and `/gpf show`.
- Theme and display options.

Source TOC states the core purpose directly: draw the shortest gathering route through GatherMate nodes.

### Public API/functions

Main functionality is contained in:

- `Core.lua`
- `Optimize.lua`
- `Options.lua`
- `Theme.lua`

The source is primarily internal/event/UI driven.

### Data structures

- `GatherPathForeverDB`.
- Zone/node route arrays.
- Optimized path results.
- Map and minimap line objects.
- Display/theme settings.

### Configuration

- Route visibility.
- Node/resource selection.
- Line appearance and theme.
- Minimap button.
- Route optimization behavior.
- Hide/show state.

### Missing from sink

`InfinityGather\Modules\RouteOptimizer.lua` is only a conceptual replacement unless it includes:

- GatherMate node ingestion.
- Route graph/optimization implementation.
- World-map and minimap line rendering.
- `/gpf` command compatibility.
- Route persistence and display settings.
- Theme implementation.

**Priority:** MEDIUM

---

# 9. Attune

**Category:** Attunement and dungeon quest tracking  
**Source:** `src\Attune\`  
**Sink:** `sink\InfinityGear`

### Core functionality and features

- Raid attunement tracking.
- Dungeon attunement quest progress.
- Class-specific quest chains.
- Quest-giver and quest-reward information.
- Attunement tree UI.
- Completion/progress state.
- Expand/collapse tree state.
- Forever-specific dungeon and quest data.
- Minimap/data-broker access.

The TOC notes: “Track raid attunements and dungeon quest progress.”

### Public API/functions

The addon is principally UI/data driven. Key implementation is in:

- `Attune.lua`
- `AttuneClassQuests.lua`
- `AttuneData.lua`
- `AttuneQuestGivers.lua`
- `AttuneQuestRewards.lua`

### Data structures

- `Attune_DB`.
- `AttuneLastViewed`.
- `TreeExpandStatus`.
- Quest-chain and prerequisite tables.
- Quest-giver coordinates.
- Static item/spell reward data.
- Raid/dungeon attunement definitions.

### Configuration

- Selected attunement/raid.
- Tree expansion.
- Character/progress display.
- Quest completion tracking.
- Minimap/data-broker visibility.

### Missing from sink

`InfinityGear\Modules\ProgressionTracker.lua` does not demonstrate:

- Attunement-specific database.
- Attunement tree UI.
- Class quest data.
- Quest-giver/reward lookup.
- Raid/dungeon chain logic.
- Attune SavedVariables compatibility.

**Priority:** HIGH

---

# 10. CommissionsForever

**Category:** Quest/profession commission tracking  
**Source:** `src\CommissionsForever\`  
**Sink:** `sink\InfinityLoot\`

### Core functionality and features

- Professions-window commission page.
- Active commission tracking.
- Commission turn-in route.
- Integration with Shortest Path Forever.
- ForeverCore integration.
- Commission status and route presentation.

The README documents `/commissions` and “Open turn-in route.”

### Public API/functions

The source uses the ForeverCore host/ready/run model:

- `ForeverCoreHost.lua`
- `ForeverCoreReady.lua`
- `ForeverCoreRun.lua`

Public behavior is primarily addon-compartment and UI integration rather than a broad standalone API.

### Data structures

- Commission records.
- Active/pending turn-in list.
- Profession and recipe metadata.
- Route stops.
- Character SavedVariables.

### Configuration

- Commission page behavior.
- Route-opening behavior.
- Profession/commission filters.
- Shortest Path integration.

### Missing from sink

`InfinityLoot\Modules\Commissions.lua` lacks demonstrated parity for:

- Professions UI integration.
- Active commission scanning.
- Turn-in route generation.
- Shortest Path integration.
- Commission status data.
- `/commissions` behavior.
- ForeverCore compatibility.

**Priority:** MEDIUM

---

# 11. TweaksForever

**Category:** Quality of life  
**Source:** `src\TweaksForever\`  
**Sink:** `sink\InfinityQoL`

### Core functionality and features

TOC notes identify:

- Quest auto-accept.
- Quest auto-turn-in.
- Polestar-compatible quest standing-down.
- Naming nearby rares.
- Repairing at merchants.
- Selling junk at merchants.
- Merchant automation.
- Optional Questie, QuestieDB, Mapster, Titan and Shortest Path integrations.

### Public API/functions

Implemented through:

- `ForeverCoreHost.lua`
- `ForeverCoreReady.lua`
- `ForeverCoreRun.lua`

Features are event/option handlers rather than a documented public API.

### Data structures

- `TweaksForeverDB`.
- `TweaksForeverCharDB`.
- Quest automation settings.
- Merchant settings.
- Rare-name/highlight settings.
- Integration state.

### Configuration

- Auto-accept and auto-turn-in.
- Polestar behavior.
- Rare naming.
- Auto-repair.
- Auto-sell junk.
- Merchant exclusions.
- Integration toggles.
- Character/profile settings.

### Missing from sink

`InfinityQoL\Modules\Tweaks.lua` and `AutomationTools.lua` do not demonstrate:

- Quest automation implementation.
- Polestar handling.
- Rare naming.
- Merchant repair/sell automation.
- SavedVariables compatibility.
- Questie/QuestieDB/Mapster/Titan integrations.
- Addon-compartment behavior.

**Priority:** MEDIUM

---

# 12. MacroAssistForever

**Category:** Macro assistance  
**Source:** `src\MacroAssistForever\`  
**Sink:** `sink\InfinityQoL`

### Core functionality and features

TOC/README identify:

- Macro list and editor.
- Completion suggestions.
- Live macro validation/checks.
- Macro shortening/rewriting.
- Recipe/class-aware macro assistance.
- Bundled monospace font.
- Addon-compartment integration.

### Public API/functions

The source is structured through:

- `ForeverCoreHost.lua`
- `ForeverCoreReady.lua`
- `ForeverCoreRun.lua`

No small formal external API is documented.

### Data structures

- `MacroAssistForeverDB`.
- Macro text and parsed lines.
- Completion candidates.
- Validation errors/warnings.
- Recipe/class capability tables.
- Editor state.

### Configuration

- Editor appearance.
- Completion behavior.
- Validation options.
- Macro shortening.
- Font and UI settings.
- Saved macro profiles.

### Missing from sink

`InfinityQoL\Modules\MacroHelper.lua` and `Macros.lua` lack demonstrated:

- Macro parser/editor.
- Live validation.
- Completion engine.
- Macro shortening.
- Recipe-aware suggestions.
- Macro list UI.
- SavedVariables compatibility.
- Addon-compartment integration.

**Priority:** MEDIUM

---

# 13. ForeverDungeonJournal

**Category:** Dungeon information  
**Source:** `src\ForeverDungeonJournal\`  
**Sink:** `sink\InfinityGuide`

### Core functionality and features

- Dungeon and boss journal.
- Boss abilities and encounter information.
- Loot pages.
- Quest information.
- Dungeon list and filtering.
- Forever-specific dungeon support.
- Dungeon/quest tracker wing.
- Compact/detailed loot presentation.
- Walk/route integration.
- Addon-compartment controls.

README and source documents describe dungeon loot, boss levels, quest chains, dungeon filtering and Forever-only options.

### Public API/functions

The TOC exposes addon-compartment functions:

- `ForeverDungeonJournal_OnAddonCompartmentClick`
- `ForeverDungeonJournal_OnAddonCompartmentEnter`
- `ForeverDungeonJournal_OnAddonCompartmentLeave`

Additional UI, dungeon, boss, loot and tracker functions are internal.

### Data structures

- `ForeverDungeonJournalDB`.
- `ForeverDungeonJournalCharacterDB`.
- Dungeon/boss tables.
- Loot tables.
- Quest and attunement links.
- WalkNet route data.
- Dungeon filters and UI state.

### Configuration

- Dungeon list filtering.
- “Forever Dungeons Only.”
- Compact/detailed loot display.
- Tracker wing.
- Route/walk integration.
- UI layout and remembered selections.

### Missing from sink

`InfinityGuide\Modules\Guides.lua`, `LootDatabase.lua` and `ZoneGuide.lua` do not demonstrate:

- Dungeon/boss database.
- Loot pages.
- Boss levels/abilities.
- Quest-linked dungeon data.
- WalkNet integration.
- Dungeon filters.
- Addon-compartment API.
- Character/database persistence.

**Priority:** HIGH

---

# 14. FieldGuideForever

**Category:** Field guide and interface information  
**Source:** `src\FieldGuideForever\`  
**Sink:** `sink\InfinityGuide`

### Core functionality and features

- In-game field-guide/book interface.
- Quest and game-information lookup.
- Questie/QuestieDB integration.
- ForeverCore integration.
- Field-guide navigation and data presentation.
- Addon-compartment/interface integration.

### Public API/functions

Implemented through:

- `ForeverCoreHost.lua`
- `ForeverCoreReady.lua`
- `ForeverCoreRun.lua`

No large separately documented external API was found.

### Data structures

- Field-guide content tables.
- Quest/NPC/item references.
- `FieldGuideForever` SavedVariables/state.
- Navigation and selected-entry state.

### Configuration

- Guide display and navigation.
- Questie/QuestieDB integration.
- UI visibility and saved state.
- Addon-compartment behavior.

### Missing from sink

`InfinityGuide` has no clearly identifiable FieldGuide-specific module. Missing:

- Field-guide UI.
- Guide content/index.
- QuestieDB integration.
- Entry navigation/search.
- FieldGuide-specific configuration.
- Addon-compartment behavior.

**Priority:** MEDIUM

---

# 15. AdventureGuideForever

**Category:** Adventure guide and quest routing  
**Source:** `src\AdventureGuideForever\`  
**Sink:** `sink\InfinityGuide`

### Core functionality and features

TOC notes:

- Zone stories presented as chapters.
- Map-selected journeys.
- Routing to quest hand-ins.
- Quest and zone progression.
- Integration with Questie, QuestieDB, AtlasLootClassic, ShortestPathForever, SkillUpForever, LegacyForever and TweaksForever.
- Character-specific saved state.
- Addon-compartment support.

### Public API/functions

Implemented through:

- `ForeverCoreHost.lua`
- `ForeverCoreReady.lua`
- `ForeverCoreRun.lua`

The main public behavior is UI, map and integration driven.

### Data structures

- `AdventureGuideForeverCharDB`.
- Zone/chapter tables.
- Quest journey sequences.
- Map objectives.
- Route/hand-in stops.
- Integration metadata.

### Configuration

- Zone/chapter selection.
- Journey selection.
- Map display.
- Route/hand-in behavior.
- Optional integration toggles.
- Character progress state.

### Missing from sink

`InfinityGuide` lacks a dedicated Adventure Guide module and therefore likely lacks:

- Zone-story chapters.
- Map journey selection.
- Quest route generation.
- Hand-in routing.
- Questie/QuestieDB integration.
- Shortest Path integration.
- Character journey persistence.
- Addon-compartment API.

**Priority:** HIGH

---

# Cross-cutting code quality findings

## Source-side issues

Potential maintenance risks across the source addons:

- Heavy use of global tables and legacy addon-global namespaces.
- Large event/UI modules with mixed responsibilities.
- Expansion-specific conditional branches.
- Vendor libraries and compatibility shims complicate static analysis.
- Some files contain compatibility stubs and API emulation, especially Details.
- SavedVariables schemas are addon-specific and cannot be merged without migration.
- Several addons rely on implicit load order through TOC files.
- Public APIs are inconsistently documented.
- UI and data logic are frequently coupled.
- Large static databases increase memory and load-time pressure.
- Sub-addons use weak or implicit integration contracts.
- Legacy WoW APIs and modern compatibility code coexist.

## Sink-side issues

The sink has more serious parity risks:

- Many modules are structural placeholders rather than ports.
- Suite names do not guarantee source feature coverage.
- No visible migration/versioning layer for source SavedVariables.
- No documented compatibility layer for source APIs.
- Core event routing can create behavioral differences from source addons.
- Consolidation may remove source-specific slash commands.
- Shared tables risk namespace collisions unless all modules are strictly local.
- Generic modules such as `Tracking.lua`, `QuestTracker.lua` and `ProgressionTracker.lua` are too broad to preserve source semantics.
- No evidence of automated feature/parity tests.
- No evidence of source data-import tooling for Questie, GatherMate2, Attune or dungeon databases.
- UI consolidation risks losing specialized controls and configuration options.

## Recommended implementation order

1. **HIGH:** ClassicLootManager, Details, HealBot, Questie/QuestieDB, GatherMate2, Attune, ForeverDungeonJournal, AdventureGuideForever.
2. **MEDIUM:** SharpiesLootTracker, GatherPathForever, CommissionsForever, TweaksForever, MacroAssistForever, FieldGuideForever.
3. **LOW:** None of the 15 can be considered safely complete based on the current sink. “LOW” should only be assigned after functional parity testing; current evidence supports HIGH or MEDIUM for every requested suite.
