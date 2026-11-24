class_name Player
extends CharacterBody3D
## First-person explorer. Movement runs every rendered frame so the camera stays smooth
## and portal teleports happen before any portal view is rendered.

const RADIUS := 0.3
const STAND_H := 1.8
const CROUCH_H := 1.05
const EYE_FROM_TOP := 0.18
const WALK := 4.3
const SPRINT := 7.2
const CROUCH_SPEED := 2.2
const JUMP_V := 5.0
const GRAVITY := 13.0
const SPAWN_KINDS := ["crate", "ball", "beach_ball", "duck", "domino", "chair", "cube", "pin", "lamp"]

var yaw := 0.0
var pitch := 0.0
var head: Node3D
var cam_pivot: Node3D
var camera: Camera3D
var flashlight: SpotLight3D
var shape: CapsuleShape3D
var col: CollisionShape3D
var body_vis: Node3D
var head_vis: Node3D
var cur_h := STAND_H
var crouching := false
var fly := false
var coyote := 0.0
var jump_buffer := 0.0
var step_accum := 0.0
var was_on_floor := true
var last_fall_speed := 0.0
## World-space offset of the camera from where it belongs, eased back to zero. Lets the
## view stay put when a teleport has to nudge the body (e.g. out of the painting).
var cam_offset := Vector3.ZERO
var _just_teleported := false

var held: RigidBody3D = null
var held_link := Transform3D.IDENTITY
var held_rel := Basis.IDENTITY
var hold_dist := 1.8
var look_hit := {}
var _held_r := 0.3
## Bodies just let go of that still overlap the player: they keep ignoring the player's
## capsule until they are clear, or they'd be shot out of it (possibly through a wall).
var _releasing: Array = []

var debug_input := Vector2.ZERO
var debug_active := false


func _ready() -> void:
	process_priority = -100
	collision_layer = G.PL_PLAYER
	collision_mask = G.PL_WORLD | G.PL_PROPS | G.PL_GLASS
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.45
	floor_constant_speed = true
	floor_block_on_wall = true
	shape = CapsuleShape3D.new()
	shape.radius = RADIUS
	shape.height = STAND_H
	col = CollisionShape3D.new()
	col.shape = shape
	col.position.y = STAND_H * 0.5
	add_child(col)
	head = Node3D.new()
	head.position.y = STAND_H - EYE_FROM_TOP
	add_child(head)
	cam_pivot = Node3D.new()
	head.add_child(cam_pivot)
	camera = Camera3D.new()
	camera.fov = 75.0
	camera.near = 0.05
	camera.far = 400.0
	camera.cull_mask = G.MAIN_CULL
	cam_pivot.add_child(camera)
	camera.current = true
	flashlight = SpotLight3D.new()
	flashlight.spot_range = 18.0
	flashlight.spot_angle = 26.0
	flashlight.light_energy = 3.0
	flashlight.light_color = Color(1.0, 0.95, 0.85)
	flashlight.shadow_enabled = true
	flashlight.position = Vector3(0.15, -0.12, 0.0)
	flashlight.visible = false
	camera.add_child(flashlight)
	_build_body()


