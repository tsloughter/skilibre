extends Node3D
## Downhill is world +Z and screen down. The camera never rotates with the skier.
## Course coordinates stay local to the start; each short run resets the course.

const UI = preload("res://scripts/interface.gd")
const SkierPose = preload("res://scripts/skier_pose.gd")
const KINDS = ["fox", "bunny", "bear", "penguin"]
const RUN_LENGTH := 360.0
const EDGE := 11.8
const SETTINGS_PATH := "user://snow_pals.cfg"
const CRASH_DURATION := 3.0
const RESPAWN_GRACE := 1.25

enum State { MENU, SKIING, CRASHED, PAUSED, FINISHED }
var state := State.MENU
var selected_pal := 0
var pace := 0
var muted := false
var stars := 0
var distance := 0.0
var speed := 0.0
var steer := 0.0
var jump_time := 0.0
var crash_time := 0.0
var recovery_time := 0.0
var respawn_z := 0.0
var tumble_side := 0.0
var pose: SkierPose
var time := 0.0
var row_z := 0.0
var track_clock := 0.0
var mouse_steering := false
var mouse_target := 0.0
var course_rng := RandomNumberGenerator.new()
var camera: Camera3D
var skier: Node3D
var model: Node3D
var ground: MeshInstance3D
var menu_world: Node3D
var course: Node3D
var trail_root: Node3D
var ui: UI
var items: Array[Dictionary] = []
var trails: Array[Node3D] = []
var particles: Array[Dictionary] = []
var scenes: Dictionary = {}
var materials: Dictionary = {}
var sounds: Dictionary = {}
var music: AudioStreamPlayer
var sfx: Array[AudioStreamPlayer] = []
var sfx_index := 0
var settings_enabled := true
var capture_mode := ""

func _ready() -> void:
	settings_enabled = not "--test" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_mode = arg.trim_prefix("--capture=")
	if settings_enabled: _load_settings()
	for kind in KINDS + ["pine", "rock", "ramp", "star"]:
		scenes[kind] = load("res://assets/models/%s.glb" % kind)
	_make_materials()
	_build_world()
	_build_audio()
	var canvas := CanvasLayer.new()
	add_child(canvas)
	ui = UI.new()
	canvas.add_child(ui)
	ui.pal_selected.connect(select_pal)
	ui.pace_selected.connect(select_pace)
	ui.play_requested.connect(start_run)
	ui.pause_requested.connect(pause_run)
	ui.resume_requested.connect(resume_run)
	ui.home_requested.connect(go_home)
	ui.hop_requested.connect(hop)
	ui.sound_requested.connect(toggle_sound)
	ui.select_pal(selected_pal)
	ui.select_pace(pace)
	ui.set_muted(muted)
	AudioServer.set_bus_mute(0, muted)
	go_home()
	if not capture_mode.is_empty(): _capture()

func _make_materials() -> void:
	for pair in [["snow","cedfe6"],["drift","e6f1f6"],["track","abc9d5"],["teal","438d87"],["wood","b28b6f"],["coral","ed9079"],["gold","f9ca74"],["blue","85a8bf"],["cream","fff3dc"]]:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(pair[1])
		m.roughness = 0.9
		materials[pair[0]] = m

func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, material: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = materials[material]
	instance.position = pos
	parent.add_child(instance)
	return instance

func _box(parent: Node3D, pos: Vector3, size_: Vector3, material: String) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size_
	return _mesh(parent,mesh,pos,material)

func _ball(parent: Node3D, pos: Vector3, scale_: Vector3, material: String) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	var instance := _mesh(parent,mesh,pos,material)
	instance.scale = scale_
	return instance

func _asset(kind: String, parent: Node3D, pos: Vector3, size_: float = 1.0) -> Node3D:
	var instance: Node3D = scenes[kind].instantiate()
	parent.add_child(instance)
	instance.position = pos
	instance.scale = Vector3.ONE * size_
	return instance

