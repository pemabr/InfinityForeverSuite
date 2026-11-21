# Infinity Forever Suite - Development Roadmap

## Project Overview

Converting 90+ individual WoW Forever addons into a unified suite experience with:
- Single cohesive interface
- Shared infrastructure (data, storage, events)
- Zero keyboard shortcut conflicts
- Professional user experience

---

## Completed ✅

### Infrastructure
- [x] Project structure and directory layout
- [x] Core addon scaffold (InfinityCore)
- [x] Constants and configuration system
- [x] Utilities library (logging, formatting, etc.)
- [x] Data Manager (aggregation and caching)
- [x] Storage Manager (persistent SavedVariables)
- [x] Messaging System (inter-addon communication)
- [x] Event Router (centralized WoW event handling)
- [x] Command Registry (slash commands & keybinds)
- [x] UI Framework (shared components)
- [x] Main Window (tabbed interface)
- [x] Localization system

### Feature Addons Scaffolding
- [x] InfinityLoot (structure)
- [x] InfinityGuild (structure)
- [x] InfinityRaid (structure)
- [x] InfinityGather (structure)
- [x] InfinityGuide (structure)
- [x] InfinityGear (structure)
- [x] InfinityQoL (structure)
- [x] InfinityData (structure)

### Documentation
- [x] Architecture document
- [x] Implementation guide
- [x] Development roadmap (this file)

---

## Phase 1: Core Foundation (Complete ✅)

### Deliverables
- [x] InfinityCore addon fully functional
- [x] All core systems operational
- [x] API documentation
- [x] Feature addon scaffolding

### Verification
- [ ] Load InfinityCore in WoW
- [ ] Verify `/infinity` command works
- [ ] Confirm main window opens
- [ ] Test debug information display

---

## Phase 2: Feature Addon Implementation

### 2.1 InfinityLoot (High Priority)
**Timeline**: Week 1-2  
**Effort**: 40 hours

#### Tasks
- [ ] Extract ClassicLootManager code
  - [ ] Parse DKP/EPGP logic
  - [ ] Extract loot tracking system
  - [ ] Identify data structures
  
- [ ] Extract SharpiesLootTracker code
  - [ ] Loot value calculation
  - [ ] Gold per hour tracking
  - [ ] Item history

- [ ] Extract CommissionsForever code
  - [ ] Commission tracking
  - [ ] Turn-in management
  - [ ] Material tracking

- [ ] Create InfinityLoot modules
  - [ ] LootManager.lua (DKP/EPGP integration)
  - [ ] Tracking.lua (loot history)
  - [ ] Economy.lua (gold flow analysis)
  - [ ] Commissions.lua (turn-in tracking)

- [ ] Build UI
  - [ ] Loot management panel
  - [ ] Loot history viewer
  - [ ] Settings integration
  - [ ] Commission tracker display

- [ ] Integration
  - [ ] Connect to InfinityCore data manager
  - [ ] Use InfinityStorageManager for settings
  - [ ] Register with command registry
  - [ ] Publish relevant events

- [ ] Testing
  - [ ] Test DKP calculation
  - [ ] Verify data persistence
  - [ ] Check UI rendering
  - [ ] Validate event flow

#### Success Criteria
- [ ] Can distribute loot with DKP/EPGP
- [ ] Loot values calculated correctly
- [ ] Commission tracking operational
- [ ] All data persists across reloads
- [ ] No conflicts with other modules

---

### 2.2 InfinityGuild (High Priority)
**Timeline**: Week 1-2 (parallel with 2.1)  
**Effort**: 25 hours

#### Tasks
- [ ] Extract GuildLadderDKP code
  - [ ] DKP ladder system
  - [ ] Historical tracking

- [ ] Extract GuildPrideForever code
  - [ ] Guild achievements
  - [ ] Pride metrics

- [ ] Extract Guild_Roster_Manager code
  - [ ] Member management
  - [ ] Roster tracking

- [ ] Create InfinityGuild modules
  - [ ] RosterManager.lua
  - [ ] DKPTracker.lua
  - [ ] MemberManagement.lua

- [ ] Build UI
  - [ ] Unified guild panel
  - [ ] DKP ladder display
  - [ ] Member list with info
  - [ ] Achievement tracking

- [ ] Integration
  - [ ] Link with InfinityLoot for DKP sync
  - [ ] Connect to InfinityCore messaging
  - [ ] Persistent storage setup

- [ ] Testing
  - [ ] Verify DKP sync with loot
  - [ ] Test member updates
  - [ ] Check data persistence

#### Success Criteria
- [ ] Guild roster displays correctly
- [ ] DKP ladder updates with loot
- [ ] Member management functional
- [ ] Data persists properly

---

### 2.3 InfinityRaid (High Priority)
**Timeline**: Week 2-3  
**Effort**: 35 hours

#### Tasks
- [ ] Extract DBM suite (massive task)
  - [ ] Core encounter timers
  - [ ] Encounter-specific alerts
  - [ ] Timer display logic
  - Prioritize most-used encounters first

- [ ] Extract MRT code
  - [ ] Raid composition
  - [ ] Assignment management

