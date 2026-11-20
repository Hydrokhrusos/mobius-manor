class_name World
extends Node3D
## Builds the whole house procedurally: rooms, impossible connections, furniture and toys.

const T := 0.2
# The repeating room sees itself through its own doors (one copy every 6 m). Portal views
# go 3 levels deep, so the 4th copy (18 m) is never drawn: the fade must be complete by
# then, or stepping through a door would make the far end of the corridor pop.
const REPEAT_FADE := Vector2(9.0, 15.5)

var portals: Array = []
var P := {}
var areas: Array = []
var M := {}
var spawn_pos := Vector3(0.0, 0.05, -2.2)
var spawn_yaw := PI
var props_root: Node3D
var spawned_root: Node3D
var _box_cache := {}
var _flower_mats := {}
var _area_node: Node3D
var _body: StaticBody3D
var _layers := 1
var _off := Vector3.ZERO
var _cleanup_t := 0.0


func build() -> void:
	_materials()
	props_root = Node3D.new()
	props_root.name = "Props"
	add_child(props_root)
	spawned_root = Node3D.new()
	spawned_root.name = "Spawned"
	add_child(spawned_root)
	_build_foyer()
	_build_hallway()
	_build_bedroom()
	_build_repeating_room()
	_build_stairwell()
	_build_attic()
	_build_great_hall()
	_build_greenhouse()
	_link()


func _process(delta: float) -> void:
	if G.player == null:
		return
	if G.player.global_position.y < -40.0:
		G.player.place(spawn_pos, spawn_yaw)
	_cleanup_t += delta
	if _cleanup_t > 1.0:
		_cleanup_t = 0.0
		for b in get_tree().get_nodes_in_group("props"):
			if b.global_position.y < -60.0:
				if G.player.held == b:
					G.player.drop()
				b.queue_free()


func area_at(p: Vector3) -> String:
	for a in areas:
		if (a.aabb as AABB).has_point(p):
			return a.name
	return ""


# =====================================================================================
# Materials
# =====================================================================================

func _materials() -> void:
	M["marble"] = Mats.make(Color(0.9, 0.88, 0.84), Color(0.1, 0.1, 0.11), Mats.CHECKER, 0.6, 0.22, 0.0, false, 0.05)
	M["green_paper"] = Mats.make(Color(0.2, 0.36, 0.28), Color(0.15, 0.28, 0.22), Mats.STRIPES, 0.3, 0.85, 0.0, false, 0.06)
	M["plaster"] = Mats.make(Color(0.86, 0.84, 0.8), Color(0.78, 0.76, 0.72), Mats.BLOTCH, 1.5, 0.95, 0.0, false, 0.05)
	M["wainscot"] = Mats.make(Color(0.36, 0.22, 0.13), Color(0.3, 0.18, 0.1), Mats.PLANKS, 0.9, 0.5)
	M["wood_trim"] = Mats.make(Color(0.3, 0.18, 0.1), Color(0.25, 0.15, 0.08), Mats.PLAIN, 1.0, 0.45, 0.0, false, 0.04)
	M["trim"] = Mats.make(Color(0.93, 0.91, 0.86), Color.WHITE, Mats.PLAIN, 1.0, 0.45, 0.0, false, 0.03)
	M["wood_floor"] = Mats.make(Color(0.5, 0.33, 0.2), Color(0.4, 0.25, 0.14), Mats.PLANKS, 1.0, 0.45)
	M["wood_light"] = Mats.make(Color(0.75, 0.58, 0.4), Color(0.64, 0.47, 0.3), Mats.PLANKS, 1.0, 0.5)
	M["red_paper"] = Mats.make(Color(0.48, 0.1, 0.1), Color(0.4, 0.08, 0.08), Mats.STRIPES, 0.16, 0.85, 0.0, false, 0.06)
	M["blue_paper"] = Mats.make(Color(0.6, 0.7, 0.82), Color(0.93, 0.93, 0.96), Mats.DOTS, 0.22, 0.9, 0.0, false, 0.04)
	M["mustard"] = Mats.make(Color(0.78, 0.62, 0.28), Color(0.66, 0.5, 0.22), Mats.STRIPES, 0.25, 0.85, 0.0, false, 0.06)
	M["teal_check"] = Mats.make(Color(0.86, 0.83, 0.72), Color(0.16, 0.42, 0.44), Mats.CHECKER, 0.5, 0.3, 0.0, false, 0.05)
	M["rug_red"] = Mats.make(Color(0.5, 0.1, 0.12), Color(0.62, 0.45, 0.16), Mats.STRIPES, 0.35, 0.95, 0.0, false, 0.08)
	M["runner"] = Mats.make(Color(0.2, 0.25, 0.45), Color(0.6, 0.5, 0.25), Mats.STRIPES, 0.28, 0.95)
	M["rug_blue"] = Mats.make(Color(0.3, 0.4, 0.6), Color(0.85, 0.82, 0.7), Mats.CHECKER, 0.3, 0.95)
	M["gold"] = Mats.make(Color(0.85, 0.66, 0.3), Color(0.6, 0.45, 0.2), Mats.PLAIN, 1.0, 0.3, 1.0, false, 0.05)
	M["door_wood"] = Mats.make(Color(0.42, 0.24, 0.13), Color(0.35, 0.19, 0.1), Mats.PLANKS, 0.6, 0.55)
	M["dark_wood"] = Mats.make(Color(0.28, 0.17, 0.1), Color(0.22, 0.13, 0.07), Mats.PLANKS, 0.7, 0.5)
	M["wardrobe"] = Mats.make(Color(0.5, 0.3, 0.17), Color(0.42, 0.24, 0.12), Mats.PLANKS, 0.7, 0.45)
	M["bulb"] = Mats.emissive(Color(1.0, 0.82, 0.55), 6.0)
	M["metal"] = Mats.make(Color(0.2, 0.2, 0.22), Color.BLACK, Mats.PLAIN, 1.0, 0.35, 0.9, false, 0.05)
	M["white"] = Mats.make(Color(0.95, 0.95, 0.93), Color.WHITE, Mats.PLAIN, 1.0, 0.6, 0.0, false, 0.03)
	M["black"] = Mats.make(Color(0.03, 0.03, 0.03), Color.BLACK, Mats.PLAIN, 1.0, 0.5, 0.0, false, 0.0)
	M["blanket"] = Mats.make(Color(0.62, 0.2, 0.25), Color(0.5, 0.14, 0.2), Mats.CHECKER, 0.2, 0.95)
	M["linen"] = Mats.make(Color(0.94, 0.93, 0.9), Color.WHITE, Mats.PLAIN, 1.0, 0.95, 0.0, false, 0.03)
	M["night_sky"] = Mats.emissive(Color(0.06, 0.1, 0.26), 0.9)
	M["moon"] = Mats.emissive(Color(0.9, 0.92, 1.0), 3.0)
	M["stair_wall"] = Mats.make(Color(0.68, 0.64, 0.56), Color(0.6, 0.56, 0.48), Mats.BLOTCH, 1.2, 0.9)
	M["stair_floor"] = Mats.make(Color(0.5, 0.48, 0.45), Color(0.4, 0.38, 0.36), Mats.TILES, 0.5, 0.6)
	M["stair_step"] = Mats.make(Color(0.45, 0.3, 0.2), Color(0.38, 0.24, 0.15), Mats.PLANKS, 0.8, 0.55)
	M["attic_wall"] = Mats.make(Color(0.45, 0.34, 0.24), Color(0.36, 0.26, 0.18), Mats.PLANKS, 1.3, 0.85, 0.0, false, 0.15)
	M["attic_floor"] = Mats.make(Color(0.42, 0.3, 0.2), Color(0.32, 0.22, 0.14), Mats.PLANKS, 1.2, 0.8, 0.0, false, 0.15)
	M["attic_roof"] = Mats.make(Color(0.38, 0.28, 0.2), Color(0.3, 0.21, 0.14), Mats.PLANKS, 1.0, 0.9, 0.0, false, 0.18)
	M["beam"] = Mats.make(Color(0.3, 0.2, 0.12), Color(0.25, 0.16, 0.09), Mats.PLANKS, 1.5, 0.85)
	M["hall_floor"] = Mats.make(Color(0.82, 0.8, 0.75), Color(0.32, 0.1, 0.1), Mats.CHECKER, 2.0, 0.25, 0.0, false, 0.06)
	M["hall_wall"] = Mats.make(Color(0.56, 0.52, 0.47), Color(0.36, 0.34, 0.31), Mats.BRICKS, 2.4, 0.9, 0.0, false, 0.12)
	M["hall_ceiling"] = Mats.make(Color(0.3, 0.2, 0.13), Color(0.24, 0.15, 0.09), Mats.PLANKS, 2.0, 0.8)
	M["column"] = Mats.make(Color(0.86, 0.84, 0.8), Color(0.7, 0.68, 0.64), Mats.BLOTCH, 0.6, 0.35)
	M["stone_trim"] = Mats.make(Color(0.45, 0.42, 0.38), Color.GRAY, Mats.PLAIN, 1.0, 0.8)
	M["moon_glow"] = Mats.emissive(Color(0.35, 0.45, 0.75), 1.2)
	M["frame_white"] = Mats.make(Color(0.95, 0.94, 0.9), Color.WHITE, Mats.PLAIN, 1.0, 0.4)
	M["machine_red"] = Mats.make(Color(0.75, 0.12, 0.1), Color(0.6, 0.1, 0.08), Mats.PLAIN, 1.0, 0.35, 0.2)
	M["button_red"] = Mats.emissive(Color(1.0, 0.15, 0.1), 2.0)
	M["ramp"] = Mats.make(Color(0.66, 0.5, 0.32), Color(0.56, 0.4, 0.24), Mats.PLANKS, 0.8, 0.6)
	M["trampoline"] = Mats.make(Color(0.15, 0.35, 0.85), Color(0.1, 0.25, 0.6), Mats.CHECKER, 0.3, 0.6)
	M["lane"] = Mats.make(Color(0.85, 0.7, 0.5), Color(0.78, 0.62, 0.42), Mats.PLANKS, 0.5, 0.3)
	M["terracotta"] = Mats.make(Color(0.72, 0.4, 0.28), Color(0.55, 0.32, 0.24), Mats.TILES, 0.6, 0.8)
	M["brick"] = Mats.make(Color(0.62, 0.3, 0.22), Color(0.78, 0.74, 0.68), Mats.BRICKS, 0.8, 0.9)
	M["glass"] = Mats.glass()
	M["grass"] = Mats.make(Color(0.24, 0.42, 0.14), Color(0.34, 0.54, 0.2), Mats.BLOTCH, 3.0, 0.95)
	M["soil"] = Mats.make(Color(0.24, 0.15, 0.09), Color(0.17, 0.1, 0.06), Mats.BLOTCH, 0.25, 1.0)
	M["leaf"] = Mats.make(Color(0.22, 0.5, 0.18), Color(0.14, 0.36, 0.11), Mats.BLOTCH, 0.12, 0.7)
	M["stem"] = Mats.make(Color(0.25, 0.45, 0.15), Color.GREEN, Mats.PLAIN, 1.0, 0.8)
	M["bark"] = Mats.make(Color(0.35, 0.24, 0.15), Color(0.25, 0.17, 0.1), Mats.BLOTCH, 0.3, 0.9)
	M["pine"] = Mats.make(Color(0.12, 0.3, 0.14), Color(0.08, 0.22, 0.1), Mats.BLOTCH, 0.5, 0.9)
	M["water"] = Mats.water()
	M["stone_gray"] = Mats.make(Color(0.55, 0.55, 0.53), Color(0.4, 0.4, 0.39), Mats.BLOTCH, 0.2, 0.9)
	M["planter"] = Mats.make(Color(0.55, 0.38, 0.22), Color(0.45, 0.3, 0.17), Mats.PLANKS, 0.5, 0.8)
	M["sunflower"] = Mats.make(Color(1.0, 0.78, 0.08), Color.YELLOW, Mats.PLAIN, 1.0, 0.7)
	M["sunflower_c"] = Mats.make(Color(0.3, 0.18, 0.08), Color(0.15, 0.08, 0.03), Mats.DOTS, 0.04, 0.9)
	M["pot"] = Mats.make(Color(0.7, 0.36, 0.22), Color(0.6, 0.3, 0.18), Mats.BANDS, 0.15, 0.85)
	M["canvases"] = []
	var pal := [[Color(0.9, 0.5, 0.2), Color(0.2, 0.3, 0.6)], [Color(0.2, 0.6, 0.5), Color(0.95, 0.85, 0.5)],
		[Color(0.7, 0.2, 0.3), Color(0.1, 0.1, 0.2)], [Color(0.4, 0.6, 0.9), Color(0.95, 0.95, 0.9)],
		[Color(0.85, 0.75, 0.3), Color(0.3, 0.15, 0.1)], [Color(0.5, 0.3, 0.6), Color(0.9, 0.6, 0.6)]]
	for i in pal.size():
		M.canvases.append(Mats.make(pal[i][0], pal[i][1], [Mats.BLOTCH, Mats.STRIPES, Mats.DOTS, Mats.CHECKER][i % 4], [0.25, 0.12, 0.1, 0.15][i % 4], 0.7, 0.0, false, 0.0))