func _build_body() -> void:
	body_vis = Node3D.new()
	add_child(body_vis)
	var coat := Mats.make(Color(0.18, 0.22, 0.38), Color(0.12, 0.15, 0.28), Mats.STRIPES, 0.12, 0.8, 0.0, true, 0.0)
	var skin := Mats.make(Color(0.93, 0.76, 0.62), Color.WHITE, Mats.PLAIN, 1.0, 0.7, 0.0, true, 0.0)
	var black := Mats.make(Color(0.03, 0.03, 0.03), Color.BLACK, Mats.PLAIN, 1.0, 0.4, 0.0, true, 0.0)
	var white := Mats.make(Color(0.97, 0.97, 0.97), Color.WHITE, Mats.PLAIN, 1.0, 0.3, 0.0, true, 0.0)
	var hat := Mats.make(Color(0.08, 0.07, 0.07), Color(0.5, 0.1, 0.1), Mats.BANDS, 0.1, 0.6, 0.0, true, 0.0)
	var torso := CapsuleMesh.new()
	torso.radius = 0.26
	torso.height = 1.3
	_vis(body_vis, torso, Transform3D(Basis.IDENTITY, Vector3(0, 0.72, 0)), coat)
	for sx in [-1.0, 1.0]:
		var arm := CapsuleMesh.new()
		arm.radius = 0.07
		arm.height = 0.7
		_vis(body_vis, arm, Transform3D(Basis(Vector3.FORWARD, 0.18 * sx), Vector3(0.31 * sx, 0.98, 0.0)), coat)
	head_vis = Node3D.new()
	head_vis.position.y = 1.58
	body_vis.add_child(head_vis)
	var hs := SphereMesh.new()
	hs.radius = 0.17
	hs.height = 0.34
	_vis(head_vis, hs, Transform3D(), skin)
	for sx in [-1.0, 1.0]:
		var e := SphereMesh.new()
		e.radius = 0.04
		e.height = 0.08
		_vis(head_vis, e, Transform3D(Basis.IDENTITY, Vector3(0.065 * sx, 0.03, -0.14)), white)
		var pu := SphereMesh.new()
		pu.radius = 0.02
		pu.height = 0.04
		_vis(head_vis, pu, Transform3D(Basis.IDENTITY, Vector3(0.065 * sx, 0.03, -0.177)), black)
	var brim := CylinderMesh.new()
	brim.top_radius = 0.24
	brim.bottom_radius = 0.24
	brim.height = 0.02
	_vis(head_vis, brim, Transform3D(Basis.IDENTITY, Vector3(0, 0.13, 0)), hat)
	var top := CylinderMesh.new()
	top.top_radius = 0.14
	top.bottom_radius = 0.14
	top.height = 0.26
	_vis(head_vis, top, Transform3D(Basis.IDENTITY, Vector3(0, 0.26, 0)), hat)


