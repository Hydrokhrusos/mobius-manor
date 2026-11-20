class_name PortalManager
extends Node
## Renders portals through a small pool of SubViewports, teleports the player and physics
## props, and offers raycasts that pass through portals.
##
## Views are handed out best-first by how much of the screen they cover: a portal seen
## directly by the player, a portal seen through that one, and so on up to MAX_DEPTH
## levels. A portal can be seen by several cameras at once and gets one view per camera.

const MAX_SLOTS := 8
const MAX_DEPTH := 3
const MAX_DIST := 75.0
const BODY_REACH := 0.45

class Slot:
	var vp: SubViewport
	var cam: Camera3D
	var id := 0
	var portal = null
	var active := false
	var depth := 0
	var rect := Rect2()

var portals: Array = []
var slots: Array = []
var main_cam: Camera3D
var env: Environment
var clip_img: Image
var clip_tex: ImageTexture
var quality := 1.0
var _size := Vector2i.ZERO
var _full_size := Vector2i.ZERO
var _prev_pos := {}
var _over_is_outside := true
var _frustum_checked := false
var stats_active := 0


func setup(p_portals: Array, cam: Camera3D, portal_env: Environment) -> void:
	portals = p_portals
	main_cam = cam
	env = portal_env
	process_priority = 100
	process_physics_priority = 100
	clip_img = Image.create(64, 1, false, Image.FORMAT_RGBAF)
	clip_img.fill(Color(0.0, 0.0, 0.0, -1.0))
	clip_tex = ImageTexture.create_from_image(clip_img)
	RenderingServer.global_shader_parameter_set("portal_clip_planes", clip_tex)
	var main_vp := get_viewport()
	for i in MAX_SLOTS:
		var s := Slot.new()
		s.id = i + 1
		s.vp = SubViewport.new()
		s.vp.name = "PortalView%d" % s.id
		s.vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		s.vp.use_hdr_2d = true
		# Match the main view so shadows don't sharpen as you step through.
		s.vp.msaa_3d = main_vp.msaa_3d
		s.vp.positional_shadow_atlas_size = main_vp.positional_shadow_atlas_size
		s.vp.positional_shadow_atlas_16_bits = main_vp.positional_shadow_atlas_16_bits
		s.vp.audio_listener_enable_3d = false
		s.vp.gui_disable_input = true
		s.vp.size = Vector2i(64, 64)
		add_child(s.vp)
		s.cam = Camera3D.new()
		s.cam.environment = env
		s.vp.add_child(s.cam)
		s.cam.current = true
		slots.append(s)
	for p in portals:
		p.refresh_xf()


func set_quality(q: float) -> void:
	quality = q
	_size = Vector2i.ZERO


func _process(_delta: float) -> void:
	if main_cam == null:
		return
	var full_sz := Vector2i(get_viewport().get_visible_rect().size.round())
	var vsz := Vector2i((Vector2(full_sz) * quality).round())
	vsz = vsz.max(Vector2i(64, 64))
	if vsz != _size or full_sz != _full_size:
		_size = vsz
		_full_size = full_sz
		for s in slots:
			s.vp.size = vsz
		# The last slot always holds the view that covers the most screen (the portal you
		# are about to walk through), so it stays sharp even on "Fast".
		slots[MAX_SLOTS - 1].vp.size = full_sz.max(Vector2i(64, 64))
	var cam_t := main_cam.global_transform
	var cam_pos := cam_t.origin
	var frustum := main_cam.get_frustum()
	if not _frustum_checked:
		_frustum_checked = true
		var probe := cam_pos - cam_t.basis.z * 5.0
		var overs := 0
		for pl in frustum:
			if pl.is_point_over(probe):
				overs += 1
		_over_is_outside = overs < 3

	for p in portals:
		p.clear_views()
		p.near_update(cam_pos)
	_update_body_clone(cam_pos)
	_update_flashlight(cam_t)

	# Best-first: always render the candidate view that covers the most screen. A view's
	# children (portals seen through it) become candidates once it has a slot.
	# Slots are handed out from the last one down. SubViewports render in tree order, so a
	# view seen through another one renders first and its parent samples this frame's
	# image rather than last frame's.
	var used := 0
	var cands := []
	_add_candidates(cands, null, main_cam, frustum, Rect2(0.0, 0.0, 1.0, 1.0))
	while used < MAX_SLOTS and not cands.is_empty():
		var bi := 0
		for i in range(1, cands.size()):
			if cands[i][0] > cands[bi][0]:
				bi = i
		var c: Array = cands[bi]
		cands.remove_at(bi)
		var p = c[1]
		var parent = c[2]
		if p.view_count >= Portal.MAX_VIEWS:
			continue
		var s: Slot = slots[MAX_SLOTS - 1 - used]
		used += 1
		var parent_xf: Transform3D = cam_t if parent == null else parent.cam.global_transform
		_activate(s, p, p.link() * parent_xf, parent == null)
		s.depth = 1 if parent == null else parent.depth + 1
		s.rect = c[3]
		p.add_view(0 if parent == null else parent.id, s.vp.get_texture())
		if s.depth < MAX_DEPTH:
			_add_candidates(cands, s, s.cam, s.cam.get_frustum(), s.rect)

	stats_active = used
	_update_clones()
	_update_audio(cam_pos)
	for i in range(0, MAX_SLOTS - used):
		var s: Slot = slots[i]
		if s.active:
			s.active = false
			s.portal = null
			s.vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
			clip_img.set_pixel(s.id, 0, Color(0.0, 0.0, 0.0, -1.0))
	clip_tex.update(clip_img)