# =====================================================================================
# Building helpers
# =====================================================================================

## Starts a new area. Everything built until the next _begin is placed relative to `off`.
func _begin(area_name: String, a: Vector3, b: Vector3, sun := false, off := Vector3.ZERO) -> void:
	_off = off
	_area_node = Node3D.new()
	_area_node.name = area_name.replace(" ", "")
	add_child(_area_node)
	_area_node.position = off
	_body = StaticBody3D.new()
	_body.collision_layer = G.PL_WORLD
	_body.collision_mask = 0
	_area_node.add_child(_body)
	_layers = (G.VL_WORLD | G.VL_SUN) if sun else G.VL_WORLD
	areas.append({"name": area_name, "aabb": AABB(a + off, b - a)})


func _bm(s: Vector3) -> BoxMesh:
	var k := "%.4f_%.4f_%.4f" % [s.x, s.y, s.z]
	if not _box_cache.has(k):
		var bm := BoxMesh.new()
		bm.size = s
		_box_cache[k] = bm
	return _box_cache[k]


func _shape(shape: Shape3D, t: Transform3D, body: CollisionObject3D = null) -> void:
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = t
	(body if body != null else _body).add_child(cs)


func mi(m: Mesh, t: Transform3D, mat: Material, shadow := true) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = m
	n.transform = t
	n.material_override = mat
	n.layers = _layers
	if not shadow:
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_area_node.add_child(n)
	return n


func box(c: Vector3, s: Vector3, mat: Material, collide := true, shadow := true, basis := Basis.IDENTITY) -> MeshInstance3D:
	var n := mi(_bm(s), Transform3D(basis, c), mat, shadow)
	if collide:
		var bs := BoxShape3D.new()
		bs.size = s
		_shape(bs, Transform3D(basis, c))
	return n


func cbox(c: Vector3, s: Vector3, basis := Basis.IDENTITY, body: CollisionObject3D = null) -> void:
	var bs := BoxShape3D.new()
	bs.size = s
	_shape(bs, Transform3D(basis, c), body)


func cyl(c: Vector3, r: float, h: float, mat: Material, collide := true, rtop := -1.0, shadow := true, basis := Basis.IDENTITY, segs := 24) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.bottom_radius = r
	m.top_radius = r if rtop < 0.0 else rtop
	m.height = h
	m.radial_segments = segs
	m.rings = 1
	var n := mi(m, Transform3D(basis, c), mat, shadow)
	if collide:
		var s := CylinderShape3D.new()
		s.radius = maxf(r, m.top_radius)
		s.height = h
		_shape(s, Transform3D(basis, c))
	return n


func sphere(c: Vector3, r: float, mat: Material, collide := false, shadow := true, squash := 1.0) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0 * squash
	m.radial_segments = 20
	m.rings = 10
	var n := mi(m, Transform3D(Basis.IDENTITY, c), mat, shadow)
	if collide:
		var s := SphereShape3D.new()
		s.radius = r
		_shape(s, Transform3D(Basis.IDENTITY, c))
	return n


## A box whose top (above=false) or bottom (above=true) face contains the segment p0->p1.
## The segment must lie in a plane of constant x; width runs along x.
func slab(p0: Vector3, p1: Vector3, width: float, thick: float, above: bool, mat: Material, visible := true, collide := true, ext := 0.0) -> void:
	var d := p1 - p0
	var length := d.length()
	var dn := d / length
	var n := Vector3.RIGHT.cross(dn).normalized()
	if (above and n.y < 0.0) or (not above and n.y > 0.0):
		n = -n
	var c := (p0 + p1) * 0.5 + n * thick * 0.5
	var basis := Basis(Vector3.RIGHT, n, Vector3.RIGHT.cross(n))
	var sz := Vector3(width, thick, length + ext * 2.0)
	if visible:
		box(c, sz, mat, collide, true, basis)
	elif collide:
		cbox(c, sz, basis)


