extends Control

var _status_label: Label
var _find_btn: Button
var _cancel_btn: Button
var _searching := false
var _search_time := 0.0
var _countdown_active := false
var _countdown_value := 3
var _countdown_timer := 0.0
var _countdown_label: Label


func _ready() -> void:
	_build_ui()
	_connect_realtime()


func _process(delta: float) -> void:
	if _searching:
		_search_time += delta
		_status_label.text = "Searching for match... %ds" % int(_search_time)
	if _countdown_active:
		_countdown_timer -= delta
		if _countdown_timer <= 0.0:
			_countdown_value -= 1
			if _countdown_value <= 0:
				_countdown_label.text = "GO!"
				_countdown_active = false
				await get_tree().create_timer(0.5).timeout
				get_tree().change_scene_to_file("res://scenes/arena.tscn")
			else:
				_countdown_label.text = str(_countdown_value)
				_countdown_timer = 1.0


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = GameConfig.COL_OCEAN
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(400, 300)
	vbox.position = Vector2(-200, -150)
	vbox.add_theme_constant_override("separation", 20)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(vbox)

	var player_label := Label.new()
	player_label.text = "Player: %s" % Asobi.player_id
	player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_label.add_theme_color_override("font_color", GameConfig.COL_MUTED)
	player_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(player_label)

	_status_label = Label.new()
	_status_label.text = "Connecting..."
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 24)
	_status_label.add_theme_color_override("font_color", GameConfig.COL_TEXT)
	vbox.add_child(_status_label)

	_find_btn = _make_button("FIND MATCH", GameConfig.COL_PRIMARY, Vector2(250, 60))
	_find_btn.pressed.connect(_on_find_match)
	_find_btn.disabled = true
	vbox.add_child(_find_btn)

	_cancel_btn = _make_button("CANCEL", GameConfig.COL_ERROR, Vector2(250, 60))
	_cancel_btn.pressed.connect(_on_cancel)
	_cancel_btn.visible = false
	vbox.add_child(_cancel_btn)

	_countdown_label = Label.new()
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.add_theme_font_size_override("font_size", 96)
	_countdown_label.add_theme_color_override("font_color", GameConfig.COL_SECONDARY)
	_countdown_label.visible = false
	vbox.add_child(_countdown_label)


func _make_button(text: String, color: Color, min_size: Vector2) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = min_size
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


func _connect_realtime() -> void:
	Asobi.realtime.connected.connect(_on_connected)
	Asobi.realtime.match_matched.connect(_on_matched)
	Asobi.realtime.error_received.connect(_on_error)
	Asobi.realtime.connect_to_server()


func _on_connected() -> void:
	_status_label.text = "Connected! Ready to play."
	_find_btn.disabled = false


func _on_find_match() -> void:
	_searching = true
	_search_time = 0.0
	_find_btn.visible = false
	_cancel_btn.visible = true
	_status_label.text = "Searching for match..."
	Asobi.realtime.add_to_matchmaker(GameConfig.GAME_MODE)


func _on_cancel() -> void:
	_searching = false
	_find_btn.visible = true
	_cancel_btn.visible = false
	_status_label.text = "Connected! Ready to play."


func _on_matched(_payload: Dictionary) -> void:
	_searching = false
	_find_btn.visible = false
	_cancel_btn.visible = false
	_status_label.visible = false
	_countdown_label.visible = true
	_countdown_value = 3
	_countdown_label.text = str(_countdown_value)
	_countdown_timer = 1.0
	_countdown_active = true


func _on_error(payload: Dictionary) -> void:
	_status_label.text = "Error: %s" % str(payload)
	_searching = false
	_find_btn.visible = true
	_cancel_btn.visible = false


func _exit_tree() -> void:
	if Asobi.realtime.connected.is_connected(_on_connected):
		Asobi.realtime.connected.disconnect(_on_connected)
	if Asobi.realtime.match_matched.is_connected(_on_matched):
		Asobi.realtime.match_matched.disconnect(_on_matched)
	if Asobi.realtime.error_received.is_connected(_on_error):
		Asobi.realtime.error_received.disconnect(_on_error)