func _build_world() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("d6e9ef")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d7e8f9")
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52,-28,0)
	sun.light_color = Color("fff2d8")
	sun.light_energy = 0.4
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.65
	sun.directional_shadow_max_distance = 85.0
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 25
	camera.far = 200
	add_child(camera)
	camera.current = true
	ground = _box(self,Vector3(0,-0.35,0),Vector3(180,0.6,220),"snow")
	course = Node3D.new()
	add_child(course)
	trail_root = Node3D.new()
	add_child(trail_root)
	skier = Node3D.new()
	add_child(skier)
	menu_world = Node3D.new()
	add_child(menu_world)
	_build_menu_scenery()
	_replace_pal()

func _build_menu_scenery() -> void:
	# Small handcrafted diorama framing the selected pal to the right of the menu.
	for data in [[-12,-8,1.7],[-7,-12,1.8],[-1,-10,1.4],[5,-10,1.4],[10,-7,1.7],[14,-3,1.5],[15,3,1.3],[12,9,1.4],[0,11,1.6],[-2,5,1.5],[2,-6,1.0]]:
		_asset("pine",menu_world,Vector3(data[0],0,data[1]),data[2])
	for data in [[10,4,1.4],[1,8,0.8],[13,-6,1.2]]:
		_asset("rock",menu_world,Vector3(data[0],0,data[1]),data[2])
	for data in [[-1,-11,6],[12,-13,5],[-13,3,5],[15,10,4]]:
		_ball(menu_world,Vector3(data[0],-.4,data[1]),Vector3(data[2],.9,data[2]*.7),"drift")
	_bunting(menu_world,Vector3(6,0,8),8.0)
	# Curved ski marks lead into the hero's little patch of snow.
	for i in range(28):
		var z := -8.0+i*.3
		var x := 6.2+sin(i*.12)*1.2
		for side in [-.34,.34]:
			var t := _box(menu_world,Vector3(x+side,.005,z),Vector3(.055,.012,.33),"track")
			t.rotation.y = cos(i*.12)*.4

func _bunting(parent: Node3D, pos: Vector3, width: float) -> void:
	for x in [-width/2,width/2]:
		_box(parent,pos+Vector3(x,1.6,0),Vector3(.09,3.2,.09),"wood")
		_ball(parent,pos+Vector3(x,3.22,0),Vector3.ONE*.13,"cream")
	_box(parent,pos+Vector3(0,2.9,0),Vector3(width,.035,.035),"cream")
	for i in range(9):
		var x := -width/2+.5+i*(width-1)/8
		var mesh := ImmediateMesh.new()
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		mesh.surface_add_vertex(Vector3(-.24,0,0))
		mesh.surface_add_vertex(Vector3(0,-.48,0))
		mesh.surface_add_vertex(Vector3(.24,0,0))
		mesh.surface_end()
		var m: StandardMaterial3D = materials[["coral","gold","teal"][i%3]].duplicate()
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		var flag := _mesh(parent,mesh,pos+Vector3(x,2.88,0),"coral")
		flag.material_override = m

func _cabin(z: float) -> void:
	var root := Node3D.new()
	course.add_child(root)
	root.position = Vector3(7,0,z)
	_box(root,Vector3(0,1.35,0),Vector3(4.5,2.7,3.8),"wood")
	for side in [-1,1]:
		var roof := _box(root,Vector3(side*1.2,3.0,0),Vector3(2.9,.23,4.5),"teal")
		roof.rotation.z = side*-.5
		var snow := _box(root,Vector3(side*1.2,3.13,0),Vector3(2.9,.16,4.5),"drift")
		snow.rotation.z = side*-.5
	_box(root,Vector3(0,.9,1.93),Vector3(.95,1.8,.08),"teal")
	for side in [-1,1]:
		_box(root,Vector3(side*1.4,1.5,1.94),Vector3(.8,.9,.06),"cream")
		_box(root,Vector3(side*1.4,1.5,2),Vector3(.045,.9,.03),"wood")
		_box(root,Vector3(side*1.4,1.5,2),Vector3(.8,.045,.03),"wood")
	var sign_label := Label3D.new()
	sign_label.text = "COCOA"
	sign_label.font = UI.BOLD
	sign_label.font_size = 48
	sign_label.pixel_size = .009
	sign_label.position = Vector3(0,2.45,1.95)
	sign_label.modulate = Color("fff3dc")
	sign_label.outline_size = 0
	root.add_child(sign_label)
	_bunting(course,Vector3(0,0,z-4),10.0)

