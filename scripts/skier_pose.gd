class_name SkierPose
extends RefCounted
## Pose the named pieces of the original Blender models without changing the
## shared meshes. Facial details rotate together around the base of the head.
const HEAD_PARTS = ["Head", "Bright eye", "Eye sparkle", "Button nose", "Smile",
	"Rosy cheek", "Fluffy cheek", "Pointy ear", "Inner ear", "Long bunny ear",
	"Pink ear", "Round ear", "Ear center", "Muzzle", "White face", "Beak", "Hat", "Pom pom"]
var parts: Array[Dictionary] = []
var legs: Array[MeshInstance3D] = []
var halo: Node3D
var orbit_stars: Array[Node3D] = []
var crown_height := 2.65

func setup(model: Node3D, star_scene: PackedScene, kind: String) -> void:
	var fur: Material
	for child in model.get_children():
		if not child is Node3D: continue
		var category := "body"
		var part_name := String(child.name)
		for prefix in HEAD_PARTS:
			if part_name.begins_with(prefix): category = "head"
		if part_name.begins_with("Boot") or part_name.begins_with("Candy-colored ski") or part_name.begins_with("Upturned ski tip"):
			category = "ski"
		if part_name.begins_with("Ski pole") or part_name.begins_with("Pole basket"):
			category = "pole"
		if part_name.begins_with("Round tummy") and child is MeshInstance3D:
			fur = child.mesh.surface_get_material(0)
		parts.append({"node":child,"rest":child.transform,"category":category})
	for side in [-1,1]:
		var leg := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = .2
		mesh.height = .85
		mesh.radial_segments = 16
		mesh.rings = 8
		leg.mesh = mesh
		leg.material_override = fur
		leg.position = Vector3(side*.34,.24,.36)
		leg.rotation.x = PI/2
		model.add_child(leg)
		legs.append(leg)
	halo = Node3D.new()
	halo.name = "DizzyStars"
	model.add_child(halo)
	crown_height = 3.05 if kind == "bunny" else 2.65
	for i in range(4):
		var star: Node3D = star_scene.instantiate()
		halo.add_child(star)
		star.scale = Vector3.ONE*.45
		orbit_stars.append(star)
	reset()

func sit(amount: float, elapsed: float) -> void:
	var body := Transform3D(Basis(Vector3.RIGHT,-.16*amount),Vector3(0,-.32*amount,-.2*amount))
	var pivot := Vector3(0,1.52,.05)
	var wobble := Basis.from_euler(Vector3(sin(elapsed*6)*.09, sin(elapsed*4)*.15, sin(elapsed*8)*.23)*amount)
	var head := body * Transform3D(Basis.IDENTITY,pivot) * Transform3D(wobble,Vector3.ZERO) * Transform3D(Basis.IDENTITY,-pivot)
	for part in parts:
		var node: Node3D = part.node
		var rest: Transform3D = part.rest
		match part.category:
			"head": node.transform = head * rest
			"body": node.transform = body * rest
			"pole": node.visible = amount < .5
			"ski":
				var side := signf(rest.origin.x)
				var foot := Vector3(side*.34,0,0)
				var turn := Basis(Vector3.UP,side*.22*amount)
				node.transform = Transform3D(turn,foot+Vector3(0,0,.75*amount)-turn*foot) * rest
	for leg in legs:
		leg.visible = amount > .1
		leg.scale = Vector3.ONE*maxf(amount,.01)
	halo.visible = true
	for i in range(orbit_stars.size()):
		var angle := elapsed*2.5+i*TAU/orbit_stars.size()
		orbit_stars[i].position = Vector3(cos(angle)*.9,crown_height+sin(angle)*.1,sin(angle)*.55-.2)
		orbit_stars[i].rotation = Vector3(-.85,0,sin(angle)*.2)

func reset() -> void:
	for part in parts:
		part.node.transform = part.rest
		part.node.visible = true
	for leg in legs: leg.hide()
	if is_instance_valid(halo): halo.hide()