## Adds the portals visible from `cam` (the main camera, or the camera of `parent`) whose
## screen rectangle overlaps `rect`, the part of the screen the parent view covers.
func _add_candidates(cands: Array, parent, cam: Camera3D, frustum: Array, rect: Rect2) -> void:
	var origin := cam.global_transform.origin
	for p in portals:
		if not p.can_render or p.target == null or p.mat == null:
			continue
		if parent != null:
			var ex = parent.portal.target
			# the exit itself and anything behind it is clipped away in that view
			if p == ex or ex.signed_dist(p.center()) < 0.02:
				continue
		if _score(p, origin, frustum, parent == null) <= 0.0:
			continue
		var r := _screen_rect(cam, p).intersection(rect)
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			continue
		cands.append([r.size.x * r.size.y, p, parent, r])


func _activate(s: Slot, p, xform: Transform3D, from_main: bool) -> void:
	s.portal = p
	s.active = true
	s.cam.global_transform = xform.orthonormalized()
	s.cam.fov = main_cam.fov
	s.cam.near = main_cam.near
	s.cam.far = main_cam.far
	var mask: int = p.cam_layers
	if from_main and p == _body_portal:
		# this camera sits inside the copy of the player's body at the exit
		mask &= ~G.VL_BODY_CLONE
	s.cam.cull_mask = mask | (s.id << 8)
	s.vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var ex = p.target
	var n: Vector3 = ex.normal()
	clip_img.set_pixel(s.id, 0, Color(n.x, n.y, n.z, n.dot(ex.center()) + 0.002))


func _outside(pl: Plane, pt: Vector3) -> bool:
	return pl.is_point_over(pt) == _over_is_outside


func _score(p, cam_pos: Vector3, frustum: Array, occl: bool) -> float:
	var sd: float = p.signed_dist(cam_pos)
	if sd < 0.0:
		return 0.0
	var cs: Array = p.corners(1.0)
	# Skip the near and far planes (indices 0 and 1). When the camera is closer to the
	# portal than its near distance, every corner is behind the near plane even though the
	# portal fills the screen, and culling it here made the doorway flash dark right
	# before stepping through.
	for i in range(2, frustum.size()):
		var pl: Plane = frustum[i]
		var all_out := true
		for c in cs:
			if not _outside(pl, c):
				all_out = false
				break
		if all_out:
			return 0.0
	var lp: Vector3 = p.to_local_p(cam_pos)
	var cl := Vector3(clampf(lp.x, -p.size.x * 0.5, p.size.x * 0.5), clampf(lp.y, -p.size.y * 0.5, p.size.y * 0.5), 0.0)
	var dist := lp.distance_to(cl)
	if dist > MAX_DIST:
		return 0.0
	if occl and dist > 0.7 and not _ray_visible(cam_pos, p):
		return 0.0
	return p.size.x * p.size.y / maxf(dist * dist, 0.05)


func _ray_visible(from: Vector3, p) -> bool:
	var space := main_cam.get_world_3d().direct_space_state
	var pts: Array = [p.center()]
	pts.append_array(p.corners(0.8))
	pts.append_array(p.corners(0.4))
	for t in pts:
		var q := PhysicsRayQueryParameters3D.create(from, t, G.PL_WORLD)
		var hit := space.intersect_ray(q)
		if hit.is_empty() or (hit.position as Vector3).distance_to(t) < 0.05:
			return true
	return false


