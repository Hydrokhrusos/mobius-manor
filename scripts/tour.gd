extends Node
## Debug tour (run with `-- --tour --shots=<dir>`): takes screenshots at fixed viewpoints
## and runs scripted walks through portals, printing whether each ends up where expected.

var shots_dir := "user://shots"
var only := ""
var filter := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots_dir = a.substr(8)
		elif a.begins_with("--only="):
			only = a.substr(7)
		elif a.begins_with("--filter="):
			filter = a.substr(9)
	DirAccess.make_dir_recursive_absolute(shots_dir)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(shots_dir.path_join(shot_name + ".png"))
	print("SHOT %s area=%s pos=%s fps=%d views=%d" % [shot_name, G.world.area_at(G.player.global_position), G.player.global_position, Engine.get_frames_per_second(), G.portal_manager.stats_active])


func _run() -> void:
	if only == "title":
		await _frames(90)
		await _shot("00_title")
		G.hud.start_game(false)
		await _frames(10)
		G.hud.set_paused(true)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		await _frames(10)
		await _shot("00_pause")
		get_tree().quit()
		return
	if only == "clone":
		await _clone_test()
		get_tree().quit()
		return
	if only == "seam":
		await _seam_test()
		get_tree().quit()
		return
	if only == "walkseam":
		await _walk_seam_test()
		get_tree().quit()
		return
	if only == "oob":
		await _oob_test()
		get_tree().quit()
		return
	G.hud.start_game(false)
	G.player.debug_active = true
	await _frames(20)
	var O := Vector3(-60, 0, 0)
	var views := [
		["01_foyer_start", Vector3(0, 0.05, -2.2), PI, 0.0],
		["02_foyer_painting", Vector3(1.5, 0.05, 0.0), PI * 0.5, 0.12],
		["03_foyer_north", Vector3(0, 0.05, 2.5), 0.0, 0.0],
		["04_bedroom_wardrobe", Vector3(6.8, 0.05, 0.4), -PI * 0.5, 0.0],
		["05_hall_entrance", Vector3(70.0, 0.05, 18.0), 0.0, 0.05],
		["06_hall_frame_back", Vector3(70.4, 0.05, -1.5), PI, 0.0],
		["07_hall_frame_side", Vector3(66.5, 0.05, 4.5), -PI * 0.5, 0.0],
		["08_greenhouse", Vector3(0.0, 0.05, 1075.5), 0.0, 0.05],
		["09_repeat_east", Vector3(-4.5, 0.05, -10.2), -PI * 0.5, 0.0],
		["10_repeat_west", Vector3(-1.0, 0.05, -11.2), PI * 0.5, 0.0],
		["11_stairs_L2_up", O + Vector3(1.4, 6.05, 2.2), 0.0, 0.1],
		["12_stairs_flightA_down", O + Vector3(1.25, 1.55, -3.0), PI, -0.25],
		["13_stairs_L1", O + Vector3(2.2, 3.05, -6.5), 0.0, 0.1],
		["14_attic_trapdoor", Vector3(0.4, 0.05, -57.6), 0.0, -0.75],
		["15_hallway_window", Vector3(2.5, 0.05, -5.9), -PI * 0.5, 0.0],
		["16_hallway_west", Vector3(-6.0, 0.05, -5.9), PI * 0.5, 0.0],
		["17_hall_high_window", Vector3(76.0, 0.05, 0.0), -PI * 0.5, 0.5],
		["18_hall_toys", Vector3(68.0, 0.05, -2.0), 2.4, -0.1],
		["19_greenhouse_door", Vector3(0.6, 0.05, 1066.5), 0.0, 0.05],
		["20_hallway_east", Vector3(-10.0, 0.05, -5.9), -PI * 0.5, 0.0],
		["21_painting_close", Vector3(-2.2, 0.05, 0.3), PI * 0.5, 0.25],
		["22_attic_overview", Vector3(3.5, 0.05, -56.8), 0.75, -0.05],
		["23_trapdoor_down", Vector3(0.0, 0.05, -58.3), 0.0, -1.1],
	]
	for v in views:
		if only != "" and not (v[0] as String).contains(only):
			continue
		G.player.place(v[1], v[2], v[3])
		await _frames(30)
		await _shot(v[0])
	if only == "" or only == "walk":
		await _walk("w1_wardrobe", Vector3(8.6, 0.05, 0.0), -PI * 0.5, 1.4, "The Great Hall")
		await _walk("w2_frame_front", Vector3(70.0, 0.05, 6.5), 0.0, 1.2, "The Greenhouse")
		await _walk("w3_front_door", Vector3(0, 0.05, 2.6), PI, 1.0, "The Great Hall")
		await _walk("w4_repeat", Vector3(-1.5, 0.05, -10.8), -PI * 0.5, 1.0, "The Repeating Room")
		await _walk("w5_stairs_up", O + Vector3(1.25, 6.05, 2.0), 0.0, 1.2, "The Endless Stairwell")
		await _walk("w6_hall_to_stairs", Vector3(-10.5, 0.05, -5.9), PI * 0.5, 1.0, "The Endless Stairwell")
		await _walk("w7_attic_trapdoor", Vector3(0.0, 0.05, -57.9), 0.0, 0.7, "The Foyer", 120)
		await _walk("w8_stairs_down", O + Vector3(1.25, 1.0, -2.0), PI, 1.5, "The Endless Stairwell")
		await _walk("w9_greenhouse_back", Vector3(0.0, 0.05, 1065.0), 0.0, 1.0, "The Great Hall")
		await _walk("w10_stairs_climb", O + Vector3(1.25, 6.05, 2.0), 0.0, 1.9, "The Endless Stairwell")
		await _throw_test()
		await _interact_test()
	if only == "" or only == "perf":
		await _perf()
	print("TOUR DONE")
	get_tree().quit()


