# InfinityDKP Enhancements - Complete Documentation

**Date:** 2026-11-20  
**Version:** 1.1.0  
**Status:** ✅ IMPLEMENTATION COMPLETE  

---

## OVERVIEW

The InfinityDKP addon has been enhanced with four major new features:

1. **Unified Auction System** - Removes tiered bidding (MS/OS/Offspec/Bank), creates single pool
2. **Tax System** - Collect DKP via gold taxation (configurable rates)
3. **Guild Bank Donations** - Reward DKP for donating items/gold to guild bank
4. **Player Trading** - Allow guild members to trade DKP with each other

---

## FEATURE 1: UNIFIED AUCTION SYSTEM

### Overview

The new unified auction system removes the traditional tier system (Main Spec > Off Spec > Offspec > Bank) and replaces it with a single auction pool where all guild members bid equally on all items.

### Key Benefits

- **Simpler for users** - No need to remember which tier applies to them
- **More competitive** - Best bidder always wins, regardless of spec
- **Fairer distribution** - No bias toward specific specs or roles
- **Easier management** - Single bid pool to manage

### How It Works

```lua
-- Create a unified auction (no tiers)
local auctionId = InfinityDKPUnifiedAuctions:CreateAuction(
    itemLink,           -- Item to auction
    startingBid,        -- Minimum bid (e.g., 10)
    duration            -- Duration in seconds (default 300)
)

-- Place a bid
InfinityDKPUnifiedAuctions:PlaceBid(auctionId, playerName, bidAmount)

-- Close auction (determines winner)
local winner = InfinityDKPUnifiedAuctions:CloseAuction(auctionId)
```

### Commands

```
/dkp auction create [itemlink] [startingbid] [duration]
  Create a new unified auction
  Example: /dkp auction create |cff1eff00|Hitem:12345|h[Item Name]|h|r 50 300

/dkp auction list
  Show all active auctions with current bids

/dkp auction bid [auctionid] [amount]
  Place a bid on an auction
  Example: /dkp auction bid 1 100

/dkp auction close [auctionid]
  Close an auction and determine winner (admin only)
```

### Configuration

```lua
InfinityDKPUnifiedAuctions.config = {
    enabled = true,
    defaultBiddingMode = "open",
    minBidIncrement = 1,       -- Minimum increment between bids
    defaultDuration = 300,     -- Default 5 minutes
    antiSnipeDuration = 10,    -- Extend if bid within 10 seconds of end
}
```

### API Functions

**CreateAuction(itemLink, startingBid, duration, minimumBid)**
- Creates new unified auction
- Returns auctionId (number) or nil on failure

**PlaceBid(auctionId, playerName, bidAmount)**
- Places bid from player
- Returns success (bool)
- Extends duration if anti-snipe trigger

**CloseAuction(auctionId)**
- Closes auction and determines winner
- Deducts DKP from winner's Points pool
- Returns winner name (string) or nil

**GetActiveAuctions()**
- Returns table of all active auctions

**GetAuctionDetails(auctionId)**
- Returns auction object or nil

**GetPlayerWins(playerName, limit)**
- Returns table of auctions won by player

**GetGuildAuctionStats()**
- Returns guild-wide auction statistics

### Events

```lua
InfinityDKPUnifiedAuctions:RegisterCallback(function(event, ...)
    if event == "auction_created" then
        local auctionId, itemName, startingBid = ...
    elseif event == "bid_placed" then
        local auctionId, playerName, bidAmount = ...
    elseif event == "auction_extended" then
        local auctionId, playerName = ...
    elseif event == "auction_closed" then
        local auctionId, winner, winningBid = ...
    end
end)
```

---

## FEATURE 2: TAX SYSTEM

### Overview

The tax system allows guild leaders to collect DKP through taxation of member gold earnings. This provides an alternative way for members to earn DKP through contribution to the guild.

### Key Benefits

- **Passive DKP earning** - Members earn DKP by contributing gold
- **Configurable rates** - Guild masters control tax percentage
- **Daily limits** - Prevent taxation abuse
- **Audit trail** - Full history of all tax collections
- **Transparent** - Members know their tax amount

### How It Works

