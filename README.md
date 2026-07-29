# fgu_brp

Fantasy Grounds Unity extensions for the official Basic Roleplaying (BRP)
ruleset, by Kerry Harrison (sirkerry).

Each extension lives in its own folder under `extensions/`, fully
self-contained with its own workflow scripts (`backup.sh`/`deploy.sh`/
`sync-to-repo.sh`/`restore.sh`/`build-ext.sh`) and README — all FGU dev
happens live at `~/.smiteworks/fgdata/extensions/<name>/`, never via
symlink; these repo folders are git-tracked backups synced with
`sync-to-repo.sh`.

## Extensions

- **[brp-effects](extensions/brp-effects/README.md)** — Check Effects.
  Stock BRP has zero `EffectManager` usage anywhere in its own code; this
  wires up the first piece of CoreRPG's Effects system to a BRP mechanic.
  Adds `CHECK` (flat percentage bonus/penalty to Skill, Characteristic, and
  Power checks), `ATK` (same, for Attack rolls), `DMG` (bonus dice/mod to
  Damage rolls), `INIT` (flat bonus/penalty to Initiative), and `ARMOR`
  (flat damage reduction, read from the target's own effects).

## Compatibility

- Official Basic Roleplaying (BRP) ruleset
