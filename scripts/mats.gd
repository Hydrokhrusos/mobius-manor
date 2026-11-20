class_name Mats
extends RefCounted
## Material factory for the procedural world shader.

const WORLD_SHADER := preload("res://shaders/world.gdshader")
const GLASS_SHADER := preload("res://shaders/glass.gdshader")
const WATER_SHADER := preload("res://shaders/water.gdshader")

const PLAIN := 0
const CHECKER := 1
const PLANKS := 2
const STRIPES := 3
const TILES := 4
const BRICKS := 5
const BLOTCH := 6
const DOTS := 7
const BANDS := 8
const SEGMENTS := 9


static func make(c1: Color, c2: Color = Color(0.5, 0.5, 0.5), pattern: int = PLAIN, scale: float = 1.0,
		rough: float = 0.8, metal: float = 0.0, obj_space: bool = false, grime: float = 0.1) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = WORLD_SHADER
	m.set_shader_parameter("albedo", c1)
	m.set_shader_parameter("albedo2", c2)
	m.set_shader_parameter("pattern", pattern)
	m.set_shader_parameter("pattern_scale", scale)
	m.set_shader_parameter("roughness", rough)
	m.set_shader_parameter("metallic", metal)
	m.set_shader_parameter("object_space", obj_space)
	m.set_shader_parameter("grime", grime)
	return m


static func emissive(c: Color, energy: float = 3.0) -> ShaderMaterial:
	var m := make(c, c, PLAIN, 1.0, 0.5, 0.0, false, 0.0)
	m.set_shader_parameter("emission", c)
	m.set_shader_parameter("emission_energy", energy)
	return m


static func glass(tint: Color = Color(0.85, 0.95, 1.0, 0.07)) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GLASS_SHADER
	m.set_shader_parameter("tint", tint)
	return m


static func water() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = WATER_SHADER
	return m
