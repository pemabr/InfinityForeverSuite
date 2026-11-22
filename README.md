# Infinity Forever Suite

Open the suite and use **Features > Open** to access loaded module windows.
The movable minimap button opens a grid of loaded modules; right-click opens
the suite. Enable or hide it in the suite settings or Game Settings > AddOns >
Infinity Suite. The map/quest, guild, spellbook/profession, character and
calendar, bank, guild bank and auction-house windows also have an **Infinity**
button for related tools. Menus open near their button, and actions open suite
windows rather than replacing Blizzard panels. If a Blizzard panel is
unavailable, use the minimap menu instead.
On the map, **Quest Waypoint** and **Quest Locations** use the selected quest. In professions,
**Recipe Reagents** checks the selected recipe when its data is available, and
**Guild Crafters** searches shared reports for that recipe.

Item tooltips show configured local Loot prices and recorded InfinityDKP awards
when available; refunded awards remain in the count but are excluded from
recorded GP/DKP averages. Enable enhanced tooltips in the suite settings.

- Navigation: **Manage** adds, removes and clears saved waypoints, saves the
  current position, and selects a quest waypoint. Deletion requires confirmation.
- Quest Log: **Search** finds known quests; select a result to inspect available
  locations. The first 200 results are shown. QuestieDB is optional and its
  indexing may take time.
- Attendance: **Start**, **End** and **Auto** control session tracking. Records
  are not saved across reloads.
- Profiler: **Thresholds** changes session-only alert limits; **Clear** requires
  confirmation.
- Analytics offers session start, end, refresh and confirmed history clearing.
  Native samples containing protected or unavailable data are marked incomplete.
- Details: **Report** opens a copyable damage and healing report for the
  selected session. Protected or incomplete data cannot be exported.
- Loot Manager: **Economy > Item prices** sets local tooltip prices after
  confirmation; prices are not guild-synchronized.
- Loot Manager **Economy > Transactions** records manual local earnings and
  spending in copper; it neither moves money nor automatically detects trades.
- Loot Manager **Tracking** supports manual item, money, cost and kill records;
  it does not collect these automatically. Paused time is excluded from rates.
  **Sessions** lists saved sessions; select one to inspect its items. Unfinished
  sessions from an earlier reload have an unavailable duration.
- Loot Manager **Loot history** displays manually entered, session-only award
  records. Recording an award there does not award an item or points.
- Loot Manager **Tax settings** edits local rates and item filters, and can
  manually award points to registered InfinityDKP players in DKP mode. No gold
  or items are transferred; sync points separately. InfinityDKP has separate filters.
- Loot Manager **Commissions > Manage** registers, completes and deletes local
  commissions. Daily status follows the client's calendar date, not the server reset.
- Loot Manager **Raid manager** records local raid members and awards. Its
  raid-only balances are separate from Loot EP/GP and InfinityDKP; no item is sent.
- Loot Manager **Guild DKP trade** opens InfinityDKP's guild trade controls;
  those operate on InfinityDKP balances, not local Loot EP/GP. The legacy
  `/dkptrade <player> <amount>` also starts an InfinityDKP trade offer. In the
  DKP actions window, select an active trade to fill its sender and ID.
- DKP Actions **Open local loot refunds** reverses a recorded DKP or GP award
  after confirmation. It does not move an item or synchronize guild points.
- DKP Actions **Open local point transactions** lists matching
  locally recorded transactions. It is not a complete audit of every change
  or incoming guild snapshot. `/pointhistory player <name>` opens the same view.
- DKP Actions **Open live guild bank log** requests an item tab or the money
  log while the guild bank is open. It displays the recent records the client
  can read; it neither stores nor shares them and never changes points or items.
- DKP Actions **Open copyable DKP reports** shows local full, priority,
  attendance and loot reports in a selectable text window.
- DKP Actions **Configure local boss kill awards** optionally awards DKP or EP
  for successful encounters to registered local players recorded as present
  at any time. It is off by default; synchronization remains manual. See the
  [InfinityDKP guide](InfinityDKP/README.md) for skipped-award conditions.
- Guild Manager **DKP → Manage local guild DKP** adjusts its own local roster
  balances after confirmation. This older store is separate from InfinityDKP;
  its records cannot be synchronized through InfinityDKP snapshots.
- Guild Manager **Roster** provides member search and selection. **Open shared
  bags** opens a member's voluntarily shared, potentially outdated item counts;
  it does not expose bank contents or item slots.
- GatherPath can manually record a herb position and display a nearest-neighbor
  order for current-zone nodes. These records are session-only; map-coordinate
  distances are not yard estimates.
- Consumables, Gear Tracker and Guild Roster Manager expose scans and filters
  in their respective windows. Gear Tracker also offers a copyable equipment
  export. The separate Loot History window displays
  session records and accepts manual records, but does not collect loot
  automatically.
- Guild Manager: **Events > New Event** and **Raiding > New Raid** open the
  local event and raid manager. Click an action twice to confirm; select a raid
  from the list to start or complete it and record participants, bosses or loot.
  These records are local, not guild-synchronized or Blizzard Calendar events.

The separate Loot History tracker uses `/lootlog`; `/loothistory` (`/lh`)
belongs to InfinityLoot. Its records are distinct from InfinityLoot's awards.
Changes to addon TOC files require a complete game restart. Mock tests do not
replace testing the interface and protected APIs in the WoW client. Some legacy
actions and reports still require slash commands.
