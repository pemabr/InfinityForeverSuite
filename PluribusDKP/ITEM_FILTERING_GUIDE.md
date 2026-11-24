# PluribusDKP Item Filtering Guide

## Overview

The Tax System and Guild Bank Donations modules now support powerful item filtering capabilities through whitelisting and blacklisting. This allows guild leadership to have fine-grained control over which items are taxed or contribute to donations.

## Filtering Modes

### Blacklist Mode (Default)
In blacklist mode, all items are taxed/credited **except** those on the blacklist. This is the default mode and is useful when you want to tax most items but exclude a few.

**Use cases:**
- Exclude vendor trash from taxation
- Exclude quest items from donations
- Exclude BoP items from contributions

### Whitelist Mode
In whitelist mode, **only** items on the whitelist are taxed/credited. All other items are ignored. This is useful when you want a strict set of items.

**Use cases:**
- Only tax valuable crafting materials
- Only credit epic/legendary donations
- Only tax items above a certain value threshold

## Tax System Filtering

### Configuration

Enable or disable whitelist mode:
```
/dkp tax whitelist mode on    -- Enable whitelist mode (only listed items taxed)
/dkp tax whitelist mode off   -- Disable whitelist mode (use blacklist instead)
```

### Adding Items

Add items to whitelist:
```
/dkp tax whitelist add 2589    -- Add specific item ID to whitelist
```

Add items to blacklist:
```
/dkp tax blacklist add 2589    -- Add specific item ID to blacklist
```

### Removing Items

Remove from whitelist:
```
/dkp tax whitelist remove 2589
```

Remove from blacklist:
```
/dkp tax blacklist remove 2589
```

### Viewing Filters

List all whitelisted items:
```
/dkp tax whitelist list
```

List all blacklisted items:
```
/dkp tax blacklist list
```

### Clearing Filters

Clear entire whitelist:
```
/dkp tax whitelist clear
```

Clear entire blacklist:
```
/dkp tax blacklist clear
```

## Guild Bank Donation Filtering

The donation system uses identical filtering logic to the tax system.

### Configuration

Enable or disable whitelist mode for donations:
```
/dkp donations whitelist mode on    -- Only whitelisted items award DKP
/dkp donations whitelist mode off   -- Blacklist mode (default)
```

### Adding Items

Add items to whitelist:
```
/dkp donations whitelist add 2589
```

Add items to blacklist:
```
/dkp donations blacklist add 2589
```

### Removing Items

Remove from whitelist:
```
/dkp donations whitelist remove 2589
```

Remove from blacklist:
```
/dkp donations blacklist remove 2589
```

### Viewing Filters

List whitelisted items:
```
/dkp donations whitelist list
```

List blacklisted items:
```
/dkp donations blacklist list
```

### Clearing Filters

Clear entire whitelist:
```
/dkp donations whitelist clear
```

Clear entire blacklist:
```
/dkp donations blacklist clear
```

## Finding Item IDs

Item IDs can be found in several ways:

### Method 1: Hover Over Item in Chat
Hover over an item link in chat and check the item ID in the item link format: `|Hitem:ITEMID:...|h[name]|h`

### Method 2: Use Item Link
Right-click an item and shift-click it into chat. The item link will appear. Extract the ID from the link.

### Method 3: Addon Database
If you have an addon database like Questie or DBM, you can look up item IDs there.

### Method 4: WoW Database Websites
Use websites like:
- Classic WoW Database: https://classicdb.ch/
- Vanilla WoW Database: https://www.vanillawowdb.com/

## Practical Examples

### Example 1: Exclude Trash from Taxation

**Goal:** Tax all items except vendor trash

1. Enable blacklist mode (default):
   ```
   /dkp tax whitelist mode off
   ```

2. Find the item ID for common trash items (e.g., 2589 = Blasted Boar Meat)

3. Add trash items to blacklist:
   ```
   /dkp tax blacklist add 2589
   /dkp tax blacklist add 2590    -- Another trash item
   /dkp tax blacklist add 2591    -- Another trash item
   ```

Now all items are taxed except the blacklisted trash.

### Example 2: Only Tax Crafting Materials

**Goal:** Only tax valuable crafting materials, not equipment

1. Enable whitelist mode:
   ```
   /dkp tax whitelist mode on
   ```

2. Clear existing whitelist:
   ```
   /dkp tax whitelist clear
   ```

3. Add only crafting materials to whitelist:
   ```
   /dkp tax whitelist add 2320    -- Mithril Ore
   /dkp tax whitelist add 2321    -- Mithril Bar
   /dkp tax whitelist add 2771    -- Thorium Ore
   /dkp tax whitelist add 3575    -- Thorium Bar
   ```

