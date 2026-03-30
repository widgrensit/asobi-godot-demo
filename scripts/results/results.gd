extends Control

var _title_label: Label
var _standings_label: Label
var _leaderboard_label: Label


func _ready() -> void:
	_build_ui()
	_show_results()
	_submit_and_fetch_leaderboard()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.15)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(500, 500)
	vbox.position = Vector2(-250, -250)
	vbox.add_theme_constant_override("separation", 16)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(vbox)

	# Title
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 48)
	vbox.add_child(_title_label)

	# Standings
	_standings_label = Label.new()
	_standings_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_standings_label.add_theme_font_size_override("font_size", 18)
	_standings_label.custom_minimum_size = Vector2(500, 150)
	vbox.add_child(_standings_label)

	# Leaderboard
	_leaderboard_label = Label.new()
	_leaderboard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_leaderboard_label.add_theme_font_size_override("font_size", 16)
	_leaderboard_label.custom_minimum_size = Vector2(400, 150)
	vbox.add_child(_leaderboard_label)

	# Buttons
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_row)

	var play_btn := _make_button("PLAY AGAIN", Color(0.0, 0.8, 0.8))
	play_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/lobby.tscn"))
	btn_row.add_child(play_btn)

	var quit_btn := _make_button("QUIT", Color(0.8, 0.2, 0.2))
	quit_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/login.tscn"))
	btn_row.add_child(quit_btn)


func _make_button(text: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(160, 50)
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = color
	style_normal.corner_radius_top_left = 4
	style_normal.corner_radius_top_right = 4
	style_normal.corner_radius_bottom_left = 4
	style_normal.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", style_normal)
	var style_hover := style_normal.duplicate()
	style_hover.bg_color = color.lightened(0.2)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_color_override("font_color", Color.BLACK)
	return btn


func _show_results() -> void:
	var result := GameConfig.match_result
	var standings: Array = result.get("standings", [])
	var winner: String = result.get("winner", "")
	var my_id := Asobi.player_id

	# Title
	if winner == my_id:
		_title_label.text = "VICTORY!"
		_title_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		_title_label.text = "DEFEAT"
		_title_label.add_theme_color_override("font_color", Color.RED)

	# Standings
	var lines: Array[String] = []
	for entry in standings:
		var pid: String = entry.get("player_id", "")
		var kills: int = int(entry.get("kills", 0))
		var deaths: int = int(entry.get("deaths", 0))
		var rank: int = int(entry.get("rank", 0))
		var suffix := " (YOU)" if pid == my_id else ""
		lines.append("#%d  %s%s  K:%d D:%d" % [rank, pid.left(12), suffix, kills, deaths])
	_standings_label.text = "\n".join(lines)


func _submit_and_fetch_leaderboard() -> void:
	_leaderboard_label.text = "Loading leaderboard..."

	# Find my kills from standings
	var my_kills := 0
	var standings: Array = GameConfig.match_result.get("standings", [])
	for entry in standings:
		if entry.get("player_id", "") == Asobi.player_id:
			my_kills = int(entry.get("kills", 0))
			break

	# Submit score
	await Asobi.leaderboards.submit_score(GameConfig.LEADERBOARD_ID, my_kills)

	# Fetch top 10
	var resp: Dictionary = await Asobi.leaderboards.get_top(GameConfig.LEADERBOARD_ID, 10)
	if resp.has("error"):
		_leaderboard_label.text = "Failed to load leaderboard"
		return

	var entries: Array = resp.get("entries", [])
	var lines: Array[String] = ["--- TOP 10 ---"]
	var my_id := Asobi.player_id
	for i in range(entries.size()):
		var e: Dictionary = entries[i]
		var pid: String = e.get("player_id", "")
		var score: int = int(e.get("score", 0))
		var marker := " *" if pid == my_id else ""
		lines.append("%d. %s - %d kills%s" % [i + 1, pid.left(12), score, marker])
	_leaderboard_label.text = "\n".join(lines)