func _walk(walk_name: String, pos: Vector3, yaw: float, secs: float, expect: String, settle := 40) -> void:
	G.player.place(pos, yaw, 0.0)
	var f0 := G.floor_number
	await _frames(5)
	G.player.debug_input = Vector2(0, -1)
	var t := 0.0
	while t < secs:
		await get_tree().process_frame
		t += get_process_delta_time()
	G.player.debug_input = Vector2.ZERO
	await _frames(settle)
	var a: String = G.world.area_at(G.player.global_position)
	print("WALK %s -> %s (expected %s) %s pos=%s floor %d->%d" % [walk_name, a, expect, "OK" if a == expect else "FAIL", G.player.global_position, f0, G.floor_number])
	await _shot(walk_name)


func _throw_test() -> void:
	# throw a ball east inside the repeating room; it should come back in through the west door
	G.player.place(Vector3(-3.0, 0.05, -8.6), -PI * 0.5, 0.0)
	await _frames(5)
	var b := Props.make("ball")
	G.world.add_spawned(b, Transform3D(Basis.IDENTITY, Vector3(-1.5, 1.2, -10.8)))
	b.linear_velocity = Vector3(8.0, 0.0, 0.0)
	b.gravity_scale = 0.0
	await get_tree().create_timer(0.45).timeout
	print("THROW ball x=%.2f (should have wrapped to the west side, x < -1.5) %s" % [b.global_position.x, "OK" if b.global_position.x < -1.5 else "FAIL"])
	b.queue_free()


func _find_prop(kind: String) -> Prop:
	for b in get_tree().get_nodes_in_group("props"):
		if b is Prop and b.kind == kind:
			return b
	return null


func _find_interactable(node_name: String) -> Interactable:
	for n in get_tree().get_root().find_children(node_name, "StaticBody3D", true, false):
		if n is Interactable:
			return n
	return null


