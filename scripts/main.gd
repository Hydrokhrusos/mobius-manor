extends Node3D
## Boots the game: input map, environment, world, player, portals and UI.

var env: Environment
var portal_env: Environment


func _ready() -> void:
	G.main = self
	_setup_input()
	_setup_env()
	var sfx := Sfx.new()
	sfx.name = "Sfx"
	add_child(sfx)
	G.sfx = sfx
	var world := World.new()
	world.name = "World"
	add_child(world)
	G.world = world
	world.build()
	var player := Player.new()
	player.name = "Player"
	add_child(player)
	G.player = player
	player.place(world.spawn_pos, world.spawn_yaw)
	var pm := PortalManager.new()
	pm.name = "Portals"
	add_child(pm)
	G.portal_manager = pm
	pm.setup(world.portals, player.camera, portal_env)
	var hud := Hud.new()
	hud.name = "Hud"
	add_child(hud)
	G.hud = hud
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tour"):
			var tour: Node = load("res://scripts/tour.gd").new()
			add_child(tour)
			break


func _key(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)


func _mouse(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var e := InputEventMouseButton.new()
	e.button_index = button
	InputMap.action_add_event(action, e)


func _setup_input() -> void:
	_key("move_forward", [KEY_W, KEY_UP])
	_key("move_back", [KEY_S, KEY_DOWN])
	_key("move_left", [KEY_A, KEY_LEFT])
	_key("move_right", [KEY_D, KEY_RIGHT])
	_key("jump", [KEY_SPACE])
	_key("crouch", [KEY_CTRL])
	_key("sprint", [KEY_SHIFT])
	_key("interact", [KEY_E])
	_key("paint", [KEY_C])
	_key("delete", [KEY_X])
	_key("gravity", [KEY_G])
	_key("slowmo", [KEY_T])
	_key("flashlight", [KEY_F])
	_key("fly", [KEY_V])
	_key("help", [KEY_H, KEY_F1])
	_key("rotate", [KEY_R])
	_key("fullscreen", [KEY_F11])
	_key("fps", [KEY_F3])
	_key("pause", [KEY_ESCAPE])
	_key("clear", [KEY_0])
	_mouse("grab", MOUSE_BUTTON_LEFT)
	_mouse("throw", MOUSE_BUTTON_RIGHT)
	_mouse("dist_up", MOUSE_BUTTON_WHEEL_UP)
	_mouse("dist_down", MOUSE_BUTTON_WHEEL_DOWN)
	for i in 9:
		_key("spawn_%d" % (i + 1), [KEY_1 + i])


func _setup_env() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.22, 0.42, 0.78)
	sm.sky_horizon_color = Color(0.68, 0.78, 0.88)
	sm.ground_horizon_color = Color(0.42, 0.52, 0.4)
	sm.ground_bottom_color = Color(0.16, 0.2, 0.12)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.56, 0.5)
	env.ambient_light_energy = 0.28
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.15
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.ssao_power = 1.4
	env.ssr_enabled = true
	env.ssr_max_steps = 48
	env.ssr_fade_in = 0.15
	env.ssr_fade_out = 2.0
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.045, 0.04)
	env.fog_density = 0.006
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.04
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# Portal views are rendered in linear HDR and tonemapped once by the main view.
	portal_env = env.duplicate()
	portal_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	portal_env.tonemap_exposure = 1.0
	portal_env.glow_enabled = false
	portal_env.adjustment_enabled = false