- [ ] Extract HealBot code
  - [ ] Healing grid display
  - [ ] Healing assignment

- [ ] Create InfinityRaid modules
  - [ ] EncounterManager.lua
  - [ ] CombatAlerts.lua
  - [ ] HealingManager.lua

- [ ] Build UI
  - [ ] Encounter timer display
  - [ ] Healing assignment panel
  - [ ] Alert configuration

- [ ] Integration
  - [ ] DBM encounter library
  - [ ] Raid composition sync
  - [ ] Healing assignment publishing

- [ ] Testing
  - [ ] Verify encounter timers
  - [ ] Test healing assignments
  - [ ] Check alert triggering

#### Success Criteria
- [ ] Encounter timers working
- [ ] Healing assignments display
- [ ] Alerts trigger correctly
- [ ] No missed encounters

---

### 2.4 InfinityGather (Medium Priority)
**Timeline**: Week 3-4  
**Effort**: 30 hours

#### Tasks
- [ ] Extract GatherMate2 code
  - [ ] Node database structure
  - [ ] Node tracking logic
  - [ ] World map integration

- [ ] Extract GatherPathForever code
  - [ ] Route optimization algorithm
  - [ ] Node prioritization

- [ ] Extract SkillUpForever code
  - [ ] Skill-up route generation
  - [ ] Optimal node selection

- [ ] Create InfinityGather modules
  - [ ] GatheringDatabase.lua
  - [ ] RouteOptimizer.lua
  - [ ] SkillTracker.lua

- [ ] Build UI
  - [ ] Node database viewer
  - [ ] Route planning panel
  - [ ] Skill-up guide

- [ ] Integration
  - [ ] Use InfinityData for database
  - [ ] Connect to mapping system
  - [ ] Skill tracking

- [ ] Testing
  - [ ] Verify node recording
  - [ ] Test route calculation
  - [ ] Check skill-up paths

#### Success Criteria
- [ ] Nodes display on world map
- [ ] Routes optimize correctly
- [ ] Skill-up paths generated
- [ ] Database persists

---

### 2.5 InfinityGuide (Medium Priority)
**Timeline**: Week 4-5  
**Effort**: 40 hours

#### Tasks
- [ ] Extract Questie code
  - [ ] Quest tracking system
  - [ ] Quest objective tracking
  - [ ] Quest data structures

- [ ] Extract Atlas suite
  - [ ] Loot information
  - [ ] Dungeon information
  - [ ] Map data

- [ ] Extract AdventureGuideForever code
  - [ ] Zone guide content
  - [ ] Story elements

- [ ] Create InfinityGuide modules
  - [ ] QuestTracker.lua
  - [ ] LootDatabase.lua
  - [ ] ZoneGuide.lua

- [ ] Build UI
  - [ ] Quest tracker panel
  - [ ] Loot information viewer
  - [ ] Zone guide display
  - [ ] Adventure interface

- [ ] Integration
  - [ ] Use InfinityData for static data
  - [ ] Connect quest tracking
  - [ ] Adventure recommendations

- [ ] Testing
  - [ ] Verify quest tracking
  - [ ] Test loot information
  - [ ] Check guide content

#### Success Criteria
- [ ] Quests track correctly
- [ ] Loot info displays
- [ ] Zone guides functional
- [ ] Adventure paths work

---

### 2.6 InfinityGear (Medium Priority)
**Timeline**: Week 5-6  
**Effort**: 25 hours

#### Tasks
- [ ] Extract SharpiesGearJudge code
  - [ ] Gear evaluation logic
  - [ ] Cross-character comparison

- [ ] Extract Attune code
  - [ ] Attunement tracking
  - [ ] Quest tracking

- [ ] Extract Consumable-Connoisseur code
  - [ ] Consumable tracking
  - [ ] Optimization logic

- [ ] Create InfinityGear modules
  - [ ] GearEvaluator.lua
  - [ ] TalentManager.lua
  - [ ] ProgressionTracker.lua

- [ ] Build UI
  - [ ] Gear comparison display
  - [ ] Talent planner
  - [ ] Attunement tracker
  - [ ] Consumable optimizer

- [ ] Integration
  - [ ] Cross-character data sharing
  - [ ] Progression tracking

- [ ] Testing
  - [ ] Verify gear evaluation
  - [ ] Test talent planning
  - [ ] Check attunement tracking

#### Success Criteria
- [ ] Gear compares across chars
- [ ] Talent planning works
- [ ] Attunement status updates
- [ ] Consumables optimize

---

### 2.7 InfinityQoL (Low Priority)
**Timeline**: Week 6-7  
**Effort**: 20 hours

#### Tasks
- [ ] Extract TweaksForever code
  - [ ] Auto quest accept/turn-in
  - [ ] NPC highlighting
  - [ ] Auto repair/sell

- [ ] Extract MacroAssistForever code
  - [ ] Macro assistance

- [ ] Extract idTip code
  - [ ] Tooltip enhancements

- [ ] Create InfinityQoL modules
  - [ ] AutomationTools.lua
  - [ ] TooltipEnhancements.lua
  - [ ] MacroHelper.lua

