class_name Hud
extends CanvasLayer
## Title screen, crosshair, prompts, toasts, help and pause menu.

const CONTROLS := [
	["WASD", "move"], ["Mouse", "look"], ["Shift", "sprint"], ["Space", "jump"],
	["Ctrl", "crouch"], ["LMB", "grab / drop"], ["RMB", "throw"], ["Wheel", "hold distance"],
	["E", "use / squeeze"], ["R", "rotate held"], ["C", "paint"], ["X", "delete"],
	["1-9", "spawn toys"], ["0", "clear spawned"], ["G", "gravity"], ["T", "slow motion"],
	["F", "flashlight"], ["V", "fly / noclip"], ["H", "help"], ["Esc", "pause"],
]

class Crosshair:
	extends Control
	var active := false

	func _draw() -> void:
		var c := size * 0.5
		if active:
			draw_circle(c, 2.6, Color(1, 1, 1, 0.95))
			draw_arc(c, 10.0, 0.0, TAU, 40, Color(1, 1, 1, 0.55), 1.6, true)
		else:
			draw_circle(c, 2.0, Color(1, 1, 1, 0.6))

var state := "title"
var root: Control
var cross: Crosshair
var hint: Label
var toast_lbl: Label
var toast_t := 0.0
var area_lbl: Label
var area_sub: Label
var area_t := 0.0
var stats: Label
var fps_lbl: Label
var help: PanelContainer
var title: Control
var title_prompt: Label
var pause_menu: Control
var sens_slider: HSlider
var quality_btn: Button
var show_fps := false
var _time := 0.0

const AREA_SUBTITLES := {
	"The Foyer": "where everything starts",
	"The Long Hallway": "mostly reliable",
	"The Bedroom": "check the wardrobe",
	"The Repeating Room": "the room next door is this room",
	"The Endless Stairwell": "every floor is the same floor",
	"The Attic": "watch your step",
	"The Great Hall": "larger than the house around it",
	"The Greenhouse": "it is always noon in here",
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	cross = Crosshair.new()
	cross.set_anchors_preset(Control.PRESET_FULL_RECT)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cross)

	hint = _label(21, Color(1, 1, 1, 0.92))
	_place(hint, 0, 1, 1, 1, 0, -96, 0, -60)
	toast_lbl = _label(26, Color(1.0, 0.95, 0.8))
	_place(toast_lbl, 0, 1, 1, 1, 0, -170, 0, -120)
	area_lbl = _label(54, Color(1.0, 0.94, 0.8), true)
	_place(area_lbl, 0, 0, 1, 0, 0, 70, 0, 140)
	area_sub = _label(22, Color(0.9, 0.85, 0.75), true)
	_place(area_sub, 0, 0, 1, 0, 0, 138, 0, 170)
	stats = _label(18, Color(1, 1, 1, 0.8))
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_place(stats, 0, 0, 0.6, 0, 20, 14, 0, 70)
	fps_lbl = _label(16, Color(0.7, 1.0, 0.7))
	fps_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(fps_lbl, 0.5, 0, 1, 0, 0, 14, -20, 40)
	fps_lbl.visible = false

	help = _build_help()
	help.visible = false
	root.add_child(help)
	_build_title()
	_build_pause()
	area_lbl.modulate.a = 0.0
	area_sub.modulate.a = 0.0


func _label(sz: int, col: Color, serif := false) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	if serif:
		l.add_theme_font_override("font", G.serif_font)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	return l


func _place(c: Control, al: float, at: float, ar: float, ab: float, ol: float, ot: float, orr: float, ob: float) -> void:
	c.anchor_left = al
	c.anchor_top = at
	c.anchor_right = ar
	c.anchor_bottom = ab
	c.offset_left = ol
	c.offset_top = ot
	c.offset_right = orr
	c.offset_bottom = ob


