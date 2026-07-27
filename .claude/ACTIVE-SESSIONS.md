# Session history

A log of completed work, newest last. Append a row when you finish something worth
remembering; this file is not used for coordination.

**Live coordination happens elsewhere:** each session takes its own git worktree and
branch, and registers its scope in the gitignored `working.md` in the main worktree root.
See `CLAUDE.md` for that protocol. The per-file claim system this file used to run was
replaced by worktrees — a claim only shrank the race window, whereas separate working
directories remove it.

## Completed work

| Session | Area | Finished | Summary |
| --- | --- | --- | --- |
| 01LdUpxe | `ideate.md` | 2026-07-26 01:38 | Pruned the backlog down to open work only: dropped the fixed P0/P1 punch-list items, Tiers 0/1, the known-issues list, and the playtest/UI/combat/pacing "shipped" sections. Loose ends those sections carried (combat feel-tuning, unused SaveManager, static rebind list, the refused-trait lever) were lifted into a new "Loose ends left by shipped work" section rather than lost. Docs only, no code. |
| 5b853033 | `scripts/player/player.gd`, `scripts/systems/camera_follow.gd`, `scripts/systems/arena_renderer.gd`, `project.godot` (added `move_down`) | 2026-07-25 22:45 | Game feel: drop through one-way shelves on `S`/Down (collision exception against the specific body, so ground stays solid); apex gravity easing; air acceleration at 0.75 of ground via `air_accel_ratio`; dash and skill input buffering to match the existing jump buffer; camera look-ahead now eased and speed-scaled instead of a sign() step, plus air look-up; squash & stretch on jump/land/dash; dust on jump, land, skid and dash. One-way platform bodies now join group `one_way_platform`. Gameplay smoke test green (26 checks). |
| 5b853033 | `scripts/systems/arena_renderer.gd`, `scripts/systems/year_shrine.gd`, `scripts/enemies/base_enemy.gd`, `scripts/ui/hud.gd`, `scripts/ui/offscreen_markers.gd` (new), `ideate.md` | 2026-07-25 22:05 | Side walls removed (`wall_height` now 0, set >0 to restore); 5 optional platforms incl. two outboard over open air; off-screen enemy edge markers in the HUD; shrines now stand until used instead of being cleared by the next wave; ground enemies leap after `unreachable_patience` so a high perch is not safe; enemies past `FALL_KILL_Y` are culled so a knock-off cannot softlock a wave. Both smoke tests green. |
| 60ada46b | `scripts/ui/*`, `scripts/enemies/*`, `scripts/player/*`, `scripts/systems/*`, `project.godot`, `scenes/*`, `tests/*` | 2026-07-25 | UI scaling + fullscreen fix, settings panel, dev-tools gate, loadout lock, horizontal devolution cards. Earlier in the same session: combat rework, enemy statuses, boss phases, Tier 2.1/2.2, devolution pacing. Added `tests/ui_smoke_test.*`. |

## Notes worth carrying between sessions

- **Test commands** (Godot 4.7.1 at `~/Downloads/Godot_v4.7.1-stable_win64_console.exe`):
  - `godot --path . --resolution 1280x720 res://tests/ui_smoke_test.tscn` — every screen,
    panel bounds, screenshots into `tests/_uishots/`.
  - `godot --headless --path . res://tests/gameplay_smoke_test.tscn` — platform flags,
    boss math, dash i-frames, enemy escape.
  - Both exit non-zero on failure. Run them after touching UI, arena or combat.
- **New assets need importing before a headless run can see them:**
  `godot --headless --path . --import` (it will hang afterwards loading the editor — the
  import itself completes, just kill it).
- **One-way platform margin extends DOWNWARD from the collider bottom.** A large margin
  on a low shelf traps anything walking under it. Sized per platform now — do not
  replace it with a single constant.
- **UI budget is 640x360.** Centre panels with `UILayout.center()`, never
  `set_anchors_preset(PRESET_CENTER)` plus a manual offset.
- **Combat contract:** enemies only hurt you through a telegraphed strike. Do not
  reintroduce meaningful passive contact damage.
- **The enemy telegraph is deliberately NOT behind the hitbox debug toggle** — it is the
  information the combat contract runs on, not debug output. Don't "fix" it by gating it.
- **Death music works** (`audio_manager.gd::_on_player_died()` plays the jingle and stops
  music). Verified in play; noted so it doesn't get "fixed" by accident.
- The PARA vault at `~/claude/para` is an rclone mount that intermittently drops writes —
  verify by re-reading, and prefer whole-file writes there.
