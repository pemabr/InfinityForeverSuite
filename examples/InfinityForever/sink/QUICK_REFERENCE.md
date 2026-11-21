# QUICK REFERENCE - 4 PRINCIPLES FOR EVERY FEATURE

**TL;DR:** Use this checklist for EVERY feature you implement.

---

## PRINCIPLE 1: Cross-Addon Compatibility

**Question:** Does this feature work when ALL 25 addons are loaded together?

### Testing Checklist
- [ ] Load all 25 addons from sink folder
- [ ] No console errors on load
- [ ] Feature functions correctly
- [ ] No namespace collisions detected
- [ ] No keybind conflicts (test all slash commands)
- [ ] Unload this addon, all others still work
- [ ] No race conditions in startup order
- [ ] Cross-addon events fire correctly

### Common Issues
- 🔴 **Namespace collision:** Variable name used by another addon
  - Fix: Prefix all globals with addon name (e.g., InfinityLoot_)
- 🔴 **Keybind conflict:** Same /command used by different addon
  - Fix: Check all existing /commands before adding new ones
- 🔴 **Startup order:** One addon depends on another's initialization
  - Fix: Use InfinityCore events (OnReady callback)
- 🔴 **Memory leak:** Addon holds references preventing unload
  - Fix: Clear all event handlers in OnUnload

---

## PRINCIPLE 2: Core-Only Soft Dependencies

**Question:** Does this feature work if other addons are disabled?

### Testing Checklist
- [ ] Load only InfinityCore + this addon
- [ ] Core features work (never should fully break)
- [ ] Optional features gracefully degrade
- [ ] Clear messages shown when optional addon missing
- [ ] No console errors if optional addon unavailable
- [ ] Example: Loot works alone, but raid tracking needs InfinityRaid

### How to Implement
`lua
-- Check if optional addon loaded
if InfinityRaid then
  -- Use InfinityRaid's raid data
  local raidComposition = InfinityRaid:GetRaidComposition()
else
  -- Degrade gracefully
  InfinityCore:Log("WARNING", "InfinityRaid not loaded, using basic composition")
  -- Provide fallback or skip feature
end
`

### Common Issues
- 🔴 **Hard dependency:** Code crashes if optional addon missing
  - Fix: Always check with if AddonName then before using
- 🔴 **Partial feature:** Only 50% works without optional addon
  - Fix: Clearly log what's unavailable
- 🟡 **Silent degradation:** Player doesn't know feature is disabled
  - Fix: Show warning message in chat

---

## PRINCIPLE 3: Performance & Network Efficiency

**Question:** Does this feature drain CPU, memory, or network bandwidth?

### CPU Performance Checklist
- [ ] Addon measured with /script InfinityProfiler:Show()
- [ ] This addon shows <2% CPU usage
- [ ] Total suite with all addons <50% CPU
- [ ] No frame-by-frame calculations (use timers instead)
- [ ] Heavy calculations done in background (async)
- [ ] Data sorted once per second (not per frame)

### Memory Checklist
- [ ] No memory leak detected after 4-hour session
- [ ] InfinityProfiler shows steady memory (no growth)
- [ ] Large data structures released when unloaded
- [ ] String/table cleanup in OnUnload hook

### Network Efficiency Checklist
- [ ] Only send data to network if necessary
- [ ] Send delta changes only (new items, not full state)
- [ ] Never send during combat (unless critical)
- [ ] Max 1 message per 2 seconds to other players
- [ ] Compress large data before transmitting
- [ ] Test: Monitor network traffic with /script InfinityProfiler:ShowNetwork()
- [ ] Rule: Total network <10KB/sec per player average

### Examples
`lua
-- ❌ BAD: Send all data every frame
OnUpdate = function(self)
  for i = 1, #allPlayers do
    InfinityCore:SendToNetwork("AllPlayerData", allPlayers)
  end
end

-- ✅ GOOD: Send delta changes
local lastSync = 0
OnUpdate = function(self, elapsed)
  lastSync = lastSync + elapsed
  if lastSync > 2 then  -- Every 2 seconds
    local changes = GetChangedPlayers()
    if #changes > 0 then
      InfinityCore:SendToNetwork("PlayerDataDelta", changes)
    end
    lastSync = 0
  end
end
`

### Combat Mode Optimization
`lua
-- Check if in combat
if UnitAffectingCombat("player") then
  -- Only send critical data
  if isCritical then
    InfinityCore:SendToNetwork("URGENT", data)
  end
  -- Skip non-critical sync
else
  -- Full sync when not in combat
  InfinityCore:SendToNetwork("AllData", data)
end
`

---

## PRINCIPLE 4: Quality Assurance & Testing

**Question:** Does this feature work correctly? Are calculations accurate?