- [ ] Build UI
  - [ ] QoL settings panel
  - [ ] Feature toggles

- [ ] Integration
  - [ ] Connect automation triggers
  - [ ] Tooltip hook system

- [ ] Testing
  - [ ] Verify auto quest handling
  - [ ] Test tooltip rendering
  - [ ] Check macro assistance

#### Success Criteria
- [ ] Auto quests functional
- [ ] Tooltips enhanced
- [ ] QoL features work
- [ ] Settings persist

---

## Phase 3: UI Consolidation

### 3.1 Main Interface Unification
**Timeline**: Week 7-8  
**Effort**: 20 hours

#### Tasks
- [ ] Design unified dashboard
- [ ] Create feature-specific tabs
- [ ] Implement settings consolidation
- [ ] Build theme system
- [ ] Add minimap integration
- [ ] Style consistency

#### Success Criteria
- [ ] Single main window for all features
- [ ] Consistent styling across all tabs
- [ ] Minimap button functional
- [ ] Settings centralized

### 3.2 Configuration Panel
**Timeline**: Week 8  
**Effort**: 15 hours

#### Tasks
- [ ] Build master settings panel
- [ ] Per-feature settings UI
- [ ] Keybind management UI
- [ ] Import/export settings
- [ ] Profile management

#### Success Criteria
- [ ] All settings accessible from one place
- [ ] Keybind conflicts resolved
- [ ] Settings import/export works

---

## Phase 4: Testing & Optimization

### 4.1 Testing
**Timeline**: Week 8-9  
**Effort**: 25 hours

#### Tasks
- [ ] Unit testing for core systems
- [ ] Integration testing between addons
- [ ] User acceptance testing
- [ ] Bug identification and fixes
- [ ] Performance profiling

#### Success Criteria
- [ ] All features functional
- [ ] No data loss
- [ ] Smooth performance
- [ ] No major bugs

### 4.2 Optimization
**Timeline**: Week 9  
**Effort**: 15 hours

#### Tasks
- [ ] Performance optimization
- [ ] Memory usage reduction
- [ ] Code cleanup
- [ ] Documentation updates

#### Success Criteria
- [ ] Acceptable performance
- [ ] Reasonable memory usage
- [ ] Clean code
- [ ] Complete documentation

---

## Phase 5: Release Preparation

### 5.1 Documentation
- [ ] User guide
- [ ] API documentation
- [ ] Migration guide for existing users
- [ ] FAQ and troubleshooting

### 5.2 Release Candidate
- [ ] Release notes
- [ ] Version tagging
- [ ] Backup plan

### 5.3 Launch
- [ ] Public release
- [ ] User support
- [ ] Bug tracking

---

## Estimated Timeline

| Phase | Duration | Status |
|-------|----------|--------|
| Core Foundation | Complete | ✅ |
| Phase 2.1-2.3 (High Priority) | 2-3 weeks | 🔄 Planned |
| Phase 2.4-2.7 (Medium/Low) | 3-4 weeks | 🔄 Planned |
| Phase 3 (UI) | 1-2 weeks | 🔄 Planned |
| Phase 4 (Testing) | 1-2 weeks | 🔄 Planned |
| Phase 5 (Release) | 1 week | 🔄 Planned |
| **Total** | **~8-10 weeks** | |

---

## Resource Requirements

- **Team Size**: 1-2 developers
- **Tools Needed**:
  - WoW Forever test server access
  - Text editor with Lua support
  - Git version control
  - Testing framework

- **Skills Required**:
  - Lua programming
  - WoW API knowledge
  - Addon development experience
  - Code refactoring

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|-----------|
| Data loss during migration | Low | High | Backup system, testing |
| Keybind conflicts | Medium | Medium | Central registry, testing |
| Performance degradation | Medium | Medium | Profiling, optimization |
| Incompatibility with WoW Forever | Low | High | Early testing, communication |
| Scope creep | Medium | Medium | Strict prioritization |

---

## Success Metrics

- [x] Core infrastructure complete
- [ ] All feature addons integrated
- [ ] Zero critical bugs
- [ ] < 5MB total addon size
- [ ] < 2 second load time
- [ ] 100% data persistence
- [ ] Positive user feedback
- [ ] No keybind conflicts

---

## Communication

**Reporting**: Weekly status updates  
**Issues**: Tracked in development folder  
**Documentation**: Updated as features complete  
**User Feedback**: Collected via in-game feedback system

---

## Sign-Off

**Project Lead**: Infinity Suite Team  
**Last Updated**: 2026-11-20  
**Status**: Active Development (Phase 1 Complete)

---

## Next Immediate Steps

1. **Week 1 Action Items**:
   - [ ] Test InfinityCore loading
   - [ ] Verify all core systems operational
   - [ ] Begin InfinityLoot code extraction
   - [ ] Set up development workflow
   - [ ] Create detailed feature specifications

2. **Communication**:
   - Notify stakeholders of timeline
   - Set up regular check-ins
   - Create issue tracking system

3. **Environment**:
   - Verify development setup
   - Test on WoW Forever realm
   - Create backup procedures

---

*This roadmap is a living document and may be updated as development progresses.*
