# primordial-countdown

Godot 4.7.1 project. Several Claude sessions may work here at once.

## Concurrent sessions: one worktree per session

Never run two sessions in the same working directory — they overwrite each other's
uncommitted edits and the work is unrecoverable. Each session gets its own worktree and
branch:

```sh
git worktree add ../pc-<topic> -b claude/<topic>
```

Work only inside that folder. **Commit often** — isolation protects committed work only;
an abandoned worktree full of uncommitted changes is still lost work. When done: merge
into `main`, `git worktree remove ../pc-<topic>`, drop your row from the register.

### The register lives in the main worktree

`working.md` is **gitignored and never committed**. Because ignored files are not copied
into new worktrees, there is exactly one copy, in the main worktree root. Find it from
anywhere:

```sh
dirname "$(git rev-parse --path-format=absolute --git-common-dir)"
```

Read it before choosing what to work on, add a row when you start, delete your row when
you merge. It coordinates **scope**, not individual files — its job is stopping two
sessions from picking overlapping areas, so merges stay clean. A stale row means a session
died; ask the user before clearing it, since its worktree may still hold uncommitted work.

`.tscn` scenes and `.uid` files merge badly, which is why scope discipline still matters.
Each worktree re-imports assets into its own `.godot/` on first launch — slow once.

## Testing

Godot 4.7.1 at `~/Downloads/Godot_v4.7.1-stable_win64_console.exe`.

- `godot --path . --resolution 1280x720 res://tests/ui_smoke_test.tscn` — every screen,
  panel bounds, screenshots into `tests/_uishots/`.
- `godot --headless --path . res://tests/gameplay_smoke_test.tscn` — platform flags, boss
  math, dash i-frames, enemy escape.

Both exit non-zero on failure. Run them after touching UI, arena or combat.

New assets need importing before a headless run can see them:
`godot --headless --path . --import` (it hangs afterwards loading the editor — the import
itself completes, just kill it).

**Do not run `--editor` headless while the user's editor is open** — it hangs on the
`.godot/` lock. Running the game (`godot --path . <scene>`) is safe.

## Project constraints — do not "fix" these

- **One-way platform margin extends DOWNWARD** from the collider bottom. A large margin on
  a low shelf traps anything walking under it. Sized per platform — do not replace with a
  single constant.
- **UI budget is 640x360.** Centre panels with `UILayout.center()`, never
  `set_anchors_preset(PRESET_CENTER)` plus a manual offset.
- **Combat contract:** enemies only hurt you through a telegraphed strike. Do not
  reintroduce meaningful passive contact damage.
- **The enemy telegraph is deliberately NOT behind the hitbox debug toggle** — it is the
  information the combat contract runs on, not debug output. Don't gate it.
- **Death music works** (`audio_manager.gd::_on_player_died()`). Verified in play; noted so
  it isn't "fixed" by accident.
- The PARA vault at `~/claude/para` is an rclone mount that intermittently drops writes —
  verify by re-reading, and prefer whole-file writes there.

Past session history is in `.claude/ACTIVE-SESSIONS.md`.
