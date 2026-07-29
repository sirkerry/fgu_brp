# BRP Check Effects

FGU extension for the official Basic Roleplaying (BRP) ruleset.

Adds three effect keywords:

- `CHECK: <mod>[, <name>]` — flat percentage bonus/penalty to Skill,
  Characteristic, and Power checks (e.g. `CHECK: 10, Spot`, or `CHECK: -20`
  with no filter to apply to every check).
- `ATK: <mod>[, <name>]` — flat percentage bonus/penalty to Attack rolls
  (e.g. `ATK: 10, Sword`). Matches against the weapon's own name and, as a
  fallback, its linked skill's name (e.g. `ATK: 10, Melee Weapons`) — see
  "Weapon attack% is a stale snapshot" below for why the fallback exists.
- `DMG: <dice/mod>[, <weapon name>]` — bonus dice and/or flat mod to
  matching Damage rolls (e.g. `DMG: 1d4, Sword` or `DMG: 2`). Source-side
  only (the attacker's own bonus damage) — a target-side armor/resistance
  effect is a different, not-yet-built piece.

All three match case-insensitively; brackets around the name also work
(`CHECK: 10 [Spot]`) but comma syntax is the documented form.

## Why

Stock Basic Roleplaying has **zero `EffectManager` usage anywhere in its
own code** — confirmed via direct source read, not assumed. The generic
CoreRPG Effects list is present on the Combat Tracker (inherited
scaffolding every CoreRPG ruleset gets), but nothing in BRP ever reads it.
This is the first piece of CoreRPG's Effects system actually wired up to a
BRP mechanic — specifically the "Pattern A" checks (Skill, Characteristic,
and Power rolls, which all share an identical "roll under %" shape),
Attack rolls (which turn out to share the same shape under a different
field name), and Damage rolls (a genuinely different shape — see below).

## How It Works

`ActionSkill.getRoll`, `ActionAbility.getRoll`, `ActionPowers.getRoll`, and
`ActionAttack.getRoll` (`manager_action_skill.lua`,
`manager_action_ability.lua`, `manager_action_powers.lua`,
`manager_action_attack.lua`) are near-identical: each builds
`rRoll.nTarget` (Attack: `rRoll.nBase`) from a precomputed total/base, then
adds the modifier tray's flat numeric stack (`ModifierStack.getStack()`)
before returning. There's no mod-handler stage for any of these four roll
types — only result handlers are registered — so the tray stack, and now
the `CHECK`/`ATK` effect bonus, is applied inline in `getRoll()` itself,
matching the ruleset's own existing pattern rather than introducing a new
pipeline stage that doesn't otherwise exist here.

`ActionDamage.getRoll` (`manager_action_damage.lua`) is a genuinely
different shape: no percentage/target number and no
`ModifierStack.getStack()` call anywhere in that file, just a flat dice
pool (`rRoll.aDice`) and flat mod (`rRoll.nMod`) built by summing
`rAction.clauses`. `DMG` adds directly to that dice pool/mod instead.

`scripts/manager_brp_effects.lua` wraps all five `getRoll` functions
(confirmed the only definition site for each, so direct wraps are safe).
Each roll type already exposes an identifying field on `rAction` (used for
its own chat text), reused here as the effect filter: `rAction.label`
(skill/power/weapon name) and/or `rAction.stat` (characteristic name). Both
PC and NPC damage-roll scripts set `rAction.label` to the weapon's name
even though `manager_action_damage.lua` itself never reads that field for
anything.

**Weapon attack% is a stale snapshot, not a live total.**
`char_weapon.lua`'s `updateAttack()` looks up a weapon's linked skill by
name and copies that skill's stored `total` DB field straight into the
weapon's own `attack` field — it never goes through a roll, so it never
sees a `CHECK` effect bonus on the underlying skill (that only applies
inside `ActionSkill.getRoll` at roll time). Since `rAction` only ever
carries the weapon's name for an Attack roll, not its linked skill, `ATK`
also looks up the weapon's own `baseskill` DB field directly (both PC and
NPC weapon rows share the same `.weaponlist` datasource and field name),
so a `CHECK`- or `ATK`-tagged effect can still target attacks by their
underlying skill name even though the roll itself never touches that
skill.

Name matching is done by hand rather than via `EffectManager.getBonusMod`'s
own `tFilter` option — confirmed via direct source read that CoreRPG's tag
parser keeps a bracketed filter's brackets literally in the parsed text
(`"[Spot]"` parses to the remainder string `"[Spot]"`, brackets included),
and the underlying Set-based match is a raw, case-sensitive string
comparison with no normalization anywhere in that path. A name typed in
its natural case, or wrapped in brackets, would silently never match using
that built-in mechanism. Instead, `getCompsDataByTag()` is called with no
filter (returns every active `CHECK` component, already correctly
respecting active state/expiration/conditionals) and each component's own
tags are compared here with brackets stripped and case folded on both
sides.

## Compatibility

- Official Basic Roleplaying (BRP) ruleset
- Purely additive — no stock ruleset file is edited
- Doesn't touch target-side armor/resistance (damage reduction) or
  Initiative — those are separate choke points with their own shapes, not
  yet covered

## Installation

Drop the `brp-effects` folder into your Fantasy Grounds Unity
`extensions/` directory and enable it when loading a Basic Roleplaying
campaign.