func _interact_test() -> void:
	var mb := _find_prop("music_box")
	mb.interact(G.player)
	await _frames(5)
	print("INTERACT music box playing: %s" % mb.audio.playing)
	mb.interact(G.player)
	var lamp := _find_prop("lamp")
	lamp.interact(G.player)
	print("INTERACT lamp light visible after toggle: %s (expected false)" % lamp.light.visible)
	lamp.interact(G.player)
	var btn := _find_interactable("BigRedButton")
	var before: int = G.world.spawned_root.get_child_count()
	btn.interact(G.player)
	await get_tree().create_timer(1.5).timeout
	print("INTERACT ball machine spawned %d balls" % (G.world.spawned_root.get_child_count() - before))
	var sw := _find_interactable("LightSwitch")
	sw.interact(G.player)
	sw.interact(G.player)
	G.player.place(Vector3(70.0, 0.05, -2.0), PI, 0.0)
	await _frames(5)
	for k in Player.SPAWN_KINDS:
		G.player.spawn(k)
		await _frames(2)
	print("INTERACT spawned all kinds, spawned count now %d" % G.world.spawned_root.get_child_count())
	for i in 3:
		G.cycle_gravity()
		await _frames(20)
	print("INTERACT gravity mode back to %s" % G.GRAVITY_MODES[G.gravity_mode])
	G.toggle_slowmo()
	await _frames(10)
	G.toggle_slowmo()
	var d := _find_prop("duck")
	d.on_grabbed()
	print("INTERACT ducks found %d / %d" % [G.ducks_found, G.ducks_total])
	var cube := _find_prop("cube")
	cube.paint(Color.RED)
	# the key hints under the crosshair
	var lamp_p: Prop = await _oob_grab("lamp", Vector3(0, 0.05, -2.2), PI)
	if lamp_p:
		G.player.drop()
		lamp_p.freeze = true
		await _frames(3)
		print("INTERACT hint aiming at a lamp: '%s'" % G.hud.hint.text)
		G.player.try_grab()
		await _frames(3)
		print("INTERACT hint holding the lamp: '%s'" % G.hud.hint.text)
		G.player.drop()
	G.world.clear_spawned()
	await _frames(5)
	print("INTERACT cleared, spawned count %d" % G.world.spawned_root.get_child_count())


func _clone_test() -> void:
	# a crate half-way through the front door, seen from the foyer and from the hall
	G.hud.start_game(false)
	G.player.debug_active = true
	var c := Props.make("crate")
	G.world.add_spawned(c, Transform3D(Basis.IDENTITY, Vector3(0.3, 0.31, 3.95)))
	c.gravity_scale = 0.0
	c.freeze = true
	await _frames(5)
	c.freeze = false
	c.sleeping = false
	c.linear_velocity = Vector3.ZERO
	G.player.place(Vector3(0.5, 0.05, 1.5), PI, -0.2)
	await _frames(30)
	await _shot("c1_crate_foyer_side")
	G.player.place(Vector3(69.6, 0.05, 1.8), PI, -0.25)
	await _frames(30)
	print("CLONES active: %d" % G.portal_manager._clones.size())
	await _shot("c2_crate_hall_side")


func _grab() -> Image:
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