func _replace_pal() -> void:
	if is_instance_valid(model):
		skier.remove_child(model)
		model.queue_free()
	model = _asset(KINDS[selected_pal],skier,Vector3.ZERO)
	pose = SkierPose.new()
	pose.setup(model,scenes["star"],KINDS[selected_pal])

func _reset_crash() -> void:
	crash_time = 0
	recovery_time = 0
	respawn_z = 0
	tumble_side = 0
	pose.reset()
	model.position = Vector3.ZERO
	model.rotation = Vector3.ZERO
	ui.message_label.position.y = 118

func select_pal(index: int) -> void:
	selected_pal = clampi(index,0,3)
	_replace_pal()
	ui.select_pal(selected_pal)
	_save_settings()
	_play_sound("pick")

func select_pace(index: int) -> void:
	pace = clampi(index,0,1)
	ui.select_pace(pace)
	_save_settings()
	_play_sound("pick")

func go_home() -> void:
	state = State.MENU
	_reset_crash()
	_clear_course()
	menu_world.show()
	skier.position = Vector3(6.3,0,2.0)
	skier.scale = Vector3.ONE*2.15
	skier.rotation = Vector3.ZERO
	ground.position.z = 0
	camera.size = 21
	camera.position = Vector3(0,22,23)
	camera.look_at(Vector3(0,0,1))
	ui.show_menu()
	mouse_steering = false

func _clear_course() -> void:
	for child in course.get_children(): child.queue_free()
	for child in trail_root.get_children(): child.queue_free()
	items.clear()
	trails.clear()
	particles.clear()

func start_run() -> void:
	_clear_course()
	_reset_crash()
	state = State.SKIING
	menu_world.hide()
	skier.scale = Vector3.ONE*1.1
	skier.position = Vector3.ZERO
	skier.rotation = Vector3.ZERO
	model.rotation = Vector3.ZERO
	stars = 0
	distance = 0
	speed = 0
	steer = 0
	jump_time = 0
	track_clock = 0
	mouse_steering = false
	course_rng.seed = 4080 + selected_pal*17 + pace*137
	row_z = -24
	while row_z < 85:
		_spawn_row(row_z)
		row_z += 8
	_cabin(RUN_LENGTH+8)
	_follow_camera()
	ui.show_game()
	ui.update_run(0,0,RUN_LENGTH)
	ui.toast("Follow the stars. There’s no hurry!",4.0)
	_play_sound("start")

func pause_run() -> void:
	if state not in [State.SKIING,State.CRASHED]: return
	state = State.PAUSED
	mouse_steering = false
	ui.show_modal(false)

func resume_run() -> void:
	if state != State.PAUSED: return
	state = State.CRASHED if crash_time > 0 else State.SKIING
	ui.show_game()
	ui.toast("A little tumble! Back up in a moment." if crash_time > 0 else "Off we go!", maxf(crash_time,1.5))

func hop() -> void:
	if state != State.SKIING or jump_time > 0: return
	jump_time = .9
	_play_sound("hop")

func _input(event: InputEvent) -> void:
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion): return
	# Handle gameplay before the GUI: A always hops, even if a HUD button has focus.
	if event.is_action_pressed("ski_pause"):
		if state in [State.SKIING,State.CRASHED]: pause_run()
		elif state == State.PAUSED: resume_run()
		get_viewport().set_input_as_handled()
	elif state in [State.SKIING,State.CRASHED]:
		if event.is_action_pressed("ski_hop"): hop()
		# Stick/D-pad navigation belongs to menus only; gameplay polls these actions.
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ESCAPE,KEY_P]:
			if state in [State.SKIING,State.CRASHED]: pause_run()
			elif state == State.PAUSED: resume_run()
		elif event.keycode == KEY_SPACE:
			hop()
		elif event.keycode == KEY_M: toggle_sound()
		elif event.keycode == KEY_F11:
			var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
		if event.keycode in [KEY_LEFT,KEY_RIGHT,KEY_A,KEY_D,KEY_UP,KEY_DOWN]: mouse_steering = false
	if state != State.SKIING: return
	if event is InputEventMouseMotion and event.relative.length() > 1.5:
		if event.position.y > 110 and event.position.y < 675:
			var origin := camera.project_ray_origin(event.position)
			var ray := camera.project_ray_normal(event.position)
			mouse_target = clampf((origin+ray*(-origin.y/ray.y)).x,-EDGE,EDGE)
			mouse_steering = true
	if event is InputEventScreenDrag or event is InputEventScreenTouch:
		if event.position.y > 110 and event.position.y < 675:
			var origin := camera.project_ray_origin(event.position)
			var ray := camera.project_ray_normal(event.position)
			mouse_target = clampf((origin+ray*(-origin.y/ray.y)).x,-EDGE,EDGE)
			mouse_steering = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state in [State.SKIING,State.CRASHED] and capture_mode.is_empty():
		pause_run()