func omni(pos: Vector3, color: Color, energy: float, rng: float, shadow := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 0.9
	l.shadow_enabled = shadow
	if shadow:
		l.shadow_bias = 0.04
		l.shadow_normal_bias = 1.2
		l.shadow_blur = 1.5
	_area_node.add_child(l)
	return l


func blocker(c: Vector3, s: Vector3) -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = G.PL_GLASS
	sb.collision_mask = 0
	_area_node.add_child(sb)
	cbox(c, s, Basis.IDENTITY, sb)


func glass_pane(c: Vector3, s: Vector3, collide := true) -> void:
	box(c, s, M.glass, false, false)
	if collide:
		blocker(c, s.max(Vector3(0.06, 0.06, 0.06)))


func make_portal(pname: String, center: Vector3, normal: Vector3, up: Vector3, sz: Vector2, fallback := Color(0.03, 0.03, 0.035), fade := Vector2(40.0, 60.0)) -> Portal:
	var p := Portal.new()
	p.name = pname
	p.size = sz
	p.fallback = fallback
	p.fade = fade
	_area_node.add_child(p)
	var z := normal.normalized()
	var x := up.cross(z).normalized()
	var y := z.cross(x).normalized()
	p.global_transform = Transform3D(Basis(x, y, z), center + _off)
	p.setup_visual()
	portals.append(p)
	P[pname] = p
	return p


func op(side: String, at: float, w: float, h: float, b: float = 0.0, trim: bool = true) -> Dictionary:
	return {"side": side, "at": at, "w": w, "h": h, "b": b, "trim": trim}


func _side_normal(side: String) -> Vector3:
	match side:
		"n":
			return Vector3(0, 0, 1)
		"s":
			return Vector3(0, 0, -1)
		"w":
			return Vector3(1, 0, 0)
	return Vector3(-1, 0, 0)


## Point on a wall: u runs along the wall, d is the distance from the interior face into the room.
func _wpos(side: String, mn: Vector3, mx: Vector3, u: float, y: float, d: float) -> Vector3:
	match side:
		"n":
			return Vector3(u, y, mn.z + d)
		"s":
			return Vector3(u, y, mx.z - d)
		"w":
			return Vector3(mn.x + d, y, u)
	return Vector3(mx.x - d, y, u)


func _wsize(side: String, su: float, sy: float, sd: float) -> Vector3:
	if side == "n" or side == "s":
		return Vector3(su, sy, sd)
	return Vector3(sd, sy, su)


func portal_for(side: String, mn: Vector3, mx: Vector3, o: Dictionary, pname: String, fallback := Color(0.03, 0.03, 0.035), fade := Vector2(40.0, 60.0)) -> Portal:
	var c := _wpos(side, mn, mx, o.at, mn.y + o.b + o.h * 0.5, -0.01)
	return make_portal(pname, c, _side_normal(side), Vector3.UP, Vector2(o.w, o.h), fallback, fade)


func room(mn: Vector3, mx: Vector3, mf: Material, mw: Material, mc: Material, ops: Array, opt := {}) -> void:
	var cx := (mn.x + mx.x) * 0.5
	var cz := (mn.z + mx.z) * 0.5
	var full := Vector3(mx.x - mn.x + 2.0 * T, T, mx.z - mn.z + 2.0 * T)
	if not opt.get("no_floor", false):
		box(Vector3(cx, mn.y - T * 0.5, cz), full, mf)
	if not opt.get("no_ceiling", false):
		box(Vector3(cx, mx.y + T * 0.5, cz), full, mc)
	for side in ["n", "s", "w", "e"]:
		var u0: float
		var u1: float
		if side == "n" or side == "s":
			u0 = mn.x - T
			u1 = mx.x + T
		else:
			u0 = mn.z
			u1 = mx.z
		var sops := ops.filter(func(o): return o.side == side)
		sops.sort_custom(func(a, b): return a.at < b.at)
		var cur := u0
		for o in sops:
			var a: float = o.at - o.w * 0.5
			var b: float = o.at + o.w * 0.5
			_wall_piece(side, mn, mx, cur, a, mn.y, mx.y, mw)
			_wall_piece(side, mn, mx, a, b, mn.y + o.b + o.h, mx.y, mw)
			_wall_piece(side, mn, mx, a, b, mn.y, mn.y + o.b, mw)
			cur = b
		_wall_piece(side, mn, mx, cur, u1, mn.y, mx.y, mw)
		if opt.has("wains"):
			_wall_strip(side, mn, mx, sops, 0.0, opt.get("wains_h", 1.0), 0.025, opt.wains)
			_wall_strip(side, mn, mx, sops, opt.get("wains_h", 1.0) - 0.05, opt.get("wains_h", 1.0), 0.045, opt.get("base", opt.wains))
		if opt.has("base"):
			_wall_strip(side, mn, mx, sops, 0.0, opt.get("base_h", 0.12), 0.035, opt.base)
		if opt.has("crown"):
			var hh := mx.y - mn.y
			_wall_strip(side, mn, mx, sops, hh - 0.1, hh, 0.05, opt.crown)
		if opt.has("trim"):
			for o in sops:
				if o.trim:
					_trims(side, mn, mx, o, opt.trim)


func _wall_piece(side: String, mn: Vector3, mx: Vector3, ua: float, ub: float, ya: float, yb: float, mat: Material) -> void:
	if ub - ua < 0.001 or yb - ya < 0.001:
		return
	box(_wpos(side, mn, mx, (ua + ub) * 0.5, (ya + yb) * 0.5, -T * 0.5), _wsize(side, ub - ua, yb - ya, T), mat)


func _wall_strip(side: String, mn: Vector3, mx: Vector3, sops: Array, y_lo: float, y_hi: float, depth: float, mat: Material) -> void:
	var u0: float
	var u1: float
	if side == "n" or side == "s":
		u0 = mn.x
		u1 = mx.x
	else:
		u0 = mn.z
		u1 = mx.z
	var cur := u0
	for o in sops:
		if o.b < y_hi and o.b + o.h > y_lo:
			var cw := 0.09 if o.trim else 0.0
			_strip_piece(side, mn, mx, cur, o.at - o.w * 0.5 - cw, y_lo, y_hi, depth, mat)
			cur = o.at + o.w * 0.5 + cw
	_strip_piece(side, mn, mx, cur, u1, y_lo, y_hi, depth, mat)


func _strip_piece(side: String, mn: Vector3, mx: Vector3, ua: float, ub: float, y_lo: float, y_hi: float, depth: float, mat: Material) -> void:
	if ub - ua < 0.01:
		return
	box(_wpos(side, mn, mx, (ua + ub) * 0.5, mn.y + (y_lo + y_hi) * 0.5, depth * 0.5), _wsize(side, ub - ua, y_hi - y_lo, depth), mat, false)


func _trims(side: String, mn: Vector3, mx: Vector3, o: Dictionary, mat: Material) -> void:
	var cw := 0.09
	var cd := 0.035
	var a: float = o.at - o.w * 0.5
	var b: float = o.at + o.w * 0.5
	var yb: float = mn.y + o.b
	var yt: float = yb + o.h
	var ylo: float = yb - (cw if o.b > 0.01 else 0.0)
	var yhi: float = minf(yt + cw, mx.y)
	box(_wpos(side, mn, mx, a - cw * 0.5, (ylo + yhi) * 0.5, cd * 0.5), _wsize(side, cw, yhi - ylo, cd), mat, false)
	box(_wpos(side, mn, mx, b + cw * 0.5, (ylo + yhi) * 0.5, cd * 0.5), _wsize(side, cw, yhi - ylo, cd), mat, false)
	box(_wpos(side, mn, mx, o.at, (yt + yhi) * 0.5, cd * 0.5), _wsize(side, o.w + 2.0 * cw, yhi - yt, cd), mat, false)
	if o.b > 0.01:
		box(_wpos(side, mn, mx, o.at, yb - cw * 0.5, (cd + 0.03) * 0.5), _wsize(side, o.w + 2.0 * cw + 0.06, cw, cd + 0.03), mat, false)


func frame_around(side: String, mn: Vector3, mx: Vector3, o: Dictionary, mat: Material, fw: float, fd: float) -> void:
	var a: float = o.at - o.w * 0.5
	var b: float = o.at + o.w * 0.5
	var yb: float = mn.y + o.b
	var yt: float = yb + o.h
	box(_wpos(side, mn, mx, a - fw * 0.5, (yb + yt) * 0.5, fd * 0.5), _wsize(side, fw, o.h + 2.0 * fw, fd), mat, false)
	box(_wpos(side, mn, mx, b + fw * 0.5, (yb + yt) * 0.5, fd * 0.5), _wsize(side, fw, o.h + 2.0 * fw, fd), mat, false)
	box(_wpos(side, mn, mx, o.at, yt + fw * 0.5, fd * 0.5), _wsize(side, o.w, fw, fd), mat, false)
	box(_wpos(side, mn, mx, o.at, yb - fw * 0.5, fd * 0.5), _wsize(side, o.w, fw, fd), mat, false)


func chandelier(ceiling: Vector3, drop: float, energy: float, rng: float, shadow: bool, scale := 1.0) -> OmniLight3D:
	var c := ceiling - Vector3(0.0, drop, 0.0)
	cyl(ceiling - Vector3(0.0, drop * 0.5, 0.0), 0.012 * scale, drop, M.gold, false, -1.0, false, Basis.IDENTITY, 6)
	sphere(c, 0.09 * scale, M.gold, false, false)
	var tm := TorusMesh.new()
	tm.inner_radius = 0.3 * scale
	tm.outer_radius = 0.34 * scale
	mi(tm, Transform3D(Basis.IDENTITY, c), M.gold, false)
	for i in 8:
		var a := i * TAU / 8.0
		sphere(c + Vector3(cos(a) * 0.32 * scale, 0.06 * scale, sin(a) * 0.32 * scale), 0.035 * scale, M.bulb, false, false)
	return omni(c - Vector3(0.0, 0.12 * scale, 0.0), Color(1.0, 0.84, 0.64), energy, rng, shadow)


func ceiling_lamp(c: Vector3, energy: float, rng: float, shadow: bool) -> OmniLight3D:
	cyl(c - Vector3(0, 0.05, 0), 0.18, 0.1, M.trim, false, 0.12, false)
	sphere(c - Vector3(0, 0.12, 0), 0.1, M.bulb, false, false)
	return omni(c - Vector3(0, 0.3, 0), Color(1.0, 0.85, 0.68), energy, rng, shadow)


func hanging_lamp(pos: Vector3, ceiling_y: float, energy: float, rng: float, shadow: bool) -> OmniLight3D:
	var cord := ceiling_y - pos.y
	cyl(pos + Vector3(0, cord * 0.5 + 0.1, 0), 0.008, cord - 0.2, M.black, false, -1.0, false, Basis.IDENTITY, 6)
	cyl(pos + Vector3(0, 0.05, 0), 0.22, 0.18, M.metal, false, 0.07, false)
	sphere(pos - Vector3(0, 0.03, 0), 0.06, M.bulb, false, false)
	return omni(pos - Vector3(0, 0.15, 0), Color(1.0, 0.82, 0.6), energy, rng, shadow)


func interactable(c: Vector3, mesh: Mesh, mat: Material, coll: Vector3, node_name: String, action: Callable, basis := Basis.IDENTITY) -> Interactable:
	var it := Interactable.new()
	it.name = node_name
	it.action = action
	it.collision_layer = G.PL_WORLD
	it.collision_mask = 0
	_area_node.add_child(it)
	it.transform = Transform3D(basis, c)
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.layers = _layers
	it.add_child(m)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = coll
	cs.shape = bs
	it.add_child(cs)
	return it


func light_switch(c: Vector3, side_normal: Vector3, lights: Array, glow_mats: Array = []) -> void:
	var sz := Vector3(0.1, 0.16, 0.1)
	var vis := Vector3(0.09, 0.14, 0.02) if absf(side_normal.z) > 0.5 else Vector3(0.02, 0.14, 0.09)
	var state := [true]
	var act := func():
		state[0] = not state[0]
		for l in lights:
			l.visible = state[0]
		for gm in glow_mats:
			gm.set_shader_parameter("emission_energy", 6.0 if state[0] else 0.0)
		if G.sfx:
			G.sfx.play_at("click", c, -2.0)
	interactable(c, _bm(vis), M.trim, sz, "LightSwitch", act)


func prop(kind: String, pos: Vector3, yaw := 0.0, color: Variant = null, sleep := true) -> Prop:
	var b := Props.make(kind, color)
	props_root.add_child(b)
	b.global_transform = Transform3D(Basis(Vector3.UP, yaw), pos + _off)
	if sleep:
		b.sleeping = true
	update_body_layers(b)
	return b


func prop_xf(kind: String, xf: Transform3D, color: Variant = null) -> Prop:
	var b := Props.make(kind, color)
	props_root.add_child(b)
	b.global_transform = xf.translated(_off)
	b.sleeping = true
	update_body_layers(b)
	return b


func duck(pos: Vector3, yaw := 0.0) -> Prop:
	var d := prop("duck", pos, yaw)
	d.collectible = true
	G.ducks_total += 1
	return d


func painting(c: Vector3, yaw: float, w: float, h: float, idx: int) -> void:
	var pb := Basis(Vector3.UP, yaw)
	var fwd := pb * Vector3(0, 0, 1)
	var fw := 0.07
	_oriented_box(c + fwd * 0.025, Vector3(w + fw * 2.0, h + fw * 2.0, 0.05), pb, M.gold)
	_oriented_box(c + fwd * 0.052, Vector3(w, h, 0.01), pb, M.canvases[idx % M.canvases.size()])


func _oriented_box(c: Vector3, s: Vector3, basis: Basis, mat: Material) -> void:
	mi(_bm(s), Transform3D(basis, c), mat, false)


# =====================================================================================
# The Foyer
# =====================================================================================

func _build_foyer() -> void:
	_begin("The Foyer", Vector3(-4.3, -1.0, -4.3), Vector3(4.3, 4.5, 4.3))
	var mn := Vector3(-4, 0, -4)
	var mx := Vector3(4, 3.5, 4)
	var o_n := op("n", 0.0, 1.4, 2.4)
	var o_e := op("e", 0.0, 1.4, 2.4)
	var o_s := op("s", 0.0, 1.2, 2.2)
	var o_w := op("w", 0.0, 1.6, 2.0, 1.0, false)
	room(mn, mx, M.marble, M.green_paper, M.plaster, [o_n, o_e, o_s, o_w],
		{"base": M.wood_trim, "wains": M.wainscot, "wains_h": 1.0, "trim": M.trim, "crown": M.trim})
	portal_for("s", mn, mx, o_s, "FrontDoor")
	var pt := portal_for("w", mn, mx, o_w, "Painting")
	pt.can_teleport = false
	frame_around("w", mn, mx, o_w, M.gold, 0.16, 0.08)
	blocker(Vector3(-4.13, 2.0, 0.0), Vector3(0.14, 2.0, 1.6))
	# console table under the painting
	box(Vector3(-3.72, 0.775, 0.0), Vector3(0.5, 0.05, 1.7), M.dark_wood)
	for z in [-0.78, 0.78]:
		for x in [-3.92, -3.52]:
			box(Vector3(x, 0.375, z), Vector3(0.05, 0.75, 0.05), M.dark_wood)
	# the front door, swung open into the foyer
	var th := deg_to_rad(-100.0)
	var lb := Basis(Vector3.UP, th)
	var d := lb * Vector3(-1, 0, 0)
	var hinge := Vector3(0.6, 1.1, 3.94)
	box(hinge + d * 0.6, Vector3(1.18, 2.18, 0.05), M.door_wood, true, true, lb)
	sphere(hinge + d * 1.05 + lb * Vector3(0, 0, 0.05), 0.035, M.gold, false, false)
	sphere(hinge + d * 1.05 + lb * Vector3(0, 0, -0.05), 0.035, M.gold, false, false)
	chandelier(Vector3(0, 3.5, 0), 0.6, 2.4, 12.0, true)
	# grandfather clock against the north wall
	var ck := Vector3(3.35, 0, -3.78)
	box(ck + Vector3(0, 0.95, 0), Vector3(0.55, 1.9, 0.34), M.dark_wood)
	box(ck + Vector3(0, 2.1, 0), Vector3(0.62, 0.42, 0.38), M.dark_wood)
	cyl(ck + Vector3(0, 2.1, 0.2), 0.17, 0.02, M.linen, false, -1.0, false, Basis(Vector3.RIGHT, PI * 0.5))
	box(ck + Vector3(0, 2.13, 0.215), Vector3(0.015, 0.13, 0.01), M.black, false, false)
	box(ck + Vector3(0.04, 2.1, 0.215), Vector3(0.1, 0.012, 0.01), M.black, false, false)
	cyl(ck + Vector3(0, 1.1, 0.175), 0.08, 0.02, M.gold, false, -1.0, false, Basis(Vector3.RIGHT, PI * 0.5))
	var tick := AudioStreamPlayer3D.new()
	tick.stream = G.sfx.get_stream("tick")
	tick.unit_size = 1.5
	tick.max_distance = 12.0
	tick.volume_db = -10.0
	tick.autoplay = true
	tick.position = ck + Vector3(0, 1.8, 0)
	tick.add_to_group("portal_audio")
	_area_node.add_child(tick)
	# coat rack
	var cr := Vector3(-3.45, 0, -3.45)
	cyl(cr + Vector3(0, 0.02, 0), 0.25, 0.04, M.dark_wood, true)
	cyl(cr + Vector3(0, 0.95, 0), 0.03, 1.9, M.dark_wood, true, -1.0, true, Basis.IDENTITY, 8)
	for i in 4:
		var a := i * TAU / 4.0 + 0.4
		box(cr + Vector3(cos(a) * 0.12, 1.75, sin(a) * 0.12), Vector3(0.2, 0.025, 0.025), M.dark_wood, false, true, Basis(Vector3.UP, -a))
	cyl(cr + Vector3(0.12, 1.86, 0.05), 0.13, 0.16, M.black, false, 0.11)
	cyl(cr + Vector3(0.12, 1.78, 0.05), 0.2, 0.015, M.black, false)
	# bench along the south wall
	_bench(Vector3(-2.4, 0, 3.65), 2.0)
	box(Vector3(0, 0.006, 0.2), Vector3(3.0, 0.012, 4.6), M.rug_red, false, false)
	# toys
	prop("crate", Vector3(2.6, 0.305, 2.7), 0.3)
	prop("crate", Vector3(3.3, 0.305, 2.95), -0.2)
	prop("small_crate", Vector3(2.85, 0.81, 2.8), 0.5)
	prop("ball", Vector3(-1.6, 0.19, 1.6), 0.0, Color(0.9, 0.2, 0.2))
	prop("lamp", Vector3(-3.72, 1.1, 0.55))
	for i in 3:
		prop("book", Vector3(-3.72, 0.922, -0.55 + i * 0.065), PI * 0.5)
	duck(Vector3(-2.0, 0.6, 3.62), 2.6)


func _bench(c: Vector3, length: float) -> void:
	box(c + Vector3(0, 0.45, 0), Vector3(length, 0.06, 0.42), M.dark_wood)
	for sx in [-1.0, 1.0]:
		box(c + Vector3(sx * (length * 0.5 - 0.08), 0.21, 0), Vector3(0.06, 0.42, 0.38), M.dark_wood)


# =====================================================================================
# The Long Hallway
# =====================================================================================

func _build_hallway() -> void:
	_begin("The Long Hallway", Vector3(-12.3, -1.0, -7.7), Vector3(6.3, 4.0, -4.25))
	var mn := Vector3(-12, 0, -7.4)
	var mx := Vector3(6, 3.0, -4.4)
	var o_s := op("s", 0.0, 1.4, 2.4)
	var o_n := op("n", -3.0, 1.4, 2.4)
	var o_w := op("w", -5.9, 1.4, 2.4)
	var o_e := op("e", -5.9, 1.4, 1.6, 0.8)
	room(mn, mx, M.wood_floor, M.red_paper, M.plaster, [o_s, o_n, o_w, o_e],
		{"base": M.wood_trim, "wains": M.wainscot, "wains_h": 0.75, "trim": M.wood_trim, "crown": M.wood_trim})
	portal_for("w", mn, mx, o_w, "HallStairs")
	var win := portal_for("e", mn, mx, o_e, "HallWindow")
	win.can_teleport = false
	glass_pane(Vector3(6.004, 1.6, -5.9), Vector3(0.006, 1.6, 1.4), false)
	blocker(Vector3(6.13, 1.6, -5.9), Vector3(0.12, 1.6, 1.4))
	box(Vector3(5.99, 1.6, -5.9), Vector3(0.03, 1.6, 0.04), M.wood_trim, false, false)
	box(Vector3(5.99, 1.6, -5.9), Vector3(0.03, 0.04, 1.4), M.wood_trim, false, false)
	for x in [-9.0, -3.0, 3.0]:
		ceiling_lamp(Vector3(x, 3.0, -5.9), 1.4, 7.5, x == -3.0)
	box(Vector3(-3.0, 0.006, -5.9), Vector3(17.0, 0.012, 1.1), M.runner, false, false)
	var i := 0
	for x in [-9.5, -6.5, 1.0, 3.6]:
		painting(Vector3(x, 1.75, -7.4), 0.0, 0.9, 0.65, i)
		i += 1
	for x in [-9.0, -5.5, -2.0, 3.0]:
		painting(Vector3(x, 1.75, -4.4), PI, 0.7, 0.9, i)
		i += 1
	# side table with a plant near the window
	box(Vector3(5.3, 0.75, -7.05), Vector3(0.7, 0.04, 0.45), M.dark_wood)
	for sx in [-0.3, 0.3]:
		for sz in [-0.18, 0.18]:
			box(Vector3(5.3 + sx, 0.37, -7.05 + sz), Vector3(0.04, 0.74, 0.04), M.dark_wood)
	cyl(Vector3(5.45, 0.88, -7.05), 0.12, 0.22, M.pot, false, 0.15)
	sphere(Vector3(5.45, 1.12, -7.05), 0.2, M.leaf, false, true, 0.9)
	prop("book", Vector3(5.1, 0.795, -7.05), 0.2).rotation = Vector3(0, 0.2, PI * 0.5)
	prop("book", Vector3(5.1, 0.85, -7.04), -0.1).rotation = Vector3(0, -0.1, PI * 0.5)
	prop("ball", Vector3(-7.5, 0.19, -5.4), 0.0, Color(0.2, 0.6, 0.95))
	prop("music_box", Vector3(-10.8, 0.065, -6.9), 0.4)
	duck(Vector3(-11.6, 0.15, -7.0), 0.8)


# =====================================================================================
# The Bedroom (with the wardrobe that is bigger on the inside)
# =====================================================================================

func _build_bedroom() -> void:
	_begin("The Bedroom", Vector3(4.25, -1.0, -3.8), Vector3(11.7, 4.0, 3.8))
	var mn := Vector3(4.4, 0, -3.5)
	var mx := Vector3(11.4, 3.0, 3.5)
	var o_w := op("w", 0.0, 1.4, 2.4)
	room(mn, mx, M.wood_light, M.blue_paper, M.plaster, [o_w], {"base": M.trim, "trim": M.trim, "crown": M.trim})
	var ceil_l := ceiling_lamp(Vector3(7.9, 3.0, 0.0), 1.5, 9.0, true)
	light_switch(Vector3(4.42, 1.3, 1.0), Vector3(1, 0, 0), [ceil_l])
	# bed against the north wall
	var bx := 6.6
	box(Vector3(bx, 0.2, -2.4), Vector3(1.9, 0.4, 2.2), M.dark_wood)
	box(Vector3(bx, 0.5, -2.4), Vector3(1.8, 0.2, 2.1), M.linen)
	box(Vector3(bx, 0.62, -2.05), Vector3(1.84, 0.06, 1.45), M.blanket, false)
	box(Vector3(bx, 0.62, -2.82), Vector3(1.84, 0.08, 0.2), M.blanket, false)
	for sx in [-0.45, 0.45]:
		box(Vector3(bx + sx, 0.68, -3.15), Vector3(0.62, 0.14, 0.38), M.linen, false)
	box(Vector3(bx, 0.6, -3.46), Vector3(2.0, 1.2, 0.08), M.dark_wood)
	# nightstand with a lamp you can switch
	var ns := Vector3(8.0, 0, -3.15)
	box(ns + Vector3(0, 0.28, 0), Vector3(0.5, 0.56, 0.42), M.dark_wood)
	cyl(ns + Vector3(0, 0.62, 0), 0.08, 0.1, M.metal, false, 0.05)
	var shade_m: ShaderMaterial = Mats.emissive(Color(1.0, 0.86, 0.6), 1.5)
	cyl(ns + Vector3(0, 0.85, 0), 0.18, 0.22, shade_m, false, 0.1)
	var nl := omni(ns + Vector3(0, 0.85, 0), Color(1.0, 0.78, 0.5), 0.9, 5.0, false)
	var lamp_on := [true]
	var lamp_act := func():
		lamp_on[0] = not lamp_on[0]
		nl.visible = lamp_on[0]
		shade_m.set_shader_parameter("emission_energy", 1.5 if lamp_on[0] else 0.0)
		G.sfx.play_at("click", ns, -3.0)
	interactable(ns + Vector3(0, 0.8, 0), _bm(Vector3(0.01, 0.01, 0.01)), M.trim, Vector3(0.36, 0.45, 0.36), "NightstandLamp", lamp_act)
	# dresser with a music box on top
	box(Vector3(6.3, 0.45, 3.22), Vector3(1.4, 0.9, 0.5), M.dark_wood)
	for row in 3:
		box(Vector3(6.3, 0.18 + row * 0.27, 2.965), Vector3(1.3, 0.2, 0.01), M.wood_trim, false, false)
		sphere(Vector3(6.3, 0.18 + row * 0.27, 2.955), 0.02, M.gold, false, false)
	prop("music_box", Vector3(6.3, 0.97, 3.2), 0.3)
	# a fake window with a night sky
	var wz := 3.49
	box(Vector3(9.0, 1.7, wz), Vector3(1.3, 1.1, 0.01), M.night_sky, false, false)
	sphere(Vector3(9.25, 1.95, wz - 0.01), 0.1, M.moon, false, false, 0.2)
	for sx in [-0.68, 0.0, 0.68]:
		box(Vector3(9.0 + sx, 1.7, wz - 0.02), Vector3(0.06, 1.2, 0.04), M.trim, false, false)
	for sy in [-0.58, 0.0, 0.58]:
		box(Vector3(9.0, 1.7 + sy, wz - 0.02), Vector3(1.42, 0.06, 0.04), M.trim, false, false)
	box(Vector3(9.0, 1.1, wz - 0.06), Vector3(1.5, 0.05, 0.14), M.trim, false)
	box(Vector3(8.3, 0.006, 0.6), Vector3(2.4, 0.012, 1.8), M.rug_blue, false, false)
	_wardrobe()
	prop("chair", Vector3(7.2, 0.475, 2.6), 2.8)
	prop("ball", Vector3(8.8, 0.19, -1.0), 0.0, Color(0.95, 0.75, 0.15))
	prop("small_crate", Vector3(10.9, 0.205, -2.9), 0.2)
	duck(Vector3(6.15, 0.86, -3.12), 0.3)


func _wardrobe() -> void:
	var x0 := 9.9
	var x1 := 10.6
	var z0 := -0.8
	var z1 := 0.8
	var h := 2.4
	var w: Material = M.wardrobe
	box(Vector3((x0 + x1) * 0.5, h * 0.5, z0 + 0.02), Vector3(x1 - x0, h, 0.04), w)
	box(Vector3((x0 + x1) * 0.5, h * 0.5, z1 - 0.02), Vector3(x1 - x0, h, 0.04), w)
	box(Vector3(x1 - 0.02, h * 0.5, 0.0), Vector3(0.04, h, z1 - z0), w)
	box(Vector3((x0 + x1) * 0.5, h - 0.02, 0.0), Vector3(x1 - x0, 0.04, z1 - z0), w)
	box(Vector3((x0 + x1) * 0.5 - 0.02, h + 0.05, 0.0), Vector3(x1 - x0 + 0.1, 0.1, z1 - z0 + 0.1), M.dark_wood)
	box(Vector3(x0 + 0.02, h * 0.5, -0.65), Vector3(0.04, h, 0.3), w)
	box(Vector3(x0 + 0.02, h * 0.5, 0.65), Vector3(0.04, h, 0.3), w)
	box(Vector3(x0 + 0.02, (2.05 + h) * 0.5, 0.0), Vector3(0.04, h - 2.05, 1.0), w)
	make_portal("Wardrobe", Vector3(x0 + 0.01, 1.025, 0.0), Vector3(-1, 0, 0), Vector3.UP, Vector2(1.0, 2.05))
	for side in [-1.0, 1.0]:
		var hinge := Vector3(x0 - 0.01, 1.025, 0.5 * side)
		var b := Basis(Vector3.UP, deg_to_rad(110.0) * side)
		var dd: Vector3 = b * Vector3(0, 0, -side)
		box(hinge + dd * 0.25, Vector3(0.03, 2.03, 0.5), w, true, true, b)
		sphere(hinge + dd * 0.44 + b * Vector3(0.03, 0, 0), 0.022, M.gold, false, false)
		sphere(hinge + dd * 0.44 + b * Vector3(-0.03, 0, 0), 0.022, M.gold, false, false)


# =====================================================================================
# The Repeating Room (east and west doors lead into each other)
# =====================================================================================

func _build_repeating_room() -> void:
	_begin("The Repeating Room", Vector3(-6.3, -1.0, -14.1), Vector3(0.3, 4.0, -7.62))
	var mn := Vector3(-5.99, 0, -13.8)
	var mx := Vector3(-0.01, 3.0, -7.8)
	var o_s := op("s", -3.0, 1.4, 2.4)
	var o_e := op("e", -10.8, 1.4, 2.4)
	var o_w := op("w", -10.8, 1.4, 2.4)
	room(mn, mx, M.teal_check, M.mustard, M.plaster, [o_s, o_e, o_w], {"base": M.wood_trim, "trim": M.wood_trim, "crown": M.wood_trim})
	var fb := Color(0.05, 0.042, 0.03)
	portal_for("e", mn, mx, o_e, "RepeatEast", fb, REPEAT_FADE)
	portal_for("w", mn, mx, o_w, "RepeatWest", fb, REPEAT_FADE)
	hanging_lamp(Vector3(-3.0, 2.3, -10.8), 3.0, 1.8, 9.0, true)
	box(Vector3(-3.0, 0.006, -10.8), Vector3(2.0, 0.012, 2.0), M.rug_red, false, false)
	# small shelf on the north wall
	box(Vector3(-5.0, 1.2, -13.62), Vector3(1.2, 0.04, 0.3), M.dark_wood)
	prop("book", Vector3(-5.35, 1.341, -13.62), 0.0)
	prop("book", Vector3(-5.28, 1.341, -13.62), 0.0)
	prop("cube", Vector3(-1.2, 0.126, -13.2), 0.2)
	prop("cube", Vector3(-0.9, 0.126, -12.8), 0.6)
	prop("cube", Vector3(-1.05, 0.377, -13.0), 0.1)
	prop("chair", Vector3(-4.9, 0.475, -9.0), 0.6)
	prop("ball", Vector3(-2.0, 0.19, -9.5), 0.0, Color(0.3, 0.85, 0.35))
	duck(Vector3(-5.5, 0.15, -13.3), 0.7)


# =====================================================================================
# The Endless Stairwell (the top landing is also the bottom landing)
# =====================================================================================

func _build_stairwell() -> void:
	var O := Vector3(-60, 0, 0)
	_begin("The Endless Stairwell", O + Vector3(-0.3, -1.0, -9.4), O + Vector3(5.7, 10.0, 3.4))
	var mw: Material = M.stair_wall
	var mf: Material = M.stair_floor
	var ms: Material = M.stair_step
	box(O + Vector3(-0.1, 4.5, -3.0), Vector3(0.2, 9.4, 12.4), mw)
	box(O + Vector3(5.5, 4.5, -3.0), Vector3(0.2, 9.4, 12.4), mw)
	box(O + Vector3(2.7, 4.4, -3.0), Vector3(0.4, 9.2, 6.0), mw)
	# middle landing (L1)
	box(O + Vector3(2.7, 2.9, -7.6), Vector3(5.4, 0.2, 3.2), mf)
	box(O + Vector3(2.7, 6.1, -7.5), Vector3(5.4, 0.2, 3.0), M.plaster)
	box(O + Vector3(1.0, 4.5, -9.1), Vector3(2.0, 3.0, 0.2), mw)
	box(O + Vector3(4.4, 4.5, -9.1), Vector3(2.0, 3.0, 0.2), mw)
	box(O + Vector3(2.7, 5.7, -9.1), Vector3(1.4, 0.6, 0.2), mw)
	box(O + Vector3(1.25, 5.8, -5.9), Vector3(2.5, 0.4, 0.2), mw)
	box(O + Vector3(4.15, 5.8, -5.9), Vector3(2.5, 0.4, 0.2), mw)
	# top landing (L2) which is also the bottom
	box(O + Vector3(2.7, 5.9, 1.6), Vector3(5.4, 0.2, 3.2), mf)
	box(O + Vector3(1.25, 5.9, -0.2), Vector3(2.5, 0.2, 0.4), mf)
	box(O + Vector3(2.7, 9.1, 1.5), Vector3(5.4, 0.2, 3.0), M.plaster)
	box(O + Vector3(1.05, 7.5, 3.1), Vector3(2.1, 3.0, 0.2), mw)
	box(O + Vector3(4.35, 7.5, 3.1), Vector3(2.1, 3.0, 0.2), mw)
	box(O + Vector3(2.7, 8.6, 3.1), Vector3(1.2, 0.8, 0.2), mw)
	box(O + Vector3(1.25, 8.8, -0.1), Vector3(2.5, 0.4, 0.2), mw)
	box(O + Vector3(4.15, 8.8, -0.1), Vector3(2.5, 0.4, 0.2), mw)
	# flight A (up to the north) with a short flat run at the bottom so the landing matches L2
	box(O + Vector3(1.25, -0.1, -0.3), Vector3(2.5, 0.2, 0.6), mf)
	box(O + Vector3(1.25, 2.7, -0.3), Vector3(2.5, 0.2, 0.6), M.plaster)
	for i in 18:
		var top := (i + 1) * (3.0 / 18.0)
		box(O + Vector3(1.25, top - 0.25, -0.6 - (i + 0.5) * 0.3), Vector3(2.5, 0.5, 0.3), ms, false)
	slab(O + Vector3(1.25, 0.0, -0.6), O + Vector3(1.25, 3.0, -6.0), 2.5, 0.3, false, null, false, true)
	slab(O + Vector3(1.25, 2.6, -0.6), O + Vector3(1.25, 5.6, -6.0), 2.5, 0.2, true, M.plaster, true, true)
	# flight B (up to the south)
	for i in 24:
		var top := 3.0 + (i + 1) * 0.125
		box(O + Vector3(4.15, top - 0.25, -6.0 + (i + 0.5) * 0.25), Vector3(2.5, 0.5, 0.25), ms, false)
	slab(O + Vector3(4.15, 3.0, -6.0), O + Vector3(4.15, 6.0, 0.0), 2.5, 0.3, false, null, false, true)
	slab(O + Vector3(4.15, 5.6, -6.0), O + Vector3(4.15, 8.6, 0.0), 2.5, 0.2, true, M.plaster, true, true)
	# handrails
	slab(O + Vector3(0.04, 0.95, -0.6), O + Vector3(0.04, 3.95, -6.0), 0.06, 0.06, true, M.dark_wood, true, false)
	slab(O + Vector3(5.36, 3.95, -6.0), O + Vector3(5.36, 6.95, 0.0), 0.06, 0.06, true, M.dark_wood, true, false)
	# portals
	var fb := Color(0.04, 0.035, 0.03)
	var up := make_portal("StairsUp", O + Vector3(1.25, 7.3, -0.01), Vector3(0, 0, 1), Vector3.UP, Vector2(2.5, 2.6), fb)
	var down := make_portal("StairsDown", O + Vector3(1.25, 1.3, -0.01), Vector3(0, 0, -1), Vector3.UP, Vector2(2.5, 2.6), fb)
	up.on_teleport = func(b):
		if b == G.player:
			_floor_changed(1)
	down.on_teleport = func(b):
		if b == G.player:
			_floor_changed(-1)
	make_portal("StairsHouseDoor", O + Vector3(2.7, 4.2, -9.01), Vector3(0, 0, 1), Vector3.UP, Vector2(1.4, 2.4))
	make_portal("StairsAtticDoor", O + Vector3(2.7, 7.1, 3.01), Vector3(0, 0, -1), Vector3.UP, Vector2(1.2, 2.2))
	# door casings
	for c in [[O + Vector3(2.7, 3.0, -9.0), 1.4, 2.4, 1.0], [O + Vector3(2.7, 6.0, 3.0), 1.2, 2.2, -1.0]]:
		var base: Vector3 = c[0]
		var w: float = c[1]
		var hh: float = c[2]
		var dz: float = c[3] * 0.018
		box(base + Vector3(-w * 0.5 - 0.045, hh * 0.5 + 0.045, dz), Vector3(0.09, hh + 0.09, 0.035), M.wood_trim, false)
		box(base + Vector3(w * 0.5 + 0.045, hh * 0.5 + 0.045, dz), Vector3(0.09, hh + 0.09, 0.035), M.wood_trim, false)
		box(base + Vector3(0, hh + 0.045, dz), Vector3(w + 0.18, 0.09, 0.035), M.wood_trim, false)
	var warm := Color(1.0, 0.84, 0.62)
	omni(O + Vector3(2.7, 5.5, -7.5), warm, 1.7, 9.0, true)
	omni(O + Vector3(2.7, 8.5, 1.5), warm, 1.7, 9.0, true)
	omni(O + Vector3(2.7, 2.5, 1.5), warm, 1.7, 9.0, true)
	omni(O + Vector3(1.25, 3.5, -3.0), warm, 0.7, 5.0, false)
	omni(O + Vector3(4.15, 6.5, -3.0), warm, 0.7, 5.0, false)
	sphere(O + Vector3(2.7, 5.93, -7.5), 0.08, M.bulb, false, false)
	sphere(O + Vector3(2.7, 8.93, 1.5), 0.08, M.bulb, false, false)
	prop("ball", O + Vector3(4.6, 3.19, -8.4), 0.0, Color(0.95, 0.45, 0.1))


func set_floor(n: int) -> void:
	G.floor_number = n


func _floor_changed(d: int) -> void:
	set_floor(G.floor_number + d)
	if d > 0 and G.floor_number == 100:
		# a reward for whoever keeps climbing
		var gd := Props.make("duck", Color(1.0, 0.8, 0.2))
		var cam: Camera3D = G.player.camera
		add_spawned(gd, Transform3D(Basis.IDENTITY, cam.global_position - cam.global_transform.basis.z * 1.2))
		G.sfx.play2d("chime", -3.0, 1.3)


# =====================================================================================
# The Attic (the trapdoor drops you out of a painting in the foyer)
# =====================================================================================

func _build_attic() -> void:
	_begin("The Attic", Vector3(-5.4, -1.0, -64.4), Vector3(5.4, 5.0, -55.7))
	var mn := Vector3(-5, 0, -64)
	var mx := Vector3(5, 2.4, -56)
	var o_s := op("s", 3.0, 1.2, 2.2)
	room(mn, mx, null, M.attic_wall, null, [o_s], {"no_floor": true, "no_ceiling": true, "base": M.wood_trim, "trim": M.wood_trim})
	var ff: Material = M.attic_floor
	box(Vector3(0, -0.1, -62.6), Vector3(10.4, 0.2, 3.2), ff)
	box(Vector3(0, -0.1, -57.4), Vector3(10.4, 0.2, 3.2), ff)
	box(Vector3(-3.0, -0.1, -60.0), Vector3(4.4, 0.2, 2.0), ff)
	box(Vector3(3.0, -0.1, -60.0), Vector3(4.4, 0.2, 2.0), ff)
	box(Vector3(-5.1, 3.25, -60.0), Vector3(0.2, 1.7, 8.4), M.attic_wall)
	box(Vector3(5.1, 3.25, -60.0), Vector3(0.2, 1.7, 8.4), M.attic_wall)
	_roof_slope(Vector3(0, 2.4, -64.0), Vector3(0, 4.0, -60.0))
	_roof_slope(Vector3(0, 2.4, -56.0), Vector3(0, 4.0, -60.0))
	# bunting strung across the attic, right above the trapdoor
	var flag_cols := [Color(0.9, 0.2, 0.2), Color(0.95, 0.75, 0.15), Color(0.2, 0.6, 0.9), Color(0.3, 0.75, 0.35), Color(0.8, 0.35, 0.8)]
	for line in [[Vector3(-4.6, 2.3, -63.2), Vector3(4.6, 2.3, -56.8)], [Vector3(-4.6, 2.3, -56.8), Vector3(4.6, 2.3, -63.2)]]:
		var a: Vector3 = line[0]
		var b: Vector3 = line[1]
		var n := 26
		for k in n:
			var t := (k + 0.5) / n
			var p := a.lerp(b, t) - Vector3(0, 0.45 * 4.0 * t * (1.0 - t), 0)
			var yaw := atan2(b.x - a.x, b.z - a.z)
			cyl(p - Vector3(0, 0.07, 0), 0.085, 0.006, _flower_mat(flag_cols[k % flag_cols.size()]), false, -1.0, false,
				Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, 0.9) * Basis(Vector3.FORWARD, PI * 0.5) * Basis(Vector3.UP, PI * 0.5), 3)
	box(Vector3(0, 3.88, -60.0), Vector3(10.0, 0.16, 0.16), M.beam, false)
	for x in [-3.6, -1.3, 1.3, 3.6]:
		box(Vector3(x, 2.3, -60.0), Vector3(0.14, 0.14, 8.0), M.beam)
		box(Vector3(x, 3.1, -60.0), Vector3(0.12, 1.6, 0.12), M.beam, false)
	# the trapdoor
	# "Up" of the trapdoor points north, the way you walk in from the attic door, so you
	# come out of the painting facing the room rather than the wall.
	make_portal("Trapdoor", Vector3(0, -0.01, -60.0), Vector3.UP, Vector3(0, 0, -1), Vector2(1.6, 2.0))
	var lb := Basis(Vector3.RIGHT, deg_to_rad(-100.0))
	box(Vector3(0, 0.0, -61.0) + lb * Vector3(0, 0.03, 1.0), Vector3(1.6, 0.05, 2.0), M.door_wood, true, true, lb)
	box(Vector3(-0.83, 0.02, -60.0), Vector3(0.06, 0.04, 2.1), M.wood_trim, false)
	box(Vector3(0.83, 0.02, -60.0), Vector3(0.06, 0.04, 2.1), M.wood_trim, false)
	box(Vector3(0, 0.02, -58.97), Vector3(1.72, 0.04, 0.06), M.wood_trim, false)
	portal_for("s", mn, mx, o_s, "AtticDoor")
	hanging_lamp(Vector3(1.6, 2.9, -60.0), 3.95, 1.8, 10.0, true)
	omni(Vector3(3.0, 1.9, -57.0), Color(1.0, 0.8, 0.55), 0.5, 5.0, false)
	# junk
	for i in 3:
		prop("crate", Vector3(-4.3, 0.305 + i * 0.605, -63.3), 0.1 * i)
	prop("crate", Vector3(-3.6, 0.305, -63.35), -0.2)
	prop("small_crate", Vector3(-3.6, 0.81, -63.3), 0.4)
	prop("crate", Vector3(-4.3, 0.305, -62.6), 0.3)
	prop("chair", Vector3(2.6, 0.475, -62.8), 0.9)
	prop("lamp", Vector3(-2.6, 0.305, -57.0))
	for i in 4:
		prop("book", Vector3(3.8 + i * 0.06, 0.125, -63.4), 0.0)
	# old trunk with a duck on it
	box(Vector3(4.2, 0.27, -58.0), Vector3(0.6, 0.54, 1.0), M.door_wood)
	box(Vector3(4.2, 0.55, -58.0), Vector3(0.64, 0.04, 1.04), M.metal, false)
	duck(Vector3(4.2, 0.72, -58.0), -1.2)
	# rocking horse
	var rh := Vector3(-3.0, 0, -58.2)
	box(rh + Vector3(0, 0.55, 0), Vector3(0.25, 0.25, 0.7), M.wardrobe)
	box(rh + Vector3(0, 0.8, -0.35), Vector3(0.18, 0.35, 0.18), M.wardrobe, false, true, Basis(Vector3.RIGHT, 0.4))
	box(rh + Vector3(0, 1.0, -0.47), Vector3(0.16, 0.16, 0.3), M.wardrobe, false)
	for sx in [-0.12, 0.12]:
		slab(rh + Vector3(sx, 0.08, -0.5), rh + Vector3(sx, 0.08, 0.5), 0.04, 0.05, true, M.dark_wood, true, false)
		for sz in [-0.25, 0.25]:
			box(rh + Vector3(sx, 0.3, sz), Vector3(0.04, 0.45, 0.04), M.dark_wood, false)
	cbox(rh + Vector3(0, 0.5, 0), Vector3(0.3, 1.0, 1.0))