## The portal's bounding rectangle on screen in 0..1 coordinates. Corners behind the
## camera are clipped against a plane just in front of it instead of giving up.
func _screen_rect(cam: Camera3D, p) -> Rect2:
	var full := Rect2(0.0, 0.0, 1.0, 1.0)
	var ct := cam.global_transform
	var le: Vector3 = p.to_local_p(ct.origin)
	if le.z >= 0.0 and le.z < 0.1 and absf(le.x) < p.size.x * 0.5 + 0.05 and absf(le.y) < p.size.y * 0.5 + 0.05 			and (-ct.basis.z).dot(p.normal()) < 0.0:
		return full
	var inv := ct.affine_inverse()
	var vs := []
	for c in p.corners(1.0):
		vs.append(inv * c)
	var vsz := cam.get_viewport().get_visible_rect().size
	var zn := -0.0001
	var r := Rect2()
	var first := true
	for i in 4:
		var a: Vector3 = vs[i]
		var b: Vector3 = vs[(i + 1) % 4]
		var pts := []
		if a.z < zn:
			pts.append(a)
		if (a.z < zn) != (b.z < zn):
			pts.append(a.lerp(b, (zn - a.z) / (b.z - a.z)))
		for q in pts:
			var sp: Vector2 = cam.unproject_position(ct * q) / vsz
			if first:
				r = Rect2(sp, Vector2.ZERO)
				first = false
			else:
				r = r.expand(sp)
	if first:
		return Rect2()
	return r.intersection(full)


# --- Copies of things that are half-way through a portal ----------------------------
# The part of a prop (or of the player's body) that pokes through a portal is drawn by a
# copy at the exit. The real object is cut at the entry plane and the copy at the exit
# plane (world shader `obj_clip`), so neither shows up on the wrong side of a door.

var _clones := {}
var _clipped := {}
var _body_portal = null
var _body_clone: Node3D = null
var _body_clone_head: Node3D = null


func _plane_of(p) -> Vector4:
	var n: Vector3 = p.normal()
	return Vector4(n.x, n.y, n.z, n.dot(p.center()))


func _set_clip(root: Node, plane: Vector4) -> void:
	for c in root.get_children():
		if c is GeometryInstance3D:
			(c as GeometryInstance3D).set_instance_shader_parameter("obj_clip", plane)
		if c.get_child_count() > 0:
			_set_clip(c, plane)


## Radius of a sphere around the body's centre that contains all of its meshes.
func body_radius(rb: RigidBody3D) -> float:
	if rb.has_meta("portal_r"):
		return rb.get_meta("portal_r")
	var r := 0.2
	for c in rb.get_children():
		if c is MeshInstance3D and c.mesh:
			var bb: AABB = (c.transform * c.mesh.get_aabb())
			r = maxf(r, maxf(bb.position.abs().length(), bb.end.abs().length()))
	rb.set_meta("portal_r", r)
	return r


func _update_clones() -> void:
	var used := {}
	var clip_now := {}
	for b in get_tree().get_nodes_in_group("travelers"):
		var rb := b as RigidBody3D
		if rb == null or not rb.is_inside_tree():
			continue
		var bid := rb.get_instance_id()
		if rb.sleeping:
			# keep whatever clone and cut a resting body already has
			for k in _clones.keys():
				if (k as String).begins_with("%d_" % bid):
					used[k] = true
			if _clipped.has(bid):
				clip_now[bid] = _clipped[bid]
			continue
		var pos := rb.global_position
		var r := body_radius(rb)
		for i in portals.size():
			var p = portals[i]
			if not p.can_teleport or p.target == null:
				continue
			var sd: float = p.signed_dist(pos)
			if sd < 0.0 or sd > r:
				continue
			var lp: Vector3 = p.to_local_p(pos)
			if absf(lp.x) > p.size.x * 0.5 + r or absf(lp.y) > p.size.y * 0.5 + r:
				continue
			var key := "%d_%d" % [bid, i]
			var c: Node3D = _clones.get(key)
			if c == null:
				c = _make_clone(rb)
				_set_clip(c, _plane_of(p.target))
				_clones[key] = c
			c.global_transform = p.link() * rb.global_transform
			used[key] = true
			# only cut the real body when it is actually going through the opening
			if absf(lp.x) <= p.size.x * 0.5 and absf(lp.y) <= p.size.y * 0.5:
				var plane := _plane_of(p)
				if not _clipped.has(bid) or _clipped[bid][1] != plane:
					_set_clip(rb, plane)
				clip_now[bid] = [rb, plane]
			break
	for k in _clones.keys():
		if not used.has(k):
			var c = _clones[k]
			if is_instance_valid(c):
				c.queue_free()
			_clones.erase(k)
	for bid in _clipped.keys():
		if not clip_now.has(bid):
			var rb = _clipped[bid][0]
			if is_instance_valid(rb):
				_set_clip(rb, Vector4.ZERO)
	_clipped = clip_now