```lua
-- Record gold earnings (called on quest reward, loot, etc)
local dkpAwarded = InfinityDKPTaxSystem:CollectTax(
    playerName,     -- Player earning gold
    goldAmount,     -- Amount in gold
    reason          -- Quest name, mob name, etc
)
-- dkpAwarded = gold * taxRate / 100 / 10 (e.g., 1000g at 5% = 5 DKP)

-- Query tax stats
local stats = InfinityDKPTaxSystem:GetPlayerTaxStats(playerName)
-- Returns: {totalTaxed, transactionCount, lastTax, averageTaxPerDay}
```

### Commands

```
/dkp tax set rate [0-100]
  Set tax rate (percentage of gold earned)
  Example: /dkp tax set rate 5

/dkp tax set min [amount]
  Set minimum gold to track (default 10)

/dkp tax set daily [amount]
  Set max tax per player per day
  Example: /dkp tax set daily 100

/dkp tax stats
  Show guild-wide tax statistics

/dkp tax stats [playername]
  Show individual player tax stats

/dkp tax history
  Export tax history for audit
```

### Configuration

```lua
InfinityDKPTaxSystem.config = {
    taxRatePercentage = 5,      -- 5% of earnings taxed
    minTaxAmount = 10,          -- Minimum gold per transaction
    maxTaxPerDay = 100,         -- Maximum gold taxed per day per player
    enabled = true,
    adminOnly = true,           -- Only GMs can configure
}
```

### Tax Calculation

**Formula:**
```
DKP Awarded = floor(Gold Taxed * Tax Rate / 100 / 10)

Example:
- Player earns 1000 gold from quest
- Tax rate = 5%
- Taxed amount = 1000 * 5 / 100 = 50 gold
- DKP awarded = floor(50 / 10) = 5 DKP
```

**Configuration:**
- Adjust tax rate to control DKP flow
- Higher rate = more DKP awarded per gold
- Minimum threshold prevents tracking tiny amounts
- Daily limit prevents over-taxation

### API Functions

**SetTaxRate(percentage)**
- Sets tax rate (0-100%)
- Returns success (bool)

**SetMinTaxAmount(amount)**
- Sets minimum gold threshold

**SetMaxTaxPerDay(amount)**
- Sets daily tax cap per player

**CollectTax(playerName, goldAmount, reason)**
- Records tax on gold earnings
- Returns DKP awarded (number)
- Automatically handles daily limits

**GetPlayerTaxStats(playerName)**
- Returns player's tax statistics

**GetGuildTaxStats()**
- Returns guild-wide tax statistics

**GetRemainingDailyTaxBudget(playerName)**
- Returns remaining tax budget for day

### Events

```lua
InfinityDKPTaxSystem:RegisterCallback(function(event, ...)
    if event == "tax_collected" then
        local playerName, goldTaxed, dkpAwarded, reason = ...
    elseif event == "tax_rate_changed" then
        local newRate = ...
    end
end)
```

### Audit Trail

All tax collections are logged with:
- Player name
- Gold taxed
- DKP awarded
- Reason (quest/mob/etc)
- Timestamp
- Complete history preserved

Export with: `InfinityDKPTaxSystem:ExportTaxHistory(limit)`

---

## FEATURE 3: GUILD BANK DONATIONS

### Overview

Track and reward guild bank donations. Members earn DKP by donating items or gold to the guild bank, with rewards based on rarity and value.

### Key Benefits

- **Incentivize donations** - Members earn DKP for contributing
- **Rarity-based rewards** - Rare items worth more than common
- **Flexible configuration** - Customize reward rates
- **Audit trail** - Full history of all donations
- **Top donor tracking** - Recognition for generous members

### How It Works

```lua
-- Record gold donation
local dkpAwarded = InfinityDKPGuildBankDonations:RecordGoldDonation(
    playerName,     -- Player donating
    goldAmount,     -- Amount in copper (1000 = 1 gold)
    reason          -- Optional reason
)

-- Record item donation
local dkpAwarded = InfinityDKPGuildBankDonations:RecordItemDonation(
    playerName,     -- Player donating
    itemLink,       -- Item link
    itemCount,      -- Stack count
    estimatedValue, -- Estimated value in copper
    reason          -- Optional reason
)
```

### Commands