## Renders the frame just before the eye crosses each walkable portal and the frame just
## after the teleport, and reports how different they are. A seamless portal gives two
## near-identical frames (the camera only moves by 2 * eps).
func _seam_test() -> void:
	G.hud.start_game(false)
	G.player.debug_active = true
	G.hud.visible = false
	await _frames(30)
	var dir := shots_dir.path_join("seam")
	DirAccess.make_dir_recursive_absolute(dir)
	var eps := 0.004
	# [yaw offset, pitch, sideways offset along the portal]
	var looks := [[0.0, 0.0, 0.0], [0.55, 0.0, 0.0], [-0.55, 0.0, 0.0], [0.0, -0.35, 0.0], [0.0, 0.3, 0.0], [0.4, -0.1, 0.3]]
	var worst := []
	for p in G.portal_manager.portals:
		if not p.can_teleport or p.target == null:
			continue
		var n: Vector3 = p.normal()
		if absf(n.y) > 0.5:
			continue
		var base_yaw := atan2(n.x, n.z)
		for lk in looks:
			var tag := "%s_y%+.2f_p%+.2f_s%+.1f" % [p.name, lk[0], lk[1], lk[2]]
			if filter != "" and not tag.contains(filter):
				continue
			# keep the body (radius 0.3) inside the opening, as it would be when walking
			var side: float = clampf(lk[2], -(p.size.x * 0.5 - 0.31), p.size.x * 0.5 - 0.31)
			var foot: Vector3 = p.center() - Vector3(0.0, p.size.y * 0.5 - 0.001, 0.0) + p.xf().basis.x * side
			G.player.place(foot + n * eps, base_yaw + lk[0], lk[1])
			await _frames(12)
			var a := await _grab()
			var eye_a: Vector3 = G.player.camera.global_position
			G.player.place(foot - n * eps, base_yaw + lk[0], lk[1])
			G.portal_manager.check_player_cross(eye_a, G.player.camera.global_position)
			await _frames(12)
			var b := await _grab()
			var r := _diff(a, b)
			print("SEAM %-34s mean=%.4f over8=%.2f%% over20=%.2f%%  -> %s" % [tag, r.mean, r.o8 * 100.0, r.o20 * 100.0, G.world.area_at(G.player.global_position)])
			worst.append([r.o8, tag])
			if r.o8 > 0.002:
				a.save_png(dir.path_join(tag + "_a.png"))
				b.save_png(dir.path_join(tag + "_b.png"))
				(r.img as Image).save_png(dir.path_join(tag + "_diff.png"))
	if filter == "" or filter == "Trapdoor":
		await _trapdoor_test()
	worst.sort_custom(func(x, y): return x[0] > y[0])
	var total := 0.0
	for w in worst:
		total += w[0]
	print("SEAM SUMMARY cases=%d mean_over8=%.3f%% worst=%s" % [worst.size(), total / maxf(worst.size(), 1) * 100.0, str(worst.slice(0, 6))])


## Walks through each portal and compares the last frame before the teleport with the
## first frame after it, as rendered while moving (catches views that lag a frame).
func _walk_seam_test() -> void:
	G.hud.start_game(false)
	G.player.debug_active = true
	G.hud.visible = false
	await _frames(30)
	var dir := shots_dir.path_join("walkseam")
	DirAccess.make_dir_recursive_absolute(dir)
	var total := 0.0
	var count := 0
	var worst := []
	for p in G.portal_manager.portals:
		if not p.can_teleport or p.target == null or absf(p.normal().y) > 0.5:
			continue
		var n: Vector3 = p.normal()
		var base_yaw := atan2(n.x, n.z)
		for lk in [[0.0, 0.0, false], [0.35, -0.2, false], [0.0, 0.0, true]]:
			var tag := "%s_y%+.2f_p%+.2f%s" % [p.name, lk[0], lk[1], "_torch" if lk[2] else ""]
			if filter != "" and not tag.contains(filter):
				continue
			G.player.flashlight.visible = lk[2]
			var foot: Vector3 = p.center() - Vector3(0.0, p.size.y * 0.5 - 0.001, 0.0) + n * 0.5
			G.player.place(foot, base_yaw + lk[0], lk[1])
			await _frames(20)
			G.player.debug_input = Vector2(0, -0.35)
			var prev_img: Image = null
			var prev2_img: Image = null
			var prev_pos: Vector3 = G.player.camera.global_position
			var done := false
			for i in 300:
				await RenderingServer.frame_post_draw
				var img := get_viewport().get_texture().get_image()
				var pos: Vector3 = G.player.camera.global_position
				if prev2_img != null and pos.distance_to(prev_pos) > 1.0:
					var r := _diff(prev_img, img)
					# the same measure for the two frames before, where nothing teleported
					var base := _diff(prev2_img, prev_img)
					print("WALKSEAM %-34s over8=%.2f%% over20=%.2f%%   (step before, no teleport: over8=%.2f%% over20=%.2f%%)" % [tag, r.o8 * 100.0, r.o20 * 100.0, base.o8 * 100.0, base.o20 * 100.0])
					total += r.o8 - base.o8
					count += 1
					worst.append([r.o8, tag])
					if r.o8 > 0.01:
						prev_img.save_png(dir.path_join(tag + "_a.png"))
						img.save_png(dir.path_join(tag + "_b.png"))
						(r.img as Image).save_png(dir.path_join(tag + "_diff.png"))
					done = true
					break
				prev2_img = prev_img
				prev_img = img
				prev_pos = pos
			G.player.debug_input = Vector2.ZERO
			if not done:
				print("WALKSEAM %-34s no teleport" % tag)
	G.player.flashlight.visible = false
	worst.sort_custom(func(x, y): return x[0] > y[0])
	print("WALKSEAM SUMMARY cases=%d mean over8 above the no-teleport step=%.3f%% worst=%s" % [count, total / maxf(count, 1) * 100.0, str(worst.slice(0, 6))])


