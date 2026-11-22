# Infinity Healer

`/healer` opens the group-frame controls. `/healer group` opens the group
cooldown and effect report. Sharing is **off by default** and is enabled
per character with the checkbox-like row in `/healer` or `/healer group on`;
it is also under game settings > AddOns > Infinity Suite > Infinity Healer
(or Infinity Healer directly, on clients without subcategories).
`/healer group off` stops sending and receiving. Both players need the addon
and must enable this option. It shares readable spell IDs, cooldown and
charge information and buffs/debuffs on your character with the current
party, raid or instance group, including non-guild members. The option remains
enabled for later groups until turned off. Others may retain the last reports
until they become stale or the group changes.

The addon discovers cooldowns from your successful casts while sharing is on.
`/healer watch <spell ID>` also watches a specific spell, including when
ready; `/healer unwatch <spell ID>` removes the explicit watch. Cast spells
may be discovered again. Up to 60 explicit and 60 automatically discovered
spells are tracked. Discovery is session-only. `/healer group sync` requests
fresh reports from the group.

In the healer window, enter a spell ID and click a binding to assign it; enter
`clear` and click it to remove the binding. Enter a scale and click **Set
Scale**. The group report window has a spell-ID field and **Watch ID**,
**Unwatch**, and **Sync** buttons.
**Watch list** shows explicitly watched spells; click one to remove it.

Only public values exposed by the client are sent. Protected or unavailable
values are omitted and reports marked partial; no restrictions are bypassed.
Effects are capped at 80 helpful and 80 harmful auras. Cooldowns, charges and
effects are unverified, approximate observations, not authoritative availability; network
delay, protected data and client APIs may prevent or delay updates. Reports
show their age, are marked stale after 90 seconds, and group changes clear
them. Use Previous/Next in the report window to view all entries.