func _process(delta: float) -> void:
	# A long frame must not skip collision windows or send a child into a tree.
	var dt := minf(delta,.05)
	if state in [State.PAUSED,State.FINISHED]: return
	time += dt
	if state == State.MENU:
		model.rotation.y = -.16+sin(time*.7)*.12
		model.position.y = sin(time*1.8)*.035
		return
	if state == State.CRASHED:
		crash_time = maxf(0,crash_time-dt)
		var elapsed := CRASH_DURATION-crash_time
		var sitting := smoothstep(0,.25,elapsed)
		# Tumble beside the obstacle so a tall pine cannot hide the seated animal.
		model.position.x = tumble_side*sitting
		pose.sit(sitting,elapsed)
		_update_particles(dt)
		if crash_time <= 0: _respawn_after_crash()
		return
	recovery_time = maxf(0,recovery_time-dt)
	var axis := Input.get_axis("ski_left", "ski_right")
	if ui.left_held: axis -= 1
	if ui.right_held: axis += 1
	axis = clampf(axis,-1,1)
	if axis != 0: mouse_steering = false
	if mouse_steering: axis = clampf((mouse_target-skier.position.x)*.7,-1,1)
	# Youngest setting gently nudges around obstacles, but still permits steering.
	if pace == 0:
		for item in items:
			if item.kind not in ["pine","rock"]: continue
			var ahead: float = item.node.position.z - skier.position.z
			var side: float = skier.position.x - item.node.position.x
			if ahead > 0 and ahead < 4.8 and absf(side) < 1.7:
				axis = clampf(axis + (1.0 if side >= 0 else -1.0)*(1.0-ahead/4.8)*.85,-1,1)
	var braking: bool = Input.is_action_pressed("ski_slow") or ui.brake_held
	var target_speed := 5.3 if pace==0 else 8.0
	if Input.is_action_pressed("ski_fast"): target_speed *= 1.18
	if braking: target_speed = 0.0
	speed = move_toward(speed,target_speed,dt*7.0)
	steer = lerpf(steer,axis,1.0-exp(-dt*7))
	skier.position.x = clampf(skier.position.x+steer*dt*(5.2 if pace==0 else 6.5)*minf(speed/2,1),-EDGE,EDGE)
	distance += speed*dt*(1.0-absf(steer)*.12)
	skier.position.z = distance
	jump_time = maxf(0,jump_time-dt)
	model.position.y = sin((1.0-jump_time/.9)*PI)*1.7 if jump_time>0 else sin(time*9)*.025*minf(speed,1)
	model.rotation.y = steer*.6
	model.rotation.z = -steer*.12
	_follow_camera()
	while row_z < distance+85:
		_spawn_row(row_z)
		row_z += 8
	_update_items(dt)
	_update_trails(dt)
	_update_particles(dt)
	ui.update_run(distance,stars,RUN_LENGTH)
	if state == State.SKIING and distance >= RUN_LENGTH: _finish_run()

func _begin_crash(obstacle: Node3D) -> void:
	state = State.CRASHED
	crash_time = CRASH_DURATION
	respawn_z = maxf(distance+4,obstacle.position.z+3)
	tumble_side = 2.0 if skier.position.x >= obstacle.position.x else -2.0
	speed = 0
	steer = 0
	jump_time = 0
	mouse_steering = false
	model.position = Vector3.ZERO
	model.rotation = Vector3.ZERO
	pose.sit(0,0)
	_burst(skier.position+Vector3(0,.5,0),"drift",10)
	ui.message_label.position.y = 588
	ui.toast("A little tumble! Back up in a moment.",CRASH_DURATION)
	_play_sound("bump")

