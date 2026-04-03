extends Node2D

const ARENA_WIDTH := 800.0
const ARENA_HEIGHT := 600.0
const PIXELS_PER_UNIT := 50.0
const LERP_WEIGHT := 0.3

# Nodes
var _camera: Camera2D
var _hud_layer: CanvasLayer
var _timer_label: Label
var _kills_label: Label
var _hp_label: Label
var _round_label: Label
var _boons_label: Label
var _overlay_layer: CanvasLayer

# Game objects
var _player_nodes: Dictionary = {}
var _projectile_nodes: Dictionary = {}
var _crosshair: Sprite2D

# Ship sprites
var _ship_player_tex: Texture2D
var _ship_enemy_tex: Texture2D
var _frame_counter: int = 0
var _last_dx: Dictionary = {}
var _last_dy: Dictionary = {}

# State
var _latest_state: Dictionary = {}
var _my_id: String
var _current_phase: String = "playing"

# Boon pick UI
var _boon_panel: Control
var _boon_cards_container: VBoxContainer
var _boon_waiting_label: Label
var _boon_timer_label: Label
var _boon_picked := false

# Vote UI
var _vote_panel: Control
var _vote_options_container: VBoxContainer
var _vote_timer_label: Label
var _vote_bars: Dictionary = {}
var _current_vote_id: String = ""
var _voted := false


func _ready() -> void:
	_my_id = Asobi.player_id
	_load_ship_sprites()
	_setup_camera()
	_draw_bounds()
	_create_crosshair()
	_build_hud()
	_build_boon_panel()
	_build_vote_panel()
	_connect_signals()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Asobi.realtime.match_state.is_connected(_on_match_state):
		Asobi.realtime.match_state.disconnect(_on_match_state)
	if Asobi.realtime.match_finished.is_connected(_on_match_finished):
		Asobi.realtime.match_finished.disconnect(_on_match_finished)
	if Asobi.realtime.vote_start.is_connected(_on_vote_start):
		Asobi.realtime.vote_start.disconnect(_on_vote_start)
	if Asobi.realtime.vote_tally.is_connected(_on_vote_tally):
		Asobi.realtime.vote_tally.disconnect(_on_vote_tally)
	if Asobi.realtime.vote_result.is_connected(_on_vote_result):
		Asobi.realtime.vote_result.disconnect(_on_vote_result)


func _process(_delta: float) -> void:
	_frame_counter += 1
	if _current_phase == "playing":
		_send_input()
		_update_crosshair()
		if not _latest_state.is_empty():
			_update_players()
			_update_projectiles()
			_update_hud()


func _load_ship_sprites() -> void:
	if ResourceLoader.exists("res://assets/ship_player.png"):
		_ship_player_tex = load("res://assets/ship_player.png")
	if ResourceLoader.exists("res://assets/ship_enemy.png"):
		_ship_enemy_tex = load("res://assets/ship_enemy.png")


func _setup_camera() -> void:
	_camera = Camera2D.new()
	_camera.position = Vector2(
		ARENA_WIDTH / PIXELS_PER_UNIT / 2.0,
		ARENA_HEIGHT / PIXELS_PER_UNIT / 2.0
	)
	var viewport_h := get_viewport().get_visible_rect().size.y
	var arena_h_units := ARENA_HEIGHT / PIXELS_PER_UNIT
	_camera.zoom = Vector2(viewport_h / (arena_h_units + 1.0), viewport_h / (arena_h_units + 1.0))
	add_child(_camera)


func _draw_bounds() -> void:
	var w := ARENA_WIDTH / PIXELS_PER_UNIT
	var h := ARENA_HEIGHT / PIXELS_PER_UNIT

	# Ocean background
	var bg := ColorRect.new()
	bg.color = GameConfig.COL_OCEAN
	bg.size = Vector2(w, h)
	bg.position = Vector2.ZERO
	bg.z_index = -10
	add_child(bg)

	var line := Line2D.new()
	line.points = PackedVector2Array([
		Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h), Vector2(0, 0)
	])
	line.width = 0.04
	line.default_color = GameConfig.COL_MUTED
	add_child(line)


