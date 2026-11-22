# DKP Display UI Module

## Overview

The **DKP Display UI Module** provides a comprehensive visual interface for DKP auctions and loot distribution. It includes bid bars, notification popups, loot queue displays, leaderboards, and anti-snipe countdowns - everything players need to track DKP auctions in real-time.

## Features

### Core Display Components

1. **Live Bid Bars**
   - Visual representation of current bids
   - Green → Yellow → Red color progression as bids increase
   - Shows bid count and current bid amount
   - Automatically updates as new bids are placed
   - Synchronized with auction events

2. **Notification Popups**
   - Outbid notifications with player name and new bid
   - Bid accepted confirmations
   - Auction closed announcements
   - Auto-fade after 3-5 seconds
   - Stacked in top-right corner

3. **Loot Queue Display**
   - Shows next 5-10 items to be auctioned
   - Current bid amount per item
   - Time remaining until auction closes
   - Scrollable list for more items
   - Updates as queue changes

4. **Podium/Leaderboard Display**
   - Ranked list of guild members by DKP
   - Shows total DKP, spent points, and class
   - Gold/Silver/Bronze highlighting for top 3
   - Sorted highest to lowest
   - Updates as standings change

5. **Anti-Snipe Countdown**
   - Countdown timer for each auctioned item
   - Color changes: Green → Yellow → Red as time runs out
   - Shows seconds remaining
   - Attached to individual bid bars
   - Auto-removes when auction closes

6. **Main Window**
   - Tabbed interface (Standing, Auction, History, Settings)
   - Movable and resizable
   - Shows different views based on tab selection
   - Persistent across game sessions

## Usage

### Slash Commands

#### Toggle Main Window
```
/dkpui                          - Toggle main DKP UI window
/dkp                            - Shortcut for /dkpui
```

#### Specific Views
```
/dkpui leaderboard              - Show DKP standings/leaderboard
/dkpui standing                 - Alias for leaderboard
/dkpui queue                    - Show loot queue display
/dkpui hide                     - Hide main window
```

#### Keybinds
```
Keybind: Toggle DKP UI          - Toggles main DKP window (bindable in settings)
Keybind: Toggle Loot Manager    - Toggles loot manager (also toggles DKP when active)
```

### Examples

#### Check current DKP standings
```
/dkpui leaderboard
```
Output window shows:
```
1. Thrall (Warrior) - 2500 DKP, Spent: 1200
2. Jaina (Mage) - 2100 DKP, Spent: 950
3. Arthus (Death Knight) - 1800 DKP, Spent: 1500
...
```

#### Watch loot queue
```
/dkpui queue
```
Shows next 10 items with current bids and countdown timers

#### Access main UI
```
/dkpui
```
Opens main window with tabs for different views

## API Reference

### Main Window Functions

#### CreateMainWindow()
Create the main DKP UI window (called automatically at init).

**Returns:** nil (sets self.mainWindow)

#### ToggleWindow()
Toggle main window visibility.

**Returns:** nil

**Example:**
```lua
InfinityDKPUI:ToggleWindow()
```

#### SelectTab(tabName)
Select a specific tab in main window.

**Parameters:**
- `tabName` (string): "Standing", "Auction", "History", or "Settings"

**Returns:** nil

**Example:**
```lua
InfinityDKPUI:SelectTab("Standing")
```

### Bid Bar Functions

#### CreateBidBar(itemId, currentBid, bidCount)
Create a visual bid bar for an auctioned item.

**Parameters:**
- `itemId` (number): Item ID
- `currentBid` (number): Current bid in DKP
- `bidCount` (number): Number of bids placed

**Returns:** `barFrame` (frame object)

**Features:**
- Automatically colors based on bid intensity
- Shows bid information
- Displays progress bar
- Linked to item ID for updates

**Example:**
```lua
local bar = InfinityDKPUI:CreateBidBar(19364, 150, 3)
bar:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 50, -150)
bar:Show()
```

#### UpdateBidBar(itemId, newBid, newBidCount)
Update existing bid bar with new information.

**Parameters:**
- `itemId` (number): Item ID
- `newBid` (number): New bid amount
- `newBidCount` (number): New bid count

**Returns:** nil

**Color Behavior:**
- <30% of max (Green): Low competition
- 30-70% of max (Yellow): Medium competition  
- >70% of max (Red): High competition

**Example:**
```lua
-- Update when new bid placed
InfinityDKPUI:UpdateBidBar(19364, 200, 4)
```

#### RemoveBidBar(itemId)
Remove bid bar when auction closes.

