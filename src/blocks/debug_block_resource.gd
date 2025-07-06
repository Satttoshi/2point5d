class_name DebugBlockResource
extends BlockResource

## Debug block resource that generates procedural cube geometry
## Perfect for testing and development, no external mesh dependencies
## Supports breaking animations with numbered damage stages

@export_group("Debug Visual Properties")
## Primary color for the block
@export var block_color: Color = Color.WHITE
## Secondary color for details/damage overlays
@export var accent_color: Color = Color.RED
## Whether to show damage numbers on faces during breaking
@export var show_damage_numbers: bool = true
## Font size for damage numbers
@export var damage_font_size: float = 0.3

## Cached procedural mesh scene
var _cached_mesh_scene: PackedScene

func _init():
	# Set default properties for debug blocks
	# Don't generate mesh yet - wait until block_id is set
	pass

## Generate a simple scene structure for the debug block
func _generate_procedural_mesh():
	
	# Create a much simpler scene structure
	var packed_scene = PackedScene.new()
	
	# Root node - just a MeshInstance3D
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "DebugBlock_" + block_id
	
	# Create BoxMesh with material
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3.ONE
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = _create_cube_material()
	
	
	# Pack the mesh instance directly as the root
	packed_scene.pack(mesh_instance)
	_cached_mesh_scene = packed_scene
	mesh_scene = _cached_mesh_scene
	

## Create perfect cube mesh with proper UV coordinates for damage overlays
func _create_cube_mesh() -> ArrayMesh:
	var array_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	# Define vertices for a 1x1x1 cube centered at origin
	var vertices = PackedVector3Array([
		# Front face (positive Z)
		Vector3(-0.5, -0.5,  0.5), Vector3( 0.5, -0.5,  0.5), Vector3( 0.5,  0.5,  0.5), Vector3(-0.5,  0.5,  0.5),
		# Back face (negative Z) 
		Vector3( 0.5, -0.5, -0.5), Vector3(-0.5, -0.5, -0.5), Vector3(-0.5,  0.5, -0.5), Vector3( 0.5,  0.5, -0.5),
		# Left face (negative X)
		Vector3(-0.5, -0.5, -0.5), Vector3(-0.5, -0.5,  0.5), Vector3(-0.5,  0.5,  0.5), Vector3(-0.5,  0.5, -0.5),
		# Right face (positive X)
		Vector3( 0.5, -0.5,  0.5), Vector3( 0.5, -0.5, -0.5), Vector3( 0.5,  0.5, -0.5), Vector3( 0.5,  0.5,  0.5),
		# Top face (positive Y)
		Vector3(-0.5,  0.5,  0.5), Vector3( 0.5,  0.5,  0.5), Vector3( 0.5,  0.5, -0.5), Vector3(-0.5,  0.5, -0.5),
		# Bottom face (negative Y)
		Vector3(-0.5, -0.5, -0.5), Vector3( 0.5, -0.5, -0.5), Vector3( 0.5, -0.5,  0.5), Vector3(-0.5, -0.5,  0.5)
	])
	
	# UV coordinates for each face (allows for damage overlay textures)
	var uvs = PackedVector2Array([
		# Front face
		Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0),
		# Back face
		Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0),
		# Left face
		Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0),
		# Right face
		Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0),
		# Top face
		Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0),
		# Bottom face
		Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)
	])
	
	# Normals for proper lighting
	var normals = PackedVector3Array([
		# Front face
		Vector3(0, 0, 1), Vector3(0, 0, 1), Vector3(0, 0, 1), Vector3(0, 0, 1),
		# Back face
		Vector3(0, 0, -1), Vector3(0, 0, -1), Vector3(0, 0, -1), Vector3(0, 0, -1),
		# Left face
		Vector3(-1, 0, 0), Vector3(-1, 0, 0), Vector3(-1, 0, 0), Vector3(-1, 0, 0),
		# Right face
		Vector3(1, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 0),
		# Top face
		Vector3(0, 1, 0), Vector3(0, 1, 0), Vector3(0, 1, 0), Vector3(0, 1, 0),
		# Bottom face
		Vector3(0, -1, 0), Vector3(0, -1, 0), Vector3(0, -1, 0), Vector3(0, -1, 0)
	])
	
	# Indices for triangulated faces (2 triangles per face)
	var indices = PackedInt32Array([
		# Front face
		0, 1, 2,  2, 3, 0,
		# Back face
		4, 5, 6,  6, 7, 4,
		# Left face
		8, 9, 10,  10, 11, 8,
		# Right face
		12, 13, 14,  14, 15, 12,
		# Top face
		16, 17, 18,  18, 19, 16,
		# Bottom face
		20, 21, 22,  22, 23, 20
	])
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return array_mesh