func _vis(parent: Node3D, m: Mesh, t: Transform3D, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.transform = t
	mi.material_override = mat
	mi.layers = G.VL_PLAYER_BODY
	parent.add_child(mi)


func place(pos: Vector3, p_yaw: float, p_pitch: float = 0.0) -> void:
	global_position = pos
	yaw = p_yaw
	pitch = p_pitch
	velocity = Vector3.ZERO
	cam_pivot.basis = Basis.IDENTITY
	cam_offset = Vector3.ZERO
	cam_pivot.position = Vector3.ZERO
	_apply_rot()


func _apply_rot() -> void:
	rotation = Vector3(0.0, yaw, 0.0)
	head.rotation = Vector3(pitch, 0.0, 0.0)
	if head_vis:
		head_vis.rotation = Vector3(pitch * 0.6, 0.0, 0.0)


func is_active() -> bool:
	return debug_active or (G.hud != null and G.hud.is_playing())


func _process(delta: float) -> void:
	var ts := Engine.time_scale
	var dt := minf(delta / maxf(ts, 0.0001), 0.05)
	var active := is_active()
	_update_crouch(dt, active)
	var prev_eye := camera.global_position
	_move(dt, active)
	if G.portal_manager:
		G.portal_manager.check_player_cross(prev_eye, camera.global_position)
	if _just_teleported:
		# the frame of a teleport shows exactly where the portal put the camera
		_just_teleported = false
	else:
		_ease_camera(dt)
	_update_look()


func _ease_camera(dt: float) -> void:
	if not cam_pivot.basis.is_equal_approx(Basis.IDENTITY):
		cam_pivot.basis = cam_pivot.basis.slerp(Basis.IDENTITY, 1.0 - exp(-6.0 * dt)).orthonormalized()
	if cam_offset != Vector3.ZERO:
		cam_offset = cam_offset.lerp(Vector3.ZERO, 1.0 - exp(-7.0 * dt))
		if cam_offset.length() < 0.0005:
			cam_offset = Vector3.ZERO
		cam_pivot.position = head.global_transform.basis.orthonormalized().inverse() * cam_offset


func _wish() -> Vector2:
	if debug_active:
		return debug_input
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")


func _move(dt: float, active: bool) -> void:
	var iv := _wish() if active else Vector2.ZERO
	var wish := Basis(Vector3.UP, yaw) * Vector3(iv.x, 0.0, iv.y)
	if wish.length() > 1.0:
		wish = wish.normalized()
	if fly:
		var dir := camera.global_transform.basis * Vector3(iv.x, 0.0, iv.y)
		if active and Input.is_action_pressed("jump"):
			dir += Vector3.UP
		if active and Input.is_action_pressed("crouch"):
			dir += Vector3.DOWN
		var spd := 13.0 if Input.is_action_pressed("sprint") else 6.0
		var tv := dir.normalized() * spd if dir.length() > 0.01 else Vector3.ZERO
		velocity = velocity.lerp(tv, 1.0 - exp(-8.0 * dt))
		global_position += velocity * dt
		return

	var on_floor := is_on_floor()
	if on_floor:
		coyote = 0.12
	else:
		coyote -= dt
	if active and Input.is_action_just_pressed("jump"):
		jump_buffer = 0.15
	else:
		jump_buffer -= dt

	var speed := WALK
	if crouching:
		speed = CROUCH_SPEED
	elif active and Input.is_action_pressed("sprint"):
		speed = SPRINT
	# a hole in the floor you fall into catches you, so you drop through it instead of
	# hitting the far lip just before you'd pass through
	var falling_in: bool = not on_floor and velocity.y <= 0.0 and G.portal_manager != null and G.portal_manager.in_floor_portal(global_position)
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	if on_floor:
		hv = hv.lerp(wish * speed, 1.0 - exp(-12.0 * dt))
	elif falling_in:
		hv *= exp(-6.0 * dt)
	elif wish.length() > 0.01:
		hv = hv.lerp(wish * maxf(speed, hv.length()), 1.0 - exp(-2.5 * dt))
	velocity.x = hv.x
	velocity.z = hv.z
	if not on_floor:
		velocity.y -= GRAVITY * G.player_gravity_scale() * dt
		velocity.y = maxf(velocity.y, -40.0)
	if jump_buffer > 0.0 and coyote > 0.0:
		velocity.y = JUMP_V
		jump_buffer = 0.0
		coyote = 0.0
	last_fall_speed = -velocity.y

	var k := 1.0 / maxf(Engine.time_scale, 0.0001)
	velocity *= k
	move_and_slide()
	velocity /= k
	_after_move(dt)


func _after_move(dt: float) -> void:
	var bounced := false
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var o := c.get_collider()
		if o is RigidBody3D:
			var rb := o as RigidBody3D
			var push := -c.get_normal()
			push.y = maxf(push.y, 0.0) * 0.3
			var spd := clampf(Vector2(velocity.x, velocity.z).length(), 0.6, 7.0)
			# scaled to game time, so high frame rates and slow motion don't kick harder
			var k := clampf(dt * Engine.time_scale * 60.0, 0.0, 1.0)
			if rb.linear_velocity.dot(push) < spd:
				rb.apply_central_impulse(push * spd * clampf(rb.mass, 0.2, 6.0) * 0.08 * k)
		elif o != null and o.has_meta("bounce") and c.get_normal().y > 0.7 and not bounced:
			bounced = true
			velocity.y = float(o.get_meta("bounce"))
			if G.sfx:
				G.sfx.play_at("boing", global_position, -2.0, randf_range(0.9, 1.1))
	var on_floor := is_on_floor()
	if on_floor and not was_on_floor:
		if last_fall_speed > 3.5 and G.sfx:
			G.sfx.landing(_floor_surface(), last_fall_speed)
		step_accum = 0.0
	was_on_floor = on_floor
	if on_floor and not fly:
		var hs := Vector2(velocity.x, velocity.z).length()
		# longer strides the faster you go: about 0.6 s between steps crouching,
		# 0.4 s walking and 0.33 s sprinting
		var stride := clampf(0.9 + hs * 0.21, 1.2, 2.4)
		if hs > 0.8:
			step_accum += hs * dt
			if step_accum > stride:
				step_accum = fmod(step_accum - stride, stride)
				if G.sfx:
					var vol := -21.0 if crouching else (-15.0 if hs > 5.0 else -17.0)
					G.sfx.footstep(_floor_surface(), vol)
		else:
			# standing still: the first step lands shortly after you set off
			step_accum = 1.0


func _floor_surface() -> String:
	return G.world.floor_surface(global_position) if G.world else "wood"


## Portal links pick up a little float error each time they are combined (the greenhouse
## is 1000 m away), so compare them loosely.
static func _same_link(a: Transform3D, b: Transform3D) -> bool:
	return a.basis.is_equal_approx(b.basis) and a.origin.distance_to(b.origin) < 0.01


func _update_releasing() -> void:
	if _releasing.is_empty():
		return
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.margin = 0.03
	q.transform = Transform3D(Basis.IDENTITY, global_position + col.position)
	q.collision_mask = G.PL_PROPS
	q.exclude = [get_rid()]
	var touching := {}
	for h in get_world_3d().direct_space_state.intersect_shape(q, 32):
		touching[h.rid] = true
	for b in _releasing.duplicate():
		if not is_instance_valid(b) or b == held:
			_releasing.erase(b)
		elif not touching.has(b.get_rid()):
			b.remove_collision_exception_with(self)
			_releasing.erase(b)


func _update_crouch(dt: float, active: bool) -> void:
	var want := active and Input.is_action_pressed("crouch") and not fly
	if not want and cur_h < STAND_H - 0.01:
		var space := get_world_3d().direct_space_state
		var from := global_position + Vector3(0.0, cur_h - 0.05, 0.0)
		var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0.0, STAND_H - cur_h + 0.12, 0.0), G.PL_WORLD | G.PL_PROPS, [get_rid()])
		if not space.intersect_ray(q).is_empty():
			want = true
	crouching = want
	var target_h := CROUCH_H if crouching else STAND_H
	if absf(cur_h - target_h) > 0.001:
		cur_h = move_toward(cur_h, target_h, dt * 5.0)
		shape.height = cur_h
		col.position.y = cur_h * 0.5
		head.position.y = cur_h - EYE_FROM_TOP