func _respawn_after_crash() -> void:
	# Find a clear spot downhill, including when two obstacles are close together.
	for attempt in range(items.size()+1):
		var moved := false
		for item in items:
			if item.kind not in ["pine","rock"]: continue
			var obstacle: Node3D = item.node
			if absf(obstacle.position.x-skier.position.x)<2.2 and absf(obstacle.position.z-respawn_z)<3:
				respawn_z = obstacle.position.z+3
				moved = true
		if not moved: break
	distance = respawn_z
	skier.position.z = distance
	pose.reset()
	model.position = Vector3.ZERO
	model.rotation = Vector3.ZERO
	recovery_time = RESPAWN_GRACE
	track_clock = 0
	state = State.SKIING
	_follow_camera()
	ui.update_run(distance,stars,RUN_LENGTH)
	ui.message_label.position.y = 118
	ui.toast("Back on our skis!",1.5)
	_burst(skier.position+Vector3(0,.4,0),"drift",8)

func _follow_camera() -> void:
	camera.size = 24
	# Looking from the downhill side preserves SkiFree's downhill-on-screen view.
	camera.position = Vector3(0,27,distance+24)
	camera.look_at(Vector3(0,0,distance+6))
	ground.position.z = distance

func _spawn_row(z: float) -> void:
	var lane := sin(z*.035)*6.2
	for side in [-1,1]:
		for offset in [0,6]:
			var x: float = side*course_rng.randf_range(14.0+offset,17.0+offset)
			_add_item("pine",Vector3(x,0,z+course_rng.randf_range(-3,3)),course_rng.randf_range(.85,1.5),false)
	if z > 12 and z < RUN_LENGTH-12:
		var row := int(z/8)
		_add_item("star",Vector3(lane,1.1,z),1,true)
		_add_item("star",Vector3(sin((z+4)*.035)*6.2,1.1,z+4),1,true)
		if row%3==0:
			var x := course_rng.randf_range(-10.5,10.5)
			if absf(x-lane)<3.8: x = clampf(lane+(5.0 if lane<0 else -5.0),-10,10)
			_add_item("pine" if row%2==0 else "rock",Vector3(x,0,z+2),1,true)
		if row%9==5: _add_item("ramp",Vector3(lane,0,z+3.2),1,true)
	# Tiny clusters of snowballs provide depth without blocking the ski path.
	if int(z)%24==0:
		var drift := _ball(course,Vector3(-19,-.1,z),Vector3(3,.65,2),"drift")
		items.append({"node":drift,"kind":"decoration","active":false,"base_y":0.0})

func _add_item(kind: String, pos: Vector3, size_: float, active: bool) -> void:
	var node := _asset(kind,course,pos,size_)
	items.append({"node":node,"kind":kind,"active":active,"base_y":pos.y})

func _update_items(dt: float) -> void:
	if state != State.SKIING: return
	for i in range(items.size()-1,-1,-1):
		var item := items[i]
		var node: Node3D = item.node
		if node.position.z < distance-30:
			node.queue_free()
			items.remove_at(i)
			continue
		if item.kind=="star":
			node.rotation.x = -0.85
			node.rotation.y = sin(time*2+node.position.z)*.5
			node.position.y = item.base_y+sin(time*3+node.position.z)*.13
		if not item.active: continue
		var dz: float = node.position.z-distance
		var dx: float = node.position.x-skier.position.x
		if item.kind=="star":
			var radius := 2.6 if pace==0 else 1.65
			if Vector2(dx,dz).length()<radius:
				_collect_star(item)
			elif pace==0 and absf(dz)<4 and absf(dx)<3.5:
				node.position.x = move_toward(node.position.x,skier.position.x,dt*2)
		elif item.kind=="ramp" and absf(dx)<1.5 and absf(dz)<.8:
			item.active = false
			hop()
			ui.toast("Wheee!",1.4)
		elif item.kind in ["pine","rock"] and absf(dx)<1.05 and absf(dz)<1.05 and jump_time<.1 and recovery_time<=0:
			item.active = false
			_begin_crash(node)
			break

