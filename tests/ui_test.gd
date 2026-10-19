extends SceneTree
## Routes real input events through the viewport to verify focus and hit targets.
var game
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, text: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(text)

func click(pos: Vector2) -> void:
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = pos
		event.global_position = pos
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event,true)
		await process_frame

func press(code: int) -> void:
	for down in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		root.push_input(event,true)
		await process_frame

func center(c: Control) -> Vector2:
	return c.get_global_rect().get_center()

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.set_process(false)
	await click(center(game.ui.licenses_button))
	check(game.ui.licenses_dialog.visible,"licenses button opens the license dialog")
	var license_tabs: TabContainer
	for child in game.ui.licenses_dialog.get_children():
		if child is TabContainer: license_tabs = child
	check(license_tabs != null and license_tabs.get_tab_count()==4,"license dialog exposes project, fonts, engine, and dependencies")
	if license_tabs != null:
		check("GNU AFFERO GENERAL PUBLIC LICENSE" in license_tabs.get_child(0).text,"project tab includes the full AGPL")
		check("SIL OPEN FONT LICENSE" in license_tabs.get_child(1).text,"font tab includes the bundled font licenses")
		check(Engine.get_license_text() in license_tabs.get_child(2).text,"engine tab includes the running engine license")
	await press(KEY_ESCAPE)
	check(not game.ui.licenses_dialog.visible,"Escape closes the license dialog")
	check(root.gui_get_focus_owner()==game.ui.play_button,"closing licenses restores keyboard start focus")
	await click(center(game.ui.cards[1]))
	check(game.selected_pal==1,"portrait hit target chooses Clover")
	await click(center(game.ui.paces[1]))
	check(game.pace==1,"pace hit target chooses Little explorer")
	await click(center(game.ui.play_button))
	check(game.state==game.State.SKIING,"play hit target starts game")
	await press(KEY_P)
	check(game.state==game.State.PAUSED,"P pauses through input routing")
	await press(KEY_ENTER)
	check(game.state==game.State.SKIING,"Enter activates focused resume button")
	await click(center(game.ui.pause_button))
	check(game.state==game.State.PAUSED,"pause button hit target works")
	await click(center(game.ui.home_button))
	check(game.state==game.State.MENU,"home button returns to selection")
	await press(KEY_ENTER)
	check(game.state==game.State.SKIING,"keyboard-only start works")
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = center(game.ui.touch_buttons["left"])
	touch.pressed = true
	root.push_input(touch,true)
	await process_frame
	check(game.ui.left_held,"touch routes to left button")
	touch.pressed = false
	root.push_input(touch,true)
	await process_frame
	check(not game.ui.left_held,"touch release stops steering")
	check(game.ui.mute_button.get_global_rect().end.x<=1280,"sound button fits design canvas")
	print("SNOW PALS UI: %d checks, %d failures" % [checks,failures])
	game.queue_free()
	await process_frame
	await create_timer(.2).timeout
	quit(1 if failures else 0)