func _update_look() -> void:
	look_hit = {}
	if G.portal_manager == null:
		return
	var ex: Array = [get_rid()]
	if held:
		ex.append(held.get_rid())
	look_hit = G.portal_manager.portal_raycast(camera.global_position, -camera.global_transform.basis.z, 3.2, G.PL_WORLD | G.PL_PROPS, ex)


func look_target() -> Object:
	if look_hit.is_empty() or not look_hit.get("hit", false):
		return null
	var c = look_hit.get("collider")
	if c == null or not is_instance_valid(c):
		return null
	return c


# --- Teleport --------------------------------------------------------------------------

func portal_teleport(L: Transform3D, _src, dst) -> void:
	var new_cam := L * camera.global_transform
	var nb := new_cam.basis.orthonormalized()
	var fwd := -nb.z
	if absf(fwd.y) < 0.97:
		yaw = atan2(-fwd.x, -fwd.z)
	else:
		var h := nb.y * (-signf(fwd.y))
		yaw = atan2(-h.x, -h.z)
	pitch = clampf(asin(clampf(fwd.y, -1.0, 1.0)), -1.54, 1.54)
	var tilted := L.basis.y.dot(Vector3.UP) < 0.99
	if tilted:
		# gravity changed direction: ease the view back towards the horizon
		pitch = clampf(pitch, -0.45, 0.3)
	_apply_rot()
	var leveled := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	cam_pivot.basis = (leveled.inverse() * nb).orthonormalized()
	var p := new_cam.origin - L.basis * cam_offset - Vector3(0.0, head.position.y, 0.0)
	var push := Vector3.ZERO
	if tilted:
		# the body has to come out of the wall (and clear of the floor or furniture below),
		# but the view stays where it was and eases after it
		var n: Vector3 = dst.normal()
		var q := p
		if absf(n.y) < 0.5:
			q += n * (RADIUS + 0.15)
		q = _free_spot(q)
		push = q - p
		p = q
	global_position = p
	cam_offset = L.basis * cam_offset - push
	cam_pivot.position = head.global_transform.basis.orthonormalized().inverse() * cam_offset
	velocity = L.basis * velocity
	if tilted and velocity.length() > 9.0:
		velocity = velocity.normalized() * 9.0
	if held:
		held_link = held_link * L.affine_inverse()
	_just_teleported = true