func _roof_slope(lo: Vector3, hi: Vector3) -> void:
	var mat: Material = M.attic_roof
	var dir := (hi - lo).normalized()
	var lo_x := lo - dir * 0.35
	var hi_x := hi + dir * 0.2
	var side_w := 4.45
	for sx in [-1.0, 1.0]:
		var xc: float = sx * (0.75 + side_w * 0.5)
		slab(Vector3(xc, lo_x.y, lo_x.z), Vector3(xc, hi_x.y, hi_x.z), side_w, 0.15, true, mat)
	var a := lo.lerp(hi, 0.33)
	var b := lo.lerp(hi, 0.8)
	slab(Vector3(0, lo_x.y, lo_x.z), Vector3(0, a.y, a.z), 1.5, 0.15, true, mat)
	slab(Vector3(0, b.y, b.z), Vector3(0, hi_x.y, hi_x.z), 1.5, 0.15, true, mat)
	for sx in [-0.79, 0.79]:
		slab(Vector3(sx, a.y, a.z), Vector3(sx, b.y, b.z), 0.08, 0.16, false, M.beam, true, false)
	var mid := (a + b) * 0.5
	var sp := SpotLight3D.new()
	sp.position = mid - Vector3(0, 0.15, 0)
	sp.rotation = Vector3(-PI * 0.5, 0, 0)
	sp.spot_range = 7.0
	sp.spot_angle = 34.0
	sp.light_energy = 2.6
	sp.light_color = Color(0.82, 0.9, 1.0)
	sp.shadow_enabled = true
	_area_node.add_child(sp)