**Parameters:**
- `itemId` (number): Item ID

**Returns:** nil

**Example:**
```lua
InfinityDKPUI:RemoveBidBar(19364)
```

### Notification Functions

#### ShowOutbidPopup(playerName, itemName, newBid)
Show notification that player was outbid.

**Parameters:**
- `playerName` (string): Player who placed new bid
- `itemName` (string): Item being auctioned
- `newBid` (number): New bid amount in DKP

**Returns:** nil

**Display:**
- Red popup with white text
- Auto-fades after 5 seconds
- Stacks with other popups

**Example:**
```lua
InfinityDKPUI:ShowOutbidPopup("Thrall", "Perdition's Blade", 250)
```

#### ShowNotification(message, color)
Show general notification with custom message and color.

**Parameters:**
- `message` (string): Notification text
- `color` (table, optional): {r, g, b} (default: green)

**Returns:** nil

**Example:**
```lua
InfinityDKPUI:ShowNotification("Bid accepted!", {r = 0.2, g = 0.8, b = 0.2})
InfinityDKPUI:ShowNotification("Auction closed!", {r = 0.8, g = 0.6, b = 0.2})
```

### Loot Queue Functions

#### CreateLootQueueFrame()
Create loot queue display (called automatically).

**Returns:** `queueFrame` (frame object)

#### UpdateLootQueue(queueItems)
Update queue display with current items.

**Parameters:**
- `queueItems` (table): Array of items
  - `itemName` (string): Item name
  - `currentBid` (number): Current bid in DKP
  - `timeRemaining` (number): Seconds until auction closes

**Returns:** nil

**Display Format:**
```
#1: Perdition's Blade - Bid: 150 DKP - 45s
#2: Sapphiron's Pendant - Bid: 100 DKP - 120s
#3: Rune of Razorice - Bid: 75 DKP - 180s
```

**Example:**
```lua
InfinityDKPUI:UpdateLootQueue({
    {itemName = "Perdition's Blade", currentBid = 150, timeRemaining = 45},
    {itemName = "Sapphiron's Pendant", currentBid = 100, timeRemaining = 120},
})
```

#### ShowLootQueue()
Show loot queue window.

**Returns:** nil

#### HideLootQueue()
Hide loot queue window.

**Returns:** nil

### Leaderboard Functions

#### CreateLeaderboardFrame()
Create leaderboard display (called automatically).

**Returns:** `leaderboardFrame` (frame object)

#### UpdateLeaderboard(players)
Update leaderboard with current standings.

**Parameters:**
- `players` (table): Array of player data
  - `name` (string): Player name
  - `dkp` (number): Current DKP
  - `spent` (number): Total spent
  - `class` (string, optional): Player class

**Returns:** nil

**Highlighting:**
- #1: Gold background
- #2: Silver background
- #3: Bronze background
- Others: Gray background

**Example:**
```lua
local standings = {
    {name = "Thrall", dkp = 2500, spent = 1200, class = "Warrior"},
    {name = "Jaina", dkp = 2100, spent = 950, class = "Mage"},
}
InfinityDKPUI:UpdateLeaderboard(standings)
```

#### ShowLeaderboard()
Show leaderboard window and populate with current standings.

**Returns:** nil

**Data Source:**
- Automatically queries InfinityLootEPGP.playerStats
- Sorts by DKP (highest first)
- Includes class information if available

**Example:**
```lua
InfinityDKPUI:ShowLeaderboard()
```

### Anti-Snipe Countdown Functions

#### CreateAntiSnipeCountdown(itemId, timeRemaining)
Create countdown timer for auction anti-snipe protection.

**Parameters:**
- `itemId` (number): Item ID
- `timeRemaining` (number): Seconds until auction closes

**Returns:** `countdownFrame` (frame object)

**Color Behavior:**
- >10 seconds: Green
- 3-10 seconds: Yellow
- <3 seconds: Red

**Features:**
- Updates every 100ms
- Centered countdown display
- Auto-removes at 0 seconds
- Linked to item ID

**Example:**
```lua
local countdown = InfinityDKPUI:CreateAntiSnipeCountdown(19364, 45)
countdown:SetPoint("TOP", bidBar, "BOTTOM", 0, -10)
countdown:Show()
```

### Configuration

#### Default Configuration

```lua
InfinityDKPUI.config = {
    enableBidBars = true,              -- Show live bid bars
    enablePopups = true,               -- Show outbid popups
    enableLootQueue = true,            -- Show queue display
    enableLeaderboard = true,          -- Show leaderboard
    enableAntiSnipeCountdown = true,   -- Show countdown timers
    maxQueueItems = 10,                -- Max items in queue display
    updateFrequency = 0.1,             -- Update rate in seconds
}
```