### Calculation Testing
- [ ] Test with known values (don't just check structure)
- [ ] Test edge cases (nil, empty, boundary values)
- [ ] Test error handling (invalid input)
- [ ] Example for DPS calculation:
  `lua
  -- ✅ Correct test: Verify math
  local damage = 1000
  local duration = 10
  local dps = damage / duration  -- Should = 100
  assert(dps == 100, "DPS calculation failed")
  
  -- ❌ Wrong test: Just check if function exists
  assert(GetDPS ~= nil, "GetDPS function exists")  -- This doesn't verify correctness
  `

### Edge Case Testing
`lua
-- Test nil handling
assert(GetPlayerValue(nil) == 0, "Should handle nil player")

-- Test empty lists
local emptyList = {}
assert(CalculateTotal(emptyList) == 0, "Should handle empty list")

-- Test boundary values
assert(CalculateDPS(0, 0) == 0, "Should handle zero duration")
assert(CalculateDPS(1000, 0.1) ~= math.huge, "Should not divide by zero")
`

### Error Handling Checklist
- [ ] No unhandled exceptions (use pcall)
- [ ] Errors logged to console but don't crash addon
- [ ] User-facing messages are clear and actionable
- [ ] Recovery from errors (don't leave addon in broken state)

`lua
-- ✅ Good error handling
local success, result = pcall(function()
  return ProcessComplexData(data)
end)

if not success then
  InfinityCore:Log("ERROR", "Failed to process data: " .. tostring(result))
  return  -- Graceful exit
end
`

### No Console Errors Checklist
- [ ] Run /console set scriptErrors 1 to show Lua errors
- [ ] Play for 30 minutes normal gameplay
- [ ] Zero errors should appear in console
- [ ] Check InfinityCore:GetErrorLog() for logged errors

### WoW API Deprecation Checklist
- [ ] No deprecated functions used (UnitLevel, UnitClass, etc.)
- [ ] Use C_Unit.* and C_PlayerInfo.* instead
- [ ] Run API checker: grep -r "UnitLevel\|UnitClass\|UnitRace" *.lua

---

## QUICK TEST TEMPLATE

Use this template to verify any feature:

`lua
-- Test cross-addon compatibility
print("Testing feature XYZ...")

-- 1. Test calculation accuracy
local testResult = CalculateXYZ(100)
assert(testResult == expectedValue, "Calculation failed")
print("  ✓ Calculation accurate")

-- 2. Test with optional addon missing
if not OptionalAddon then
  local result = CalculateXYZ(100)
  assert(result > 0, "Should degrade gracefully")
  print("  ✓ Degrades without optional addon")
end

-- 3. Test performance
local start = GetTime()
for i = 1, 1000 do
  CalculateXYZ(100)
end
local elapsed = GetTime() - start
assert(elapsed < 0.1, "Too slow: " .. elapsed .. "s")
print("  ✓ Performance acceptable")

-- 4. Test error handling
local success, result = pcall(function()
  return CalculateXYZ(nil)  -- Invalid input
end)
assert(success, "Should handle errors")
print("  ✓ Error handling works")

print("Feature XYZ PASSED all checks ✓")
`

---

## CHECKLIST VERIFICATION BEFORE MARKING TASK DONE

### For Every Task Completion
- [ ] Read all Core Principles (this document)
- [ ] Implemented all features listed in checklist
- [ ] Ran all 4 compatibility checks:
  - Cross-Addon: All 25 addons load together ✓
  - Core-Only: Works without optional addons ✓
  - Performance: CPU <2%, Network efficient ✓
  - Quality: Calculations tested, no errors ✓
- [ ] Updated InfinityCore logging (track what's working)
- [ ] Wrote test cases (at least 5 per feature)
- [ ] Documented any architectural decisions
- [ ] Code reviewed for obvious bugs
- [ ] No regression (previous features still work)
- [ ] Ready to continue to next task

### How to Report Completion
1. What you completed
2. What tests passed
3. Any bugs found/fixed
4. Any architectural decisions
5. Ready to continue to next phase

---

## COMMON MISTAKES TO AVOID

| Mistake | Impact | Fix |
|---------|--------|-----|
| Global variable used by other addon | 🔴 CRITICAL - Addon conflict | Use namespace prefix (InfinityLoot_) |
| Feature only works if other addon loaded | 🔴 CRITICAL - Hard dependency violation | Check addon and degrade gracefully |
| Calculate on every frame | 🔴 PERFORMANCE - CPU spike | Use timer, calculate once per second |
| Send all data to network | 🟠 NETWORK - Bandwidth hog | Only send changes (delta) |
| Return dummy values without testing | 🔴 FUNCTIONAL - Feature broken | Test calculations with real values |
| Unhandled exceptions crash addon | 🔴 STABILITY - User can't play | Use pcall() wrapper |
| Memory leak on reload | 🟠 STABILITY - Game gets slow | Clear all references in OnUnload |
| Feature silently doesn't work | 🟡 UX - Player confused | Log clear warning messages |

---

**Save this document. Reference it constantly while implementing features.**

Generated by: Copilot CLI Assistant  
Last updated: 2026-11-20  
