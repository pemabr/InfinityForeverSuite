# Infinity Inventory

The inventory window opens guild stock and a **Reagents** checker. Enter a
recipe ID and quantity after opening its profession; only basic bag materials
are checked. When a profession recipe is selected, the reagent window fills
and checks it automatically for one craft. Shopping lists can be deleted with
two clicks on **Delete**.

`/inv` opens a searchable item grid for the current character's bags. Left-click
moves an item or places it into an empty slot; right-click uses it. Alt-click
opens its auction-price search. During combat, use the game bags instead.
Shift-click links an item in an active chat; split stacks using **Game Bags**,
which opens the normal interface.

**Inventories** opens a searchable character and bank selector. Each selection
opens a separate item-grid window with its own item search. This character's
open bank is interactive; other characters' bags and banks, and closed-bank
views, are read-only snapshots. Bag snapshots are saved locally as they update;
bank snapshots are saved only while visiting the bank. Visit each character and
its bank before expecting them to appear. If a previously populated bank
looks empty when first opened, the old snapshot is retained; **Refresh bank**
explicitly confirms a new empty view. Snapshots can be incomplete or outdated.

Guild members appear only when their voluntary bag reports are available.
Their windows show reported item totals, not actual slot positions or bank
contents. Each item tooltip shows its report time. These reports can be stale
or incomplete and cannot be used to move another player's items. **Guild
sharing** opens the Data Collector settings; sharing remains opt-in.

`/inv recipe <recipe ID> [quantity]` checks basic reagents in bags only.

`/inv crafters` opens the guild recipe-report directory when Infinity Data
Collector is enabled. Members opt in separately with
`/datacollector guild recipes on` and open their own profession windows.
Reports can be outdated; confirm with the crafter.

`/inv stock [item ID]` searches voluntary guild bag reports by item ID. Sharing requires
Infinity Data Collector and Infinity Inventory and is separately enabled with
`/datacollector guild bags on`. It shares all carried bag item IDs and counts;
bank and equipped items are excluded. Reports can be outdated or unverified.

At an open auction house, `/inv price [item ID]` opens the read-only price window.
Enter an item ID and search, or click a bag item. Only one explicit query is made;
there is no automatic scanning. Results use the base item key and can differ for
item variants. Partial results, the first-200 limit, unavailable entries and
timeouts are marked. Other addons and the game share auction search results.
Purchases, bids, listing and cancellation remain in the game's interface.

`/inv list` opens shopping lists. Enter a name and click **New**; select existing
lists with **Lists**. Enter an item ID and target quantity, then **Set**; **Remove**
removes the entered ID. Clicking an item searches its prices at the auction house.
The targets do not buy items or subtract bag stock.

Commands: `/inv list create <name>`, `/inv list use <id|none>`, `/inv list set
<item ID> <quantity>`, `/inv list remove <item ID>`, `/inv list delete <id>`,
and `/inv list share [id]`. Each list accepts up to 200 unique items. Up to 100
lists are stored locally. **Share** publishes the selected snapshot through
InfinityGuide; guild members may save or discard it without selecting it.
`/infguide guild sync`, `published`, and `unpublish S:<id>` also apply to these
snapshots. Changes require sharing again; existing copies are not removed.
InfinityGuide must be enabled for guild sharing. The character holding a copy
must be online for another player to receive it.
