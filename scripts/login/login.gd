extends Control

var _username_field: LineEdit
var _password_field: LineEdit
var _status_label: Label
var _login_btn: Button
var _register_btn: Button


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = GameConfig.COL_OCEAN
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	# Center panel
	var panel := PanelContainer.new()
	panel.set_anchors_preset(PRESET_CENTER)
	panel.custom_minimum_size = Vector2(400, 350)
	panel.position = Vector2(-200, -175)
	var style := StyleBoxFlat.new()
	style.bg_color = GameConfig.COL_SURFACE
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 40
	style.content_margin_right = 40
	style.content_margin_top = 30
	style.content_margin_bottom = 30
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "ASOBI ARENA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", GameConfig.COL_PRIMARY)
	vbox.add_child(title)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	# Username
	_username_field = LineEdit.new()
	_username_field.placeholder_text = "Username"
	_username_field.custom_minimum_size = Vector2(300, 40)
	vbox.add_child(_username_field)

	# Password
	_password_field = LineEdit.new()
	_password_field.placeholder_text = "Password"
	_password_field.secret = true
	_password_field.custom_minimum_size = Vector2(300, 40)
	vbox.add_child(_password_field)

	# Buttons row
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_row)

	_login_btn = _make_button("LOGIN", GameConfig.COL_PRIMARY)
	_login_btn.pressed.connect(_on_login)
	btn_row.add_child(_login_btn)

	_register_btn = _make_button("REGISTER", GameConfig.COL_TERTIARY)
	_register_btn.pressed.connect(_on_register)
	btn_row.add_child(_register_btn)

	# Status
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_color_override("font_color", GameConfig.COL_SECONDARY)
	_status_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(_status_label)


func _make_button(text: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(130, 40)
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


func _set_busy(busy: bool) -> void:
	_login_btn.disabled = busy
	_register_btn.disabled = busy


func _on_login() -> void:
	var username := _username_field.text.strip_edges()
	var password := _password_field.text.strip_edges()
	if username.is_empty() or password.is_empty():
		_status_label.text = "Enter username and password"
		return

	_set_busy(true)
	_status_label.text = "Logging in..."
	var resp: Dictionary = await Asobi.auth.login(username, password)
	_set_busy(false)

	if resp.has("error"):
		_status_label.text = "Login failed: %s" % resp.get("error", "unknown")
	else:
		get_tree().change_scene_to_file("res://scenes/lobby.tscn")


func _on_register() -> void:
	var username := _username_field.text.strip_edges()
	var password := _password_field.text.strip_edges()
	if username.is_empty() or password.is_empty():
		_status_label.text = "Enter username and password"
		return

	_set_busy(true)
	_status_label.text = "Registering..."
	var resp: Dictionary = await Asobi.auth.register(username, password)
	_set_busy(false)

	if resp.has("error"):
		_status_label.text = "Register failed: %s" % resp.get("error", "unknown")
	else:
		get_tree().change_scene_to_file("res://scenes/lobby.tscn")