## Tries to get props out of the house: holding them against walls, throwing them hard at
## walls, glass, floor and ceiling, and spawning them while hugging a wall.
var _oob_bad := 0
var _oob_total := 0


func _oob_test() -> void:
	G.hud.start_game(false)
	G.player.debug_active = true
	G.world.set("oob_recovery", false)
	await _frames(20)
	var bed := func(b: Vector3) -> bool: return b.x < 11.45 and b.y > -0.1 and b.y < 3.05 and absf(b.z) < 3.55
	var hall := func(b: Vector3) -> bool: return b.x < 6.06 and b.y > -0.1 and b.y < 3.05
	var foyer := func(b: Vector3) -> bool: return b.x > -4.06 and b.y > -0.1
	var gh := func(b: Vector3) -> bool: return b.z < 1077.15 and absf(b.x) < 7.15 and b.y < 4.55 and b.y > -0.1
	var great := func(b: Vector3) -> bool: return b.y > -0.1
	var attic := func(b: Vector3) -> bool: return G.world.area_at(b) == "The Attic" and b.y < 4.1
	# holding things against a wall while waving them about
	for k in ["domino", "book", "duck", "cube", "pin", "lamp", "crate", "chair", "beach_ball", "music_box", "ball"]:
		await _oob_hold(k, Vector3(9.6, 0.001, 2.0), -PI * 0.5, bed)
	# throwing hard
	for k in ["domino", "book", "duck", "cube", "pin", "music_box", "crate"]:
		for d in [0.35, 0.9]:
			for pt in [0.0, 0.45, -0.9]:
				await _oob_throw(k, Vector3(11.4 - 0.3 - d, 0.001, 1.5), -PI * 0.5, pt, bed, "bedroom wall d=%.2f pitch=%.2f" % [d, pt])
		await _oob_throw(k, Vector3(2.0, 0.001, 1077.1 - 0.65), 0.0 + PI, 0.1, gh, "greenhouse glass")
		await _oob_throw(k, Vector3(0.0, 0.001, 1069.0), PI, 1.35, gh, "greenhouse roof")
		await _oob_throw(k, Vector3(6.0 - 0.65, 0.001, -5.9), -PI * 0.5, 0.0, hall, "hallway window")
		await _oob_throw(k, Vector3(-3.0, 0.001, 0.0), PI * 0.5, 0.25, foyer, "foyer painting")
		await _oob_throw(k, Vector3(66.0, 0.001, -4.0), 0.0, -1.45, great, "great hall floor")
		await _oob_throw(k, Vector3(0.0, 0.001, -61.8), 0.0, 1.35, attic, "attic skylight")
	# spawning while hugging a wall
	for pt in [0.0, -0.75, -1.45]:
		for k in Player.SPAWN_KINDS:
			await _oob_spawn(k, Vector3(11.4 - 0.31, 0.001, 1.5), -PI * 0.5, pt, bed)
	print("OOB SUMMARY escaped %d / %d" % [_oob_bad, _oob_total])


