extends Node
## Global game state (autoload "G").

const GAME_NAME := "Möbius Manor"
const TAGLINE := "a house that does not add up"

# Visual layers (bit values)
const VL_WORLD := 1
const VL_PLAYER_BODY := 2
const VL_MAIN_ONLY := 4
const VL_UP_ONLY := 8
const VL_SUN := 64
const MAIN_CULL := VL_WORLD | VL_MAIN_ONLY | VL_SUN
const PORTAL_CULL := VL_WORLD | VL_PLAYER_BODY | VL_MAIN_ONLY | VL_SUN

# Physics layers (bit values)
const PL_WORLD := 1
const PL_PROPS := 2
const PL_PLAYER := 4
const PL_GLASS := 8

const GRAVITY_MODES := ["Normal", "Moon", "Zero"]
const GRAVITY_VALUES := [9.8, 1.62, 0.0]
const PLAYER_GRAVITY_SCALE := [1.0, 0.28, 0.06]

var player = null
var portal_manager = null
var hud = null
var sfx = null
var world = null
var main = null

var ducks_found := 0
var ducks_total := 0
var floor_number := 1
var gravity_mode := 0
var slowmo := false
var settings := {"sensitivity": 1.0, "portal_quality": 1.0}

var serif_font: SystemFont


func _ready() -> void:
	serif_font = SystemFont.new()
	serif_font.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Book Antiqua", "Times New Roman", "serif"])


func player_gravity_scale() -> float:
	return PLAYER_GRAVITY_SCALE[gravity_mode]


func cycle_gravity() -> void:
	gravity_mode = (gravity_mode + 1) % GRAVITY_MODES.size()
	var space := get_viewport().get_world_3d().space
	PhysicsServer3D.area_set_param(space, PhysicsServer3D.AREA_PARAM_GRAVITY, GRAVITY_VALUES[gravity_mode])
	for b in get_tree().get_nodes_in_group("props"):
		if b is RigidBody3D:
			b.sleeping = false
			if gravity_mode == 2:
				b.apply_central_impulse(Vector3(randf_range(-0.2, 0.2), randf_range(0.1, 0.5), randf_range(-0.2, 0.2)) * b.mass)
	if hud:
		hud.toast("Gravity: " + GRAVITY_MODES[gravity_mode])
	if sfx:
		sfx.play2d("chime", -10.0, 0.7 + 0.3 * gravity_mode)


func toggle_slowmo() -> void:
	slowmo = not slowmo
	Engine.time_scale = 0.25 if slowmo else 1.0
	AudioServer.playback_speed_scale = 0.6 if slowmo else 1.0
	if hud:
		hud.toast("Slow motion" if slowmo else "Normal time")


func duck_found(duck) -> void:
	ducks_found += 1
	if sfx:
		sfx.play2d("chime", -4.0)
	if hud:
		if ducks_found >= ducks_total:
			hud.toast("All %d ducks found!  The house approves." % ducks_total, 6.0)
		else:
			hud.toast("Rubber duck found  (%d / %d)" % [ducks_found, ducks_total], 3.0)
	if ducks_found >= ducks_total and world:
		world.celebrate(duck.global_position)