func _collect_star(item: Dictionary) -> void:
	item.active = false
	item.node.hide()
	stars += 1
	_burst(item.node.position,"gold",7)
	_play_sound("star")
	if stars%5==0: ui.toast(["Lovely turns!","You’re a snow star!","Look at you go!","Happy little skis!"][int(stars/5.0-1)%4])

func _update_trails(dt: float) -> void:
	track_clock += dt
	if track_clock>.09 and speed>.5 and jump_time<=0:
		track_clock = 0
		for side in [-.34,.34]:
			var track := _box(trail_root,skier.position+Vector3(side,.012,-.6),Vector3(.065,.015,.65),"track")
			track.rotation.y = steer*.6
			trails.append(track)
	while not trails.is_empty() and (trails[0].position.z<distance-24 or trails.size()>180):
		trails.pop_front().queue_free()

func _burst(pos: Vector3, material: String, count: int) -> void:
	for i in range(count):
		var p := _ball(trail_root,pos,Vector3.ONE*.12,material)
		particles.append({"node":p,"life":.7,"velocity":Vector3(course_rng.randf_range(-2,2),course_rng.randf_range(1,3),course_rng.randf_range(-2,2))})

func _update_particles(dt: float) -> void:
	for i in range(particles.size()-1,-1,-1):
		var p := particles[i]
		p.life -= dt
		p.velocity.y -= dt*6
		p.node.position += p.velocity*dt
		p.node.scale = Vector3.ONE*maxf(0,p.life)*.2
		if p.life<=0:
			p.node.queue_free()
			particles.remove_at(i)

func _finish_run() -> void:
	state = State.FINISHED
	ui.show_modal(true,stars)
	_play_sound("finish")

func _build_audio() -> void:
	for sound in ["pick","hop","star","bump","start","finish"]:
		sounds[sound] = load("res://assets/audio/%s.wav" % sound)
	for i in range(6):
		var player := AudioStreamPlayer.new()
		player.volume_db = -13
		add_child(player)
		sfx.append(player)
	music = AudioStreamPlayer.new()
	music.stream = load("res://assets/audio/snow_day.wav")
	music.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	music.stream.loop_end = int(music.stream.get_length()*music.stream.mix_rate)
	music.volume_db = -23
	add_child(music)
	music.play()

func _exit_tree() -> void:
	if is_instance_valid(music):
		music.stop()
		music.stream = null
	for player in sfx:
		if is_instance_valid(player):
			player.stop()
			player.stream = null

func _play_sound(key: String) -> void:
	if sfx.is_empty(): return
	var player := sfx[sfx_index%sfx.size()]
	sfx_index += 1
	player.stream = sounds[key]
	player.play()

func toggle_sound() -> void:
	muted = not muted
	AudioServer.set_bus_mute(0,muted)
	ui.set_muted(muted)
	_save_settings()

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH)==OK:
		selected_pal = clampi(int(config.get_value("play","pal",0)),0,3)
		pace = clampi(int(config.get_value("play","pace",0)),0,1)
		muted = bool(config.get_value("play","muted",false))

func _save_settings() -> void:
	if not settings_enabled: return
	var config := ConfigFile.new()
	config.set_value("play","pal",selected_pal)
	config.set_value("play","pace",pace)
	config.set_value("play","muted",muted)
	config.save(SETTINGS_PATH)

func _capture() -> void:
	# Reproducible real-engine screenshots for visual QA, never a mock rendering.
	if capture_mode != "menu":
		start_run()
		if capture_mode == "game":
			distance = 65
			skier.position = Vector3(3,0,distance)
			_follow_camera()
			ui.update_run(distance,stars,RUN_LENGTH)
		elif capture_mode == "finish":
			stars = 24
			distance = RUN_LENGTH
			_process(.016)
		elif capture_mode.begins_with("crash-"):
			select_pal(KINDS.find(capture_mode.trim_prefix("crash-")))
			_add_item("rock",Vector3(0,0,.8),1,true)
			_update_items(.016)
	await get_tree().create_timer(1.0).timeout
	if capture_mode == "game":
		set_process(false)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://screenshots/%s.png" % capture_mode)
	_exit_tree()
	await get_tree().create_timer(.2).timeout
	get_tree().quit()