## The nearest spot at or above `p` where the body's capsule touches no level geometry.
func _free_spot(p: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = G.PL_WORLD | G.PL_GLASS
	q.exclude = [get_rid()]
	for k in 31:
		var t := p + Vector3.UP * (0.04 * k)
		q.transform = Transform3D(Basis.IDENTITY, t + col.position)
		if space.intersect_shape(q, 1).is_empty():
			return t
	return p


# --- Interaction ---------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not is_active():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var s: float = 0.0022 * float(G.settings.sensitivity)
		yaw -= event.relative.x * s
		pitch = clampf(pitch - event.relative.y * s, -1.54, 1.54)
		_apply_rot()
		return
	if event.is_action_pressed("grab"):
		if held:
			drop()
		else:
			try_grab()
	elif event.is_action_pressed("throw"):
		if held:
			throw_held()
	elif event.is_action_pressed("interact"):
		interact()
	elif event.is_action_pressed("dist_up"):
		hold_dist = minf(hold_dist + 0.2, 3.0)
	elif event.is_action_pressed("dist_down"):
		hold_dist = maxf(hold_dist - 0.2, 0.9)
	elif event.is_action_pressed("rotate"):
		if held:
			held_rel = Basis(Vector3.UP, PI * 0.25) * held_rel
	elif event.is_action_pressed("paint"):
		paint_target()
	elif event.is_action_pressed("delete"):
		delete_target()
	elif event.is_action_pressed("gravity"):
		G.cycle_gravity()
	elif event.is_action_pressed("slowmo"):
		G.toggle_slowmo()
	elif event.is_action_pressed("flashlight"):
		flashlight.visible = not flashlight.visible
		if G.sfx:
			G.sfx.play2d("click", -6.0)
	elif event.is_action_pressed("fly"):
		fly = not fly
		velocity = Vector3.ZERO
		if G.hud:
			G.hud.toast("Fly mode on" if fly else "Fly mode off")
	elif event.is_action_pressed("clear"):
		if G.world:
			G.world.clear_spawned()
	else:
		for i in SPAWN_KINDS.size():
			if event.is_action_pressed("spawn_%d" % (i + 1)):
				spawn(SPAWN_KINDS[i])
				break


func try_grab() -> void:
	var c := look_target()
	if c == null:
		return
	if c is RigidBody3D and c.is_in_group("grabbable"):
		held = c
		_releasing.erase(c)
		_held_r = G.portal_manager.body_radius(held)
		held_link = look_hit.link
		var ct: Transform3D = held_link * camera.global_transform
		held_rel = (ct.basis.inverse() * held.global_transform.basis).orthonormalized()
		hold_dist = clampf(ct.origin.distance_to(held.global_position), 1.0, 2.6)
		held.add_collision_exception_with(self)
		held.sleeping = false
		if held.has_method("on_grabbed"):
			held.on_grabbed()
		if G.sfx:
			G.sfx.play2d("grab", -10.0)
	elif c.has_method("interact"):
		c.interact(self)


func drop() -> void:
	if held and is_instance_valid(held):
		_releasing.append(held)
		held.angular_velocity *= 0.3
	held = null
	held_link = Transform3D.IDENTITY


func throw_held() -> void:
	if held == null or not is_instance_valid(held):
		held = null
		return
	var dir: Vector3 = held_link.basis * (-camera.global_transform.basis.z)
	var speed := 15.0 / sqrt(maxf(held.mass, 0.5))
	held.linear_velocity = dir * clampf(speed, 4.0, 20.0) + Vector3.UP * 0.6
	held.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))
	var b := held
	drop()
	b.sleeping = false
	if G.sfx:
		G.sfx.play2d("whoosh", -12.0, 1.6)


func interact() -> void:
	var c := look_target()
	if c != null and c.has_method("interact"):
		c.interact(self)
	elif held and held.has_method("interact"):
		held.interact(self)


func paint_target() -> void:
	var c := look_target()
	if c == null and held:
		c = held
	if c != null and c.has_method("paint"):
		c.paint(Color.from_hsv(randf(), randf_range(0.55, 0.9), randf_range(0.7, 1.0)))
		if G.sfx:
			G.sfx.play_at("pop", (c as Node3D).global_position, -6.0, 1.6)


func delete_target() -> void:
	var c := look_target()
	if c == null or not (c is Prop):
		return
	if c.collectible:
		if G.hud:
			G.hud.toast("That duck is far too important to delete.")
		return
	if c == held:
		drop()
	if G.sfx:
		G.sfx.play_at("pop", c.global_position, -2.0, 0.8)
	c.queue_free()


