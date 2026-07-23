# trait_manager.gd
# Holds the current stage of every trait. Single source of truth for player capability.
# Combat, movement, and UI all query this rather than tracking capability themselves.
extends Node