func _oob_grab(kind: String, foot: Vector3, yaw: float) -> Prop:
	G.player.place(foot, yaw, 0.0)
	await _frames(3)
	var cam: Camera3D = G.player.camera
	var b := Props.make(kind)
	G.world.add_spawned(b, Transform3D(Basis(Vector3.UP, yaw), cam.global_position - cam.global_transform.basis.z * 1.2))
	b.gravity_scale = 0.0
	await _frames(3)
	G.player.try_grab()
	b.gravity_scale = 1.0
	if G.player.held != b:
		print("OOB could not grab %s" % kind)
		b.queue_free()
		return null
	return b


func _oob_check(b: Prop, inside: Callable, what: String) -> void:
	_oob_total += 1
	var ok: bool = is_instance_valid(b) and b.is_inside_tree() and inside.call(b.global_position)
	if not ok:
		_oob_bad += 1
		print("OOB ESCAPED %s -> %s" % [what, b.global_position if is_instance_valid(b) else "deleted"])
	if is_instance_valid(b):
		if G.player.held == b:
			G.player.drop()
		b.queue_free()


func _oob_hold(kind: String, foot: Vector3, yaw: float, inside: Callable) -> void:
	var b = await _oob_grab(kind, foot, yaw)
	if b == null:
		return
	G.player.hold_dist = 3.0
	G.player.debug_input = Vector2(0, -1)
	await get_tree().create_timer(0.7).timeout
	var t := 0.0
	while t < 2.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		G.player.pitch = -1.3 + 1.9 * (0.5 + 0.5 * sin(t * 5.0))
		G.player.yaw = yaw + 0.7 * sin(t * 3.3)
		G.player._apply_rot()
		if t > 1.0:
			Input.action_press("crouch")
	Input.action_release("crouch")
	G.player.debug_input = Vector2.ZERO
	G.player.drop()
	await get_tree().create_timer(1.0).timeout
	_oob_check(b, inside, "holding %s against a wall" % kind)


func _oob_throw(kind: String, foot: Vector3, yaw: float, pitch: float, inside: Callable, what: String) -> void:
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var b = await _oob_grab(kind, foot - fwd * 1.5, yaw)
	if b == null:
		return
	G.player.hold_dist = 1.0
	G.player.global_position = foot
	G.player.pitch = pitch
	G.player._apply_rot()
	await _frames(12)
	if G.player.held == b:
		G.player.throw_held()
	await get_tree().create_timer(1.3).timeout
	_oob_check(b, inside, "throwing %s at %s" % [kind, what])


func _oob_spawn(kind: String, foot: Vector3, yaw: float, pitch: float, inside: Callable) -> void:
	G.player.place(foot, yaw, pitch)
	await _frames(3)
	var before: int = G.world.spawned_root.get_child_count()
	G.player.spawn(kind)
	var kids: Array = G.world.spawned_root.get_children()
	if kids.size() == before:
		print("OOB spawn refused: %s hugging a wall, pitch %.2f" % [kind, pitch])
		return
	var b: Prop = kids[kids.size() - 1]
	await get_tree().create_timer(1.0).timeout
	_oob_check(b, inside, "spawning %s hugging a wall, pitch %.2f" % [kind, pitch])


