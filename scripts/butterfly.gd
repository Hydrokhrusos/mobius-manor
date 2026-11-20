extends Node3D
## A little butterfly that flutters around a home point.

var home := Vector3.ZERO
var hue := 0.0
var _t := 0.0
var _speed := 1.0
var _phase := 0.0
var _wl: Node3D
var _wr: Node3D


func _ready() -> void:
	_t = randf() * 100.0
	_speed = randf_range(0.6, 1.1)
	_phase = randf() * TAU
	var col := Color.from_hsv(hue, 0.75, 1.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.emission_enabled = true
	mat.emission = col * 0.25
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.07)
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		add_child(pivot)
		var m := MeshInstance3D.new()
		m.mesh = q
		m.material_override = mat
		m.position = Vector3(0.045 * side, 0.0, 0.0)
		m.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
		m.layers = G.VL_WORLD | G.VL_SUN
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(m)
		if side < 0.0:
			_wl = pivot
		else:
			_wr = pivot
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.008
	cm.height = 0.06
	body.mesh = cm
	body.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.1, 0.08, 0.06)
	body.material_override = bm
	body.layers = G.VL_WORLD | G.VL_SUN
	add_child(body)


func _process(delta: float) -> void:
	_t += delta * _speed
	var p := home + Vector3(sin(_t * 0.7 + _phase) * 1.6, 0.4 * sin(_t * 1.3) + 0.25 * sin(_t * 3.1), cos(_t * 0.53 + _phase) * 1.6)
	var vel := p - position
	position = p
	if vel.length() > 0.0001:
		rotation.y = atan2(-vel.x, -vel.z)
	var flap := sin(_t * 30.0) * 1.1
	_wl.rotation.z = flap
	_wr.rotation.z = -flap