func _panel_style(alpha := 0.78) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.05, alpha)
	sb.border_color = Color(0.75, 0.62, 0.4, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	return sb


func _controls_grid(cols: int, sz: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols * 2
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 4)
	for c in CONTROLS:
		var k := Label.new()
		k.text = c[0]
		k.add_theme_font_size_override("font_size", sz)
		k.add_theme_color_override("font_color", Color(1.0, 0.82, 0.5))
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		g.add_child(k)
		var d := Label.new()
		d.text = c[1]
		d.add_theme_font_size_override("font_size", sz)
		d.add_theme_color_override("font_color", Color(0.95, 0.93, 0.9))
		g.add_child(d)
	return g


func _build_help() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _panel_style(0.72))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(p, 1, 0.5, 1, 0.5, -340, -260, -20, 260)
	var v := VBoxContainer.new()
	p.add_child(v)
	var t := Label.new()
	t.text = "Controls"
	t.add_theme_font_override("font", G.serif_font)
	t.add_theme_font_size_override("font_size", 28)
	t.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	v.add_child(t)
	v.add_child(_controls_grid(1, 17))
	var spawn := Label.new()
	spawn.text = "1 crate  2 ball  3 beach ball  4 duck\n5 domino  6 chair  7 cube  8 pin  9 lamp"
	spawn.add_theme_font_size_override("font_size", 15)
	spawn.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
	v.add_child(spawn)
	return p


func _build_title() -> void:
	title = Control.new()
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(title)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.015, 0.02, 0.72)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_child(center)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(v)
	var t := Label.new()
	t.text = G.GAME_NAME
	t.add_theme_font_override("font", G.serif_font)
	t.add_theme_font_size_override("font_size", 92)
	t.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	t.add_theme_constant_override("shadow_offset_x", 3)
	t.add_theme_constant_override("shadow_offset_y", 3)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var tag := Label.new()
	tag.text = G.TAGLINE
	tag.add_theme_font_override("font", G.serif_font)
	tag.add_theme_font_size_override("font_size", 28)
	tag.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tag)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 26)
	v.add_child(sp)
	title_prompt = Label.new()
	title_prompt.text = "click anywhere to step inside"
	title_prompt.add_theme_font_size_override("font_size", 26)
	title_prompt.add_theme_color_override("font_color", Color(1, 1, 1))
	title_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title_prompt)
	var sp2 := Control.new()
	sp2.custom_minimum_size = Vector2(0, 26)
	v.add_child(sp2)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(0.55))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(panel)
	var pv := VBoxContainer.new()
	panel.add_child(pv)
	var grid := _controls_grid(4, 17)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pv.add_child(grid)
	var goal := Label.new()
	goal.text = "Explore the house. Throw things through doorways. Find the 9 rubber ducks."
	goal.add_theme_font_size_override("font_size", 18)
	goal.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(goal)
	var foot := Label.new()
	foot.text = "made with Godot " + Engine.get_version_info().string.get_slice(".", 0) + "." + Engine.get_version_info().string.get_slice(".", 1)
	foot.add_theme_font_size_override("font_size", 14)
	foot.add_theme_color_override("font_color", Color(0.6, 0.58, 0.55))
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(foot)
	goal.set_meta("is_goal", true)
	title.set_meta("goal_label", goal)


func _build_pause() -> void:
	pause_menu = Control.new()
	pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.visible = false
	root.add_child(pause_menu)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.55)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(0.9))
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size = Vector2(420, 0)
	panel.add_child(v)
	var t := Label.new()
	t.text = "Paused"
	t.add_theme_font_override("font", G.serif_font)
	t.add_theme_font_size_override("font_size", 44)
	t.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(_button("Resume", func(): set_paused(false)))
	var sl := Label.new()
	sl.text = "Mouse sensitivity"
	sl.add_theme_font_size_override("font_size", 18)
	v.add_child(sl)
	sens_slider = HSlider.new()
	sens_slider.min_value = 0.2
	sens_slider.max_value = 3.0
	sens_slider.step = 0.05
	sens_slider.value = 1.0
	sens_slider.custom_minimum_size = Vector2(0, 28)
	sens_slider.value_changed.connect(func(val): G.settings.sensitivity = val)
	v.add_child(sens_slider)
	quality_btn = _button("Portal quality: Full", _toggle_quality)
	v.add_child(quality_btn)
	v.add_child(_button("Toggle fullscreen  (F11)", toggle_fullscreen))
	v.add_child(_button("Back to the foyer", func():
		G.player.drop()
		G.player.place(G.world.spawn_pos, G.world.spawn_yaw)
		set_paused(false)))
	v.add_child(_button("Quit", func(): get_tree().quit()))


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(cb)
	return b


func _toggle_quality() -> void:
	var q: float = 1.0 if G.settings.portal_quality < 0.9 else 0.6
	G.settings.portal_quality = q
	G.portal_manager.set_quality(q)
	quality_btn.text = "Portal quality: " + ("Full" if q > 0.9 else "Fast")


