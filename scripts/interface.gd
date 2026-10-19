extends Control
## Fixed design canvas, scaled by the project's 1280 × 800 stretch settings.

signal pal_selected(index: int)
signal pace_selected(index: int)
signal play_requested
signal pause_requested
signal resume_requested
signal home_requested
signal sound_requested
signal hop_requested

const INK = Color("264b50")
const TEAL = Color("287f78")
const MUTED = Color("6e898c")
const CREAM = Color("fffdf5")
const GOLD = Color("f8c76b")
const NAMES = ["Pip", "Clover", "Maple", "Pebble"]
const KINDS = ["fox", "bunny", "bear", "penguin"]
const DESCRIPTIONS = ["A curious little fox", "A bunny with happy feet", "A bear who loves fresh snow", "A very cool little penguin"]
const BOLD = preload("res://assets/fonts/Display-Bold.otf")
const REGULAR = preload("res://assets/fonts/Display-Medium.otf")
const SYMBOLS = preload("res://assets/fonts/Symbols.ttf")

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
var progress_fill: Panel
var mute_button: Button
var left_held := false
var right_held := false
var brake_held := false
var portraits: Array[SubViewport] = []
var play_button: Button
var message_time := 0.0
var touch_actions: Dictionary = {}
var touch_buttons: Dictionary = {}
var licenses_dialog: AcceptDialog

func _ready() -> void:
	BOLD.set_fallbacks([SYMBOLS])
	REGULAR.set_fallbacks([SYMBOLS])
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_menu()
	_build_hud()
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(modal)
	mute_button = button(self, "Sound on", Rect2(1126, 28, 126, 44), false, 16)
	mute_button.pressed.connect(func(): sound_requested.emit())
	hud.hide()
	modal.hide()
	play_button.grab_focus()

