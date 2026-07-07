extends Node

const HOST := "localhost"
# The bundled lua/ arena game runs locally via `asobi dev` on :8084.
const PORT := 8084
const GAME_MODE := "arena"
const LEADERBOARD_ID := "arena_kills"

# Ship spritesheet constants
const SHIP_FRAME_W := 52
const SHIP_FRAME_H := 53
const SHIP_COLS := 3
const SHIP_ROWS := 4
const SHIP_SCALE := 1.5

# Naval theme colors (from asobi.dev)
const COL_OCEAN := Color(0.051, 0.122, 0.235)       # #0d1f3c
const COL_PRIMARY := Color(0.788, 0.745, 1.0)        # #c9beff
const COL_SECONDARY := Color(0.569, 0.804, 1.0)      # #91cdff
const COL_TERTIARY := Color(0.290, 0.882, 0.514)     # #4ae183
const COL_ERROR := Color(1.0, 0.706, 0.671)          # #ffb4ab
const COL_TEXT := Color(0.878, 0.882, 0.961)          # #e0e1f5
const COL_MUTED := Color(0.576, 0.557, 0.627)        # #938ea0
const COL_SURFACE := Color(0.110, 0.122, 0.176)      # #1c1f2d
const COL_HP_GOOD := Color(0.290, 0.882, 0.514)      # #4ae183
const COL_HP_MID := Color(0.788, 0.745, 1.0)         # #c9beff
const COL_HP_LOW := Color(1.0, 0.706, 0.671)         # #ffb4ab

# Shared match result data (set by arena, read by results)
var match_result: Dictionary = {}
var current_round: int = 1
var current_modifier: String = ""
var player_boons: Array = []

func _ready() -> void:
	Asobi.host = HOST
	Asobi.port = PORT