Now only these specific materials are taxed.

### Example 3: Only Credit Epic & Legendary Donations

**Goal:** Only reward DKP for epic and legendary item donations

1. Enable whitelist mode for donations:
   ```
   /dkp donations whitelist mode on
   ```

2. Clear existing whitelist:
   ```
   /dkp donations whitelist clear
   ```

3. Add only epic/legendary item IDs:
   ```
   /dkp donations whitelist add 1234    -- Some epic item
   /dkp donations whitelist add 5678    -- Some legendary item
   -- Add many more epic/legendary items
   ```

Now only donations of whitelisted items award DKP.

## Integration with Direct DKP Configuration

Item filtering works seamlessly with the direct DKP amount configuration:

**Example:** Tax at a rate of 1 DKP per 50 gold, only on crafting materials

```
/dkp tax set rate 0.02           -- 0.02 DKP per gold = 1 DKP per 50 gold
/dkp tax whitelist mode on       -- Enable whitelist mode
/dkp tax whitelist clear         -- Clear existing items
/dkp tax whitelist add 2320      -- Add Mithril Ore
/dkp tax whitelist add 2321      -- Add Mithril Bar
-- ... add more crafting materials
```

## API Functions (For Custom Scripts)

### TaxSystem

```lua
-- Set whitelist mode
TaxSystem:SetWhitelistMode(enabled)

-- Whitelist operations
TaxSystem:WhitelistItem(itemId)
TaxSystem:UnwhitelistItem(itemId)
TaxSystem:GetWhitelist()
TaxSystem:ClearWhitelist()

-- Blacklist operations
TaxSystem:BlacklistItem(itemId)
TaxSystem:UnblacklistItem(itemId)
TaxSystem:GetBlacklist()
TaxSystem:ClearBlacklist()

-- Check if item passes filters
TaxSystem:ShouldTaxItem(itemId)  -- Returns true if item should be taxed
```

### GuildBankDonations

```lua
-- Set whitelist mode
GuildBankDonations:SetWhitelistMode(enabled)

-- Whitelist operations
GuildBankDonations:WhitelistItem(itemId)
GuildBankDonations:UnwhitelistItem(itemId)
GuildBankDonations:GetWhitelist()
GuildBankDonations:ClearWhitelist()

-- Blacklist operations
GuildBankDonations:BlacklistItem(itemId)
GuildBankDonations:UnblacklistItem(itemId)
GuildBankDonations:GetBlacklist()
GuildBankDonations:ClearBlacklist()

-- Check if item passes filters
GuildBankDonations:ShouldAwardDKP(itemId)  -- Returns true if item should award DKP
```

## Events

Both modules trigger events when filters are modified:

```lua
-- Events triggered by TaxSystem
"whitelist_mode_changed"    -- args: (enabled)
"item_whitelisted"          -- args: (itemId)
"item_unwhitelisted"        -- args: (itemId)
"item_blacklisted"          -- args: (itemId)
"item_unblacklisted"        -- args: (itemId)
"whitelist_cleared"         -- no args
"blacklist_cleared"         -- no args

-- Same events triggered by GuildBankDonations
```

## Troubleshooting

### Items still being taxed after blacklisting
- Verify you're in **blacklist mode** (not whitelist mode)
- Use `/dkp tax blacklist list` to confirm the item ID is in the list
- Ensure you used the exact item ID without extra characters

### No items being taxed
- Check if you're in **whitelist mode** with an empty whitelist
- Use `/dkp tax whitelist list` and `/dkp tax whitelist mode` to verify settings
- If you want to tax all items, use `/dkp tax whitelist mode off`

### Unclear if whitelist mode is on
- Check with: `/dkp tax whitelist mode`
- Current mode is printed in chat

### Performance with large filter lists
- If you have more than 1,000 items in your filters, consider:
  - Using the opposite mode (whitelist vs blacklist)
  - Combining multiple similar items into categories
  - Reviewing your filter strategy

## Best Practices

1. **Document your filters**: Keep a note of why certain items are whitelisted/blacklisted
2. **Review periodically**: Remove items that are no longer relevant
3. **Communicate changes**: Inform guild members when filter settings change
4. **Test before going live**: Test your filter settings in a low-impact scenario first
5. **Keep backups**: Before making major filter changes, export your current settings
6. **Use whitelist mode sparingly**: Whitelist mode is more restrictive and requires maintenance
7. **Be inclusive by default**: Unless you have a specific reason, use blacklist mode