func _create_crosshair() -> void:
	_crosshair = Sprite2D.new()
	var img := Image.create(28, 28, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var center := 14
	var cross_col := GameConfig.COL_PRIMARY
	cross_col.a = 0.6
	# Circle
	for angle in range(360):
		var rad := deg_to_rad(float(angle))
		var px := int(center + 10.0 * cos(rad))
		var py := int(center + 10.0 * sin(rad))
		if px >= 0 and px < 28 and py >= 0 and py < 28:
			img.set_pixel(px, py, cross_col)
	# Cross lines
	for i in range(28):
		img.set_pixel(center, i, cross_col)
		img.set_pixel(i, center, cross_col)
	_crosshair.texture = ImageTexture.create_from_image(img)
	_crosshair.scale = Vector2.ONE * (0.5 / 28.0)
	_crosshair.z_index = 100
	add_child(_crosshair)


func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 100
	add_child(_hud_layer)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_hud_layer.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_TOP_WIDE)
	margin.add_child(hbox)

	# Left side: timer + stats
	var left_vbox := VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(left_vbox)

	_timer_label = Label.new()
	_timer_label.text = "1:30"
	_timer_label.add_theme_font_size_override("font_size", 28)
	_timer_label.add_theme_color_override("font_color", GameConfig.COL_SECONDARY)
	left_vbox.add_child(_timer_label)

	_kills_label = Label.new()
	_kills_label.text = "Kills: 0"
	_kills_label.add_theme_font_size_override("font_size", 20)
	_kills_label.add_theme_color_override("font_color", GameConfig.COL_TEXT)
	left_vbox.add_child(_kills_label)

	_hp_label = Label.new()
	_hp_label.text = "HP: 100"
	_hp_label.add_theme_font_size_override("font_size", 20)
	_hp_label.add_theme_color_override("font_color", GameConfig.COL_HP_GOOD)
	left_vbox.add_child(_hp_label)

	# Right side: round + modifier
	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_SHRINK_END
	hbox.add_child(right_vbox)

	_round_label = Label.new()
	_round_label.text = "Round 1"
	_round_label.add_theme_font_size_override("font_size", 18)
	_round_label.add_theme_color_override("font_color", GameConfig.COL_MUTED)
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_vbox.add_child(_round_label)

	# Bottom: boons list
	_boons_label = Label.new()
	_boons_label.text = ""
	_boons_label.add_theme_font_size_override("font_size", 14)
	_boons_label.add_theme_color_override("font_color", GameConfig.COL_MUTED)
	_boons_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_boons_label.position = Vector2(20, -30)
	_hud_layer.add_child(_boons_label)


