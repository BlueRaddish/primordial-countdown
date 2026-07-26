# Active Claude sessions — coordination log

Several Claude instances may work in this repo at once. This file is how they avoid
overwriting each other. It is the **first thing to read and the last thing to update**
in any session that edits files here.

## Protocol

1. **On starting work:** read this file. If another session is `ACTIVE` and claims a
   file or area you need, do not edit it — pick different work, or note the conflict
   to the user and ask. Timestamps older than ~2 hours with no updates can be treated
   as stale and released.
2. **Claim before editing.** Add a row under *Active* with your session id, what you
   are touching, and the time. Claim the narrowest area that is true — a whole
   directory only if you really are reworking all of it.
3. **Update as you go.** When your claim changes, edit your row rather than adding a
   new one.
4. **On finishing:** move your row to *Recently finished* with a one-line summary,
   and drop the claim.

Rules that matter more than the bookkeeping:

- **Never revert another session's work.** If a file changed under you, re-read it and
  merge on top rather than writing your remembered version back.
- **Whole-file writes are the dangerous ones.** Prefer targeted edits to files you did
  not claim exclusively.
- **This repo's `.godot/` cache is shared with the user's open editor.** Do not run
  `--editor` headless while the editor is open; it hangs on the lock. Running the game
  (`godot --path . <scene>`) is safe.

## Active

| Session | Claimed | Since | Notes |
| --- | --- | --- | --- |
| _none_ | — | — | — |

## Recently finished

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
