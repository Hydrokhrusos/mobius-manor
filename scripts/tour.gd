extends Node
## Debug tour (run with `-- --tour --shots=<dir>`): takes screenshots at fixed viewpoints
## and runs scripted walks through portals, printing whether each ends up where expected.

var shots_dir := "user://shots"
var only := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots_dir = a.substr(8)
		elif a.begins_with("--only="):
			only = a.substr(7)
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


func _find_interactable(prompt: String) -> Interactable:
	for n in get_tree().get_root().find_children("*", "StaticBody3D", true, false):
		if n is Interactable and n.prompt == prompt:
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
	var btn := _find_interactable("Press the big red button")
	var before: int = G.world.spawned_root.get_child_count()
	btn.interact(G.player)
	await get_tree().create_timer(1.5).timeout
	print("INTERACT ball machine spawned %d balls" % (G.world.spawned_root.get_child_count() - before))
	var sw := _find_interactable("Flip light switch")
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
