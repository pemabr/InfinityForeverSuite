# InfinityDKP

The DKP window's **DKP Actions** button opens controls for points, snapshots,
auctions, trades and tax/donation filters. Mutating actions require a second
click. Reports labelled “in chat” still write their output to the chat window.
**Open copyable DKP reports** displays full, priority, attendance and loot
reports in a selectable text window. Editing that text does not change records.

**Open local point transactions** shows matching logged records, 200 per page;
it is not a complete audit of every balance change or incoming snapshot.
**Open local loot refunds** reverses a recorded DKP or GP loot award after
confirmation. Both are local: no items move and guild points are not synced.
The DKP tax/donation filters persist locally and do not automatically
process bank deposits. With administrator-only settings enabled, tax and
donation configuration requires a guild master, rank-1 member, or a recognized
suite administrator. **Open DKP tax and donation configuration** exposes the
local rates, thresholds, modes and rarity multipliers; each change requires a
second click. It also lists the configured filters, which can be edited in DKP
Actions. These settings are separate from InfinityLoot's tax settings.

**Open live guild bank log** requests a selected item tab or money log at an
open guild bank. The view is read-only, session-only and limited to the recent
records and permissions exposed by the client. It does not award points.
`/bankdeposit` also opens this view.

**Configure local boss kill awards** enables an optional automatic award.
It is off by default. Choose DKP for the DKP system or EP for EPGP, and a
positive integer amount. On a successful matching encounter, all registered
local players recorded as present at any point receive that amount, including
players who left before the kill. Unregistered players are skipped with a
warning. Incomplete/protected attendance, incompatible system, invalid
balances, or a sending snapshot prevent the whole award. An encounter record
is awarded at most once; this is not lockout-based duplicate prevention.
The transactions are local and guild synchronization remains manual.
If a boss award follows an applied guild snapshot, snapshot undo is disabled
to avoid discarding that award.

## Guild auctions

The guild master starts one session-only auction with
`/dkp guildauction create <starting bid> <seconds> <item link>`.
Shift-click an item to insert its link. The starting bid must be a positive
integer and the duration must be between 1 and 3600 seconds.

Online guild members with InfinityDKP can bid with
`/dkp guildauction bid <amount>`. The guild master validates and broadcasts
accepted bids; the highest accepted bid wins. The master may use
`/dkp guildauction close` or `/dkp guildauction cancel`. Members who missed
the start can request the current auction with `/dkp guildauction sync`.
The Auctions tab shows the received auction.

This is not a loot distribution or points transaction: hand out the item and
record the points separately, for example with `/dkp spend` or `/dkp award`.
Bids are not checked against point balances. Only online guild members receive
messages, and auctions do not survive a reload or disconnect. If a closing
message fails, the master must retry `/dkp guildauction close`.
All participants need the updated addon and a loaded guild roster.

`/dkp auction` remains a separate, local-only auction.