func _make_clone(rb: RigidBody3D) -> Node3D:
	var n := Node3D.new()
	add_child(n)
	for c in rb.get_children():
		if c is MeshInstance3D:
			var m := MeshInstance3D.new()
			m.mesh = c.mesh
			m.material_override = c.material_override
			m.transform = c.transform
			m.layers = c.layers
			n.add_child(m)
	return n


## The portal the player's body is currently poking through (eye in front of it, some of
## the body behind it), or null.
func _find_body_portal(eye: Vector3):
	var pl = G.player
	if pl == null or pl.body_vis == null:
		return null
	var top := eye + Vector3.UP * 0.35
	var bot: Vector3 = pl.global_position
	for p in portals:
		if not p.can_teleport or p.target == null or p.signed_dist(eye) < 0.0:
			continue
		var n: Vector3 = p.normal()
		var side := BODY_REACH * sqrt(maxf(0.0, 1.0 - n.y * n.y))
		if minf(p.signed_dist(top), p.signed_dist(bot)) - side >= 0.0:
			continue
		var a: Vector3 = p.to_local_p(top)
		var b: Vector3 = p.to_local_p(bot)
		var hx: float = p.size.x * 0.5
		var hy: float = p.size.y * 0.5
		if minf(a.x, b.x) > hx or maxf(a.x, b.x) < -hx or minf(a.y, b.y) > hy or maxf(a.y, b.y) < -hy:
			continue
		return p
	return null


func _update_body_clone(eye: Vector3) -> void:
	var p = _find_body_portal(eye)
	if p != _body_portal:
		_body_portal = p
		if _body_clone != null:
			_body_clone.queue_free()
			_body_clone = null
			_body_clone_head = null
		var body: Node3D = G.player.body_vis if G.player else null
		if body != null:
			_set_clip(body, Vector4.ZERO if p == null else _plane_of(p))
			if p != null:
				_body_clone = body.duplicate() as Node3D
				add_child(_body_clone)
				_set_layers(_body_clone, G.VL_BODY_CLONE)
				_set_clip(_body_clone, _plane_of(p.target))
				_body_clone_head = _body_clone.get_child(G.player.head_vis.get_index())
	if _body_clone != null:
		_body_clone.global_transform = p.link() * G.player.body_vis.global_transform
		_body_clone_head.transform = G.player.head_vis.transform


func _set_layers(root: Node, layers: int) -> void:
	for c in root.get_children():
		if c is VisualInstance3D:
			(c as VisualInstance3D).layers = layers
		if c.get_child_count() > 0:
			_set_layers(c, layers)


# --- The flashlight shining through a portal -----------------------------------------
# A copy of the flashlight on the far side lights the room you are looking into. It
# fades in over the last couple of metres, so it is at full strength at the moment you
# step through and the real flashlight takes over.

const FLASH_REACH := 2.5
var _flash_clone: SpotLight3D = null