# =====================================================================================
# The Great Hall (inside the wardrobe)
# =====================================================================================

func _build_great_hall() -> void:
	_begin("The Great Hall", Vector3(54.7, -1.0, -20.3), Vector3(85.3, 13.0, 20.3))
	var mn := Vector3(55, 0, -20)
	var mx := Vector3(85, 12, 20)
	var o_s := op("s", 70.0, 1.0, 2.05)
	var o_e := op("e", 0.0, 1.4, 1.6, 7.0)
	room(mn, mx, M.hall_floor, M.hall_wall, M.hall_ceiling, [o_s, o_e], {"base": M.stone_trim, "base_h": 0.3, "trim": M.wood_trim})
	portal_for("s", mn, mx, o_s, "HallWardrobeDoor")
	var ghw := portal_for("e", mn, mx, o_e, "HallHighWindow")
	ghw.can_teleport = false
	glass_pane(Vector3(84.996, 7.8, 0.0), Vector3(0.006, 1.6, 1.4), false)
	blocker(Vector3(85.13, 7.8, 0.0), Vector3(0.12, 1.6, 1.4))
	box(Vector3(84.99, 7.8, 0.0), Vector3(0.03, 1.6, 0.04), M.wood_trim, false, false)
	box(Vector3(84.99, 7.8, 0.0), Vector3(0.03, 0.04, 1.4), M.wood_trim, false, false)
	# free-standing door frame in the middle of the hall
	var fz := 4.0
	box(Vector3(69.3, 1.225, fz), Vector3(0.2, 2.45, 0.25), M.frame_white)
	box(Vector3(70.7, 1.225, fz), Vector3(0.2, 2.45, 0.25), M.frame_white)
	box(Vector3(70.0, 2.325, fz), Vector3(1.6, 0.25, 0.25), M.frame_white)
	box(Vector3(70.0, 2.48, fz), Vector3(1.75, 0.06, 0.32), M.gold, false)
	for sx in [69.3, 70.7]:
		box(Vector3(sx, 0.05, fz), Vector3(0.3, 0.1, 0.36), M.gold, false)
	make_portal("HallFrameFront", Vector3(70.0, 1.1, fz), Vector3(0, 0, 1), Vector3.UP, Vector2(1.2, 2.2))
	make_portal("HallFrameBack", Vector3(70.0, 1.1, fz), Vector3(0, 0, -1), Vector3.UP, Vector2(1.2, 2.2))
	# columns
	for x in [60.0, 80.0]:
		for z in [-15.0, -9.0, -3.0, 3.0, 9.0, 15.0]:
			cyl(Vector3(x, 6.0, z), 0.5, 12.0, M.column, true, -1.0, true, Basis.IDENTITY, 20)
			box(Vector3(x, 0.2, z), Vector3(1.3, 0.4, 1.3), M.stone_trim)
			box(Vector3(x, 11.8, z), Vector3(1.3, 0.4, 1.3), M.stone_trim, false)
	# tall moonlit windows (decoration)
	for z in [-16.0, -8.0, 0.0, 8.0, 16.0]:
		box(Vector3(55.01, 5.5, z), Vector3(0.02, 5.0, 1.8), M.moon_glow, false, false)
		box(Vector3(55.04, 5.5, z), Vector3(0.06, 5.0, 0.08), M.dark_wood, false, false)
		for yy in [3.0, 4.6, 6.4, 8.0]:
			box(Vector3(55.04, yy, z), Vector3(0.06, 0.08, 1.8), M.dark_wood, false, false)
		box(Vector3(55.04, 5.5, z - 0.94), Vector3(0.08, 5.1, 0.1), M.dark_wood, false, false)
		box(Vector3(55.04, 5.5, z + 0.94), Vector3(0.08, 5.1, 0.1), M.dark_wood, false, false)
	# lights
	chandelier(Vector3(70, 12, 0), 2.6, 5.0, 26.0, true, 2.0)
	for c in [Vector3(63, 12, -12), Vector3(77, 12, -12), Vector3(63, 12, 12), Vector3(77, 12, 12)]:
		chandelier(c, 3.4, 2.6, 15.0, false, 1.4)
	omni(Vector3(70.0, 3.0, 18.5), Color(1.0, 0.84, 0.64), 1.0, 7.0, false)
	box(Vector3(70.0, 0.006, 12.0), Vector3(2.4, 0.012, 15.5), M.rug_red, false, false)
	_domino_run()
	_crate_pyramid(Vector3(72.0, 0.0, -15.0))
	_ball_machine(Vector3(75.5, 0.0, 13.0))
	slab(Vector3(63.5, 0.0, 17.5), Vector3(63.5, 1.8, 11.0), 3.0, 0.25, false, M.ramp, true, true)
	box(Vector3(63.5, 0.9, 10.85), Vector3(3.0, 1.8, 0.3), M.ramp)
	_trampoline_and_chair()
	_bowling()
	_seesaw(Vector3(67.0, 0.0, -9.0))
	prop("beach_ball", Vector3(72.0, 0.455, 8.0))
	prop("beach_ball", Vector3(66.0, 0.455, 6.0))
	prop("beach_ball", Vector3(76.5, 0.455, 0.5))
	for i in 8:
		prop("cube", Vector3(71.6 + (i % 4) * 0.3, 0.126 + (i / 4) * 0.255, 1.5), 0.0)
	prop("crate", Vector3(73.0, 0.305, 5.5), 0.3)
	prop("crate", Vector3(67.2, 0.305, 2.8), -0.4)
	prop("gnome", Vector3(68.5, 0.25, 6.5), 2.5)
	duck(Vector3(57.3, 2.08, 0.2), PI * 0.5)
	duck(Vector3(80.0, 0.15, 16.1), PI)