func _build_boon_panel() -> void:
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 200
	add_child(_overlay_layer)

	_boon_panel = Control.new()
	_boon_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boon_panel.visible = false
	_overlay_layer.add_child(_boon_panel)

	var bg := ColorRect.new()
	bg.color = Color(GameConfig.COL_OCEAN.r, GameConfig.COL_OCEAN.g, GameConfig.COL_OCEAN.b, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boon_panel.add_child(bg)

	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.custom_minimum_size = Vector2(500, 400)
	center.position = Vector2(-250, -200)
	center.add_theme_constant_override("separation", 16)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	_boon_panel.add_child(center)

	var title := Label.new()
	title.text = "CHOOSE A BOON"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", GameConfig.COL_PRIMARY)
	center.add_child(title)

	_boon_timer_label = Label.new()
	_boon_timer_label.text = ""
	_boon_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boon_timer_label.add_theme_font_size_override("font_size", 20)
	_boon_timer_label.add_theme_color_override("font_color", GameConfig.COL_SECONDARY)
	center.add_child(_boon_timer_label)

	_boon_waiting_label = Label.new()
	_boon_waiting_label.text = ""
	_boon_waiting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boon_waiting_label.add_theme_font_size_override("font_size", 18)
	_boon_waiting_label.add_theme_color_override("font_color", GameConfig.COL_MUTED)
	center.add_child(_boon_waiting_label)

	_boon_cards_container = VBoxContainer.new()
	_boon_cards_container.add_theme_constant_override("separation", 10)
	center.add_child(_boon_cards_container)


func _build_vote_panel() -> void:
	_vote_panel = Control.new()
	_vote_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vote_panel.visible = false
	_overlay_layer.add_child(_vote_panel)

	var bg := ColorRect.new()
	bg.color = Color(GameConfig.COL_OCEAN.r, GameConfig.COL_OCEAN.g, GameConfig.COL_OCEAN.b, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vote_panel.add_child(bg)

	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.custom_minimum_size = Vector2(500, 400)
	center.position = Vector2(-250, -200)
	center.add_theme_constant_override("separation", 16)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	_vote_panel.add_child(center)

	var title := Label.new()
	title.text = "VOTE FOR NEXT MODIFIER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", GameConfig.COL_PRIMARY)
	center.add_child(title)

	_vote_timer_label = Label.new()
	_vote_timer_label.text = ""
	_vote_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vote_timer_label.add_theme_font_size_override("font_size", 20)
	_vote_timer_label.add_theme_color_override("font_color", GameConfig.COL_SECONDARY)
	center.add_child(_vote_timer_label)

	_vote_options_container = VBoxContainer.new()
	_vote_options_container.add_theme_constant_override("separation", 8)
	center.add_child(_vote_options_container)


func _connect_signals() -> void:
	Asobi.realtime.match_state.connect(_on_match_state)
	Asobi.realtime.match_finished.connect(_on_match_finished)
	Asobi.realtime.vote_start.connect(_on_vote_start)
	Asobi.realtime.vote_tally.connect(_on_vote_tally)
	Asobi.realtime.vote_result.connect(_on_vote_result)


func _send_input() -> void:
	var up := Input.is_action_pressed("move_up")
	var down := Input.is_action_pressed("move_down")
	var left := Input.is_action_pressed("move_left")
	var right := Input.is_action_pressed("move_right")
	var shooting := Input.is_action_pressed("shoot")

	if not (up or down or left or right or shooting):
		return

	var mouse_world := _get_mouse_world_pos()
	var aim_x := mouse_world.x * PIXELS_PER_UNIT
	var aim_y := mouse_world.y * PIXELS_PER_UNIT

	Asobi.realtime.send_match_input({
		"up": up,
		"down": down,
		"left": left,
		"right": right,
		"shoot": shooting,
		"aim_x": aim_x,
		"aim_y": aim_y
	})


func _get_mouse_world_pos() -> Vector2:
	return get_global_mouse_position()


func _update_crosshair() -> void:
	_crosshair.position = _get_mouse_world_pos()


func _on_match_state(payload: Dictionary) -> void:
	_latest_state = payload
	var phase: String = payload.get("phase", "playing")

	if phase == "boon_pick" and _current_phase != "boon_pick":
		_current_phase = "boon_pick"
		_show_boon_pick(payload)
	elif phase == "boon_pick":
		_update_boon_pick(payload)
	elif phase == "playing" and _current_phase != "playing":
		_current_phase = "playing"
		_boon_panel.visible = false
		_vote_panel.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _on_match_finished(payload: Dictionary) -> void:
	_current_phase = "finished"
	GameConfig.match_result = payload
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/results.tscn")


func _on_vote_start(payload: Dictionary) -> void:
	_current_phase = "voting"
	_boon_panel.visible = false
	_vote_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_voted = false
	_current_vote_id = payload.get("vote_id", "")

	for child in _vote_options_container.get_children():
		child.queue_free()
	_vote_bars.clear()

	var options: Array = payload.get("options", [])
	var window_ms: float = payload.get("window_ms", 10000.0)
	_vote_timer_label.text = "%ds" % int(window_ms / 1000.0)

	for opt in options:
		var opt_id: String = opt.get("id", "")
		var opt_label: String = opt.get("label", "")
		_create_vote_option(opt_id, opt_label)


func _on_vote_tally(payload: Dictionary) -> void:
	var tallies: Dictionary = payload.get("tallies", {})
	var total: int = maxi(int(payload.get("total_votes", 1)), 1)
	var time_remaining_ms: float = payload.get("time_remaining_ms", 0.0)

	_vote_timer_label.text = "%ds" % int(time_remaining_ms / 1000.0)

	for opt_id in tallies:
		if _vote_bars.has(opt_id):
			var bar: ColorRect = _vote_bars[opt_id]
			var count: int = int(tallies[opt_id])
			var frac := float(count) / float(total)
			bar.size.x = 300.0 * frac


func _on_vote_result(payload: Dictionary) -> void:
	var winner: String = payload.get("winner", "")
	for opt_id in _vote_bars:
		if _vote_bars.has(opt_id):
			var bar: ColorRect = _vote_bars[opt_id]
			if opt_id == winner:
				bar.color = GameConfig.COL_TERTIARY


# -- Boon pick --

func _show_boon_pick(state: Dictionary) -> void:
	_boon_panel.visible = true
	_vote_panel.visible = false
	_boon_picked = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	for child in _boon_cards_container.get_children():
		child.queue_free()

	var offers: Array = state.get("boon_offers", [])
	var time_remaining: float = state.get("time_remaining", 0.0)
	_boon_timer_label.text = "%ds" % int(time_remaining / 1000.0)

	if offers.is_empty():
		_boon_waiting_label.text = "Waiting for top players to pick..."
	else:
		_boon_waiting_label.text = ""
		for offer in offers:
			_create_boon_card(offer)


func _update_boon_pick(state: Dictionary) -> void:
	var time_remaining: float = state.get("time_remaining", 0.0)
	_boon_timer_label.text = "%ds" % int(time_remaining / 1000.0)

	var picks_done: Array = state.get("picks_done", [])
	if _boon_picked:
		_boon_waiting_label.text = "Picked! Waiting for others... (%d done)" % picks_done.size()


func _create_boon_card(offer: Dictionary) -> void:
	var boon_id: String = offer.get("id", "")
	var boon_name: String = offer.get("name", "")
	var boon_desc: String = offer.get("description", "")

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(400, 70)
	btn.text = "%s\n%s" % [boon_name, boon_desc]
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER

	var style := StyleBoxFlat.new()
	style.bg_color = GameConfig.COL_SURFACE
	style.border_color = GameConfig.COL_PRIMARY
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", style)

	var hover_style := style.duplicate()
	hover_style.bg_color = GameConfig.COL_PRIMARY.darkened(0.7)
	btn.add_theme_stylebox_override("hover", hover_style)

	btn.add_theme_color_override("font_color", GameConfig.COL_TEXT)
	btn.add_theme_font_size_override("font_size", 16)

	btn.pressed.connect(func():
		if _boon_picked:
			return
		_boon_picked = true
		Asobi.realtime.send_match_input({"type": "boon_pick", "boon_id": boon_id})
		_boon_waiting_label.text = "Picked %s! Waiting for others..." % boon_name
		for child in _boon_cards_container.get_children():
			if child is Button:
				child.disabled = true
	)
	_boon_cards_container.add_child(btn)


func _create_vote_option(opt_id: String, opt_label: String) -> void:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 4)

	var btn := Button.new()
	btn.text = opt_label
	btn.custom_minimum_size = Vector2(400, 50)
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER

	var style := StyleBoxFlat.new()
	style.bg_color = GameConfig.COL_SURFACE
	style.border_color = GameConfig.COL_SECONDARY
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", style)

	var hover_style := style.duplicate()
	hover_style.bg_color = GameConfig.COL_SECONDARY.darkened(0.7)
	btn.add_theme_stylebox_override("hover", hover_style)

	btn.add_theme_color_override("font_color", GameConfig.COL_TEXT)
	btn.add_theme_font_size_override("font_size", 18)

	btn.pressed.connect(func():
		if _voted:
			return
		_voted = true
		Asobi.realtime.cast_vote(_current_vote_id, opt_id)
		var selected_style := style.duplicate()
		selected_style.border_color = GameConfig.COL_TERTIARY
		selected_style.border_width_left = 3
		selected_style.border_width_right = 3
		selected_style.border_width_top = 3
		selected_style.border_width_bottom = 3
		btn.add_theme_stylebox_override("normal", selected_style)
	)
	container.add_child(btn)

	# Vote bar
	var bar_bg := ColorRect.new()
	bar_bg.color = GameConfig.COL_SURFACE.lightened(0.1)
	bar_bg.custom_minimum_size = Vector2(400, 8)
	container.add_child(bar_bg)

	var bar := ColorRect.new()
	bar.color = GameConfig.COL_SECONDARY
	bar.size = Vector2(0, 8)
	bar.position = Vector2.ZERO
	bar_bg.add_child(bar)
	_vote_bars[opt_id] = bar

	_vote_options_container.add_child(container)


