# InfinityGuide

Open **My Guides**, then **Edit / Sync**, to create guides, edit steps, manage
QuestieDB imports and guild presets. Deletion, step removal and publishing all
require a second click. **Manage published presets** lets you stop publishing
individual presets; already distributed copies remain.

`/infguide` opens the quest log. The **My Guides** button opens available guides.
No premade leveling routes are bundled.

- `/infguide create <name>` creates and selects a guide.
- `/infguide step <text>` appends a step to the selected guide (60 characters maximum).
- `/infguide quest <quest ID> <text>` adds a step completed by turning in that quest.
- `/infguide guides` lists guides; click one to select it.
- `/infguide select <id>` selects a guide by the ID shown in the list.
- `/infguide select none` or **Use none** disables the selected guide.
- Click a step to mark it complete or undo it.
- `/infguide unstep <number>` removes a step from the selected guide.
- `/infguide delete <id>` deletes a guide and its steps.

Guide data and progress are saved in InfinityCore. Quest turn-ins check off the
first matching unfinished step in the selected guide while the addon is loaded.
Other steps are checked manually; turn-ins missed while offline are not inferred.

## Optional QuestieDB source

When a compatible QuestieDB is detected, a prompt asks whether to allow imports.
`/infguide source allow|disable` changes that choice. With permission,
`/infguide import questie <first quest ID>` creates a selectable guide from the
linked quest IDs. It does not activate the guide or copy QuestieDB text.
Quest names are displayed from the game's cache when available. The list is not
a verified leveling route: prerequisites, faction, class, availability, and
branching are not checked.

## Guild sharing

Select a guide and click **Share with guild**, or use
`/infguide guild send <guide ID>`; `/infguide guild sendall` sends every saved
guide, boss-watch preset and shopping list. Sending publishes a snapshot for that guild.
After login, guild members request published snapshots from online peers;
`/infguide guild sync` requests them again. Accepted guild presets are also
republished so other members can receive them. At least one member holding a
published copy must be online; the game does not deliver messages to offline
players. Changes require sending the preset again.

Each recipient can save or discard a preset using the prompt or `/infguide guild
accept|discard`. Saving creates a new, unselected preset and never overwrites
existing ones. Accepted or discarded versions are not reoffered automatically;
an explicit send can offer them again. `/infguide guild published` lists local
publication IDs;
`/infguide guild unpublish <G:guide_ID|E:preset_ID|S:list_ID|all>` stops locally
republishing them. Already received copies remain on other characters and may
still be republished there. Deleting a local guide does not unpublish its
snapshot. Up to 100 presets may be published, and 100 received presets can wait
for review. Pending transfers are session-only. Progress is not shared. Only
share content you may distribute.

InfinityEncounter can also share player-created or DBM spell-ID boss-watch
presets over this channel; see its documentation. DBM scripts and boss
mechanics are not transferred. Its separate DBM integration displays supported
live DBM timers.

InfinityInventory can share player-created shopping lists through the same
channel; see its documentation.
