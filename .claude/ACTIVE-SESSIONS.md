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
| 60ada46b | `scripts/ui/*`, `scripts/enemies/*`, `scripts/player/*`, `scripts/systems/*`, `project.godot`, `scenes/*`, `tests/*` | 2026-07-25 | UI scaling + fullscreen fix, settings panel, dev-tools gate, loadout lock, horizontal devolution cards. Earlier in the same session: combat rework, enemy statuses, boss phases, Tier 2.1/2.2, devolution pacing. Added `tests/ui_smoke_test.*`. |

## Notes worth carrying between sessions

- **Playtest command:** `godot --path . --resolution 1280x720 res://tests/ui_smoke_test.tscn`
  (Godot 4.7.1 at `~/Downloads/Godot_v4.7.1-stable_win64_console.exe`).
- **UI budget is 640x360.** Centre panels with `UILayout.center()`, never
  `set_anchors_preset(PRESET_CENTER)` plus a manual offset.
- **Combat contract:** enemies only hurt you through a telegraphed strike. Do not
  reintroduce meaningful passive contact damage.
- The PARA vault at `~/claude/para` is an rclone mount that intermittently drops writes —
  verify by re-reading, and prefer whole-file writes there.
