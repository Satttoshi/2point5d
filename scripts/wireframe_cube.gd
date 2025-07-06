class_name WireframeCube
extends MeshInstance3D

## Custom wireframe cube mesh generator for clean edge visualization
## Creates proper line-based wireframe with configurable thickness and color

## Display mode for different types of indicators
enum DisplayMode {
	CUBE,        ## Full wireframe cube for blocks
	WALL_BACK,   ## Flat rectangle at back face for wall items
	PLATFORM     ## Horizontal lines showing platform placement between coordinates
}

@export var cube_size: Vector3 = Vector3.ONE
@export var line_thickness: float = 0.02
@export var wireframe_color: Color = Color.YELLOW
@export var alpha: float = 0.7
@export var display_mode: DisplayMode = DisplayMode.CUBE

var wireframe_material: StandardMaterial3D

func _ready():
	create_wireframe_mesh()
	setup_material()

## Generate wireframe mesh using ArrayMesh with line geometry
func create_wireframe_mesh():
	var array_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	var vertices = PackedVector3Array()
	var indices = PackedInt32Array()
	
	if display_mode == DisplayMode.CUBE:
		_create_cube_wireframe(vertices, indices)
	elif display_mode == DisplayMode.WALL_BACK:
		_create_wall_back_wireframe(vertices, indices)
	elif display_mode == DisplayMode.PLATFORM:
		_create_platform_wireframe(vertices, indices)
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = array_mesh

## Generate full cube wireframe
func _create_cube_wireframe(vertices: PackedVector3Array, indices: PackedInt32Array):
	# Define cube vertices
	var half_size = cube_size * 0.5
	
	# Cube corner vertices
	var corners = [
		Vector3(-half_size.x, -half_size.y, -half_size.z), # 0: bottom-left-back
		Vector3( half_size.x, -half_size.y, -half_size.z), # 1: bottom-right-back
		Vector3( half_size.x,  half_size.y, -half_size.z), # 2: top-right-back
		Vector3(-half_size.x,  half_size.y, -half_size.z), # 3: top-left-back
		Vector3(-half_size.x, -half_size.y,  half_size.z), # 4: bottom-left-front
		Vector3( half_size.x, -half_size.y,  half_size.z), # 5: bottom-right-front
		Vector3( half_size.x,  half_size.y,  half_size.z), # 6: top-right-front
		Vector3(-half_size.x,  half_size.y,  half_size.z)  # 7: top-left-front
	]
	
	# Define the 12 edges of a cube as line segments
	var edges = [
		# Bottom face edges
		[0, 1], [1, 5], [5, 4], [4, 0],
		# Top face edges  
		[3, 2], [2, 6], [6, 7], [7, 3],
		# Vertical edges
		[0, 3], [1, 2], [5, 6], [4, 7]
	]
	
	# Create tube geometry for each edge to make lines visible
	for edge in edges:
		var start_pos = corners[edge[0]]
		var end_pos = corners[edge[1]]
		_add_line_tube(vertices, indices, start_pos, end_pos)

## Generate wall back face wireframe (rectangle at back of voxel)
func _create_wall_back_wireframe(vertices: PackedVector3Array, indices: PackedInt32Array):
	# Define back face rectangle vertices positioned just behind voxel center
	var half_size = cube_size * 0.5
	
	# Back face corners positioned just 1px behind the voxel center (Z = -0.01)
	var wall_z = -0.5  # Very thin offset, like 1px
	var corners = [
		Vector3(-half_size.x, -half_size.y, wall_z), # 0: bottom-left-back
		Vector3( half_size.x, -half_size.y, wall_z), # 1: bottom-right-back
		Vector3( half_size.x,  half_size.y, wall_z), # 2: top-right-back
		Vector3(-half_size.x,  half_size.y, wall_z)  # 3: top-left-back
	]
	
	# Define the 4 edges of the back face rectangle
	var edges = [
		[0, 1], # bottom edge
		[1, 2], # right edge
		[2, 3], # top edge
		[3, 0]  # left edge
	]
	
	# Create tube geometry for each edge
	for edge in edges:
		var start_pos = corners[edge[0]]
		var end_pos = corners[edge[1]]
		_add_line_tube(vertices, indices, start_pos, end_pos)