# -- Player rendering --

func _get_ship_row(dx: float, dy: float) -> int:
	if absf(dy) > absf(dx):
		return 0 if dy > 0.0 else 3  # down : up
	return 2 if dx > 0.0 else 1  # right : left


func _update_players() -> void:
	var players: Dictionary = _latest_state.get("players", {})
	var seen_ids: Array = []

	for pid in players:
		seen_ids.append(pid)
		var pdata: Dictionary = players[pid]
		var target_pos := Vector2(
			pdata.get("x", 0.0) / PIXELS_PER_UNIT,
			pdata.get("y", 0.0) / PIXELS_PER_UNIT
		)
		var hp: int = int(pdata.get("hp", 0))
		var max_hp: int = int(pdata.get("max_hp", 100))
		var kills: int = int(pdata.get("kills", 0))
		var is_me: bool = (pid == _my_id)
		var boons: Array = pdata.get("boons", [])

		if not _player_nodes.has(pid):
			_player_nodes[pid] = _create_player_node(pid, is_me)

		var node: Node2D = _player_nodes[pid]
		var old_pos := node.position
		node.position = node.position.lerp(target_pos, LERP_WEIGHT)

		# Track movement direction for sprite row selection
		var dx := node.position.x - old_pos.x
		var dy := node.position.y - old_pos.y
		if absf(dx) > 0.001 or absf(dy) > 0.001:
			_last_dx[pid] = dx
			_last_dy[pid] = dy

		var cur_dx: float = _last_dx.get(pid, 0.0)
		var cur_dy: float = _last_dy.get(pid, 1.0)

		# Update sprite
		var sprite: Sprite2D = node.get_node("Sprite")
		var dead := hp <= 0

		var tex: Texture2D = _ship_player_tex if is_me else _ship_enemy_tex
		if tex != null:
			sprite.texture = tex
			sprite.region_enabled = true
			var row := _get_ship_row(cur_dx, cur_dy)
			var anim_frame := (int(_frame_counter / 10)) % GameConfig.SHIP_COLS
			sprite.region_rect = Rect2(
				anim_frame * GameConfig.SHIP_FRAME_W,
				row * GameConfig.SHIP_FRAME_H,
				GameConfig.SHIP_FRAME_W,
				GameConfig.SHIP_FRAME_H
			)
			var ship_scale := GameConfig.SHIP_SCALE / PIXELS_PER_UNIT
			sprite.scale = Vector2(ship_scale, ship_scale)
			sprite.modulate = Color(1, 1, 1, 0.3 if dead else 1.0)
		else:
			# Fallback circles
			sprite.modulate = Color.GRAY if dead else (GameConfig.COL_PRIMARY if is_me else GameConfig.COL_ERROR)

		# Own ship glow
		var glow: Sprite2D = node.get_node_or_null("Glow")
		if glow:
			glow.visible = is_me and not dead

		# HP bar
		var hp_bar: ColorRect = node.get_node("HPBar")
		var hp_frac := maxf(float(hp) / float(max_hp), 0.0)
		hp_bar.scale.x = hp_frac
		hp_bar.visible = not dead
		if hp_frac > 0.5:
			hp_bar.color = GameConfig.COL_HP_GOOD
		elif hp_frac > 0.25:
			hp_bar.color = GameConfig.COL_HP_MID
		else:
			hp_bar.color = GameConfig.COL_HP_LOW

		var hp_bg: ColorRect = node.get_node("HPBarBg")
		hp_bg.visible = not dead

		# Name label
		var label: Label = node.get_node("Label")
		if is_me:
			label.text = "YOU"
			label.add_theme_color_override("font_color", GameConfig.COL_TEXT)
		else:
			label.text = pid.left(8)
			label.add_theme_color_override("font_color", GameConfig.COL_MUTED if dead else GameConfig.COL_TEXT)

		# HUD for local player
		if is_me:
			_kills_label.text = "Kills: %d" % kills
			_hp_label.text = "HP: %d/%d" % [hp, max_hp]
			if hp_frac > 0.5:
				_hp_label.add_theme_color_override("font_color", GameConfig.COL_HP_GOOD)
			elif hp_frac > 0.25:
				_hp_label.add_theme_color_override("font_color", GameConfig.COL_HP_MID)
			else:
				_hp_label.add_theme_color_override("font_color", GameConfig.COL_HP_LOW)

			if boons.size() > 0:
				var boon_names: PackedStringArray = []
				for b in boons:
					boon_names.append(str(b))
				_boons_label.text = "Boons: %s" % ", ".join(boon_names)
				GameConfig.player_boons = boons
			else:
				_boons_label.text = ""

	for pid in _player_nodes.keys():
		if pid not in seen_ids:
			_player_nodes[pid].queue_free()
			_player_nodes.erase(pid)


