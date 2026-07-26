Free Pixel Game UI for Cyberpunk — CraftPix.net, via Free Game Assets
https://free-game-assets.itch.io/free-gui-for-cyberpunk-pixel-art

STATUS: NOT DOWNLOADED. Same block as pack 24 — see that README for the reasoning;
it is one decision covering both, not two.

LICENCE (established 2026-07-26):
  The itch.io page states NO licence. It carries only a "No generative AI was used"
  tag. That was flagged going in as the reason to do this pack last, and to treat a
  HUD element with unknown terms as the worst thing to ship.

  It resolves cleanly. The publisher, "Free Game Assets (GUI, Sprite, Tilesets)", is
  CraftPix's own itch.io account — the page links back to craftpix.net and to their
  Cyberpunk Platformer collection. This repo's pack 18 came from that same account,
  and its zip ships a license.txt containing one line:
  https://craftpix.net/file-licenses/

  So the expected terms are CraftPix's standard ones:
    commercial use YES · attribution not required · AI/ML training forbidden ·
    REDISTRIBUTION OF SOURCE FILES FORBIDDEN

  VERIFY ON ARRIVAL ANYWAY. Read the license.txt in the zip before staging. If it is
  absent or says something else, stop and re-decide — the inference above is strong
  but it is still an inference, and a licence you assumed is not a licence you have.

CONTENTS (per the store page):
  81 tiles (32x32) for building frames
  20 bars (energy, health, scrolling)
  30 buttons, 40 icons (arrows, stars, pause, settings)
  shade palette, 3 logo variations, social icons, cursors
  fonts in a cyberpunk style, letters, numbers
  decorations (broken wires), skill icons
  PSD + PNG, "Free-GUI-for-Cyberpunk-Pixel-Art1.zip", 2.8 MB

  Comfortably the most comprehensive of the three era UI kits.

ON THE BUNDLED FONTS: check their grid before using them. This project's cards were
unreadable for a long time because Kenney Pixel was being asked for sizes it cannot
draw — it is only crisp at multiples of 16 (see the note at the top of
scripts/ui/devolution_popup.gd). Any new pixel font has the same constraint at some
other multiple. Measure it, do not eyeball it.

WHY THIS PACK: the cyberpunk era's UI. If the redistribution question goes against
staging it, the existing flat card styling is a perfectly good fallback for that era —
the era-keyed kit lookup is meant to fall back to StyleBoxFlat when an era has no kit.
