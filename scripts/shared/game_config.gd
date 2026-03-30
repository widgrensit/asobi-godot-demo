extends Node

const HOST := "localhost"
const PORT := 8084
const GAME_MODE := "arena"
const LEADERBOARD_ID := "arena_kills"

# Shared match result data (set by arena, read by results)
var match_result: Dictionary = {}

func _ready() -> void:
	Asobi.host = HOST
	Asobi.port = PORT
