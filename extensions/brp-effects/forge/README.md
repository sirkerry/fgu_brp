# BRP Effects

FGU extension for the official Basic Roleplaying (BRP) ruleset.

Stock BRP has zero `EffectManager` usage anywhere in its own code. This
wires up five effect keywords covering every roll type BRP has:

- `CHECK: <mod>[, <name>]` — flat percentage bonus/penalty to Skill,
  Characteristic, and Power checks (e.g. `CHECK: 10, Spot`, or `CHECK: -20`
  with no filter to apply to every check).
- `ATK: <mod>[, <name>]` — flat percentage bonus/penalty to Attack rolls
  (e.g. `ATK: 10, Sword`). Matches against the weapon's own name and, as a
  fallback, its linked skill's name (e.g. `ATK: 10, Melee Weapons`), since
  a weapon's attack% is a stale snapshot of its linked skill's total and
  never sees a `CHECK` bonus on that skill otherwise.
- `DMG: <dice/mod>[, <weapon name>]` — bonus dice and/or flat mod to
  matching Damage rolls (e.g. `DMG: 1d4, Sword` or `DMG: 2`). Source-side
  only (the attacker's own bonus damage).
- `INIT: <mod>` — flat bonus/penalty to Initiative. No name filter;
  initiative isn't rolled "for" anything, so every active `INIT` effect on
  the actor just adds to the total.
- `ARMOR: <mod>` — flat damage reduction, floored at 0, applied to
  incoming damage. Unlike the other four, this is read from the
  **target's** effect list, not the source's — put it on whichever
  character/NPC should resist damage. No name filter; BRP has no
  damage-type/resistance concept to filter by, so it applies to all
  incoming damage. Stacks with, and applies before, the optional Hit
  Locations rule's own per-location AP subtraction.

`CHECK`/`ATK`/`DMG` match case-insensitively; brackets around the name
also work (`CHECK: 10 [Spot]`) but comma syntax is the documented form.

## Compatibility

- Official Basic Roleplaying (BRP) ruleset
- Purely additive — no stock ruleset file is edited