func _create_player_node(pid: String, is_me: bool) -> Node2D:
	var node := Node2D.new()
	add_child(node)

	var sprite := Sprite2D.new()
	sprite.name = "Sprite"

	var tex: Texture2D = _ship_player_tex if is_me else _ship_enemy_tex
	if tex != null:
		sprite.texture = tex
		sprite.region_enabled = true
		sprite.region_rect = Rect2(0, 0, GameConfig.SHIP_FRAME_W, GameConfig.SHIP_FRAME_H)
		var ship_scale := GameConfig.SHIP_SCALE / PIXELS_PER_UNIT
		sprite.scale = Vector2(ship_scale, ship_scale)
	else:
		sprite.texture = _make_circle_texture(24, Color.WHITE)
		sprite.scale = Vector2.ONE * (0.64 / 48.0)
		sprite.modulate = GameConfig.COL_PRIMARY if is_me else GameConfig.COL_ERROR
	node.add_child(sprite)

	# Own ship glow
	if is_me:
		var glow := Sprite2D.new()
		glow.name = "Glow"
		glow.texture = _make_circle_texture(32, GameConfig.COL_PRIMARY)
		glow.scale = Vector2.ONE * (1.0 / 64.0)
		glow.modulate.a = 0.2
		glow.z_index = -1
		node.add_child(glow)

	# HP bar background
	var hp_bg := ColorRect.new()
	hp_bg.name = "HPBarBg"
	hp_bg.color = GameConfig.COL_SURFACE
	hp_bg.size = Vector2(1.0, 0.06)
	hp_bg.position = Vector2(-0.5, 0.45)
	hp_bg.z_index = 5
	node.add_child(hp_bg)

	# HP bar
	var hp_bar := ColorRect.new()
	hp_bar.name = "HPBar"
	hp_bar.color = GameConfig.COL_HP_GOOD
	hp_bar.size = Vector2(1.0, 0.06)
	hp_bar.position = Vector2(-0.5, 0.45)
	hp_bar.z_index = 6
	node.add_child(hp_bar)

	# Name label
	var label := Label.new()
	label.name = "Label"
	label.text = "YOU" if is_me else pid.left(8)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-0.5, -0.75)
	label.scale = Vector2(0.01, 0.01)
	label.z_index = 10
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", GameConfig.COL_TEXT)
	node.add_child(label)

	return node