func _update_flashlight(cam_t: Transform3D) -> void:
	var fl: SpotLight3D = G.player.flashlight if G.player else null
	var best = null
	var best_d := INF
	if fl != null and fl.is_visible_in_tree():
		var fwd := -cam_t.basis.z
		for p in portals:
			if not p.can_teleport or p.target == null:
				continue
			var sd: float = p.signed_dist(cam_t.origin)
			if sd < 0.0 or sd > FLASH_REACH or fwd.dot(-p.normal()) < 0.1:
				continue
			var lp: Vector3 = p.to_local_p(cam_t.origin)
			if absf(lp.x) > p.size.x * 0.5 + 1.0 or absf(lp.y) > p.size.y * 0.5 + 1.5:
				continue
			if sd < best_d:
				best_d = sd
				best = p
	if best == null:
		if _flash_clone != null:
			_flash_clone.visible = false
		return
	if _flash_clone == null:
		_flash_clone = SpotLight3D.new()
		add_child(_flash_clone)
	# Start the copy where its beam comes out of the exit, so nothing behind the exit (the
	# wardrobe's back panel, say) can shade it.
	var xf: Transform3D = best.link() * fl.global_transform
	var ex = best.target
	var axis := -xf.basis.z
	var into: float = axis.dot(ex.normal())
	var sd: float = ex.signed_dist(xf.origin)
	var moved := 0.0
	if sd < 0.0:
		if into < 0.1:
			_flash_clone.visible = false
			return
		moved = -sd / into
		xf.origin += axis * moved
	_flash_clone.spot_range = maxf(fl.spot_range - moved, 0.5)
	_flash_clone.spot_angle = fl.spot_angle
	_flash_clone.spot_attenuation = fl.spot_attenuation
	_flash_clone.spot_angle_attenuation = fl.spot_angle_attenuation
	_flash_clone.light_color = fl.light_color
	_flash_clone.shadow_enabled = fl.shadow_enabled
	_flash_clone.light_energy = fl.light_energy * (1.0 - smoothstep(0.6, FLASH_REACH, best_d))
	_flash_clone.global_transform = xf
	_flash_clone.visible = true


# --- Sounds heard through portals ----------------------------------------------------
# Looping positional sounds (group "portal_audio": the clock, the birds, music boxes) also
# play from where they appear through a portal when that is closer than the real thing,
# so stepping through a portal doesn't suddenly switch a sound on or off.

var _audio_proxies := {}


func _update_audio(listener: Vector3) -> void:
	var live := {}
	for n in get_tree().get_nodes_in_group("portal_audio"):
		var src := n as AudioStreamPlayer3D
		if src == null or not src.is_inside_tree() or not src.playing:
			continue
		var sp := src.global_position
		var best_d := listener.distance_to(sp)
		var best_pos := Vector3.ZERO
		var found := false
		for p in portals:
			if not p.can_teleport or p.target == null or p.signed_dist(listener) < 0.0:
				continue
			if p.target.signed_dist(sp) < 0.0:
				continue
			var img: Vector3 = p.link().affine_inverse() * sp
			var d := listener.distance_to(img)
			if d < best_d and d < src.max_distance:
				best_d = d
				best_pos = img
				found = true
		if not found:
			continue
		var id := src.get_instance_id()
		var px: AudioStreamPlayer3D = _audio_proxies.get(id)
		if px == null:
			px = AudioStreamPlayer3D.new()
			px.stream = src.stream
			px.volume_db = src.volume_db
			px.unit_size = src.unit_size
			px.max_db = src.max_db
			px.max_distance = src.max_distance
			px.pitch_scale = src.pitch_scale
			px.attenuation_model = src.attenuation_model
			px.attenuation_filter_cutoff_hz = src.attenuation_filter_cutoff_hz
			px.attenuation_filter_db = src.attenuation_filter_db
			px.panning_strength = src.panning_strength
			px.bus = src.bus
			add_child(px)
			_audio_proxies[id] = px
		px.global_position = best_pos
		if px.stream != src.stream:
			px.stream = src.stream
		if not px.playing:
			px.play(src.get_playback_position())
		live[id] = true
	for id in _audio_proxies.keys():
		if not live.has(id):
			var px: AudioStreamPlayer3D = _audio_proxies[id]
			if is_instance_valid(px):
				px.queue_free()
			_audio_proxies.erase(id)


# --- Teleporting -----------------------------------------------------------------

## True when a ball of radius `rad` at `pos` would sit behind a walkable portal, in its
## doorway, where nothing would ever carry it through.
func behind_portal(pos: Vector3, rad: float) -> bool:
	for p in portals:
		if not p.can_teleport or p.target == null:
			continue
		var lp: Vector3 = p.to_local_p(pos)
		if lp.z < 0.0 and lp.z > -1.0 and absf(lp.x) < p.size.x * 0.5 + rad and absf(lp.y) < p.size.y * 0.5 + rad:
			return true
	return false


