class_name Prop
extends RigidBody3D
## A physics toy that can be grabbed, thrown, painted and carried through portals.

var kind := ""
var prompt := ""
var action: Callable = Callable()
var paint_meshes: Array = []
var collectible := false
var found := false
var light: OmniLight3D
var audio: AudioStreamPlayer3D
var lifetime := -1.0
var _last_snd := 0.0


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 2
	body_entered.connect(_on_hit)
	set_process(lifetime > 0.0)


func _process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_hit(_other: Node) -> void:
	var now := Time.get_ticks_msec() * 0.001
	if now - _last_snd < 0.12:
		return
	var v := linear_velocity.length()
	if v < 0.9:
		return
	_last_snd = now
	if G.sfx:
		G.sfx.impact(global_position, v, mass, kind)


func has_prompt() -> bool:
	return action.is_valid() or collectible or kind == "duck"


func get_prompt() -> String:
	if prompt != "":
		return prompt
	if kind == "duck":
		return "Squeeze"
	return "Use"


func interact(_who) -> void:
	if kind == "duck":
		_squeak()
	if action.is_valid():
		action.call(self)


func on_grabbed() -> void:
	if collectible and not found:
		_squeak()


func _squeak() -> void:
	if G.sfx:
		G.sfx.play_at("squeak", global_position, -2.0, randf_range(0.9, 1.15))
	if collectible and not found:
		found = true
		G.duck_found(self)


func paint(c: Color) -> void:
	for mi in paint_meshes:
		if is_instance_valid(mi):
			var m: ShaderMaterial = (mi.material_override as ShaderMaterial).duplicate()
			m.set_shader_parameter("albedo", c)
			m.set_shader_parameter("albedo2", c.darkened(0.35))
			mi.material_override = m
	if light:
		light.light_color = c.lightened(0.3)
