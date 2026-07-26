Free Pixel Art Explosion Sprites — CraftPix.net
https://craftpix.net/freebies/11-free-pixel-art-explosion-sprites/
itch.io mirror: https://free-game-assets.itch.io/11-free-pixel-art-explosion-sprites

STATUS: NOT DOWNLOADED. Blocked on a decision, not on sourcing — see below.

LICENCE (read at https://craftpix.net/file-licenses/ on 2026-07-26):
  Commercial use:  YES — "You are permitted to use the resources in any number of
                   personal and commercial projects."
  Attribution:     not required, "any credit will be highly appreciated".
  AI/ML training:  explicitly forbidden.
  Redistribution:  FORBIDDEN — "You can NOT resell the art source files (PNG, JPG,
                   EPS, Adobe Illustrator, etc) or slightly modified version of the
                   art", and the art may not be redistributed "in a manner that would
                   make some or all of the art files useable to another end user".

  Same tier as pack 18, which is already in this repo. On arrival the zip will contain
  a license.txt — pack 18's contains exactly one line, the file-licenses URL above.

  Aside, for whoever inherits the earlier note that this was an "unstated licence on a
  repost": it is not. free-game-assets.itch.io is CraftPix's own itch.io account, it
  links back to craftpix.net, and its zips ship that license.txt. The terms are pinned
  down. The problem below is a different one.

WHY IT IS BLOCKED — the redistribution clause vs. this repo

  art-resources/ is committed, and the GitHub remote is PUBLIC (verified 2026-07-26:
  github.com/BlueRaddish/down-to-the-bone redirects to .../primordial-countdown and
  serves 200 anonymously).

  Putting CraftPix source PNGs in a public repo plausibly is "redistributing the art
  files in a manner that would make them useable to another end user" — someone can
  clone the repo and take the sprites without ever visiting CraftPix. That is the
  thing the licence names.

  Note the distinction the licence draws, because it decides the fix:
    USING the art inside the shipped game  -> explicitly allowed, not in question
    REDISTRIBUTING the source files        -> forbidden
  So assets/sprites/**, where the art is baked into the game, is fine. It is
  art-resources/**, the raw staging copies, that is exposed.

  THIS ALREADY APPLIES TO PACK 18, which is committed and public today. Adding packs
  24 and 25 makes it three CraftPix packs rather than one; it does not create the
  problem.

  Cheapest fix, and the one that fits what this tree already is: add the CraftPix pack
  folders to .gitignore. art-resources is explicitly a staging area ("copy out only
  what you use"), every pack's download URL is recorded, and nothing builds from it —
  tools/ reads it locally and .gdignore already hides it from Godot. Keeping these
  packs local costs nothing and removes the exposure. Making the repo private also
  works, and is the user's call, not a licence question.

CONTENTS (per the store page): 11 pixel-art explosion sprites — fiery, chemical,
water and electric — in PSD and PNG.

WHY THIS PACK: the prehistoric era's attack VFX.