## Create material for the cube with the specified color
func _create_cube_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	
	# Ensure we have a valid color, default to white if not set
	var final_color = block_color if block_color != Color.TRANSPARENT else Color.WHITE
	
	# Make it really simple and unshaded to ensure visibility
	material.flags_unshaded = true
	material.albedo_color = final_color
	material.metallic = 0.0
	material.roughness = 1.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Show both sides
	material.flags_transparent = false
	material.flags_use_point_size = false
	
	
	return material

## Create collision shape for the cube
func _create_cube_collision() -> BoxShape3D:
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3.ONE
	return box_shape

## Create a debug block with specific color
static func create_debug_block(id: String, name: String, color: Color) -> DebugBlockResource:
	var debug_block = DebugBlockResource.new()
	debug_block.block_id = id
	debug_block.block_name = name
	debug_block.block_description = "Debug block for testing and development"
	debug_block.block_color = color
	debug_block.durability = 100
	debug_block.break_time = 1.0
	debug_block.category = "Debug"
	debug_block.tags = ["debug", "procedural"]
	debug_block.placeable = true
	debug_block.breakable = true
	debug_block.has_collision = true
	debug_block.is_solid = true
	debug_block.is_transparent = false
	
	# Generate the procedural mesh after setting all properties
	debug_block._generate_procedural_mesh()
	
	return debug_block

## Update block color and regenerate material
func set_block_color(color: Color):
	block_color = color
	if _cached_mesh_scene:
		_generate_procedural_mesh()

## Get material for specific damage stage (for breaking animations)
func get_damage_stage_material(damage_stage: int) -> StandardMaterial3D:
	var material = _create_cube_material()
	
	if damage_stage > 0 and show_damage_numbers:
		# Create damage progression: green -> yellow -> orange -> red -> dark red
		var damage_colors = [
			block_color,           # Stage 0: original color
			Color.YELLOW,          # Stage 1: light damage
			Color.ORANGE,          # Stage 2: medium damage
			Color.RED,             # Stage 3: heavy damage
			Color.DARK_RED         # Stage 4: about to break
		]
		
		var stage_index = clamp(damage_stage, 0, damage_colors.size() - 1)
		material.albedo_color = damage_colors[stage_index]
		
		# Add transparency to show damage
		var alpha = 1.0 - (float(damage_stage) * 0.1)  # Slight transparency increase
		material.albedo_color.a = alpha
		
		if alpha < 1.0:
			material.flags_transparent = true
	
	return material

## Create a breaking animation overlay material with number display
## This would be enhanced in the future with actual number textures
func create_breaking_overlay_material(damage_stage: int) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	
	# Create a simple overlay effect for now
	# In a full implementation, this would use actual number textures
	var stage_colors = [
		Color.TRANSPARENT,     # Stage 0: no overlay
		Color(1, 1, 0, 0.3),   # Stage 1: light yellow overlay
		Color(1, 0.5, 0, 0.4), # Stage 2: orange overlay
		Color(1, 0, 0, 0.5),   # Stage 3: red overlay
		Color(0.5, 0, 0, 0.6)  # Stage 4: dark red overlay
	]
	
	var stage_index = clamp(damage_stage, 0, stage_colors.size() - 1)
	material.albedo_color = stage_colors[stage_index]
	material.flags_transparent = true
	material.flags_unshaded = true
	material.no_depth_test = false
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	return material

## Validate debug block (override parent validation)
func is_valid() -> bool:
	if block_id.is_empty():
		push_error("DebugBlockResource: block_id cannot be empty")
		return false
	
	if block_name.is_empty():
		push_error("DebugBlockResource: block_name cannot be empty")
		return false
	
	# Debug blocks don't need external mesh_scene since they're procedural
	return true
