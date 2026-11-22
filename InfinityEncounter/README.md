# InfinityEncounter

Open **Controls** in the encounter window for manual timers, watches, boss
presets, DBM options and imports. Applying or deleting a preset replaces or
removes local data only after confirmation; shared copies remain elsewhere.

The encounter window shows detected casts and timers supplied by the client's
native encounter timeline. Timers can also be started manually with
`/encounter timer <seconds> <name>`.

The Journal button, or `/encounter journal`, lists native Encounter Journal
entries for the current map. Use `/encounter journal <journal ID>` to view an
entry and its available mechanics. These IDs are journal IDs, not encounter
event IDs. Journal text is informational and does not create timers or alerts.
The client must expose the journal APIs and have journal data for that instance;
the journal's current difficulty can affect available text.
If the journal has not been initialized yet, listing encounters selects the
current instance in the native journal. This initial selection is only done
outside combat.

Use `/encounter watch add <spell ID> [label]` to alert on a visible boss cast,
`/encounter watch` to list watches, and `/encounter watch remove <spell ID>` to
remove one. Watches are saved in InfinityCore. Journal entries can show spell
IDs. Alerts require public boss unit spellcast events; protected or unavailable
event data cannot trigger them. Instant casts alert on completion.

Save the current watches as a reusable boss preset with `/encounter preset
create <name>`. `/encounter preset list` lists IDs; `/encounter preset use <id>`
replaces the current watches with a preset, and `/encounter preset use none`
clears them. `/encounter preset delete <id>` deletes a saved preset without
changing current watches. A preset contains 1–200 unique spell IDs and labels;
labels are limited to 60 bytes and cannot contain `|`.

With InfinityGuide enabled, `/encounter preset send <id>` shares a preset with
online guild members running both addons. They choose whether to save it; saving
does not activate it. `/infguide guild accept|discard` also handles these
invitations. Sending publishes a snapshot for later guild sync; see the
InfinityGuide documentation for availability and unpublishing.

When DBM is detected, a prompt offers to display its public live timers.
`/encounter dbm on|off` changes the choice. This requires DBM to remain loaded;
protected timer data is not displayed, and DBM and the native timeline may
show the same ability.

A separate prompt controls DBM spell-ID imports; change the choice with
`/encounter dbm import on|off`. `/encounter dbm modules [filter]` lists loaded
module IDs. `/encounter dbm import <module ID>` creates an unselected boss-watch
preset containing the module's public numeric spell IDs with generic labels.
DBM loads many modules only when entering the relevant instance. Invalid,
non-numeric, and protected IDs are skipped; imports exceeding 200 IDs are
rejected. This does not import encounter scripts, timings, mechanics, or DBM
settings. It cannot guarantee that every listed spell is a detectable boss cast.