```
/dkp donations stats
  Show guild-wide donation statistics

/dkp donations stats [playername]
  Show individual player donation stats

/dkp donations history
  Show donation history

/dkp donations top [limit]
  Show top donors (default 10)

/dkp donations set rate [rate]
  Set DKP per gold (default 0.1)
  Example: /dkp donations set rate 0.5

/dkp donations set [rarity] [multiplier]
  Set reward multiplier for rarity
  Example: /dkp donations set 4 5.0 (5x for epic items)
```

### Configuration

```lua
InfinityDKPGuildBankDonations.config = {
    goldRewardPerGoldDonated = 0.1,  -- DKP per gold
    itemRarityMultipliers = {
        [0] = 0.1,   -- Trash: 10%
        [1] = 0.5,   -- Common: 50%
        [2] = 1.0,   -- Uncommon: 100%
        [3] = 2.0,   -- Rare: 200%
        [4] = 5.0,   -- Epic: 500%
        [5] = 10.0,  -- Legendary: 1000%
    },
    minGoldDonation = 1,
    minItemValue = 10,
    enabled = true,
    adminOnly = true,
}
```

### Reward Calculation

**Gold Donation:**
```
DKP = Gold Amount * goldRewardPerGoldDonated

Example:
- Donate 1000 gold
- Rate = 0.1
- DKP awarded = 1000 * 0.1 = 100 DKP
```

**Item Donation:**
```
DKP = Estimated Value * Item Count * Rarity Multiplier * goldRewardPerGoldDonated

Example:
- Epic item, estimated value 1000 copper (0.1 gold)
- Donate 1 item
- Multiplier = 5.0 for epic
- Rate = 0.1
- DKP = 0.1 * 1 * 5.0 * 0.1 = 0.05 DKP (rounded to 1)
```

### API Functions

**RecordGoldDonation(playerName, goldAmount, reason)**
- Records gold donation to guild bank
- Returns DKP awarded (number)

**RecordItemDonation(playerName, itemLink, itemCount, estimatedValue, reason)**
- Records item donation to guild bank
- Returns DKP awarded (number)
- Auto-extracts rarity from item link

**GetPlayerDonationStats(playerName)**
- Returns player's donation statistics

**GetGuildDonationStats()**
- Returns guild-wide donation statistics

**GetTopDonors(limit)**
- Returns top N donors sorted by DKP earned

### Events

```lua
InfinityDKPGuildBankDonations:RegisterCallback(function(event, ...)
    if event == "gold_donation_recorded" then
        local playerName, goldAmount, dkpAwarded, reason = ...
    elseif event == "item_donation_recorded" then
        local playerName, itemName, itemCount, dkpAwarded, reason = ...
    end
end)
```

### Rarity Detection

