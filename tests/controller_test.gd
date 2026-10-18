extends SceneTree
## Exercise mapped controller events through the viewport and actual skiing loop.
var game
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)

func button(code: int, down: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame

func press(code: int) -> void:
	await button(code,true)
	await button(code,false)

func motion(code: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = code
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame

func step(seconds: float) -> void:
	for i in range(int(seconds*60)):
		game._process(1.0/60.0)

func clear_obstacles() -> void:
	for item in game.items:
		if item.kind in ["pine","rock"]: item.active = false

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.set_process(false)
	game.select_pace(1)
	await press(JOY_BUTTON_A) # Printed Nintendo B, not the requested A.
	check(game.state==game.State.MENU,"Nintendo B does not start the run")
	await press(JOY_BUTTON_B) # Printed Nintendo A, on the right.
	check(game.state==game.State.SKIING,"Nintendo A activates the focused play button")
	check(game.jump_time==0,"starting with A does not also jump")
	clear_obstacles()
	step(2)
	await motion(JOY_AXIS_LEFT_X,.12)
	game.mouse_steering = true
	game.mouse_target = game.skier.position.x
	step(.1)
	check(game.mouse_steering,"stick drift inside deadzone does not steal mouse steering")
	await motion(JOY_AXIS_LEFT_X,.5)
	check(Input.get_axis("ski_left","ski_right")>0 and Input.get_axis("ski_left","ski_right")<1,"partial stick tilt provides analog steering")
	var x: float = game.skier.position.x
	step(.5)
	check(game.skier.position.x>x and not game.mouse_steering,"stick steers right and takes over from mouse")
	check(root.gui_get_focus_owner()==null,"stick does not navigate HUD buttons")
	await motion(JOY_AXIS_LEFT_X,0)
	await button(JOY_BUTTON_DPAD_LEFT,true)
	x = game.skier.position.x
	step(1)
	check(game.skier.position.x<x,"D-pad steers left")
	await button(JOY_BUTTON_B,true)
	check(game.jump_time>0,"Nintendo A hops while D-pad is held")
	step(.4)
	check(game.model.position.y>1,"controller hop visibly lifts the skier")
	step(1)
	check(game.jump_time==0,"holding A does not repeatedly hop")
	await button(JOY_BUTTON_B,false)
	await button(JOY_BUTTON_DPAD_LEFT,false)
	await press(JOY_BUTTON_A)
	check(game.jump_time==0,"Nintendo B does not hop")
	await motion(JOY_AXIS_LEFT_Y,-1)
	step(2)
	check(game.speed<.01,"stick up brakes to a stop")
	await motion(JOY_AXIS_LEFT_Y,0)
	step(1)
	check(game.speed>5,"centering stick releases brake")
	await button(JOY_BUTTON_DPAD_UP,true)
	step(2)
	check(game.speed<.01,"D-pad up brakes to a stop")
	await button(JOY_BUTTON_DPAD_UP,false)
	await button(JOY_BUTTON_DPAD_DOWN,true)
	step(2)
	check(game.speed>8,"D-pad down gives the explorer pace a small boost")
	await button(JOY_BUTTON_DPAD_DOWN,false)
	await press(JOY_BUTTON_START)
	check(game.state==game.State.PAUSED,"+ pauses")
	var distance: float = game.distance
	await press(JOY_BUTTON_B)
	check(game.state==game.State.SKIING and game.jump_time==0,"A resumes through the GUI without jumping")
	await press(JOY_BUTTON_START)
	step(1)
	check(game.distance==distance,"pause freezes the run")
	await press(JOY_BUTTON_START)
	check(game.state==game.State.SKIING,"+ also resumes")
	# Even a clicked/focused HUD button must not hijack A or D-pad input.
	game.ui.mute_button.grab_focus()
	var muted: bool = game.muted
	await press(JOY_BUTTON_B)
	check(game.jump_time>0 and game.muted==muted,"A hops instead of activating a focused HUD button")
	game.jump_time = 0
	game._begin_crash(game.skier)
	await press(JOY_BUTTON_B)
	check(game.state==game.State.CRASHED and game.jump_time==0,"A cannot bypass tumble recovery")
	await press(JOY_BUTTON_START)
	check(game.state==game.State.PAUSED,"+ pauses a tumble")
	await press(JOY_BUTTON_START)
	check(game.state==game.State.CRASHED,"+ resumes the tumble")
	game._finish_run()
	await press(JOY_BUTTON_B)
	check(game.state==game.State.SKIING and game.distance==0,"A starts another run from the finish screen")
	game.go_home()
	game.ui.cards[0].grab_focus()
	await press(JOY_BUTTON_DPAD_RIGHT)
	check(root.gui_get_focus_owner()==game.ui.cards[1],"D-pad navigates animal choices")
	await press(JOY_BUTTON_B)
	check(game.selected_pal==1,"A selects a pal")
	game.ui._show_licenses()
	await process_frame
	await press(JOY_BUTTON_A)
	check(not game.ui.licenses_dialog.visible,"Nintendo B closes the license dialog")
	print("SNOW PALS CONTROLLER: %d checks, %d failures" % [checks,failures])
	game.queue_free()
	await process_frame
	await create_timer(.2).timeout
	quit(1 if failures else 0)