## Generate platform wireframe (horizontal lines showing platform placement)
func _create_platform_wireframe(vertices: PackedVector3Array, indices: PackedInt32Array):
	# Define platform dimensions - show horizontal lines at the top and bottom of where platform will be placed
	var half_size = cube_size * 0.5
	var platform_thickness = 0.1  # 2/20 of block height
	var half_thickness = platform_thickness * 0.5
	
	# Platform spans full X width but is thin in Y
	var top_y = half_thickness
	var bottom_y = -half_thickness
	
	# Define horizontal lines that show where the platform will be placed
	var lines = [
		# Top edges of platform
		[Vector3(-half_size.x, top_y, -half_size.z), Vector3(half_size.x, top_y, -half_size.z)],  # front top
		[Vector3(-half_size.x, top_y,  half_size.z), Vector3(half_size.x, top_y,  half_size.z)],  # back top
		# Bottom edges of platform
		[Vector3(-half_size.x, bottom_y, -half_size.z), Vector3(half_size.x, bottom_y, -half_size.z)],  # front bottom
		[Vector3(-half_size.x, bottom_y,  half_size.z), Vector3(half_size.x, bottom_y,  half_size.z)],  # back bottom
		# Side connectors (short lines on sides)
		[Vector3(-half_size.x, bottom_y, -half_size.z), Vector3(-half_size.x, top_y, -half_size.z)],  # left front
		[Vector3( half_size.x, bottom_y, -half_size.z), Vector3( half_size.x, top_y, -half_size.z)],  # right front
		[Vector3(-half_size.x, bottom_y,  half_size.z), Vector3(-half_size.x, top_y,  half_size.z)],  # left back
		[Vector3( half_size.x, bottom_y,  half_size.z), Vector3( half_size.x, top_y,  half_size.z)]   # right back
	]
	
	# Create tube geometry for each line
	for line in lines:
		_add_line_tube(vertices, indices, line[0], line[1])

## Set the display mode and regenerate mesh
func set_display_mode(mode: DisplayMode):
	display_mode = mode
	create_wireframe_mesh()

## Add tube geometry between two points to create visible line
func _add_line_tube(vertices: PackedVector3Array, indices: PackedInt32Array, start: Vector3, end: Vector3):
	var direction = (end - start).normalized()
	var _length = start.distance_to(end)  # Length not needed for current tube implementation
	
	# Create a simple tube with 8 sides for smooth appearance
	var tube_sides = 8
	var radius = line_thickness * 0.5
	
	# Generate perpendicular vectors for tube cross-section
	var up = Vector3.UP
	if abs(direction.dot(up)) > 0.9:
		up = Vector3.RIGHT
	var right = direction.cross(up).normalized()
	up = right.cross(direction).normalized()
	
	var start_vertex_count = vertices.size()
	
	# Add vertices for tube geometry
	for i in range(tube_sides):
		var angle = (float(i) / tube_sides) * TAU
		var offset = (right * cos(angle) + up * sin(angle)) * radius
		
		# Start cap vertices
		vertices.append(start + offset)
		# End cap vertices  
		vertices.append(end + offset)
	
	# Create triangles for tube surface
	for i in range(tube_sides):
		var next_i = (i + 1) % tube_sides
		var base_idx = start_vertex_count
		
		# Two triangles per quad segment
		# Triangle 1
		indices.append(base_idx + i * 2)         # start current
		indices.append(base_idx + i * 2 + 1)     # end current
		indices.append(base_idx + next_i * 2)    # start next
		
		# Triangle 2
		indices.append(base_idx + next_i * 2)    # start next
		indices.append(base_idx + i * 2 + 1)     # end current
		indices.append(base_idx + next_i * 2 + 1) # end next

## Setup material properties for wireframe appearance
func setup_material():
	wireframe_material = StandardMaterial3D.new()
	wireframe_material.flags_unshaded = true
	wireframe_material.flags_transparent = true
	# flags_do_not_use_vertex_color is deprecated in Godot 4.x
	wireframe_material.albedo_color = wireframe_color
	wireframe_material.albedo_color.a = alpha
	wireframe_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wireframe_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	wireframe_material.no_depth_test = false
	wireframe_material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	
	material_override = wireframe_material

## Update wireframe color
func set_color(color: Color):
	wireframe_color = color
	if wireframe_material:
		wireframe_material.albedo_color = color
		wireframe_material.albedo_color.a = alpha

## Update alpha transparency
func set_alpha(new_alpha: float):
	alpha = new_alpha
	if wireframe_material:
		wireframe_material.albedo_color.a = alpha

## Update line thickness and regenerate mesh
func set_line_thickness(thickness: float):
	line_thickness = thickness
	create_wireframe_mesh()

## Update cube size and regenerate mesh
func set_cube_size(size: Vector3):
	cube_size = size
	create_wireframe_mesh()