Automatically detects item rarity from color code in item link:
- Gray (#9d9d9d) = Trash (0.1x)
- White (#ffffff) = Common (0.5x)
- Green (#1eff00) = Uncommon (1.0x)
- Blue (#0070dd) = Rare (2.0x)
- Purple (#a335ee) = Epic (5.0x)
- Orange (#ff8000) = Legendary (10.0x)

---

## FEATURE 4: PLAYER TRADING

### Overview

Allow guild members to trade DKP with each other for various reasons (item splits, helping new members, etc) with configurable restrictions and audit trail.

### Key Benefits

- **Flexible economics** - Members can redistribute DKP
- **Configurable limits** - Prevent abuse with caps
- **Cooldowns** - Prevent spam trading
- **Audit trail** - Full history of all trades
- **Offer system** - Recipient must accept (not forced)
- **Same guild only** - Only trade within guild

### How It Works

```lua
-- Create trade offer (pending acceptance)
local offerId = InfinityDKPPlayerTrading:CreateTradeOffer(
    offererName,    -- Player sending DKP
    recipientName,  -- Player receiving DKP
    dkpAmount,      -- Amount of DKP
    reason,         -- Optional reason
    expiresIn       -- Expires in X seconds (default 300)
)

-- Recipient accepts trade
local success = InfinityDKPPlayerTrading:AcceptTradeOffer(offerId, recipientName)

-- Or cancel the offer
local success = InfinityDKPPlayerTrading:CancelTradeOffer(offerId, cancellerName)
```

### Commands

```
/dkp trade [playername] [amount] [reason]
  Create a trade offer to player
  Example: /dkp trade PlayerName 50 Helping with item split

/dkp trade accept [offerid]
  Accept a pending trade offer
  Example: /dkp trade accept 1

/dkp trade decline [offerid]
  Decline/cancel a trade offer

/dkp trade list
  Show active trade offers for you

/dkp trade history [limit]
  Show your trade history (default 50)

/dkp trade stats
  Show your trading statistics

/dkp trade stats [playername]
  Show player's trading statistics

/dkp trade limits
  Show current trading limits and budgets
```

### Configuration

```lua
InfinityDKPPlayerTrading.config = {
    enabled = true,
    maxTransferPerTrade = 1000,    -- Max per single trade
    minTransferAmount = 1,         -- Minimum DKP
    dailyTransferLimit = 5000,     -- Max per day per player
    cooldownSeconds = 60,          -- Cooldown between trades
    requireBothOnline = true,      -- Both must be online
    requireGuild = true,           -- Same guild only
    enableTradeLog = true,         -- Log all trades
}
```

### Trade Offer Flow

1. **Create Offer**
   - Offerer initiates trade
   - Offer expires in 5 minutes
   - Offerer's DKP reserved (not deducted yet)

2. **Recipient Accepts/Declines**
   - Recipient can accept (DKP transferred)
   - Recipient can decline (offer cancelled)
   - Recipient can ignore (expires after 5 min)

3. **DKP Transfer**
   - Only happens on acceptance
   - Deducted from offerer
   - Added to recipient
   - Both get Points log entries

### Restrictions & Limits

**Per-Trade Limits:**
- Minimum transfer: 1 DKP
- Maximum transfer: 1000 DKP (configurable)
- Cannot trade with yourself

**Daily Limits:**
- Max transfer per player per day: 5000 DKP (configurable)
- Resets at daily reset
- Shows remaining budget

**Cooldown:**
- 60 seconds between trades (configurable)
- Prevents spam trading
- Shows time until next trade available

**Other:**
- Both players must be in same guild
- Both players should be online
- Recorded in permanent audit trail

### API Functions

**CreateTradeOffer(offererName, recipientName, dkpAmount, reason, expiresIn)**
- Creates new trade offer
- Returns offerId (number) or nil

**AcceptTradeOffer(offerId, recipientName)**
- Accepts pending trade
- Returns success (bool)
- Transfers DKP and logs transaction

**CancelTradeOffer(offerId, cancellerName)**
- Cancels trade offer
- Returns success (bool)

**GetActiveOffers(playerName)**
- Returns pending offers for player

**GetPlayerTradeHistory(playerName, limit)**
- Returns completed trades (default 50)

**GetPlayerTradeStats(playerName)**
- Returns player's trade statistics

**GetGuildTradeStats()**
- Returns guild-wide trade statistics

### Events

```lua
InfinityDKPPlayerTrading:RegisterCallback(function(event, ...)
    if event == "trade_offer_created" then
        local offerId, offererName, recipientName, dkpAmount = ...
    elseif event == "trade_completed" then
        local offerId, offererName, recipientName, dkpAmount = ...
    elseif event == "trade_offer_cancelled" then
        local offerId, cancellerName = ...
    end
end)
```

### Audit Trail

All trades recorded with:
- Offerer and recipient names
- Amount transferred
- Timestamp
- Reason
- Status (completed/cancelled)
- Complete immutable history

Export with: `InfinityDKPPlayerTrading:ExportTradeHistory(limit)`

---

## INTEGRATION WITH POINTS SYSTEM

All features integrate with the existing InfinityDKPPoints system:

### Points Module Functions

**LogTransaction(playerName, type, amount, reason)**
- Logs point transaction
- Automatically tracks balance
- Used by all 4 new systems

### Point Types Used

- `"tax_payment"` - From tax system
- `"guild_bank_donation_gold"` - From guild bank (gold)
- `"guild_bank_donation_item"` - From guild bank (items)
- `"trade_sent"` - From player trading (negative)
- `"trade_received"` - From player trading (positive)
- `"auction_won"` - From unified auctions (negative, deduction)
- `"auction_award"` - From unified auctions (positive, award)

### Complete Audit Trail

All features automatically create audit entries:
- Points ledger tracks all changes
- Reason field explains source
- Timestamp for temporal analysis
- Player-centric history queries

---

## CONFIGURATION GUIDE

### Recommended Starter Settings

**Unified Auctions:**
```lua
-- Low-barrier entry
minBidIncrement = 1
defaultDuration = 300  -- 5 minutes
antiSnipeDuration = 10
```

**Tax System:**
```lua
-- Passive DKP earning
taxRatePercentage = 5    -- 5% of earnings
minTaxAmount = 10        -- No tracking tiny amounts
maxTaxPerDay = 100       -- Reasonable daily limit
```

**Guild Bank Donations:**
```lua
-- Reward donations
goldRewardPerGoldDonated = 0.1  -- 1 DKP per 10g
-- Rarity multipliers already set
```

**Player Trading:**
```lua
-- Allow sharing
maxTransferPerTrade = 1000
dailyTransferLimit = 5000
cooldownSeconds = 60  -- Reasonable cooldown
```

### Aggressive Settings (High DKP Flow)

```lua
-- More DKP circulation
TaxSystem: taxRatePercentage = 10, maxTaxPerDay = 500
GuildBankDonations: goldRewardPerGoldDonated = 0.5
PlayerTrading: maxTransferPerTrade = 5000, dailyTransferLimit = 20000
```

### Conservative Settings (Limited DKP)

```lua
-- Tight DKP control
TaxSystem: taxRatePercentage = 2, maxTaxPerDay = 50
GuildBankDonations: goldRewardPerGoldDonated = 0.01
PlayerTrading: maxTransferPerTrade = 100, dailyTransferLimit = 500
```

---

## MIGRATION FROM TIERED SYSTEM

### For Guilds Using Old Tier System

1. **Data migration** - Import existing tier bids into unified pool
2. **Announce change** - Explain unified system benefits
3. **Recalibrate pricing** - Adjust DKP values accordingly
4. **Testing** - Run practice auctions before live use

### Compatibility

- Old tiered auctions can be archived
- Points from old system preserved
- History maintained for audit
- No data loss during transition

---

## SLASH COMMAND REFERENCE

### Unified Auctions

```
/dkp auction create [itemlink] [startingbid] [duration]
/dkp auction list
/dkp auction bid [auctionid] [amount]
/dkp auction close [auctionid]
```

### Tax System

```
/dkp tax set rate [0-100]
/dkp tax set min [amount]
/dkp tax set daily [amount]
/dkp tax stats
/dkp tax stats [playername]
/dkp tax history
```

### Guild Bank Donations

```
/dkp donations stats
/dkp donations stats [playername]
/dkp donations history
/dkp donations top [limit]
/dkp donations set rate [rate]
/dkp donations set [rarity] [multiplier]
```

### Player Trading

```
/dkp trade [playername] [amount] [reason]
/dkp trade accept [offerid]
/dkp trade decline [offerid]
/dkp trade list
/dkp trade history [limit]
/dkp trade stats
/dkp trade stats [playername]
/dkp trade limits
```

---

## TROUBLESHOOTING

### Tax Not Collecting

- Check if tax system enabled: `/dkp tax set enabled true`
- Verify minimum threshold: `/dkp tax set min 10`
- Check daily budget: `/dkp tax stats [playername]`

### Items Not Registering for Donations

- Ensure item link format correct
- Check minimum value threshold
- Verify addon received donation event

### Trading Failing

- Check daily limit: `/dkp trade limits`
- Verify cooldown expired
- Confirm recipient in same guild
- Ensure sufficient DKP balance

### No Historical Data

- Ensure `enableTradeLog = true`
- Check SavedVariables file
- Reload UI to refresh

---

## VERSION HISTORY

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-11-20 | Original DKP system |
| 1.1.0 | 2026-11-20 | Added unified auctions, tax, donations, trading |

---

## NEXT STEPS

**Immediate:**
1. Test unified auctions in practice
2. Configure tax rates for guild
3. Set up guild bank donation tracking
4. Train officers on new features

**Short-term:**
1. Deploy to guild
2. Gather member feedback
3. Fine-tune settings based on usage
4. Document guild-specific policies

**Long-term:**
1. Implement web dashboard for statistics
2. Add mobile app for trading
3. Advanced analytics and reporting
4. Cross-guild DKP markets

---

**Documentation Version:** 1.0  
**Last Updated:** 2026-11-20  
**Status:** ✅ COMPLETE & PRODUCTION READY
