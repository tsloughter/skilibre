class_name SnowPalsUI
extends Control
## Fixed 1280 × 800 design canvas, scaled by the project's stretch settings.
## Every group is anchored or laid out by a container, so moving one element
## moves its neighbours and the touch hit-tests with it.

signal pal_selected(index: int)
signal pace_selected(index: int)
signal play_requested
signal pause_requested
signal resume_requested
signal home_requested
signal sound_requested
signal hop_requested

const CANVAS := Vector2(1280, 800)
const INK = Color("264b50")
const TEAL = Color("287f78")
const MUTED = Color("6e898c")
const CREAM = Color("fffdf5")
const GOLD = Color("f8c76b")
const BOLD = preload("res://assets/fonts/Display-Bold.otf")
const REGULAR = preload("res://assets/fonts/Display-Medium.otf")

var menu: Control
var hud: Control
var modal: Control
var cards: Array[Button] = []
var paces: Array[Button] = []
var pal_title: Label
var pal_description: Label
var star_label: Label
var distance_label: Label
var message_label: Label
var progress: ProgressBar
var mute_button: Button
var play_button: Button
var pause_button: Button
var licenses_button: Button
var home_button: Button
var left_held := false
var right_held := false
var brake_held := false
var portraits: Array[SubViewport] = []
var message_time := 0.0
var touch_actions: Dictionary[int, String] = {}
var touch_buttons: Dictionary[String, Button] = {}
var licenses_dialog: AcceptDialog
var modal_icon: Label
var modal_title: Label
var modal_subtitle: Label
var modal_detail: Label
var modal_primary: Button
var modal_finished := false

func _ready() -> void:
	theme = _build_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_menu()
	_build_hud()
	_build_modal()
	mute_button = button("Sound on", "", 16)
	mute_button.pressed.connect(func(): sound_requested.emit())
	_pin(mute_button, self, Control.PRESET_TOP_RIGHT, Rect2(1126, 28, 126, 44))
	hud.hide()
	modal.hide()
	play_button.grab_focus()

# --- theme -------------------------------------------------------------------

