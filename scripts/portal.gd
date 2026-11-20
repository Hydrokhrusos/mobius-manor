class_name Portal
extends Node3D
## A rectangular window into another place. Local +Z is the front normal (the side you
## look from), local X/Y span the rectangle. Rendering and teleporting are handled by
## the PortalManager.

const PORTAL_SHADER := preload("res://shaders/portal.gdshader")
const MARGIN := 0.04

var size := Vector2(1.2, 2.2)
var target: Portal = null
var can_teleport := true
var can_render := true
var no_l2 := false
var cam_layers: int = 1 | 2 | 4 | 64
var fallback := Color(0.03, 0.03, 0.035)
var fade := Vector2(8.0, 18.0)
var on_teleport: Callable = Callable()

var mat: ShaderMaterial
var quad: MeshInstance3D
var inner: MeshInstance3D
var l2_assigned := false

var _xf := Transform3D.IDENTITY
var _inv := Transform3D.IDENTITY
var _depth := -1.0


func setup_visual() -> void:
	mat = ShaderMaterial.new()
	mat.shader = PORTAL_SHADER
	mat.set_shader_parameter("fallback_color", Vector3(fallback.r, fallback.g, fallback.b))
	mat.set_shader_parameter("l2_fade_start", fade.x)
	mat.set_shader_parameter("l2_fade_end", fade.y)
	var q := QuadMesh.new()
	q.size = size + Vector2(MARGIN, MARGIN) * 2.0
	quad = MeshInstance3D.new()
	quad.mesh = q
	quad.material_override = mat
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(quad)
	var b := BoxMesh.new()
	b.size = Vector3(size.x + MARGIN * 2.0, size.y + MARGIN * 2.0, 1.0)
	b.flip_faces = true
	inner = MeshInstance3D.new()
	inner.mesh = b
	inner.material_override = mat
	inner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inner)
	set_depth(0.0)
	refresh_xf()
	if not can_render:
		quad.visible = false


func refresh_xf() -> void:
	_xf = global_transform.orthonormalized()
	_inv = _xf.affine_inverse()


func set_depth(d: float) -> void:
	if is_equal_approx(d, _depth):
		return
	_depth = d
	if inner == null:
		return
	if d <= 0.002:
		inner.visible = false
		return
	inner.visible = can_render
	inner.transform = Transform3D(Basis.from_scale(Vector3(1.0, 1.0, d)), Vector3(0.0, 0.0, -d * 0.5))


## Extend a box behind the surface while the camera is about to pass through, so the
## camera's near plane never clips the portal surface.
func near_update(cam_pos: Vector3) -> void:
	var lp := _inv * cam_pos
	if lp.z > -0.02 and lp.z < 0.6 and absf(lp.x) < size.x * 0.5 + 0.3 and absf(lp.y) < size.y * 0.5 + 0.3:
		set_depth(0.35)
	else:
		set_depth(0.0)


func normal() -> Vector3:
	return _xf.basis.z


func center() -> Vector3:
	return _xf.origin


func xf() -> Transform3D:
	return _xf


func to_local_p(p: Vector3) -> Vector3:
	return _inv * p


func link() -> Transform3D:
	return target._xf * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO) * _inv


func signed_dist(p: Vector3) -> float:
	return (p - _xf.origin).dot(_xf.basis.z)


func corners(f: float = 1.0) -> Array:
	var hx := size.x * 0.5 * f
	var hy := size.y * 0.5 * f
	return [_xf * Vector3(-hx, -hy, 0.0), _xf * Vector3(hx, -hy, 0.0), _xf * Vector3(hx, hy, 0.0), _xf * Vector3(-hx, hy, 0.0)]


## True when the segment a->b passes from the front side to the back side through the rectangle.
func crossed(a: Vector3, b: Vector3) -> bool:
	var da := signed_dist(a)
	var db := signed_dist(b)
	if da >= 0.0 and db < 0.0:
		var t := da / (da - db)
		var lp := _inv * a.lerp(b, t)
		return absf(lp.x) <= size.x * 0.5 + 0.05 and absf(lp.y) <= size.y * 0.5 + 0.05
	return false


## Distance along a ray (from the front side) to the rectangle, or -1.
func ray_hit(o: Vector3, d: Vector3, max_t: float) -> float:
	var n := _xf.basis.z
	var denom := d.dot(n)
	if denom >= -0.0001:
		return -1.0
	var t := (_xf.origin - o).dot(n) / denom
	if t < 0.0 or t > max_t:
		return -1.0
	var lp := _inv * (o + d * t)
	if absf(lp.x) > size.x * 0.5 or absf(lp.y) > size.y * 0.5:
		return -1.0
	return t
