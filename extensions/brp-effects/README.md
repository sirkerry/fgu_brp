# BRP Check Effects

FGU extension for the official Basic Roleplaying (BRP) ruleset.

Adds a `CHECK` effect keyword: a flat percentage bonus/penalty to Skill,
Characteristic, and Power checks, filterable by name (e.g. `CHECK: 10,
Spot`, or `CHECK: -20` with no filter to apply to every check). The name
is matched case-insensitively; brackets around the name also work
(`CHECK: 10 [Spot]`) but comma syntax is the documented form.

## Why

Stock Basic Roleplaying has **zero `EffectManager` usage anywhere in its
own code** — confirmed via direct source read, not assumed. The generic
CoreRPG Effects list is present on the Combat Tracker (inherited
scaffolding every CoreRPG ruleset gets), but nothing in BRP ever reads it.
This is the first piece of CoreRPG's Effects system actually wired up to a
BRP mechanic — specifically the "Pattern A" checks: Skill, Characteristic,
and Power rolls, which all share an identical "roll under %" shape.

## How It Works

`ActionSkill.getRoll`, `ActionAbility.getRoll`, and `ActionPowers.getRoll`
(`manager_action_skill.lua`, `manager_action_ability.lua`,
`manager_action_powers.lua`) are near-identical: each builds `rRoll.nTarget`
from a precomputed total/base, then adds the modifier tray's flat numeric
stack (`ModifierStack.getStack()`) before returning. There's no mod-handler
stage for any of these three roll types — only result handlers are
registered — so the tray stack, and now the `CHECK` effect bonus, is
applied inline in `getRoll()` itself, matching the ruleset's own existing
pattern rather than introducing a new pipeline stage that doesn't otherwise
exist here.

`scripts/manager_brp_effects.lua` wraps all three `getRoll` functions
(confirmed the only definition site for each, so direct wraps are safe).
Each roll type already exposes an identifying field on `rAction` (used for
its own chat text), reused here as the effect filter: `rAction.label`
(skill name or power name) and/or `rAction.stat` (characteristic name).

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
- Doesn't touch Attack rolls, Damage rolls, or Initiative — those are
  separate choke points with their own shapes, not yet covered

## Installation

Drop the `brp-effects` folder into your Fantasy Grounds Unity
`extensions/` directory and enable it when loading a Basic Roleplaying
campaign.