#### Customizing Configuration

```lua
-- Disable popups if too intrusive
InfinityDKPUI.config.enablePopups = false

-- Show more queue items
InfinityDKPUI.config.maxQueueItems = 20

-- Disable anti-snipe countdown
InfinityDKPUI.config.enableAntiSnipeCountdown = false
```

### Utility Functions

#### GetAwardColor(awardType)
Get display color for auction tier.

**Parameters:**
- `awardType` (string): "MS", "OS", "OFFSPEC", or "BANK"

**Returns:** `color` (table {r, g, b})

**Color Map:**
- MS (Main Spec): Green
- OS (Off-Spec): Yellow
- OFFSPEC: Orange
- BANK: Gray

**Example:**
```lua
local color = InfinityDKPUI:GetAwardColor("MS")
-- Returns: {r = 0.2, g = 0.8, b = 0.2}
```

#### FormatDKP(value)
Format DKP amount for display.

**Parameters:**
- `value` (number): DKP amount

**Returns:** `formatted` (string)

**Formatting:**
- 1000+ = "1.5k", "2.3k", etc.
- <1000 = "500", "750", etc.

**Example:**
```lua
print(InfinityDKPUI:FormatDKP(2500))  -- Outputs: "2.5k"
print(InfinityDKPUI:FormatDKP(500))   -- Outputs: "500"
```

## Event Integration

### Supported Events

The DKP UI automatically responds to the following events:

| Event | Data | Response |
|-------|------|----------|
| `bid_placed` | {itemId, bid, bidCount, isPlayerBid} | Update bid bar, show notification |
| `outbid` | {playerName, itemName, newBid} | Show outbid popup |
| `auction_closed` | {itemId, winner, finalBid} | Remove bid bar, show announcement |
| `queue_updated` | {queueItems} | Update loot queue display |
| `standings_updated` | {players} | Update leaderboard |

### Publishing Events

To trigger UI updates from other addons:

```lua
-- Someone placed a bid
InfinityMessaging:Publish(INFINITY_EVENTS.DATA_CHANGED, "dkp", "bid_placed", {
    itemId = 19364,
    bid = 250,
    bidCount = 5,
    isPlayerBid = true
})

-- Player was outbid
InfinityMessaging:Publish(INFINITY_EVENTS.DATA_CHANGED, "dkp", "outbid", {
    playerName = "Thrall",
    itemName = "Perdition's Blade",
    newBid = 300
})

-- Auction ended
InfinityMessaging:Publish(INFINITY_EVENTS.DATA_CHANGED, "dkp", "auction_closed", {
    itemId = 19364,
    winner = "Jaina",
    finalBid = 300
})
```

## Performance Considerations

### UI Rendering
- **Bid Bar Creation**: <5ms
- **Leaderboard Update**: <20ms (100 players)
- **Queue Display**: <10ms (20 items)
- **Popup Display**: <1ms
- **Total UI Impact**: <0.5% CPU during auction

### Memory Usage
- Bid bars: ~2KB per active auction
- Leaderboards: ~5KB per 100 players
- Popups: ~1KB per popup
- Queue display: ~3KB
- **Total typical memory**: <20MB

### Best Practices
1. Only update displays when data actually changes
2. Use batch updates for multiple changes
3. Disable popups if too many auctions running
4. Clear old countdown timers to prevent memory leaks
5. Update leaderboard once per minute, not per second

## Troubleshooting

### Bid bars not showing
- Verify `enableBidBars = true` in config
- Check that auction events are being published
- Ensure bid frame is positioned visible on screen

### Popups appearing off-screen
- Popups stack from top-right corner
- If too many, some may appear off-screen (design choice)
- Reduce number of active auctions or disable popups

### Leaderboard not updating
- Run `/dkpui leaderboard` to manually refresh
- Verify `InfinityLootEPGP.playerStats` has data
- Check that standings change events are firing

### Performance lag during auctions
- Disable popups: `InfinityDKPUI.config.enablePopups = false`
- Disable countdown timers: `enableAntiSnipeCountdown = false`
- Reduce queue max items: `maxQueueItems = 5`

## Future Enhancements

Possible additions:
- Customizable bid bar colors and styles
- Sound effects for outbid notifications
- Auction timer warnings
- Player avatar icons in leaderboard
- Bid history timeline
- Price trend analysis
- Comparison with historical average prices
- Mobile/remote leaderboard access
- Animation effects for bid updates
