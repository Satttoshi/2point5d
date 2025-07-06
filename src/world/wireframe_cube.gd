class_name WireframeCube
extends MeshInstance3D

## Custom wireframe cube mesh generator for clean edge visualization
## Creates proper line-based wireframe with configurable thickness and color

@export var cube_size: Vector3 = Vector3.ONE
@export var line_thickness: float = 0.02
@export var wireframe_color: Color = Color.YELLOW
@export var alpha: float = 0.7

var wireframe_material: StandardMaterial3D

func _ready():
	create_wireframe_mesh()
	setup_material()

## Generate wireframe mesh using ArrayMesh with line geometry
func create_wireframe_mesh():
	var array_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	# Define cube vertices
	var half_size = cube_size * 0.5
	var vertices = PackedVector3Array()
	var indices = PackedInt32Array()
	
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
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = array_mesh

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
