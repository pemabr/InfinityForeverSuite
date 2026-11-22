# Infinity Gather

`/gather` opens saved gathering positions and waypoints. Manual and automatic positions
are stored locally. The world map can show up to 500 positions when ForeverCore's
map canvas is available; waypoints use up to 200 positions on the player's current
map, in approximate coordinate order, not a pathfinding route.

With Infinity Data Collector, `/datacollector guild nodes on` separately enables
automatic sharing of saved and future player-recorded herb and ore positions.
This reveals approximate collection locations to opted-in guild members. Shared
positions are included in the current-map list, pins and waypoints; turn them
off with `/datacollector guild nodes off`. Removing a local position does not
retract shared copies.

If GatherMate2 is loaded, Infinity Gather asks whether to display its herb and ore
positions as an optional live source. `/gather source on`, `/gather source off` and
`/gather source status` change or inspect the choice; the GatherMate2 button toggles it.
GatherMate2's current node
filters apply. Saved positions take priority when limits are reached. Source positions
are read from the loaded addon when the map or waypoint list is refreshed; they are
not imported, saved, or shared with the guild. GatherMate2 must remain loaded to use
them. Other GatherMate2 node types and features are not included.