## Falls through the attic trapdoor and measures how far the camera jumps (in the
## portal's frame of reference) on the frame it comes out of the painting.
func _trapdoor_test() -> void:
	var td = G.world.P["Trapdoor"]
	var painting = G.world.P["Painting"]
	# walk (and then sprint) in from the attic door, the way a player would
	for run in [[0.0, false], [0.0, true], [-0.6, false]]:
		G.player.place(Vector3(0.0, 0.05, -58.0), 0.0, run[0])
		await _frames(5)
		G.player.debug_input = Vector2(0, -1)
		if run[1]:
			Input.action_press("sprint")
		var prev: Vector3 = G.player.camera.global_position
		var jump := -1.0
		var normal_step := 0.0
		var bump := false
		var prev_h := 0.0
		for i in 400:
			await get_tree().process_frame
			var cur: Vector3 = G.player.camera.global_position
			var step := cur.distance_to(prev)
			if step > 1.0:
				jump = cur.distance_to(td.link() * prev)
				G.player.debug_input = Vector2.ZERO
				Input.action_release("sprint")
			elif jump < 0.0:
				normal_step = maxf(normal_step, step)
				var h := Vector2(G.player.velocity.x, G.player.velocity.z).length()
				if prev_h > 1.5 and h < prev_h * 0.3:
					bump = true
				prev_h = h
			prev = cur
		G.player.debug_input = Vector2.ZERO
		Input.action_release("sprint")
		var fwd: Vector3 = -G.player.global_transform.basis.z
		print("SEAM Trapdoor %s pitch %.1f: camera jump on exit=%.3f m (largest step while falling %.3f m), hit the lip=%s, facing room=%.2f -> %s" % [
			"sprint" if run[1] else "walk", run[0], jump, normal_step, bump, fwd.dot(painting.normal()), G.world.area_at(G.player.global_position)])
	# a running jump across the hole should clear it, not get caught by it
	G.player.place(Vector3(2.6, 0.001, -60.0), PI * 0.5, 0.0)
	await _frames(5)
	G.player.debug_input = Vector2(0, -1)
	Input.action_press("sprint")
	var jumped := false
	for i in 240:
		await get_tree().process_frame
		if not jumped and G.player.global_position.x < 1.05:
			Input.action_press("jump")
			jumped = true
		elif jumped:
			Input.action_release("jump")
		if G.player.global_position.x < -1.6:
			break
	G.player.debug_input = Vector2.ZERO
	Input.action_release("sprint")
	await _frames(30)
	var landed: Vector3 = G.player.global_position
	print("SEAM Trapdoor jump across: landed at x=%.2f in %s (%s)" % [landed.x, G.world.area_at(landed), "OK" if G.world.area_at(landed) == "The Attic" and landed.x < -0.8 else "FAIL"])


func _diff(full_a: Image, full_b: Image) -> Dictionary:
	var w := 480
	var h := 270
	var a := full_a.duplicate() as Image
	var b := full_b.duplicate() as Image
	a.resize(w, h, Image.INTERPOLATE_BILINEAR)
	b.resize(w, h, Image.INTERPOLATE_BILINEAR)
	var out := Image.create(w, h, false, Image.FORMAT_RGB8)
	var sum := 0.0
	var o8 := 0
	var o20 := 0
	for y in h:
		for x in w:
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			var d := maxf(absf(ca.r - cb.r), maxf(absf(ca.g - cb.g), absf(ca.b - cb.b)))
			sum += d
			if d > 0.08:
				o8 += 1
			if d > 0.2:
				o20 += 1
			var g := ca.get_luminance() * 0.35
			out.set_pixel(x, y, Color(minf(g + d * 4.0, 1.0), g, g))
	var n := float(w * h)
	return {"mean": sum / n, "o8": o8 / n, "o20": o20 / n, "img": out}


func _perf() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var O := Vector3(-60, 0, 0)
	var spots := [
		["foyer_front_door", Vector3(0, 0.05, -2.2), PI, 0.0],
		["hall_frame", Vector3(70.4, 0.05, -1.5), PI, 0.0],
		["hall_entrance", Vector3(70.0, 0.05, 18.0), 0.0, 0.05],
		["repeat_corner", Vector3(-4.5, 0.05, -10.2), -PI * 0.5, 0.0],
		["greenhouse", Vector3(0.0, 0.05, 1075.5), 0.0, 0.05],
		["stairs", O + Vector3(1.4, 6.05, 2.2), 0.0, 0.1],
	]
	for s in spots:
		G.player.place(s[1], s[2], s[3])
		await _frames(30)
		var t0 := Time.get_ticks_usec()
		var n := 0
		while Time.get_ticks_usec() - t0 < 1500000:
			await get_tree().process_frame
			n += 1
		var secs := (Time.get_ticks_usec() - t0) / 1000000.0
		print("PERF %s: %.0f fps (views=%d)" % [s[0], n / secs, G.portal_manager.stats_active])
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