func style(color: Color, radius: int = 20, border: Color = Color.TRANSPARENT, width: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(width)
	return s

func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = REGULAR
	t.default_font_size = 20
	t.set_color("font_color", "Label", INK)
	for variation in ["BoldLabel", "KickerLabel", "StarLabel", "ModalIconLabel", "ToastLabel"]:
		t.set_type_variation(variation, "Label")
		t.set_font("font", variation, BOLD)
	t.set_type_variation("MutedLabel", "Label")
	t.set_color("font_color", "MutedLabel", MUTED)
	t.set_type_variation("TealLabel", "Label")
	t.set_color("font_color", "TealLabel", TEAL)
	t.set_color("font_color", "KickerLabel", TEAL)
	t.set_color("font_color", "StarLabel", Color("a87524"))
	t.set_color("font_color", "ModalIconLabel", Color("d6a348"))
	t.set_color("font_color", "ToastLabel", TEAL)
	t.set_color("font_shadow_color", "ToastLabel", Color.WHITE)
	t.set_constant("shadow_offset_x", "ToastLabel", 1)
	t.set_constant("shadow_offset_y", "ToastLabel", 2)
	# Buttons: cream by default, teal for the primary action, tinted when selected.
	t.set_font("font", "Button", BOLD)
	t.set_font_size("font_size", "Button", 22)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(state, "Button", INK)
	t.set_stylebox("normal", "Button", style(CREAM, 17))
	t.set_stylebox("hover", "Button", style(Color("e4f1ed"), 17))
	t.set_stylebox("pressed", "Button", style(Color("cfe5de"), 17))
	t.set_stylebox("focus", "Button", style(Color.TRANSPARENT, 17, GOLD, 3))
	t.set_type_variation("PrimaryButton", "Button")
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(state, "PrimaryButton", Color.WHITE)
	t.set_stylebox("normal", "PrimaryButton", style(TEAL, 17))
	t.set_stylebox("hover", "PrimaryButton", style(Color("368f87"), 17))
	t.set_stylebox("pressed", "PrimaryButton", style(Color("216a65"), 17))
	for pair in [["CardButton", "f2f3ec", "e2efdf"], ["PaceButton", "f1f3ed", "e4f0e9"]]:
		t.set_type_variation(pair[0], "Button")
		t.set_stylebox("normal", pair[0], style(Color(pair[1]), 17))
		t.set_type_variation("Selected" + pair[0], "Button")
		t.set_stylebox("normal", "Selected" + pair[0], style(Color(pair[2]), 17, TEAL, 2))
	# Panels.
	t.set_stylebox("panel", "PanelContainer", style(CREAM, 22))
	for data in [["MenuPanel", "fffdf5f5", 30], ["CaptionPanel", "fffdf5e8", 30], ["ModalPanel", "fffdf5", 32]]:
		t.set_type_variation(data[0], "PanelContainer")
		t.set_stylebox("panel", data[0], style(Color(data[1]), data[2]))
	t.set_stylebox("background", "ProgressBar", style(Color("e4eeeb"), 4))
	t.set_stylebox("fill", "ProgressBar", style(TEAL, 4))
	t.set_font("title_font", "Window", BOLD)
	t.set_font("normal_font", "RichTextLabel", REGULAR)
	t.set_font_size("normal_font_size", "RichTextLabel", 16)
	return t

# --- widget helpers ----------------------------------------------------------

func _pin(c: Control, parent: Node, preset: Control.LayoutPreset, rect: Rect2, parent_size: Vector2 = CANVAS) -> void:
	# Place a control by its design-canvas rect, anchored to the given edge.
	parent.add_child(c)
	c.set_anchors_preset(preset)
	c.offset_left = rect.position.x - c.anchor_left * parent_size.x
	c.offset_top = rect.position.y - c.anchor_top * parent_size.y
	c.offset_right = rect.end.x - c.anchor_right * parent_size.x
	c.offset_bottom = rect.end.y - c.anchor_bottom * parent_size.y

func _container(c: Container, parent: Node = null, separation: int = -1) -> Container:
	# Pass no parent when the container will be placed with _pin instead.
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if separation >= 0: c.add_theme_constant_override("separation", separation)
	if parent: parent.add_child(c)
	return c

func _margins(parent: Node, left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", left)
	m.add_theme_constant_override("margin_top", top)
	m.add_theme_constant_override("margin_right", right)
	m.add_theme_constant_override("margin_bottom", bottom)
	return _container(m, parent)

func _spacer(parent: Node, height: float) -> void:
	var s := Control.new()
	s.custom_minimum_size.y = height
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(s)

func panel(variation: String = "") -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = variation
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

func label(text: String, variation: String = "", font_size: int = 20, centered: bool = false, height: float = 0) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	if font_size != 20: l.add_theme_font_size_override("font_size", font_size)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if centered: l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size.y = height
	return l

func button(text: String, variation: String = "", font_size: int = 22, min_size: Vector2 = Vector2.ZERO) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	if font_size != 22: b.add_theme_font_size_override("font_size", font_size)
	b.custom_minimum_size = min_size
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b

# --- menu --------------------------------------------------------------------

func _build_menu() -> void:
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(menu)
	var card := panel("MenuPanel")
	_pin(card, menu, Control.PRESET_LEFT_WIDE, Rect2(32, 32, 548, 736))
	var column := _container(VBoxContainer.new(), _margins(card, 32, 20, 32, 24), 0)
	column.add_child(label("PINECONE PEAK  /  SKI CLUB", "KickerLabel", 13, false, 28))
	_spacer(column, 10)
	column.add_child(label("Snow Pals", "BoldLabel", 68, false, 80))
	_spacer(column, 6)
	column.add_child(label("Little skis. Big smiles.", "MutedLabel", 22, false, 30))
	_spacer(column, 23)
	column.add_child(label("01   PICK YOUR PAL", "KickerLabel", 14, false, 28))
	_spacer(column, 13)
	var card_row := _container(HBoxContainer.new(), column, 10)
	for i in range(4):
		var b := button("", "CardButton", 22, Vector2(112, 160))
		b.tooltip_text = "%s the %s" % [Pals.NAMES[i], Pals.KINDS[i]]
		b.pressed.connect(func(): pal_selected.emit(i))
		card_row.add_child(b)
		cards.append(b)
		_add_portrait(b, Pals.KINDS[i])
		_pin(label(Pals.NAMES[i], "BoldLabel", 19, true), b, Control.PRESET_BOTTOM_WIDE, Rect2(0, 119, 112, 30), b.custom_minimum_size)
	_spacer(column, 24)
	column.add_child(label("02   CHOOSE YOUR PACE", "KickerLabel", 14, false, 24))
	_spacer(column, 12)
	var pace_row := _container(HBoxContainer.new(), column, 10)
	for i in range(2):
		var b := button("", "PaceButton", 22, Vector2(234, 70))
		_pin(label(["Bunny slope", "Little explorer"][i], "BoldLabel", 20), b, Control.PRESET_TOP_LEFT, Rect2(17, 8, 210, 26), b.custom_minimum_size)
		_pin(label(["Extra gentle · steering help", "A little faster · more exploring"][i], "MutedLabel", 12), b, Control.PRESET_TOP_LEFT, Rect2(17, 37, 214, 22), b.custom_minimum_size)
		b.pressed.connect(func(): pace_selected.emit(i))
		pace_row.add_child(b)
		paces.append(b)
	_spacer(column, 28)
	play_button = button("Let’s ski!    →", "PrimaryButton", 28, Vector2(0, 70))
	play_button.pressed.connect(func(): play_requested.emit())
	column.add_child(play_button)
	_spacer(column, 24)
	column.add_child(label("←  →   Steer     ↑   Slow     SPACE   Hop", "MutedLabel", 16, true, 25))
	_spacer(column, 4)
	column.add_child(label("Controller: stick / D-pad · A hop · + pause", "MutedLabel", 14, true, 22))
	# Hero text framing the selected pal on the right.
	var hero := _container(VBoxContainer.new(), null, 0)
	_pin(hero, menu, Control.PRESET_TOP_RIGHT, Rect2(690, 116, 480, 130))
	hero.add_child(label("THE MOUNTAIN IS YOURS", "KickerLabel", 13, true, 24))
	_spacer(hero, 7)
	pal_title = label("Meet Pip.", "BoldLabel", 44, true, 58)
	hero.add_child(pal_title)
	_spacer(hero, 2)
	pal_description = label(Pals.DESCRIPTIONS[0], "MutedLabel", 18, true, 30)
	hero.add_child(pal_description)
	var caption := panel("CaptionPanel")
	caption.add_child(label("Fresh snow. Happy little feet.", "KickerLabel", 17, true))
	_pin(caption, menu, Control.PRESET_BOTTOM_RIGHT, Rect2(821, 678, 304, 60))
	licenses_button = button("Licenses", "", 16)
	licenses_button.pressed.connect(_show_licenses)
	_pin(licenses_button, menu, Control.PRESET_BOTTOM_RIGHT, Rect2(1120, 744, 132, 40))

func _show_licenses() -> void:
	if not is_instance_valid(licenses_dialog):
		licenses_dialog = AcceptDialog.new()
		licenses_dialog.title = "Snow Pals — Licenses"
		licenses_dialog.ok_button_text = "Close"
		licenses_dialog.dialog_hide_on_ok = true
		add_child(licenses_dialog)
		licenses_dialog.visibility_changed.connect(func():
			if not licenses_dialog.visible: play_button.grab_focus())
		var tabs := TabContainer.new()
		tabs.custom_minimum_size = Vector2(960,560)
		licenses_dialog.add_child(tabs)
		_license_page(tabs, "Snow Pals", FileAccess.get_file_as_string("res://NOTICE.txt") + "\n\n" + FileAccess.get_file_as_string("res://LICENSE.txt"))
		_license_page(tabs, "Fonts", "Red Hat Display\n\n" + FileAccess.get_file_as_string("res://assets/fonts/LICENSE.txt") + "\n\nAdwaita Sans symbol fallback\n\n" + FileAccess.get_file_as_string("res://assets/fonts/SYMBOLS-LICENSE.txt"))
		_license_page(tabs, "Godot Engine", Engine.get_license_text())
		var notices := "Godot Engine third-party components\n\n"
		for component in Engine.get_copyright_info():
			notices += component.name + "\n"
			for part in component.parts:
				notices += "Files: " + ", ".join(part.files) + "\n"
				notices += "\n".join(part.copyright) + "\nLicense: " + part.license + "\n\n"
		var engine_licenses := Engine.get_license_info()
		for license_name in engine_licenses:
			notices += license_name + "\n\n" + engine_licenses[license_name] + "\n\n"
		_license_page(tabs, "Godot dependencies", notices)
	licenses_dialog.popup_centered()

func _license_page(tabs: TabContainer, title: String, text: String) -> void:
	var page := RichTextLabel.new()
	page.name = title
	page.text = text
	page.selection_enabled = true
	tabs.add_child(page)

func _add_portrait(parent: Button, kind: String) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(224,230)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	# The portrait never moves, so one render per menu visit is enough.
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	parent.add_child(viewport)
	portraits.append(viewport)
	var model: Node3D = load("res://assets/models/%s.glb" % kind).instantiate()
	viewport.add_child(model)
	model.rotation.y = -0.15
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.65
	camera.position = Vector3(0,3.1,7)
	camera.look_at(Vector3(0,1.5,0))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40,-30,0)
	light.light_energy = 0.8
	viewport.add_child(light)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("e7f0ff")
	world.environment.ambient_light_energy = 0.4
	viewport.add_child(world)
	var image := TextureRect.new()
	image.texture = viewport.get_texture()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pin(image, parent, Control.PRESET_TOP_WIDE, Rect2(0, 3, 112, 115), parent.custom_minimum_size)

# --- in-game HUD -------------------------------------------------------------

func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	var title := panel()
	_margins(title, 20, 4, 20, 8).add_child(label("Snow Pals", "BoldLabel", 27))
	_pin(title, hud, Control.PRESET_TOP_LEFT, Rect2(28, 26, 204, 62))
	var progress_panel := panel()
	var progress_column := _container(VBoxContainer.new(), _margins(progress_panel, 24, 5, 24, 14), 17)
	distance_label = label("A little mountain adventure", "BoldLabel", 16, true, 28)
	progress_column.add_child(distance_label)
	progress = ProgressBar.new()
	progress.show_percentage = false
	progress.custom_minimum_size.y = 8
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_column.add_child(progress)
	_pin(progress_panel, hud, Control.PRESET_CENTER_TOP, Rect2(398, 26, 484, 72))
	var corner := _container(HBoxContainer.new(), null, 14)
	_pin(corner, hud, Control.PRESET_TOP_RIGHT, Rect2(916, 26, 194, 62))
	var star_panel := panel()
	star_panel.custom_minimum_size.x = 122
	star_label = label("★  0", "StarLabel", 28, true)
	star_panel.add_child(star_label)
	corner.add_child(star_panel)
	pause_button = button("Ⅱ", "", 28, Vector2(58, 58))
	pause_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pause_button.tooltip_text = "Take a break (Esc, P or +)"
	pause_button.pressed.connect(func(): pause_requested.emit())
	corner.add_child(pause_button)
	message_label = label("Follow the stars!", "ToastLabel", 26, true)
	_pin(message_label, hud, Control.PRESET_CENTER_TOP, Rect2(320, 118, 640, 42))
	# Touch controls: steering on the left, slow and hop on the right.
	var steer := _container(HBoxContainer.new(), null, 12)
	var left := button("←", "", 38, Vector2(88, 88))
	var right := button("→", "", 38, Vector2(88, 88))
	left.button_down.connect(func(): left_held = true)
	left.button_up.connect(func(): left_held = false)
	right.button_down.connect(func(): right_held = true)
	right.button_up.connect(func(): right_held = false)
	steer.add_child(left)
	steer.add_child(right)
	_pin(steer, hud, Control.PRESET_BOTTOM_LEFT, Rect2(28, 678, 188, 88))
	var actions := _container(HBoxContainer.new(), null, 12)
	var brake := button("Slow", "", 22, Vector2(104, 78))
	brake.size_flags_vertical = Control.SIZE_SHRINK_END
	brake.button_down.connect(func(): brake_held = true)
	brake.button_up.connect(func(): brake_held = false)
	var jump := button("Hop ↑", "PrimaryButton", 26, Vector2(138, 88))
	jump.pressed.connect(func(): hop_requested.emit())
	actions.add_child(brake)
	actions.add_child(jump)
	_pin(actions, hud, Control.PRESET_BOTTOM_RIGHT, Rect2(998, 678, 254, 88))
	touch_buttons = {"left": left, "right": right, "slow": brake, "hop": jump}
	# Gameplay buttons never take keyboard or controller focus, so Space and A
	# always reach the skier through _unhandled_input.
	for b in [left, right, brake, jump, pause_button]:
		b.focus_mode = Control.FOCUS_NONE
	var hint := label("← →  STEER    ↑  SLOW    SPACE / A  HOP    +  PAUSE", "MutedLabel", 15, true)
	_pin(hint, hud, Control.PRESET_CENTER_BOTTOM, Rect2(320, 739, 640, 28))

func _build_modal() -> void:
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(modal)
	var shade := ColorRect.new()
	shade.color = Color(0.13,0.28,0.31,0.3)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(shade)
	var card := panel("ModalPanel")
	_pin(card, modal, Control.PRESET_CENTER, Rect2(340, 155, 600, 490))
	var column := _container(VBoxContainer.new(), _margins(card, 40, 33, 40, 47), 0)
	modal_icon = label("", "ModalIconLabel", 48, true, 72)
	column.add_child(modal_icon)
	_spacer(column, 20)
	modal_title = label("", "BoldLabel", 44, true, 65)
	column.add_child(modal_title)
	_spacer(column, 5)
	modal_subtitle = label("", "MutedLabel", 22, true, 34)
	column.add_child(modal_subtitle)
	_spacer(column, 12)
	modal_detail = label("", "TealLabel", 18, true, 30)
	column.add_child(modal_detail)
	_spacer(column, 35)
	modal_primary = button("", "PrimaryButton", 26, Vector2(480, 64))
	modal_primary.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	modal_primary.pressed.connect(func():
		if modal_finished: play_requested.emit()
		else: resume_requested.emit())
	column.add_child(modal_primary)
	_spacer(column, 19)
	home_button = button("Choose another pal", "", 20, Vector2(480, 54))
	home_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	home_button.pressed.connect(func(): home_requested.emit())
	column.add_child(home_button)

# --- state shown by the game ---------------------------------------------------

func select_pal(index: int) -> void:
	for i in range(cards.size()):
		cards[i].theme_type_variation = "SelectedCardButton" if i == index else "CardButton"
	pal_title.text = "Meet %s." % Pals.NAMES[index]
	pal_description.text = Pals.DESCRIPTIONS[index]

func select_pace(index: int) -> void:
	for i in range(paces.size()):
		paces[i].theme_type_variation = "SelectedPaceButton" if i == index else "PaceButton"

func show_menu() -> void:
	menu.show()
	hud.hide()
	modal.hide()
	_clear_holds()
	for v in portraits: v.render_target_update_mode = SubViewport.UPDATE_ONCE
	mute_button.focus_mode = Control.FOCUS_ALL
	play_button.grab_focus()

func show_game() -> void:
	menu.hide()
	hud.show()
	modal.hide()
	_clear_holds()
	for v in portraits: v.render_target_update_mode = SubViewport.UPDATE_DISABLED
	mute_button.focus_mode = Control.FOCUS_NONE
	get_viewport().gui_release_focus()

func show_modal(finished: bool, stars: int = 0) -> void:
	_clear_holds()
	modal_finished = finished
	modal_icon.text = "★   ★   ★" if finished else "Ⅱ"
	modal_title.text = "You did it!" if finished else "A little breather"
	modal_subtitle.text = "Warm cocoa for everyone." if finished else "Your mountain will be right here."
	modal_detail.text = "%d stars collected · So many happy turns!" % stars if finished else "Ready for a few more happy turns?"
	modal_primary.text = "Ski again!   →" if finished else "Keep skiing   →"
	modal.show()
	modal_primary.grab_focus()

func set_muted(muted: bool) -> void:
	mute_button.text = "Sound off" if muted else "Sound on"

func set_message_low(low: bool) -> void:
	# During a tumble the message sits beside the skier instead of under the HUD.
	message_label.offset_top = 588 if low else 118
	message_label.offset_bottom = message_label.offset_top + 42

func update_run(distance: float, stars: int, length: float) -> void:
	progress.max_value = length
	progress.value = distance
	star_label.text = "★  %d" % stars
	distance_label.text = "%d m   /   %d m     ·     The cocoa cabin" % [int(distance), int(length)]

func toast(text: String, duration: float = 2.2) -> void:
	message_label.text = text
	message_label.modulate.a = 1.0
	message_time = duration

func _process(delta: float) -> void:
	message_time = maxf(0,message_time-delta)
	if message_time <= 0: message_label.modulate.a = move_toward(message_label.modulate.a,0,delta)

# --- held controls -----------------------------------------------------------

func get_steer_axis() -> float:
	return (1.0 if right_held else 0.0) - (1.0 if left_held else 0.0)

func is_braking() -> bool:
	return brake_held

func _clear_holds() -> void:
	touch_actions.clear()
	left_held = false
	right_held = false
	brake_held = false

func _input(event: InputEvent) -> void:
	# Track fingers independently so a child can steer and hop at the same time.
	if not hud.visible or modal.visible: return
	if event is InputEventScreenTouch:
		if not event.pressed:
			if not touch_actions.has(event.index): return
			touch_actions.erase(event.index)
		else:
			var action := _touch_action(event.position)
			if action.is_empty(): return
			touch_actions[event.index] = action
			if action == "hop": hop_requested.emit()
		_update_touch_holds()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and touch_actions.has(event.index):
		touch_actions[event.index] = _touch_action(event.position)
		_update_touch_holds()
		get_viewport().set_input_as_handled()

func _touch_action(pos: Vector2) -> String:
	# Hit-test the real buttons so layout changes cannot desynchronise touch.
	for action in touch_buttons:
		if touch_buttons[action].get_global_rect().has_point(pos): return action
	return ""

func _update_touch_holds() -> void:
	left_held = "left" in touch_actions.values()
	right_held = "right" in touch_actions.values()
	brake_held = "slow" in touch_actions.values()
