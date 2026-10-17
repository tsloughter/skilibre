extends SceneTree
## Integration tests against the actual scene, imported Blender assets and UI signals.
## godot --headless --path . --script tests/game_test.gd -- --test
var game
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + description)

func step(seconds: float) -> void:
	for i in range(int(seconds*60)):
		game._process(1.0/60.0)

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.set_process(false)
	check(game.state == game.State.MENU,"starts on character selection")
	check(game.ui.cards.size()==4,"four selectable animal portraits")
	for i in range(4):
		game.ui.cards[i].pressed.emit()
		check(game.selected_pal==i,"character selection signal %d" % i)
		check(game.model.get_child_count()>10,"Blender animal mesh imported %d" % i)
	game.select_pal(0)
	game.ui.paces[1].pressed.emit()
	check(game.pace==1,"pace button selects explorer")
	game.ui.play_button.pressed.emit()
	check(game.state==game.State.SKIING and game.ui.hud.visible,"play enters skiing")
	check(not game.ui.menu.visible,"menu hidden during run")
	# Test steering/braking independently from the separately tested tumble delay.
	for item in game.items:
		if item.kind in ["pine","rock"]: item.active = false
	step(2)
	check(game.distance>8,"automatically skis downhill")
	var x: float = game.skier.position.x
	key(KEY_RIGHT,true)
	await process_frame
	step(1)
	key(KEY_RIGHT,false)
	await process_frame
	check(game.skier.position.x>x+2,"right arrow steers right")
	x = game.skier.position.x
	key(KEY_LEFT,true)
	await process_frame
	step(1.5)
	key(KEY_LEFT,false)
	await process_frame
	check(game.skier.position.x<x-2,"left arrow steers left")
	key(KEY_UP,true)
	await process_frame
	step(2)
	check(game.speed<.01,"up arrow stops gently")
	key(KEY_UP,false)
	await process_frame
	step(1)
	check(game.speed>5,"releasing brake resumes")
	game.ui.left_held = true
	x = game.skier.position.x
	step(1)
	check(game.skier.position.x<x,"on-screen steering works")
	game.ui.left_held = false
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = Vector2(60,720)
	touch.pressed = true
	game.ui._input(touch)
	check(game.ui.left_held,"touch left button holds steering")
	var second_touch := InputEventScreenTouch.new()
	second_touch.index = 1
	second_touch.position = Vector2(1160,720)
	second_touch.pressed = true
	game.ui._input(second_touch)
	check(game.ui.left_held and game.jump_time>0,"second finger hops while steering")
	touch.pressed = false
	game.ui._input(touch)
	second_touch.pressed = false
	game.ui._input(second_touch)
	check(not game.ui.left_held and game.ui.touch_actions.is_empty(),"touch release clears holds")
	step(1)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(900,400)
	motion.relative = Vector2(100,0)
	game._unhandled_input(motion)
	check(game.mouse_steering and game.mouse_target>0,"mouse projects onto snow")
	x = game.skier.position.x
	step(2)
	check(game.skier.position.x>x,"mouse steering moves toward cursor")
	game.mouse_steering = false
	game.hop()
	step(.4)
	check(game.model.position.y>1,"hop lifts model above snow")
	step(1)
	check(game.jump_time==0 and absf(game.model.position.y)<.1,"hop lands safely")
	var d: float = game.distance
	game.pause_run()
	step(3)
	check(game.distance==d and game.ui.modal.visible,"pause freezes simulation")
	game.resume_run()
	step(.5)
	check(game.distance>d and not game.ui.modal.visible,"resume continues")
	# Isolate collisions from the rest of the seeded course.
	for item in game.items: item.active = false
	game._add_item("star",game.skier.position+Vector3(0,1,0),1,true)
	var before: int = game.stars
	game._update_items(.016)
	game._update_items(.016)
	check(game.stars==before+1,"star is collected exactly once")
	game._add_item("rock",game.skier.position,1,true)
	game.recovery_time = 0
	game.jump_time = 0
	game._update_items(.016)
	check(game.crash_time>0 and game.state==game.State.CRASHED,"bump starts a seated tumble")
	step(3.1)
	check(game.state==game.State.SKIING,"tumble automatically recovers")
	game._add_item("ramp",game.skier.position,1,true)
	game._update_items(.016)
	check(game.jump_time>0,"ramp auto-hops")
	game.start_run()
	await process_frame
	check(game.stars==0 and game.distance==0,"restart clears counters")
	for pace_index in range(2):
		game.select_pace(pace_index)
		game.start_run()
		await process_frame
		step(2)
		check(game.speed>4 and game.speed<9,"pace speed in child-friendly range")
		var guard := 0
		while game.state in [game.State.SKIING,game.State.CRASHED] and guard<6000:
			game._process(1.0/60.0)
			guard += 1
			if guard%60==0: await process_frame
		check(game.state==game.State.FINISHED,"full run reaches celebration for pace %d" % pace_index)
		check(game.items.size()<140,"course nodes stay bounded")
		check(game.trails.size()<=180,"ski tracks stay bounded")
		check(game.ui.modal.visible,"finish shows replay and character choice")
	game.go_home()
	await process_frame
	check(game.state==game.State.MENU and game.items.is_empty(),"home clears course")
	game.start_run()
	await process_frame
	check(game.state==game.State.SKIING,"play works after returning home")
	game.toggle_sound()
	check(AudioServer.is_bus_mute(0)==game.muted,"mute state reaches audio bus")
	print("SNOW PALS: %d checks, %d failures" % [checks,failures])
	game.queue_free()
	await process_frame
	await create_timer(.2).timeout
	quit(1 if failures else 0)
