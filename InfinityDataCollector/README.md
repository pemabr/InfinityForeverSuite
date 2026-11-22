# InfinityDataCollector

The collector stores public quest-log details and unambiguous single-source
creature drops locally. Missing or protected data is not inferred.

The collection and guild-sharing switches are available under game settings
> AddOns > Infinity Suite > Infinity Data Collector, as well as in
`/datacollector settings`. On clients without nested categories, look for
Infinity Data Collector directly under AddOns.
The **Network** tab provides snapshot send/apply/discard, manual sync for each
guild knowledge channel, and buttons to open the crafter and guild-stock
directories. **Statistics** has external-database sync and auto-sync controls.

## Guild snapshots

- Both sender and receiver enable sharing with `/datacollector guild enable`
  or the checkbox in `/datacollector settings`.
- Send with `/datacollector guild send`. Recipients must be online and enabled.
- Recipients review the sender and record count with `/datacollector guild`,
  then use `/datacollector guild apply` or `/datacollector guild discard`.
- Disable with `/datacollector guild disable`.

Snapshots contain quest IDs, names and levels, plus creature/item IDs, names
and known item rarity. Quest text, locations and player information are not
included in the payload. This is a manual guild broadcast, not live auction
or point synchronization. Import adds missing records only; existing records
are unchanged. A snapshot is limited to 1,000 records.

## Live guild knowledge

`/datacollector guild live on` opts into automatic sharing and merging of observed
quest IDs, names and levels and unambiguous creature/item drop IDs, names and
known rarity. The settings tab has the same switch. Both players must opt in.
No quest text, progress, player locations or private notes are sent. Received
records do not replace existing names or known values; missing quest levels and
drop rarity may be filled in.

Online peers discover each other and reconcile their guild-specific knowledge
in pages, including observations missed while a member was offline. Reconciliation
runs periodically; `/datacollector guild live sync` requests the next peer now.
Transfers can take time and require at least one peer holding the data online.
After a send failure, sharing pauses briefly and later reconciliation retries
stored knowledge.
Only observations made with live sharing enabled, the current cached quest log
when enabling it, and records received through this channel are relayed;
existing databases and manual snapshots are not automatically published.
Each guild has a separate 10,000-record limit.
Disabling live sharing stops transfers but does not erase already received data.
Switching guilds disables live sharing until explicitly re-enabled. The
quest/drop channel does not synchronize DKP, bags, positions, auction prices
or full quest/encounter data. Separate location-sharing options are below.

The collector's **Knowledge** tab looks up locally collected or received quests
and creature drops by ID. Drop results are paginated.
Infinity Questie's `/questie search <name or ID>` also searches collected and
received quest names; these records do not supply quest locations.

## Guild gathering positions

With Infinity Gather loaded, `/datacollector guild nodes on` separately opts in
to sharing existing manually saved and automatically recorded herb and ore
positions, as well as future observations. Coordinates approximate the
player's location when collecting. Guild members must also opt in to exchange
and display them. The setting is independent of quest/drop sharing and can be
disabled with `/datacollector guild nodes off`; previously received positions
remain saved but hidden while disabled. `/datacollector guild nodes sync`
requests reconciliation with the next online peer. Disabling or changing guilds
stops sharing; prior recipients retain their copies. GatherMate2 live-source
data is never published. Each guild has a separate 10,000-position limit.

## Guild recipe reports

`/datacollector guild recipes on` separately opts into sharing your character
name and learned recipe IDs and names. Open each of your own profession windows
to report its currently visible recipes; linked and guild profession windows
are not scanned. Other opted-in members receive reports and reconcile missed
ones with online peers. `/datacollector guild recipes` opens a searchable
directory; `/datacollector guild recipes sync` requests the next peer.
The directory shows at most 200 results at a time; refine the search for more.

Reports are last-observed claims, not a guarantee of current professions,
materials, availability or ability to craft. Forgotten recipes are not removed
automatically. `/datacollector guild recipes off` stops and hides sharing, but
does not retract copies already received. Guild changes disable sharing. Each
guild has a separate limit of 10,000 character/profession/recipe reports.

## Guild quest-offer positions

`/datacollector guild offers on` separately opts into sharing the quest ID,
giver name and approximate player location when opening an NPC quest offer.
Both members must opt in and local gathering must be enabled. Existing
quest records are not published as positions. `/datacollector guild offers sync`
requests reconciliation; `off` stops sharing and hides received positions.
Guild changes disable sharing, but previously distributed copies remain.
Infinity Questie's `/questie locations <quest ID>` can show these approximate
offer positions and set waypoints, even without QuestieDB. They are not objective
or turn-in locations and may be outdated. Each guild has a 10,000-position limit.

## Guild world-boss reports

`/datacollector guild bosses on` separately opts into sharing successful
`ENCOUNTER_END` observations for bosses the player has registered in
Infinity World Boss. Only observations after enabling are shared; manually
recorded kills and estimated respawn intervals are not sent. Peers must also
opt in. `/datacollector guild bosses sync` requests reconciliation; `off`
stops sharing and hides received reports. Guild changes disable sharing, but
previously distributed copies remain.

Reports are unverified and may refer to a different layer; they do not update
local kill records or calculate spawn times. Infinity World Boss shows the most
recent guild report alongside locally registered bosses.

## Guild bag reports

With Infinity Inventory loaded, `/datacollector guild bags on` separately opts
into sharing your character name, **all carried bag item IDs and quantities**,
and observation times with other opted-in guild members. The bank and equipped
items are not scanned. Complete bag scans automatically update changed counts,
including zero when an item disappears; failed scans do not clear reports.
This setting applies to characters using the same collector settings. Search by
item ID with `/inv stock [item ID]` or `/datacollector guild bags`.

Reports are unverified, may be outdated, and do not guarantee availability,
tradeability or ownership; confirm with the player. Online peers reconcile
missed reports, and `/datacollector guild bags sync` requests the next peer.
`/datacollector guild bags off` stops and hides sharing, but cannot retract
copies already received; a guild change disables sharing. Each guild has a
10,000 character/item report limit.