func _domino_run() -> void:
	var raw: Array = []
	for i in 600:
		var t := float(i) / 599.0
		raw.append(Vector3(61.8 + 2.4 * sin(t * TAU), 0.0, -17.0 + 13.0 * t))
	var spacing := 0.23
	var acc := 0.0
	var placed: Array = [raw[0]]
	for i in range(1, raw.size()):
		acc += (raw[i] as Vector3).distance_to(raw[i - 1])
		if acc >= spacing:
			placed.append(raw[i])
			acc = 0.0
	for i in placed.size():
		var p: Vector3 = placed[i]
		var q: Vector3 = placed[mini(i + 1, placed.size() - 1)] if i < placed.size() - 1 else p + (p - placed[i - 1])
		var basis := Basis.looking_at((q - p).normalized(), Vector3.UP)
		prop_xf("domino", Transform3D(basis, p + Vector3(0, 0.201, 0)), Color.from_hsv(float(i) / placed.size(), 0.55, 0.95))
	var first: Vector3 = placed[0]


func _crate_pyramid(base: Vector3) -> void:
	for r in 4:
		for j in 4 - r:
			prop("crate", base + Vector3(r * 0.305 + j * 0.61, 0.305 + r * 0.6, 0.0), 0.0)


func _ball_machine(base: Vector3) -> void:
	box(base + Vector3(0, 0.5, 0), Vector3(1.0, 1.0, 1.0), M.machine_red)
	cyl(base + Vector3(0, 3.5, 0), 0.15, 5.0, M.metal, true)
	cyl(base + Vector3(0, 6.3, 0), 0.3, 0.8, M.machine_red, false, 0.8)
	sphere(base + Vector3(0, 1.0, 0), 0.25, M.gold, false)
	var bp := base + Vector3(-1.8, 0.0, 1.8)
	box(bp + Vector3(0, 0.5, 0), Vector3(0.5, 1.0, 0.5), M.metal)
	var m := CylinderMesh.new()
	m.top_radius = 0.16
	m.bottom_radius = 0.17
	m.height = 0.1
	var spout := base + Vector3(0, 6.9, 0)
	var press := func():
		_spawn_balls(spout)
	interactable(bp + Vector3(0, 1.05, 0), m, M.button_red, Vector3(0.36, 0.14, 0.36), "BigRedButton", press)


