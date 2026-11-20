class_name Props
extends RefCounted
## Factory for physics props.

static var _cache := {}


static func _m(key: String, c1: Color, c2: Color = Color.GRAY, pat: int = Mats.PLAIN, sc: float = 1.0,
		rough: float = 0.6, metal: float = 0.0) -> ShaderMaterial:
	if not _cache.has(key):
		_cache[key] = Mats.make(c1, c2, pat, sc, rough, metal, true, 0.04)
	return _cache[key]


static func _col(c: Color) -> ShaderMaterial:
	return Mats.make(c, c.darkened(0.3), Mats.PLAIN, 1.0, 0.45, 0.0, true, 0.03)


static func _mesh(b: Prop, m: Mesh, t: Transform3D, mat: Material, paint := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.transform = t
	mi.material_override = mat
	b.add_child(mi)
	if paint:
		b.paint_meshes.append(mi)
	return mi


static func _shape(b: Prop, s: Shape3D, t: Transform3D = Transform3D.IDENTITY) -> void:
	var cs := CollisionShape3D.new()
	cs.shape = s
	cs.transform = t
	b.add_child(cs)


static func _box(sz: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = sz
	return m


static func _boxs(sz: Vector3) -> BoxShape3D:
	var s := BoxShape3D.new()
	s.size = sz
	return s


static func _sph(r: float, h: float = -1.0) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = h if h > 0.0 else r * 2.0
	m.radial_segments = 24
	m.rings = 12
	return m


static func _cyl(rt: float, rb: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = rt
	m.bottom_radius = rb
	m.height = h
	m.radial_segments = 20
	return m


static func _pmat(friction: float, bounce: float) -> PhysicsMaterial:
	var p := PhysicsMaterial.new()
	p.friction = friction
	p.bounce = bounce
	return p


static func bright() -> Color:
	return Color.from_hsv(randf(), randf_range(0.55, 0.85), randf_range(0.75, 1.0))


static func make(kind: String, color: Variant = null) -> Prop:
	var b := Prop.new()
	b.kind = kind
	b.name = kind.capitalize().replace(" ", "")
	var T := Transform3D.IDENTITY
	match kind:
		"crate", "small_crate":
			var s := 0.6 if kind == "crate" else 0.4
			var wood := _m("crate", Color(0.7, 0.52, 0.3), Color(0.58, 0.4, 0.22), Mats.PLANKS, 0.45, 0.75)
			_mesh(b, _box(Vector3(s, s, s)), T, wood, true)
			var edge := _m("crate_edge", Color(0.42, 0.28, 0.15), Color.BLACK, Mats.PLAIN, 1.0, 0.8)
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var off := Vector3(sx, 0.0, sz) * (s * 0.5 - 0.022)
					_mesh(b, _box(Vector3(0.05, s + 0.004, 0.05)), Transform3D(Basis.IDENTITY, off), edge)
			_shape(b, _boxs(Vector3(s, s, s)))
			b.mass = 6.0 if kind == "crate" else 3.0
			b.physics_material_override = _pmat(0.8, 0.05)
		"ball":
			var c: Color = color if color != null else bright()
			_mesh(b, _sph(0.18), T, _col(c), true)
			var sh := SphereShape3D.new()
			sh.radius = 0.18
			_shape(b, sh)
			b.mass = 0.6
			b.physics_material_override = _pmat(0.5, 0.7)
			b.continuous_cd = true
		"beach_ball":
			var bm := Mats.make(Color(0.95, 0.2, 0.2), Color(0.2, 0.45, 0.95), Mats.SEGMENTS, 1.0, 0.35, 0.0, true, 0.0)
			_mesh(b, _sph(0.45), T, bm, true)
			var sh2 := SphereShape3D.new()
			sh2.radius = 0.45
			_shape(b, sh2)
			b.mass = 0.3
			b.linear_damp = 0.35
			b.physics_material_override = _pmat(0.6, 0.8)
		"bowling_ball":
			_mesh(b, _sph(0.11), T, _m("bowl", Color(0.1, 0.12, 0.45), Color(0.3, 0.1, 0.5), Mats.BLOTCH, 0.05, 0.15), true)
			var sh3 := SphereShape3D.new()
			sh3.radius = 0.11
			_shape(b, sh3)
			b.mass = 6.0
			b.physics_material_override = _pmat(0.25, 0.1)
			b.continuous_cd = true
		"pin":
			var pm := _m("pin", Color(0.97, 0.97, 0.95), Color(0.8, 0.1, 0.1), Mats.PLAIN, 1.0, 0.3)
			_mesh(b, _cyl(0.045, 0.06, 0.3), Transform3D(Basis.IDENTITY, Vector3(0, -0.04, 0)), pm, true)
			_mesh(b, _cyl(0.05, 0.05, 0.03), Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 0)), _m("pin_band", Color(0.8, 0.1, 0.1)))
			_mesh(b, _sph(0.05), Transform3D(Basis.IDENTITY, Vector3(0, 0.15, 0)), pm)
			var cs := CylinderShape3D.new()
			cs.radius = 0.06
			cs.height = 0.4
			_shape(b, cs)
			b.mass = 1.5
			b.physics_material_override = _pmat(0.4, 0.3)
		"domino":
			var dc: Color = color if color != null else Color(0.95, 0.93, 0.86)
			_mesh(b, _box(Vector3(0.18, 0.4, 0.04)), T, _col(dc), true)
			_shape(b, _boxs(Vector3(0.18, 0.4, 0.04)))
			b.mass = 0.5
			b.physics_material_override = _pmat(0.5, 0.05)
		"cube":
			var cc: Color = color if color != null else bright()
			var m := Mats.make(cc, Color(0.05, 0.05, 0.05), Mats.DOTS, 0.083, 0.4, 0.0, true, 0.0)
			_mesh(b, _box(Vector3(0.25, 0.25, 0.25)), T, m, true)
			_shape(b, _boxs(Vector3(0.25, 0.25, 0.25)))
			b.mass = 0.8
			b.physics_material_override = _pmat(0.7, 0.15)
		"confetti":
			_mesh(b, _box(Vector3(0.06, 0.06, 0.06)), T, _col(bright()), true)
			_shape(b, _boxs(Vector3(0.06, 0.06, 0.06)))
			b.mass = 0.05
			b.lifetime = 14.0
		"duck":
			var y := _m("duck", Color(1.0, 0.85, 0.1), Color(1, 0.7, 0), Mats.PLAIN, 1.0, 0.35)
			var orange := _m("beak", Color(1.0, 0.45, 0.05))
			var blk := _m("eye", Color(0.02, 0.02, 0.02), Color.BLACK, Mats.PLAIN, 1.0, 0.2)
			if color != null:
				y = _col(color)
			_mesh(b, _sph(0.14, 0.22), Transform3D(Basis.IDENTITY, Vector3(0, 0.0, 0.02)), y, true)
			_mesh(b, _sph(0.085), Transform3D(Basis.IDENTITY, Vector3(0, 0.14, -0.07)), y, true)
			_mesh(b, _box(Vector3(0.07, 0.025, 0.08)), Transform3D(Basis.IDENTITY, Vector3(0, 0.13, -0.16)), orange)
			for sx in [-1.0, 1.0]:
				_mesh(b, _sph(0.014), Transform3D(Basis.IDENTITY, Vector3(0.045 * sx, 0.17, -0.135)), blk)
			_mesh(b, _box(Vector3(0.05, 0.06, 0.06)), Transform3D(Basis(Vector3.RIGHT, -0.6), Vector3(0, 0.07, 0.15)), y)
			var s1 := SphereShape3D.new()
			s1.radius = 0.12
			_shape(b, s1, Transform3D(Basis.IDENTITY, Vector3(0, 0.0, 0.02)))
			var s2 := SphereShape3D.new()
			s2.radius = 0.08
			_shape(b, s2, Transform3D(Basis.IDENTITY, Vector3(0, 0.14, -0.07)))
			b.mass = 0.3
			b.physics_material_override = _pmat(0.6, 0.45)
		"chair":
			var w := _m("chair", Color(0.55, 0.33, 0.18), Color(0.45, 0.26, 0.13), Mats.PLANKS, 0.3, 0.6)
			_mesh(b, _box(Vector3(0.46, 0.05, 0.46)), Transform3D(Basis.IDENTITY, Vector3(0, 0.0, 0)), w, true)
			for lx in [-0.2, 0.2]:
				for lz in [-0.2, 0.2]:
					_mesh(b, _box(Vector3(0.04, 0.45, 0.04)), Transform3D(Basis.IDENTITY, Vector3(lx, -0.24, lz)), w)
			_mesh(b, _box(Vector3(0.46, 0.5, 0.04)), Transform3D(Basis.IDENTITY, Vector3(0, 0.27, 0.21)), w, true)
			_shape(b, _boxs(Vector3(0.46, 0.05, 0.46)))
			_shape(b, _boxs(Vector3(0.44, 0.45, 0.44)), Transform3D(Basis.IDENTITY, Vector3(0, -0.24, 0)))
			_shape(b, _boxs(Vector3(0.46, 0.5, 0.04)), Transform3D(Basis.IDENTITY, Vector3(0, 0.27, 0.21)))
			b.mass = 4.0
			b.physics_material_override = _pmat(0.7, 0.05)
		"book":
			var bc: Color = color if color != null else Color.from_hsv(randf(), 0.6, randf_range(0.35, 0.7))
			_mesh(b, _box(Vector3(0.05, 0.24, 0.17)), T, _col(bc), true)
			_mesh(b, _box(Vector3(0.042, 0.226, 0.005)), Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.084)), _m("pages", Color(0.95, 0.92, 0.82)))
			_shape(b, _boxs(Vector3(0.05, 0.24, 0.17)))
			b.mass = 0.4
			b.physics_material_override = _pmat(0.8, 0.05)
		"gnome":
			var blue := _m("gnome_body", Color(0.15, 0.3, 0.7))
			var red := _m("gnome_hat", Color(0.85, 0.12, 0.1))
			var skin := _m("gnome_skin", Color(0.95, 0.75, 0.62))
			var white := _m("gnome_beard", Color(0.96, 0.96, 0.96))
			_mesh(b, _cyl(0.08, 0.12, 0.22), Transform3D(Basis.IDENTITY, Vector3(0, -0.12, 0)), blue, true)
			_mesh(b, _sph(0.07), Transform3D(Basis.IDENTITY, Vector3(0, 0.04, 0)), skin)
			_mesh(b, _cyl(0.07, 0.0, 0.12), Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0, -0.02, -0.04)), white)
			_mesh(b, _cyl(0.0, 0.075, 0.2), Transform3D(Basis.IDENTITY, Vector3(0, 0.17, 0)), red)
			var cap := CapsuleShape3D.new()
			cap.radius = 0.1
			cap.height = 0.5
			_shape(b, cap, Transform3D(Basis.IDENTITY, Vector3(0, 0.0, 0)))
			b.mass = 2.0
			b.physics_material_override = _pmat(0.7, 0.2)
		"lamp":
			var metal := _m("lamp_metal", Color(0.25, 0.22, 0.2), Color.BLACK, Mats.PLAIN, 1.0, 0.35, 0.8)
			_mesh(b, _cyl(0.1, 0.11, 0.03), Transform3D(Basis.IDENTITY, Vector3(0, -0.28, 0)), metal)
			_mesh(b, _cyl(0.012, 0.012, 0.42), Transform3D(Basis.IDENTITY, Vector3(0, -0.06, 0)), metal)
			var shade := Mats.make(Color(0.95, 0.85, 0.6), Color.WHITE, Mats.PLAIN, 1.0, 0.8, 0.0, true, 0.0)
			shade.set_shader_parameter("emission", Color(1.0, 0.8, 0.5))
			shade.set_shader_parameter("emission_energy", 1.2)
			_mesh(b, _cyl(0.08, 0.15, 0.18), Transform3D(Basis.IDENTITY, Vector3(0, 0.2, 0)), shade, true)
			var cs2 := CylinderShape3D.new()
			cs2.radius = 0.13
			cs2.height = 0.6
			_shape(b, cs2)
			b.light = OmniLight3D.new()
			b.light.light_color = Color(1.0, 0.82, 0.6)
			b.light.light_energy = 1.4
			b.light.omni_range = 4.5
			b.light.position = Vector3(0, 0.18, 0)
			b.add_child(b.light)
			b.mass = 1.5
			b.prompt = "Toggle lamp"
			b.action = func(p: Prop):
				p.light.visible = not p.light.visible
				var mi: MeshInstance3D = p.paint_meshes[0]
				(mi.material_override as ShaderMaterial).set_shader_parameter("emission_energy", 1.2 if p.light.visible else 0.0)
				if G.sfx:
					G.sfx.play_at("click", p.global_position, -4.0)
			b.physics_material_override = _pmat(0.7, 0.1)
		"music_box":
			var wood := _m("mbox", Color(0.45, 0.2, 0.12), Color(0.35, 0.15, 0.08), Mats.PLANKS, 0.15, 0.4)
			var gold := _m("gold", Color(0.9, 0.7, 0.3), Color.BLACK, Mats.PLAIN, 1.0, 0.25, 1.0)
			_mesh(b, _box(Vector3(0.24, 0.12, 0.16)), T, wood, true)
			_mesh(b, _box(Vector3(0.25, 0.015, 0.17)), Transform3D(Basis.IDENTITY, Vector3(0, 0.065, 0)), gold)
			_mesh(b, _cyl(0.008, 0.008, 0.08), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0.16, 0, 0)), gold)
			_mesh(b, _box(Vector3(0.02, 0.06, 0.015)), Transform3D(Basis.IDENTITY, Vector3(0.2, 0.025, 0)), gold)
			_shape(b, _boxs(Vector3(0.24, 0.13, 0.16)))
			b.audio = AudioStreamPlayer3D.new()
			b.audio.unit_size = 2.5
			b.audio.max_distance = 18.0
			b.audio.volume_db = -6.0
			b.audio.add_to_group("portal_audio")
			b.add_child(b.audio)
			b.mass = 1.0
			b.prompt = "Wind music box"
			b.action = func(p: Prop):
				if p.audio.playing:
					p.audio.stop()
				else:
					if G.sfx:
						p.audio.stream = G.sfx.get_stream("musicbox")
					p.audio.play()
			b.physics_material_override = _pmat(0.7, 0.1)
		"plank":
			var w2 := _m("plank", Color(0.62, 0.45, 0.28), Color(0.5, 0.34, 0.2), Mats.PLANKS, 0.6, 0.7)
			_mesh(b, _box(Vector3(4.0, 0.1, 0.6)), T, w2, true)
			_shape(b, _boxs(Vector3(4.0, 0.1, 0.6)))
			b.mass = 12.0
			b.physics_material_override = _pmat(0.9, 0.0)
		_:
			_mesh(b, _box(Vector3(0.3, 0.3, 0.3)), T, _col(bright()), true)
			_shape(b, _boxs(Vector3(0.3, 0.3, 0.3)))
	b.collision_layer = G.PL_PROPS
	b.collision_mask = G.PL_WORLD | G.PL_PROPS | G.PL_PLAYER | G.PL_GLASS
	b.angular_damp = 0.4
	b.add_to_group("travelers")
	b.add_to_group("props")
	if kind != "plank":
		b.add_to_group("grabbable")
	return b