func toggle_fullscreen() -> void:
	var w := get_window()
	if w.mode == Window.MODE_FULLSCREEN or w.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
		w.mode = Window.MODE_WINDOWED
	else:
		w.mode = Window.MODE_FULLSCREEN


func is_playing() -> bool:
	return state == "playing"


func start_game(capture := true) -> void:
	state = "playing"
	title.visible = false
	if capture:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if G.sfx:
		G.sfx.start_ambience()
		G.sfx.play2d("chime", -12.0, 0.8)
	if G.world:
		area_toast(G.world.current_area() if G.world.current_area() != "" else "The Foyer")
	toast("Press H for controls", 4.0)


func set_paused(p: bool) -> void:
	if state == "title":
		return
	state = "paused" if p else "playing"
	pause_menu.visible = p
	get_tree().paused = p
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if p else Input.MOUSE_MODE_CAPTURED


func toast(text: String, secs := 2.5) -> void:
	toast_lbl.text = text
	toast_t = secs
	toast_lbl.modulate.a = 1.0


func area_toast(area: String) -> void:
	if state == "title":
		return
	area_lbl.text = area
	area_sub.text = AREA_SUBTITLES.get(area, "")
	area_t = 3.2


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == "playing" and not G.player.debug_active:
		set_paused(true)


func _input(event: InputEvent) -> void:
	if state == "title":
		var go := false
		if event is InputEventMouseButton and event.pressed:
			go = true
		elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_SPACE, KEY_KP_ENTER]:
			go = true
		if go:
			start_game()
			get_viewport().set_input_as_handled()
		return
	if state == "paused":
		if event.is_action_pressed("pause"):
			set_paused(false)
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		set_paused(true)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("help"):
		help.visible = not help.visible
	elif event.is_action_pressed("fps"):
		show_fps = not show_fps
		fps_lbl.visible = show_fps
	elif event.is_action_pressed("fullscreen"):
		toggle_fullscreen()
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_time += delta / maxf(Engine.time_scale, 0.0001) if not get_tree().paused else delta
	var rd := delta / maxf(Engine.time_scale, 0.0001)
	if state == "title":
		title_prompt.modulate.a = 0.55 + 0.45 * sin(_time * 3.0)
		var gl: Label = title.get_meta("goal_label")
		if G.ducks_total > 0:
			gl.text = "Explore the house. Throw things through doorways. Find the %d rubber ducks." % G.ducks_total
	if toast_t > 0.0:
		toast_t -= rd
		toast_lbl.modulate.a = clampf(toast_t / 0.5, 0.0, 1.0)
	if area_t > 0.0:
		area_t -= rd
		var a := clampf(minf((3.2 - area_t) / 0.4, area_t / 0.8), 0.0, 1.0)
		area_lbl.modulate.a = a
		area_sub.modulate.a = a
	if G.player == null:
		return
	var t := ""
	var p = G.player
	if state == "playing":
		if p.held:
			t = "[LMB] drop    [RMB] throw    [Wheel] distance    [R] rotate"
			if p.held.has_method("has_prompt") and p.held.has_prompt():
				t += "    [E] " + p.held.get_prompt()
		else:
			var c = p.look_target()
			if c != null:
				var parts := []
				if c is RigidBody3D and c.is_in_group("grabbable"):
					parts.append("[LMB] grab")
				if c is Prop:
					if c.has_prompt():
						parts.append("[E] " + c.get_prompt())
				elif c.has_method("get_prompt"):
					parts.append("[E] " + c.get_prompt())
				t = "    ".join(parts)
	hint.text = t
	cross.active = t != "" and not p.held
	cross.visible = state == "playing"
	cross.queue_redraw()
	var s := "Rubber ducks  %d / %d" % [G.ducks_found, G.ducks_total]
	if G.world and G.world.current_area() == "The Endless Stairwell":
		s += "      Floor %d" % G.floor_number
	if G.gravity_mode != 0:
		s += "      Gravity: " + G.GRAVITY_MODES[G.gravity_mode]
	if G.slowmo:
		s += "      Slow motion"
	if p.fly:
		s += "      Flying"
	stats.text = s
	stats.visible = state != "title"
	if show_fps:
		fps_lbl.text = "%d fps   portal views %d" % [Engine.get_frames_per_second(), G.portal_manager.stats_active]