func _spawn_balls(at: Vector3) -> void:
	if G.sfx:
		G.sfx.play_at("button", at - Vector3(0, 6, 0), 0.0)
	for i in 16:
		var b := Props.make("ball")
		add_spawned(b, Transform3D(Basis.IDENTITY, at + Vector3(randf_range(-0.3, 0.3), randf_range(0, 0.3), randf_range(-0.3, 0.3))))
		b.linear_velocity = Vector3(randf_range(-3.0, 3.0), randf_range(1.0, 3.5), randf_range(-3.0, 3.0))
		if G.sfx and i % 4 == 0:
			G.sfx.play_at("pop", at, -6.0, randf_range(0.9, 1.3))
		await get_tree().create_timer(0.06).timeout


func _trampoline_and_chair() -> void:
	# giant chair (scale x4)
	var c := Vector3(57.3, 0.0, 0.2)
	var w: Material = M.wardrobe
	box(c + Vector3(0, 1.88, 0), Vector3(1.9, 0.16, 1.9), w)
	for sx in [-0.85, 0.85]:
		for sz in [-0.85, 0.85]:
			box(c + Vector3(sx, 0.9, sz), Vector3(0.16, 1.8, 0.16), w)
	box(c + Vector3(-0.87, 3.1, 0), Vector3(0.16, 2.3, 1.9), w)
	# trampoline
	var tp := Vector3(62.3, 0.0, 0.2)
	var tb := StaticBody3D.new()
	tb.collision_layer = G.PL_WORLD
	tb.collision_mask = 0
	tb.set_meta("bounce", 12.5)
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.9
	tb.physics_material_override = pm
	_area_node.add_child(tb)
	var cs := CylinderShape3D.new()
	cs.radius = 1.15
	cs.height = 0.35
	_shape(cs, Transform3D(Basis.IDENTITY, tp + Vector3(0, 0.175, 0)), tb)
	cyl(tp + Vector3(0, 0.15, 0), 1.2, 0.3, M.metal, false)
	cyl(tp + Vector3(0, 0.31, 0), 1.05, 0.04, M.trampoline, false)


func _bowling() -> void:
	box(Vector3(83.5, 0.004, 0.0), Vector3(1.8, 0.008, 34.0), M.lane, false, false)
	box(Vector3(82.55, 0.04, 0.0), Vector3(0.1, 0.08, 34.0), M.dark_wood)
	box(Vector3(84.45, 0.04, 0.0), Vector3(0.1, 0.08, 34.0), M.dark_wood)
	for r in 4:
		for j in r + 1:
			prop("pin", Vector3(83.5 - r * 0.15 + j * 0.3, 0.201, -14.5 - r * 0.26))
	prop("bowling_ball", Vector3(83.2, 0.111, 16.5))
	prop("bowling_ball", Vector3(83.8, 0.111, 16.5))


func _seesaw(c: Vector3) -> void:
	var pivot := StaticBody3D.new()
	pivot.collision_layer = G.PL_WORLD
	pivot.collision_mask = 0
	_area_node.add_child(pivot)
	pivot.position = c + Vector3(0, 0.25, 0)
	var pm := MeshInstance3D.new()
	pm.mesh = _bm(Vector3(0.3, 0.5, 0.7))
	pm.material_override = M.metal
	pivot.add_child(pm)
	cbox(Vector3.ZERO, Vector3(0.3, 0.5, 0.7), Basis.IDENTITY, pivot)
	var plank := Props.make("plank")
	props_root.add_child(plank)
	plank.global_position = c + Vector3(0, 0.56, 0) + _off
	var j := HingeJoint3D.new()
	_area_node.add_child(j)
	j.position = c + Vector3(0, 0.51, 0)
	j.node_a = j.get_path_to(pivot)
	j.node_b = j.get_path_to(plank)
	j.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
	j.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, deg_to_rad(22.0))
	j.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, deg_to_rad(-22.0))
	prop("small_crate", c + Vector3(1.6, 0.82, 0), 0.0)


# =====================================================================================
# The Greenhouse (through the front of the free-standing frame)
# =====================================================================================