## True when `feet` have dropped into a portal set into the floor (not just jumping over it).
func in_floor_portal(feet: Vector3) -> bool:
	for p in portals:
		if not p.can_teleport or p.target == null or p.normal().y < 0.7:
			continue
		var lp: Vector3 = p.to_local_p(feet)
		if lp.z < 0.05 and lp.z > -2.0 and absf(lp.x) < p.size.x * 0.5 and absf(lp.y) < p.size.y * 0.5:
			return true
	return false


func check_player_cross(prev_eye: Vector3, eye: Vector3) -> void:
	for p in portals:
		if p.can_teleport and p.target != null and p.crossed(prev_eye, eye):
			var L: Transform3D = p.link()
			G.player.portal_teleport(L, p, p.target)
			if p.on_teleport.is_valid():
				p.on_teleport.call(G.player)
			return


func _physics_process(_delta: float) -> void:
	var next := {}
	for b in get_tree().get_nodes_in_group("travelers"):
		var rb := b as RigidBody3D
		if rb == null or not rb.is_inside_tree():
			continue
		var id := rb.get_instance_id()
		var pos := rb.global_position
		if _prev_pos.has(id):
			var prev: Vector3 = _prev_pos[id]
			for p in portals:
				if p.can_teleport and p.target != null and p.crossed(prev, pos):
					teleport_body(rb, p)
					pos = rb.global_position
					break
		next[id] = pos
	_prev_pos = next


func teleport_body(rb: RigidBody3D, p) -> void:
	var L: Transform3D = p.link()
	rb.global_transform = L * rb.global_transform
	rb.linear_velocity = L.basis * rb.linear_velocity
	rb.angular_velocity = L.basis * rb.angular_velocity
	if G.player and G.player.held == rb:
		G.player.held_link = L * G.player.held_link
	if p.on_teleport.is_valid():
		p.on_teleport.call(rb)
	_unstick(rb, p.target)
	if G.world:
		G.world.update_body_layers(rb)


## A body that comes out of a portal into something solid (out of the painting, into the
## console table under it) is moved clear along the exit normal, instead of being shot out
## by the physics engine's depenetration, which can send it through a wall.
func _unstick(rb: RigidBody3D, exit) -> void:
	var kc := KinematicCollision3D.new()
	if not rb.test_move(rb.global_transform, Vector3.ZERO, kc, 0.001, true) or kc.get_travel().length() < 0.03:
		return
	var n: Vector3 = exit.normal()
	for k in range(1, 31):
		var t := rb.global_transform.translated(n * (0.02 * k))
		if not rb.test_move(t, Vector3.ZERO, kc, 0.001, true) or kc.get_travel().length() < 0.005:
			rb.global_transform = t
			return


## Forget where a body was last tick (after it was moved by hand), so the jump is not
## mistaken for walking through a portal.
func reset_body(rb: RigidBody3D) -> void:
	_prev_pos.erase(rb.get_instance_id())


# --- Raycasts through portals ---------------------------------------------------------

func portal_raycast(from: Vector3, dir: Vector3, max_len: float, mask: int, exclude: Array) -> Dictionary:
	var space := main_cam.get_world_3d().direct_space_state
	var o := from
	var d := dir.normalized()
	var remaining := max_len
	var link := Transform3D.IDENTITY
	var travelled := 0.0
	var exit = null
	for i in 4:
		var q := PhysicsRayQueryParameters3D.create(o, o + d * remaining, mask, exclude)
		var hit := space.intersect_ray(q)
		var hit_t := remaining
		if not hit.is_empty():
			hit_t = o.distance_to(hit.position)
		var bp = null
		var bt := hit_t
		for p in portals:
			if not p.can_teleport or p.target == null:
				continue
			var t: float = p.ray_hit(o, d, bt)
			if t >= 0.0 and t < bt:
				bt = t
				bp = p
		if bp != null:
			var L: Transform3D = bp.link()
			o = L * (o + d * bt)
			d = (L.basis * d).normalized()
			remaining -= bt
			travelled += bt
			link = L * link
			exit = bp.target
			o += d * 0.002
			continue
		return {
			"hit": not hit.is_empty(),
			"collider": hit.get("collider"),
			"position": hit.get("position", o + d * remaining),
			"normal": hit.get("normal", Vector3.ZERO),
			"dir": d,
			"link": link,
			"exit": exit,
			"distance": travelled + hit_t,
		}
	return {"hit": false, "collider": null, "position": o, "normal": Vector3.ZERO, "dir": d, "link": link, "exit": exit, "distance": max_len}