func _make_circle_texture(radius: int, color: Color) -> ImageTexture:
	var size := radius * 2
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var center := Vector2(radius, radius)
	for x in range(size):
		for y in range(size):
			if Vector2(x, y).distance_to(center) <= radius:
				img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)


# -- Projectile rendering --

func _update_projectiles() -> void:
	var projectiles: Array = _latest_state.get("projectiles", [])
	var seen_ids: Array = []

	for proj in projectiles:
		var proj_id: int = int(proj.get("id", 0))
		seen_ids.append(proj_id)
		var pos := Vector2(
			proj.get("x", 0.0) / PIXELS_PER_UNIT,
			proj.get("y", 0.0) / PIXELS_PER_UNIT
		)
		var owner_id: String = proj.get("owner", "")

		if not _projectile_nodes.has(proj_id):
			_projectile_nodes[proj_id] = _create_projectile_node(owner_id == _my_id)

		var node: Sprite2D = _projectile_nodes[proj_id]
		node.position = pos

	for pid in _projectile_nodes.keys():
		if pid not in seen_ids:
			_projectile_nodes[pid].queue_free()
			_projectile_nodes.erase(pid)


func _create_projectile_node(is_mine: bool) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = _make_circle_texture(8, Color.WHITE)
	sprite.scale = Vector2.ONE * (0.2 / 16.0)
	sprite.modulate = GameConfig.COL_ERROR
	sprite.modulate.a = 0.9
	sprite.z_index = 3
	add_child(sprite)

	# Trail glow
	var trail := Sprite2D.new()
	trail.name = "Trail"
	trail.texture = _make_circle_texture(12, GameConfig.COL_ERROR)
	trail.scale = Vector2.ONE * (0.3 / 24.0)
	trail.modulate.a = 0.3
	trail.z_index = 2
	sprite.add_child(trail)

	return sprite


# -- HUD --

func _update_hud() -> void:
	var remaining_ms: float = _latest_state.get("time_remaining", 0.0)
	var remaining_s := int(remaining_ms / 1000.0)
	var minutes := remaining_s / 60
	var seconds := remaining_s % 60
	_timer_label.text = "%d:%02d" % [minutes, seconds]

	if remaining_s <= 10:
		_timer_label.add_theme_color_override("font_color", GameConfig.COL_ERROR)
	else:
		_timer_label.add_theme_color_override("font_color", GameConfig.COL_SECONDARY)

	var round_num: int = int(_latest_state.get("round", 1))
	var modifier: String = _latest_state.get("modifier", "")
	GameConfig.current_round = round_num
	GameConfig.current_modifier = modifier

	var round_text := "Round %d" % round_num
	if modifier != "" and modifier != "null":
		round_text += " | %s" % modifier
	_round_label.text = round_text