func style(color: Color, radius: int = 20, border: Color = Color.TRANSPARENT, width: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(width)
	return s

func panel(parent: Node, rect: Rect2, color: Color, radius: int = 24) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.add_theme_stylebox_override("panel", style(color, radius))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p

func label(parent: Node, text: String, rect: Rect2, font_size: int = 20, color: Color = INK, bold: bool = false, centered: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.position = rect.position
	l.size = rect.size
	l.add_theme_font_override("font", BOLD if bold else REGULAR)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if centered: l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func button(parent: Node, text: String, rect: Rect2, primary: bool = false, font_size: int = 22) -> Button:
	var b := Button.new()
	b.text = text
	b.position = rect.position
	b.size = rect.size
	b.add_theme_font_override("font", BOLD)
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", Color.WHITE if primary else INK)
	b.add_theme_color_override("font_hover_color", Color.WHITE if primary else INK)
	b.add_theme_color_override("font_pressed_color", Color.WHITE if primary else INK)
	b.add_theme_stylebox_override("normal", style(TEAL if primary else CREAM, 17))
	b.add_theme_stylebox_override("hover", style(Color("368f87") if primary else Color("e4f1ed"), 17))
	b.add_theme_stylebox_override("pressed", style(Color("216a65") if primary else Color("cfe5de"), 17))
	b.add_theme_stylebox_override("focus", style(Color.TRANSPARENT, 17, GOLD, 3))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(b)
	return b

func _build_menu() -> void:
	menu = Control.new()
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(menu)
	panel(menu, Rect2(32,32,548,736), Color("fffdf5f5"), 30)
	label(menu, "PINECONE PEAK  /  SKI CLUB", Rect2(64,55,480,28), 13, TEAL, true)
	label(menu, "Snow Pals", Rect2(60,90,490,80), 68, INK, true)
	label(menu, "Little skis. Big smiles.", Rect2(65,176,470,30), 22, MUTED)
	label(menu, "01   PICK YOUR PAL", Rect2(64,229,470,28), 14, TEAL, true)
	for i in range(4):
		var b := button(menu, "", Rect2(64+i*122,270,112,160))
		b.tooltip_text = "%s the %s" % [NAMES[i], KINDS[i]]
		b.pressed.connect(func(): pal_selected.emit(i))
		cards.append(b)
		_add_portrait(b, KINDS[i])
		label(b, NAMES[i], Rect2(0,119,112,30), 19, INK, true, true)
	label(menu, "02   CHOOSE YOUR PACE", Rect2(64,454,470,24), 14, TEAL, true)
	for i in range(2):
		var b := button(menu, "", Rect2(64+i*244,490,234,70))
		label(b, ["Bunny slope", "Little explorer"][i], Rect2(17,8,210,26), 20, INK, true)
		label(b, ["Extra gentle · steering help", "A little faster · more exploring"][i], Rect2(17,37,214,22), 12, MUTED)
		b.pressed.connect(func(): pace_selected.emit(i))
		paces.append(b)
	play_button = button(menu, "Let’s ski!    →", Rect2(64,588,478,70), true, 28)
	play_button.pressed.connect(func(): play_requested.emit())
	label(menu, "←  →   Steer     ↑   Slow     SPACE   Hop", Rect2(64,682,478,25), 16, MUTED, false, true)
	label(menu, "Controller: stick / D-pad · A hop · + pause", Rect2(64,711,478,22), 14, MUTED, false, true)
	label(menu, "THE MOUNTAIN IS YOURS", Rect2(690,116,480,24), 13, TEAL, true, true)
	pal_title = label(menu, "Meet Pip.", Rect2(690,147,480,58), 44, INK, true, true)
	pal_description = label(menu, DESCRIPTIONS[0], Rect2(690,207,480,30), 18, MUTED, false, true)
	panel(menu, Rect2(821,678,304,60), Color("fffdf5e8"), 30)
	label(menu, "Fresh snow. Happy little feet.", Rect2(821,678,304,60), 17, TEAL, true, true)
	var licenses := button(menu, "Licenses", Rect2(1120,744,132,40), false, 16)
	licenses.pressed.connect(_show_licenses)

func _show_licenses() -> void:
	if not is_instance_valid(licenses_dialog):
		licenses_dialog = AcceptDialog.new()
		licenses_dialog.title = "Snow Pals — Licenses"
		licenses_dialog.ok_button_text = "Close"
		licenses_dialog.dialog_hide_on_ok = true
		licenses_dialog.add_theme_font_override("font", REGULAR)
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
	page.add_theme_font_override("normal_font", REGULAR)
	page.add_theme_font_size_override("normal_font_size", 16)
	tabs.add_child(page)

func _add_portrait(parent: Control, kind: String) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(224,230)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
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
	image.position = Vector2(0,3)
	image.size = Vector2(112,115)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)

func _build_hud() -> void:
	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	panel(hud, Rect2(28,26,204,62), CREAM, 22)
	label(hud, "Snow Pals", Rect2(48,30,164,50), 27, INK, true)
	panel(hud, Rect2(398,26,484,72), CREAM, 22)
	distance_label = label(hud, "A little mountain adventure", Rect2(420,31,440,28), 16, INK, true, true)
	panel(hud, Rect2(422,76,436,8), Color("e4eeeb"), 4)
	progress_fill = panel(hud, Rect2(422,76,0,8), TEAL, 4)
	panel(hud, Rect2(916,26,122,62), CREAM, 22)
	star_label = label(hud, "★  0", Rect2(926,30,102,50), 28, Color("a87524"), true, true)
	var pause_btn := button(hud, "Ⅱ", Rect2(1052,28,58,58), false, 28)
	pause_btn.tooltip_text = "Take a break (Esc, P or +)"
	pause_btn.pressed.connect(func(): pause_requested.emit())
	message_label = label(hud, "Follow the stars!", Rect2(320,118,640,42), 26, TEAL, true, true)
	message_label.add_theme_color_override("font_shadow_color", Color("ffffff"))
	message_label.add_theme_constant_override("shadow_offset_x", 1)
	message_label.add_theme_constant_override("shadow_offset_y", 2)
	var left := button(hud, "←", Rect2(28,678,88,88), false, 38)
	var right := button(hud, "→", Rect2(128,678,88,88), false, 38)
	left.button_down.connect(func(): left_held = true)
	left.button_up.connect(func(): left_held = false)
	right.button_down.connect(func(): right_held = true)
	right.button_up.connect(func(): right_held = false)
	var brake := button(hud, "Slow", Rect2(998,688,104,78), false, 22)
	brake.button_down.connect(func(): brake_held = true)
	brake.button_up.connect(func(): brake_held = false)
	var jump := button(hud, "Hop ↑", Rect2(1114,678,138,88), true, 26)
	jump.pressed.connect(func(): hop_requested.emit())
	touch_buttons = {"left": left, "right": right, "slow": brake, "hop": jump}
	label(hud, "← →  STEER    ↑  SLOW    SPACE / A  HOP    +  PAUSE", Rect2(320,739,640,28), 15, MUTED, true, true)

func select_pal(index: int) -> void:
	for i in range(cards.size()):
		cards[i].add_theme_stylebox_override("normal", style(Color("e2efdf") if i==index else Color("f2f3ec"), 17, TEAL if i==index else Color.TRANSPARENT, 2 if i==index else 0))
	pal_title.text = "Meet %s." % NAMES[index]
	pal_description.text = DESCRIPTIONS[index]

func select_pace(index: int) -> void:
	for i in range(paces.size()):
		paces[i].add_theme_stylebox_override("normal", style(Color("e4f0e9") if i==index else Color("f1f3ed"),17,TEAL if i==index else Color.TRANSPARENT,2 if i==index else 0))

func show_menu() -> void:
	menu.show()
	hud.hide()
	modal.hide()
	_clear_holds()
	for v in portraits: v.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	play_button.grab_focus()

func show_game() -> void:
	menu.hide()
	hud.show()
	modal.hide()
	_clear_holds()
	for v in portraits: v.render_target_update_mode = SubViewport.UPDATE_DISABLED
	get_viewport().gui_release_focus()

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

func update_run(distance: float, stars: int, length: float) -> void:
	progress_fill.visible = distance > 0
	progress_fill.size.x = clampf(distance / length,0,1)*436
	star_label.text = "★  %d" % stars
	distance_label.text = "%d m   /   %d m     ·     The cocoa cabin" % [int(distance), int(length)]

func toast(text: String, duration: float = 2.2) -> void:
	message_label.text = text
	message_label.modulate.a = 1.0
	message_time = duration

func _process(delta: float) -> void:
	message_time = maxf(0,message_time-delta)
	if message_time <= 0: message_label.modulate.a = move_toward(message_label.modulate.a,0,delta)

func show_modal(finished: bool, stars: int = 0) -> void:
	for child in modal.get_children(): child.queue_free()
	_clear_holds()
	modal.show()
	var shade := ColorRect.new()
	shade.color = Color(0.13,0.28,0.31,0.3)
	shade.size = Vector2(1280,800)
	modal.add_child(shade)
	panel(modal, Rect2(340,155,600,490), CREAM, 32)
	label(modal, "★   ★   ★" if finished else "Ⅱ", Rect2(400,188,480,72), 48, Color("d6a348"), true, true)
	label(modal, "You did it!" if finished else "A little breather", Rect2(380,280,520,65), 44, INK, true, true)
	label(modal, "Warm cocoa for everyone." if finished else "Your mountain will be right here.", Rect2(380,350,520,34), 22, MUTED, false, true)
	label(modal, "%d stars collected · So many happy turns!" % stars if finished else "Ready for a few more happy turns?", Rect2(380,396,520,30), 18, TEAL, false, true)
	var primary := button(modal, "Ski again!   →" if finished else "Keep skiing   →", Rect2(400,461,480,64), true, 26)
	primary.pressed.connect(func():
		if finished: play_requested.emit()
		else: resume_requested.emit())
	var home := button(modal, "Choose another pal", Rect2(400,544,480,54), false, 20)
	home.pressed.connect(func(): home_requested.emit())
	primary.grab_focus()

func set_muted(muted: bool) -> void:
	mute_button.text = "Sound off" if muted else "Sound on"