func _build_greenhouse() -> void:
	# Built far away so none of the other buildings can be seen through the glass.
	_begin("The Greenhouse", Vector3(-7.4, -1.0, 62.7), Vector3(7.4, 6.5, 77.4), true, Vector3(0, 0, 1000))
	var H := 4.5
	var knee := 0.8
	box(Vector3(0, -0.1, 70.0), Vector3(14.4, 0.2, 14.4), M.terracotta)
	box(Vector3(-3.9, knee * 0.5, 62.9), Vector3(6.6, knee, 0.2), M.brick)
	box(Vector3(3.9, knee * 0.5, 62.9), Vector3(6.6, knee, 0.2), M.brick)
	box(Vector3(0, knee * 0.5, 77.1), Vector3(14.4, knee, 0.2), M.brick)
	box(Vector3(-7.1, knee * 0.5, 70.0), Vector3(0.2, knee, 14.0), M.brick)
	box(Vector3(7.1, knee * 0.5, 70.0), Vector3(0.2, knee, 14.0), M.brick)
	var gh := H - knee
	glass_pane(Vector3(-3.925, knee + gh * 0.5, 62.9), Vector3(6.55, gh, 0.02))
	glass_pane(Vector3(3.925, knee + gh * 0.5, 62.9), Vector3(6.55, gh, 0.02))
	glass_pane(Vector3(0.0, (2.3 + H) * 0.5, 62.9), Vector3(1.3, H - 2.3, 0.02))
	glass_pane(Vector3(0.0, knee + gh * 0.5, 77.1), Vector3(14.4, gh, 0.02))
	glass_pane(Vector3(-7.1, knee + gh * 0.5, 70.0), Vector3(0.02, gh, 14.0))
	glass_pane(Vector3(7.1, knee + gh * 0.5, 70.0), Vector3(0.02, gh, 14.0))
	glass_pane(Vector3(0.0, H + 0.01, 70.0), Vector3(14.4, 0.02, 14.4))
	var fw: Material = M.frame_white
	for i in 11:
		var u := -7.0 + i * 1.4
		if absf(u) > 0.8:
			box(Vector3(u, (knee + H) * 0.5, 62.9), Vector3(0.06, gh, 0.08), fw, false)
		box(Vector3(u, (knee + H) * 0.5, 77.1), Vector3(0.06, gh, 0.08), fw, false)
		box(Vector3(-7.1, (knee + H) * 0.5, 63.0 + i * 1.4), Vector3(0.08, gh, 0.06), fw, false)
		box(Vector3(7.1, (knee + H) * 0.5, 63.0 + i * 1.4), Vector3(0.08, gh, 0.06), fw, false)
		box(Vector3(u, H + 0.02, 70.0), Vector3(0.06, 0.1, 14.4), fw, false)
		box(Vector3(0.0, H + 0.02, 63.0 + i * 1.4), Vector3(14.4, 0.1, 0.06), fw, false)
	for yy in [knee, 2.6, H]:
		box(Vector3(0.0, yy, 77.1), Vector3(14.4, 0.06, 0.09), fw, false)
		box(Vector3(-7.1, yy, 70.0), Vector3(0.09, 0.06, 14.2), fw, false)
		box(Vector3(7.1, yy, 70.0), Vector3(0.09, 0.06, 14.2), fw, false)
		box(Vector3(-3.95, yy, 62.9), Vector3(6.5, 0.06, 0.09), fw, false)
		box(Vector3(3.95, yy, 62.9), Vector3(6.5, 0.06, 0.09), fw, false)
	# door frame in the glass wall
	box(Vector3(-0.66, 1.15, 62.92), Vector3(0.12, 2.3, 0.26), fw)
	box(Vector3(0.66, 1.15, 62.92), Vector3(0.12, 2.3, 0.26), fw)
	box(Vector3(0.0, 2.25, 62.92), Vector3(1.44, 0.1, 0.26), fw)
	make_portal("GreenhouseDoor", Vector3(0.0, 1.1, 62.99), Vector3(0, 0, 1), Vector3.UP, Vector2(1.2, 2.2))
	# sunlight (only affects the greenhouse layer)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-52.0), deg_to_rad(28.0), 0.0)
	sun.light_energy = 1.6
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_cull_mask = G.VL_SUN
	sun.set("shadow_caster_mask", G.VL_SUN)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45.0
	_area_node.add_child(sun)
	omni(Vector3(0, 3.8, 70.0), Color(0.95, 1.0, 0.9), 0.7, 14.0, false)
	# the world outside
	box(Vector3(0, -0.3, 70.0), Vector3(100.0, 0.2, 100.0), M.grass, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 46:
		var a := rng.randf() * TAU
		var r := rng.randf_range(13.0, 46.0)
		var tp := Vector3(cos(a) * r, -0.2, 70.0 + sin(a) * r)
		var h := rng.randf_range(3.0, 7.0)
		cyl(tp + Vector3(0, h * 0.2, 0), 0.18, h * 0.4, M.bark, false, 0.14, true, Basis.IDENTITY, 8)
		cyl(tp + Vector3(0, h * 0.55, 0), h * 0.28, h * 0.5, M.pine, false, 0.0, true, Basis.IDENTITY, 10)
		cyl(tp + Vector3(0, h * 0.82, 0), h * 0.2, h * 0.36, M.pine, false, 0.0, true, Basis.IDENTITY, 10)
	# planters with flowers
	for side in [-1.0, 1.0]:
		var px: float = 6.3 * side
		box(Vector3(px, 0.3, 70.5), Vector3(1.0, 0.6, 11.0), M.planter)
		box(Vector3(px, 0.61, 70.5), Vector3(0.9, 0.02, 10.9), M.soil, false)
		for k in 13:
			var z := 65.5 + k * 0.82
			if side > 0.0 and k % 4 == 1:
				_sunflower(Vector3(px + rng.randf_range(-0.2, 0.2), 0.62, z), rng.randf_range(1.8, 2.5))
			else:
				_plant(Vector3(px + rng.randf_range(-0.25, 0.25), 0.62, z), rng.randf_range(0.35, 0.9), Color.from_hsv(rng.randf(), 0.75, 0.95))
	# pond
	cyl(Vector3(2.0, 0.025, 72.0), 2.0, 0.05, M.water, false, -1.0, false, Basis.IDENTITY, 40)
	for k in 22:
		var a := k * TAU / 22.0
		sphere(Vector3(2.0 + cos(a) * 2.08, 0.05, 72.0 + sin(a) * 2.08), 0.16 + 0.04 * sin(k * 3.1), M.stone_gray, false, true, 0.55)
	duck(Vector3(2.3, 0.14, 71.6), 0.5)
	# bench and pots
	_bench(Vector3(-2.5, 0, 75.9), 2.2)
	for pp in [Vector3(-3.6, 0, 64.6), Vector3(3.6, 0, 64.6), Vector3(5.2, 0, 75.8), Vector3(-5.0, 0, 76.0), Vector3(-1.0, 0, 69.0)]:
		cyl(pp + Vector3(0, 0.22, 0), 0.22, 0.44, M.pot, true, 0.3)
		sphere(pp + Vector3(0, 0.65, 0), 0.38, M.leaf, false, true, 0.85)
		sphere(pp + Vector3(0.15, 0.85, 0.1), 0.22, M.leaf, false, true)
	# watering can
	cyl(Vector3(-5.4, 0.15, 64.2), 0.12, 0.3, M.metal, false)
	cyl(Vector3(-5.25, 0.25, 64.2), 0.02, 0.35, M.metal, false, 0.03, true, Basis(Vector3.FORWARD, -0.9))
	prop("gnome", Vector3(-1.8, 0.25, 72.5), 0.4)
	prop("gnome", Vector3(4.3, 0.25, 74.6), -2.0)
	prop("gnome", Vector3(-4.5, 0.25, 67.0), 1.2)
	prop("beach_ball", Vector3(0.5, 0.455, 66.5))
	prop("beach_ball", Vector3(-3.0, 0.455, 70.5))
	prop("ball", Vector3(1.0, 0.19, 75.0), 0.0, Color(1.0, 0.5, 0.7))
	var bird := AudioStreamPlayer3D.new()
	bird.stream = G.sfx.get_stream("birds")
	bird.unit_size = 6.0
	bird.max_distance = 26.0
	bird.volume_db = -8.0
	bird.autoplay = true
	bird.position = Vector3(0, 4.0, 70.0)
	bird.add_to_group("portal_audio")
	_area_node.add_child(bird)
	var bscript: Script = load("res://scripts/butterfly.gd")
	for k in 7:
		var bf := Node3D.new()
		bf.set_script(bscript)
		bf.set("home", Vector3(rng.randf_range(-5.0, 5.0), 1.3, rng.randf_range(65.0, 75.0)))
		bf.set("hue", rng.randf())
		_area_node.add_child(bf)


func _flower_mat(c: Color) -> Material:
	var k := c.to_html()
	if not _flower_mats.has(k):
		_flower_mats[k] = Mats.make(c, c.darkened(0.3), Mats.PLAIN, 1.0, 0.6)
	return _flower_mats[k]


func _plant(base: Vector3, h: float, flower: Color) -> void:
	cyl(base + Vector3(0, h * 0.5, 0), 0.015, h, M.stem, false, -1.0, true, Basis.IDENTITY, 6)
	sphere(base + Vector3(0, h * 0.45, 0), 0.1 + h * 0.1, M.leaf, false, true, 0.7)
	sphere(base + Vector3(0, h, 0), 0.055, _flower_mat(flower), false)
	sphere(base + Vector3(0.05, h - 0.05, 0.03), 0.04, _flower_mat(flower), false)


func _sunflower(base: Vector3, h: float) -> void:
	cyl(base + Vector3(0, h * 0.5, 0), 0.03, h, M.stem, false, -1.0, true, Basis.IDENTITY, 6)
	sphere(base + Vector3(0, h * 0.4, 0.08), 0.14, M.leaf, false, true, 0.4)
	sphere(base + Vector3(0, h * 0.6, -0.08), 0.12, M.leaf, false, true, 0.4)
	var tilt := Basis(Vector3.RIGHT, PI * 0.5 - 0.3)
	cyl(base + Vector3(-0.0, h, -0.05), 0.28, 0.03, M.sunflower, false, -1.0, true, tilt, 16)
	cyl(base + Vector3(-0.0, h + 0.005, -0.07), 0.13, 0.04, M.sunflower_c, false, -1.0, true, tilt, 16)


# =====================================================================================
# Linking, layers and spawned things
# =====================================================================================

func _pair(a: String, b: String) -> void:
	P[a].target = P[b]
	P[b].target = P[a]


func _link() -> void:
	_pair("FrontDoor", "HallFrameBack")
	_pair("HallFrameFront", "GreenhouseDoor")
	_pair("Wardrobe", "HallWardrobeDoor")
	_pair("HallStairs", "StairsHouseDoor")
	_pair("StairsAtticDoor", "AtticDoor")
	_pair("StairsUp", "StairsDown")
	_pair("RepeatEast", "RepeatWest")
	_pair("HallWindow", "HallHighWindow")
	_pair("Trapdoor", "Painting")
	P.HallStairs.on_teleport = func(b):
		if b == G.player:
			set_floor(1)
	for p in portals:
		p.refresh_xf()
		if p.target == null:
			push_warning("Portal %s has no target" % p.name)
		elif not p.size.is_equal_approx(p.target.size):
			push_warning("Portal size mismatch: %s vs %s" % [p.name, p.target.name])


func update_body_layers(rb: Node) -> void:
	var inside := false
	for a in areas:
		if a.name == "The Greenhouse" and (a.aabb as AABB).has_point((rb as Node3D).global_position):
			inside = true
	var layers := (G.VL_WORLD | G.VL_SUN) if inside else G.VL_WORLD
	for c in rb.get_children():
		if c is MeshInstance3D:
			c.layers = layers


func add_spawned(b: Prop, xf: Transform3D) -> void:
	spawned_root.add_child(b)
	b.global_transform = xf
	b.set_meta("spawned", true)
	update_body_layers(b)
	var kids := spawned_root.get_children()
	if kids.size() > 260:
		for i in kids.size() - 260:
			if G.player and G.player.held == kids[i]:
				G.player.drop()
			kids[i].queue_free()


func clear_spawned() -> void:
	var n := 0
	for c in spawned_root.get_children():
		if G.player and G.player.held == c:
			G.player.drop()
		c.queue_free()
		n += 1
	if G.hud:
		G.hud.toast("Cleared %d spawned things" % n)


func celebrate(at: Vector3) -> void:
	for i in 90:
		var c := Props.make("confetti")
		add_spawned(c, Transform3D(Basis.IDENTITY, at + Vector3(randf_range(-0.4, 0.4), 1.5 + randf() * 0.5, randf_range(-0.4, 0.4))))
		c.linear_velocity = Vector3(randf_range(-4, 4), randf_range(3, 8), randf_range(-4, 4))
		c.angular_velocity = Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))