func spawn(kind: String) -> void:
	if G.portal_manager == null or G.world == null:
		return
	var prop := Props.make(kind)
	var rad: float = G.portal_manager.body_radius(prop)
	var r: Dictionary = G.portal_manager.portal_raycast(camera.global_position, -camera.global_transform.basis.z, 2.0, G.PL_WORLD | G.PL_PROPS | G.PL_GLASS, [get_rid()])
	var dir: Vector3 = r.dir
	var link: Transform3D = r.link
	# off the surface you're looking at by the prop's own size, not just back along the ray
	var p: Vector3 = (r.position as Vector3) + (r.normal as Vector3) * (rad + 0.05) if r.hit else (r.position as Vector3) - dir * rad
	var spots := [p]
	if r.exit != null:
		# don't leave it behind (inside the frame of) the portal it was spawned through
		var sd: float = r.exit.signed_dist(p)
		if sd < rad:
			spots[0] = p + r.exit.normal() * (rad - sd + 0.02)
	elif Vector2(p.x - global_position.x, p.z - global_position.z).length() < RADIUS + rad + 0.05:
		# that would be inside you (looking at your feet, or at a wall you're touching):
		# try in front of you, behind you, beside you, then over your head
		var h := Vector2(dir.x, dir.z)
		if h.length() < 0.01:
			h = Vector2(-sin(yaw), -cos(yaw))
		h = h.normalized() * (RADIUS + rad + 0.05)
		var y := maxf(p.y, global_position.y + rad + 0.02)
		spots = []
		for v in [h, -h, Vector2(h.y, -h.x), Vector2(-h.y, h.x)]:
			spots.append(Vector3(global_position.x + v.x, y, global_position.z + v.y))
		spots.append(global_position + Vector3.UP * (cur_h + rad + 0.05))
	var spot = null
	var first := true
	for c in spots:
		if r.exit == null and G.portal_manager.behind_portal(c, rad):
			first = false
			continue
		spot = _free_prop_spot(c, rad)
		if spot != null:
			break
		first = false
	if spot == null:
		prop.free()
		return
	p = spot
	var basis: Basis = (link.basis * Basis(Vector3.UP, yaw)).orthonormalized()
	G.world.add_spawned(prop, Transform3D(basis, p))
	if first:
		prop.linear_velocity = dir * 1.5
	if G.sfx:
		G.sfx.play_at("pop", p, -4.0, randf_range(0.9, 1.2))


## `p`, or the nearest spot up to a metre above it, where a ball of radius `rad` touches
## neither the level nor the player; null if there is none.
func _free_prop_spot(p: Vector3, rad: float):
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var ball := SphereShape3D.new()
	ball.radius = rad * 0.85
	q.shape = ball
	q.collision_mask = G.PL_WORLD | G.PL_GLASS | G.PL_PLAYER
	for k in 11:
		q.transform = Transform3D(Basis.IDENTITY, p + Vector3.UP * (0.1 * k))
		if space.intersect_shape(q, 1).is_empty():
			return q.transform.origin
	return null


func _physics_process(dt: float) -> void:
	_update_releasing()
	if held == null:
		return
	if not is_instance_valid(held) or not held.is_inside_tree():
		held = null
		return
	var ct: Transform3D = held_link * camera.global_transform
	# Keep the hold point in front of whatever you're looking at (through portals too), so
	# standing close to a wall never drags the held thing into or through it.
	var dist := hold_dist
	var r: Dictionary = G.portal_manager.portal_raycast(camera.global_position, -camera.global_transform.basis.z, hold_dist + _held_r + 0.05, G.PL_WORLD | G.PL_GLASS, [get_rid(), held.get_rid()])
	if r.hit and _same_link(r.link, held_link):
		dist = minf(dist, maxf(float(r.distance) - _held_r - 0.05, 0.0))
	var tgt := ct.origin - ct.basis.z * dist
	var diff := tgt - held.global_position
	if diff.length() > 3.0:
		drop()
		return
	held.linear_velocity = (diff / maxf(dt, 0.0001) * 0.5).limit_length(25.0)
	var cur := held.global_transform.basis.orthonormalized()
	var tb := (ct.basis * held_rel).orthonormalized()
	var q := Quaternion(tb * cur.inverse())
	var ang := q.get_angle()
	if ang > PI:
		ang -= TAU
	if absf(ang) > 0.002:
		held.angular_velocity = (q.get_axis().normalized() * ang / maxf(dt, 0.0001) * 0.35).limit_length(20.0)
	else:
		held.angular_velocity = Vector3.ZERO
