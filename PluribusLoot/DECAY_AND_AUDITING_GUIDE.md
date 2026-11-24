# PluribusLoot Decay & Interval Awards System

## Overview

The Decay System manages periodic point degradation, interval awards for attendance, and weekly/lifetime caps. This ensures EP/GP remain balanced over time and prevents excessive point accumulation.

## Features

### 1. Automatic Decay
Periodically reduces EP/GP by a configurable percentage to keep the economy healthy.

**Configuration:**
- Decay percentage (default 10% per week)
- Decay interval (default 7 days)
- Decay rounding mode (floor/ceil/round)
- Minimum decay threshold (don't decay below 0)

**Example:**
- Player has 500 EP
- Decay enabled: 10% per week
- After one week: 500 × 0.9 = 450 EP
- After two weeks: 450 × 0.9 = 405 EP

### 2. Interval Awards (Attendance)
Award EP to raid members at regular intervals for participation.

**Configuration:**
- Attendance EP amount (default 50 EP per interval)
- Attendance check interval (default 24 hours)

**Use Cases:**
- Reward showing up to raids
- Encourage regular participation
- Catch up newer members

### 3. Weekly EP Cap
Limit maximum EP gain per week to prevent point farming.

**Configuration:**
- Weekly cap amount (default 2000 EP)
- Set to 0 for no cap

**Example:**
- Cap set to 2000 EP per week
- Player gains 1500 EP from raids
- Player can only gain 500 more this week
- Fourth award would be partially blocked

### 4. Minimum GP Threshold
Prevent players from obtaining loot if their GP is too low.

**Configuration:**
- Minimum GP requirement (default 50 GP)

## Slash Commands

### Decay System

```
/decay                              -- Show decay status
/decay apply                        -- Apply decay to all players NOW
/decay percent [0-100]              -- Set decay percentage
/decay interval [seconds]           -- Set decay interval
/decay enable                       -- Enable decay
/decay disable                      -- Disable decay
/decay weeklycap [amount]          -- Set weekly EP cap (0 = unlimited)
/decay resetweekly                  -- Reset weekly EP counters
/decay minggp [amount]              -- Set minimum GP threshold
/decay history                      -- Show recent decay transactions
```

### Interval Awards

```
/awards                             -- Show awards configuration
/awards award                       -- Award attendance EP to all players
/awards amount [ep]                 -- Set attendance award amount
/awards interval [seconds]          -- Set attendance check interval
```

### Audit & Transaction History

```
/audit                              -- Show audit statistics
/audit player [playername]          -- Show all transactions for player
/audit ep [playername]              -- Show EP history for player
/audit gp [playername]              -- Show GP history for player
/audit export                       -- Export full transaction history
/audit type [transaction_type]      -- Show all transactions of specific type
```

## API Functions

### Decay System

```lua
-- Enable/disable decay
PluribusLootDecay:SetDecayEnabled(enabled)

-- Apply decay now
PluribusLootDecay:ApplyDecayToAll()

-- Configuration
PluribusLootDecay:SetDecayPercent(percent)         -- 0-100
PluribusLootDecay:SetDecayInterval(seconds)        -- Minimum 3600
PluribusLootDecay:SetMinGPThreshold(amount)        -- Minimum GP

-- Query
PluribusLootDecay:GetDecayHistory(limit)           -- Returns table
PluribusLootDecay:ExportDecayHistory(limit)        -- Returns string
```

### Interval Awards

```lua
-- Award EP
PluribusLootDecay:AwardAllAttendanceEP()           -- Award to all players
PluribusLootDecay:AwardAttendanceEP(playerName)    -- Award to one player

-- Configuration
PluribusLootDecay:SetAttendanceAwardAmount(epAmount)
PluribusLootDecay:SetAttendanceCheckInterval(seconds)
```

### Weekly Cap

```lua
-- Check cap status
PluribusLootDecay:CanReceiveEP(playerName, amount) -- Returns bool
PluribusLootDecay:GetWeeklyEPGain(playerName)      -- Returns current gain
PluribusLootDecay:GetRemainingWeeklyEP(playerName) -- Returns remaining

-- Award EP with cap enforcement
PluribusLootDecay:AwardEPWithCap(playerName, amount)

-- Management
PluribusLootDecay:SetWeeklyEPCap(amount)           -- 0 = no cap
PluribusLootDecay:ResetWeeklyEPCounters()          -- Reset all counters
```

### Transaction History & Auditing

```lua
-- Get history
PluribusLootEPGP:GetPlayerTransactionHistory(playerName, limit)
PluribusLootEPGP:GetPlayerEPHistory(playerName, limit)
PluribusLootEPGP:GetPlayerGPHistory(playerName, limit)
PluribusLootEPGP:GetTransactionsByType(type, limit)
PluribusLootEPGP:GetTransactionsByDateRange(startTime, endTime, playerName)

-- Export
PluribusLootEPGP:ExportTransactionHistory(limit)

-- Statistics
PluribusLootEPGP:GetTransactionStats()
```

## Configuration Examples

### Example 1: Casual Guild (Weekly Decay + Attendance)

```
/decay percent 5                 -- 5% decay per week (lighter)
/decay interval 604800           -- 7 days
/decay weeklycap 1000            -- 1000 EP max per week
/awards amount 25                -- 25 EP for attendance
```

**Result:**
- Casual players lose 5% per week (soft reset)
- Can earn 1000 EP/week from loot
- Get 25 EP/day for showing up
- Points stay controlled and fair

### Example 2: Hardcore Guild (Heavy Decay + High Caps)

```
/decay percent 20                -- 20% decay per week (aggressive)
/decay interval 604800           -- 7 days
/decay weeklycap 5000            -- 5000 EP max per week
/awards amount 100               -- 100 EP for attendance
```

**Result:**
- Aggressive decay encourages constant activity
- High cap allows big point gains for active raiders
- Attendance bonus is significant
- Old points degrade quickly

### Example 3: No Decay (Accumulative System)

```
/decay disable                   -- Disable decay
/decay weeklycap 0               -- No weekly cap
```

**Result:**
- Classic EPGP without decay
- Points accumulate indefinitely
- Older members always have advantage
- Requires manual resets occasionally

## Transaction Types

The audit system tracks these transaction types:

| Type | Description |
|------|-------------|
| `ep_awarded` | Player received EP |
| `gp_awarded` | Player received GP for loot |
| `ep_decayed` | Automatic EP decay applied |
| `player_reset` | Player's points reset to 0 |
| `player_created` | Player added to system |

## Auditing Use Cases

### Investigation: "Why does Player X have 50,000 EP?"

```
/audit ep PlayerX
```
Shows every EP award/decay for that player.

### Investigation: "What GP was awarded last week?"

```
/audit gp PlayerX
```
Shows every GP award with item names.

### Investigation: "When was the last decay?"

```
/audit type ep_decayed
```
Shows all decay transactions.

### Export for Records

```
/audit export
```
Exports full audit trail to chat for record-keeping.

## Events

The Decay system publishes these events:

```lua
-- Decay events
PluribusMessaging:Subscribe("player_decayed", function(playerName, oldEP, newEP, oldGP, newGP)
	print(playerName .. " decayed: EP " .. oldEP .. "→" .. newEP)
end)

-- Attendance award events
PluribusMessaging:Subscribe("attendance_ep_awarded", function(playerName, amount)
	print(playerName .. " earned " .. amount .. " EP for attendance")
end)

-- Weekly cap reached
PluribusMessaging:Subscribe("weekly_cap_reached", function(playerName)
	print(playerName .. " has reached weekly EP cap")
end)
```

## Best Practices

### For Guild Masters

1. **Choose decay percentage carefully:**
   - 5-10%: Casual/social guilds (slow reset)
   - 15-20%: Competitive guilds (medium reset)
   - 25%+: Hardcore guilds (aggressive reset)

2. **Set attendance awards to encourage participation:**
   - Below cap: Small amount (10-30 EP)
   - Above cap: Moderate amount (50-100 EP)
   - For hardcore: Large amount (100-200 EP)

3. **Use weekly caps to prevent farming:**
   - New members: 1000-1500 EP/week
   - Regular members: 2000-3000 EP/week
   - Hardcore guilds: 5000+ EP/week

4. **Monitor audit logs regularly:**
   - Check for point anomalies
   - Verify decay is working
   - Track member participation

### For Officers

1. **Review transaction history before awarding loot:**
   - Check if player has earned it
   - Verify no mistakes in prior awards

2. **Reset weekly counters on schedule:**
   - Every Sunday for most guilds
   - Use `/decay resetweekly`
   - Announce in guild chat

3. **Document manual corrections:**
   - Always use audit trail
   - Provide clear reason
   - Keep records for disputes

## Troubleshooting

### Decay not applying

```
/decay                     -- Check if enabled
/decay enable              -- Enable decay
/decay apply              -- Force apply decay now
```

### Weekly cap not working

```
/decay weeklycap 2000     -- Verify cap is set
/audit PlayerX            -- Check their history
```

### Players not getting attendance awards

```
/awards amount 50         -- Verify amount set
/awards interval 86400    -- Verify interval
/awards award             -- Try awarding manually
```

## Performance Impact

- **Decay Calculation:** O(n) where n = number of players (runs weekly/on-demand)
- **Memory:** ~8 bytes per player for decay tracking
- **Network:** One sync per decay application
- **CPU:** <1% during decay (not in-combat)

## Migration & Backup

### Export Current State

```lua
local history = PluribusLootEPGP:ExportTransactionHistory(10000)
-- Save to file or database
```

### Restore from Backup

The transaction history is automatically saved in SavedVariables and restored on login. No manual action needed.

## Future Enhancements

Potential improvements:

1. **Seasonal Resets** - Automatically reset at season start
2. **Custom Decay Curves** - Non-linear decay formulas
3. **Member Lifetime Caps** - Prevent individual domination
4. **Vacation Mode** - Temporarily exempt members from decay
5. **Graduated Caps** - Different caps by role/rank
6. **Decay Notifications** - Alert players when decay applied

## Summary

The Decay and Interval Awards system provides guild leadership with powerful tools to:
- Keep the economy balanced
- Encourage regular participation
- Prevent point farming
- Maintain transparent audit trails
- Support multiple playstyles

Combined with weekly caps and minimum thresholds, it creates a fair and transparent EPGP system for guilds of any size or playstyle.
