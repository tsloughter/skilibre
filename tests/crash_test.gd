extends SceneTree
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

func step(seconds: float) -> void:
	for i in range(roundi(seconds*60)):
		game._process(1.0/60)

func prepare(pal: int) -> void:
	game.select_pal(pal)
	game.start_run()
	for item in game.items: item.active = false
	game.stars = 7

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	game.set_process(false)
	for pal in range(4):
		for kind in ["pine","rock"]:
			prepare(pal)
			await process_frame
			game._add_item(kind,Vector3(0,0,.8),1,true)
			game._update_items(.016)
			check(game.state==game.State.CRASHED,"%s/%s triggers tumble" % [pal,kind])
			check(game.pose.halo.visible and game.pose.orbit_stars.size()==4,"four circling stars appear")
			var start: Vector3 = game.skier.position
			game.ui.right_held = true
			game.hop()
			step(.6)
			check(game.skier.position==start and game.speed==0 and game.jump_time==0,"skier sits still despite steering/hop")
			var head_part: Dictionary
			var head_count := 0
			for part in game.pose.parts:
				if part.category=="head":
					head_part = part
					head_count += 1
			check(head_count>=10,"face and ears are included in head pose")
			check(not head_part.node.transform.is_equal_approx(head_part.rest),"head is posed independently")
			var head_before: Transform3D = head_part.node.transform
			var star_before: Vector3 = game.pose.orbit_stars[0].position
			step(.2)
			check(not head_part.node.transform.is_equal_approx(head_before),"head wobbles while sitting")
			check(not game.pose.orbit_stars[0].position.is_equal_approx(star_before),"stars orbit rather than staying still")
			check(game.pose.legs[0].visible,"sitting legs extend in front of body")
			game.pause_run()
			var remaining: float = game.crash_time
			var pose_before: Transform3D = head_part.node.transform
			step(5)
			check(game.crash_time==remaining and head_part.node.transform==pose_before,"pause freezes timer and pose")
			game.resume_run()
			check(game.state==game.State.CRASHED,"resume returns to tumble")
			step(2)
			check(game.state==game.State.CRASHED,"tumble lasts a full three seconds")
			step(.3)
			check(game.state==game.State.SKIING and game.distance>3.8,"respawns past obstacle")
			check(game.stars==7,"tumble preserves collected stars")
			check(not game.pose.halo.visible and not game.pose.legs[0].visible,"recovery hides dizzy effect and sitting legs")
			for part in game.pose.parts:
				check(part.node.transform.is_equal_approx(part.rest),"restores original mesh transform")
			var recovered_z: float = game.distance
			step(.5)
			check(game.distance>recovered_z and game.speed>0,"continues skiing automatically")
	# Adjacent obstacles must not occupy the chosen respawn spot.
	prepare(0)
	await process_frame
	game._add_item("rock",Vector3(0,0,.5),1,true)
	game._add_item("pine",Vector3(0,0,4),1,true)
	game._update_items(.016)
	step(3.1)
	check(game.distance>=7,"respawn clears an adjacent obstacle too")
	game._add_item("rock",game.skier.position,1,true)
	game._update_items(.016)
	check(game.state==game.State.SKIING,"brief recovery grace prevents immediate repeated crash")
	step(1.3)
	game._add_item("rock",game.skier.position,1,true)
	game._update_items(.016)
	check(game.state==game.State.CRASHED,"later collisions still trigger tumbles")
	game.go_home()
	check(game.crash_time==0 and not game.pose.halo.visible,"home cancels tumble")
	prepare(1)
	await process_frame
	game.hop()
	step(.4)
	game._add_item("rock",game.skier.position,1,true)
	game._update_items(.016)
	check(game.state==game.State.SKIING,"hopping clears an obstacle without tumbling")
	game.jump_time = 0
	game._update_items(.016)
	check(game.state==game.State.CRASHED,"ground contact triggers tumble")
	game.start_run()
	check(game.crash_time==0 and game.distance==0 and not game.pose.halo.visible,"restart clears crash state and pose")
	print("SNOW PALS TUMBLES: %d checks, %d failures" % [checks,failures])
	game.queue_free()
	await process_frame
	await create_timer(.2).timeout
	quit(1 if failures else 0)
