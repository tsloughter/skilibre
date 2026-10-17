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

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.set_process(false)
	await click(Vector2(240,340))
	check(game.selected_pal==1,"portrait hit target chooses Clover")
	await click(Vector2(420,525))
	check(game.pace==1,"pace hit target chooses Little explorer")
	await click(Vector2(300,620))
	check(game.state==game.State.SKIING,"play hit target starts game")
	await press(KEY_P)
	check(game.state==game.State.PAUSED,"P pauses through input routing")
	await press(KEY_ENTER)
	check(game.state==game.State.SKIING,"Enter activates focused resume button")
	await click(Vector2(1080,56))
	check(game.state==game.State.PAUSED,"pause button hit target works")
	await click(Vector2(600,570))
	check(game.state==game.State.MENU,"home button returns to selection")
	await press(KEY_ENTER)
	check(game.state==game.State.SKIING,"keyboard-only start works")
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = Vector2(60,720)
	touch.pressed = true
	root.push_input(touch,true)
	await process_frame
	check(game.ui.left_held,"touch routes to left button")
	touch.pressed = false
	root.push_input(touch,true)
	await process_frame
	check(not game.ui.left_held,"touch release stops steering")
	check(game.ui.mute_button.get_rect().end.x<=1280,"sound button fits design canvas")
	print("SNOW PALS UI: %d checks, %d failures" % [checks,failures])
	game.queue_free()
	await process_frame
	await create_timer(.2).timeout
	quit(1 if failures else 0)
