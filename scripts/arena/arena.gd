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

# Game objects
var _player_nodes: Dictionary = {}  # player_id -> Node2D
var _projectile_nodes: Dictionary = {}  # proj_id -> Node2D
var _crosshair: Sprite2D

# State
var _latest_state: Dictionary = {}
var _my_id: String


func _ready() -> void:
	_my_id = Asobi.player_id
	_setup_camera()
	_draw_bounds()
	_create_crosshair()
	_build_hud()
	_connect_signals()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Asobi.realtime.match_state.is_connected(_on_match_state):
		Asobi.realtime.match_state.disconnect(_on_match_state)
	if Asobi.realtime.match_finished.is_connected(_on_match_finished):
		Asobi.realtime.match_finished.disconnect(_on_match_finished)


func _process(_delta: float) -> void:
	_send_input()
	_update_crosshair()
	if not _latest_state.is_empty():
		_update_players()
		_update_projectiles()
		_update_hud()


func _setup_camera() -> void:
	_camera = Camera2D.new()
	_camera.position = Vector2(
		ARENA_WIDTH / PIXELS_PER_UNIT / 2.0,
		ARENA_HEIGHT / PIXELS_PER_UNIT / 2.0
	)
	_camera.zoom = Vector2(1, 1)
	# Set orthographic size to cover the arena
	var viewport_h := get_viewport().get_visible_rect().size.y
	var arena_h_units := ARENA_HEIGHT / PIXELS_PER_UNIT
	_camera.zoom = Vector2(viewport_h / (arena_h_units + 1.0), viewport_h / (arena_h_units + 1.0))
	add_child(_camera)


func _draw_bounds() -> void:
	var w := ARENA_WIDTH / PIXELS_PER_UNIT
	var h := ARENA_HEIGHT / PIXELS_PER_UNIT
	var line := Line2D.new()
	line.points = PackedVector2Array([
		Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h), Vector2(0, 0)
	])
	line.width = 2.0 / _camera.zoom.x  # Constant screen width
	line.default_color = Color.WHITE
	add_child(line)


func _create_crosshair() -> void:
	_crosshair = Sprite2D.new()
	# Draw a simple cross using a small texture
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	for i in range(16):
		img.set_pixel(7, i, Color.WHITE)
		img.set_pixel(8, i, Color.WHITE)
		img.set_pixel(i, 7, Color.WHITE)
		img.set_pixel(i, 8, Color.WHITE)
	_crosshair.texture = ImageTexture.create_from_image(img)
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
	_hud_layer.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_TOP_WIDE)
	margin.add_child(hbox)

	_timer_label = Label.new()
	_timer_label.text = "1:30"
	_timer_label.add_theme_font_size_override("font_size", 28)
	_timer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_timer_label)

	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_SHRINK_END
	hbox.add_child(right_vbox)

	_kills_label = Label.new()
	_kills_label.text = "Kills: 0"
	_kills_label.add_theme_font_size_override("font_size", 22)
	_kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_vbox.add_child(_kills_label)

	_hp_label = Label.new()
	_hp_label.text = "HP: 100"
	_hp_label.add_theme_font_size_override("font_size", 22)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_vbox.add_child(_hp_label)


func _connect_signals() -> void:
	Asobi.realtime.match_state.connect(_on_match_state)
	Asobi.realtime.match_finished.connect(_on_match_finished)


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


func _on_match_finished(payload: Dictionary) -> void:
	GameConfig.match_result = payload
	get_tree().change_scene_to_file("res://scenes/results.tscn")


# -- Player rendering --

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
		var kills: int = int(pdata.get("kills", 0))
		var is_me := (pid == _my_id)

		if not _player_nodes.has(pid):
			_player_nodes[pid] = _create_player_node(pid, is_me)

		var node: Node2D = _player_nodes[pid]
		node.position = node.position.lerp(target_pos, LERP_WEIGHT)

		# Update color
		var sprite: Sprite2D = node.get_node("Sprite")
		if hp <= 0:
			sprite.modulate = Color.GRAY
		elif is_me:
			sprite.modulate = Color.CYAN
		else:
			sprite.modulate = Color.RED

		# Update HP bar
		var hp_bar: ColorRect = node.get_node("HPBar")
		hp_bar.scale.x = maxf(hp / 100.0, 0.0)

		# Update label
		var label: Label = node.get_node("Label")
		if is_me:
			label.text = "YOU"
		else:
			label.text = pid.left(8)

		# Update HUD for local player
		if is_me:
			_kills_label.text = "Kills: %d" % kills
			_hp_label.text = "HP: %d" % hp

	# Remove disconnected players
	for pid in _player_nodes.keys():
		if pid not in seen_ids:
			_player_nodes[pid].queue_free()
			_player_nodes.erase(pid)


func _create_player_node(pid: String, is_me: bool) -> Node2D:
	var node := Node2D.new()
	add_child(node)

	# Body sprite (circle)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = _make_circle_texture(24, Color.WHITE)
	sprite.scale = Vector2(0.6 / _camera.zoom.x, 0.6 / _camera.zoom.x) * 0.04
	sprite.modulate = Color.CYAN if is_me else Color.RED
	node.add_child(sprite)

	# HP bar background
	var hp_bg := ColorRect.new()
	hp_bg.name = "HPBarBg"
	hp_bg.color = Color.BLACK
	hp_bg.size = Vector2(1.0, 0.08)
	hp_bg.position = Vector2(-0.5, 0.5)
	hp_bg.z_index = 5
	node.add_child(hp_bg)

	# HP bar
	var hp_bar := ColorRect.new()
	hp_bar.name = "HPBar"
	hp_bar.color = Color.GREEN
	hp_bar.size = Vector2(1.0, 0.08)
	hp_bar.position = Vector2(-0.5, 0.5)
	hp_bar.z_index = 6
	node.add_child(hp_bar)

	# Name label
	var label := Label.new()
	label.name = "Label"
	label.text = "YOU" if is_me else pid.left(8)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-0.5, -0.8)
	label.scale = Vector2(0.01, 0.01)
	label.z_index = 10
	label.add_theme_font_size_override("font_size", 14)
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

	# Remove expired projectiles
	for pid in _projectile_nodes.keys():
		if pid not in seen_ids:
			_projectile_nodes[pid].queue_free()
			_projectile_nodes.erase(pid)


func _create_projectile_node(is_mine: bool) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = _make_circle_texture(8, Color.WHITE)
	sprite.scale = Vector2(0.15 / _camera.zoom.x, 0.15 / _camera.zoom.x) * 0.04
	sprite.modulate = Color.YELLOW if is_mine else Color.WHITE
	sprite.z_index = 3
	add_child(sprite)
	return sprite


# -- HUD --

func _update_hud() -> void:
	var remaining_ms: float = _latest_state.get("time_remaining", 0.0)
	var remaining_s := int(remaining_ms / 1000.0)
	var minutes := remaining_s / 60
	var seconds := remaining_s % 60
	_timer_label.text = "%d:%02d" % [minutes, seconds]
