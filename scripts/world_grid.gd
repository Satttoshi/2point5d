class_name WorldGrid
extends Node3D

## Dynamic world management system for 2.5D block placement and removal
## Replaces static GridMap with a flexible system for voxel-like block manipulation
## Manages block instances, collision, and visual representation

signal block_placed(position: Vector2i, block_id: String)
signal block_removed(position: Vector2i, block_id: String)
signal block_damaged(position: Vector2i, damage: int, current_health: int)

## Size of each grid cell in world units
@export var cell_size: float = 1.0
## Maximum distance from origin for block placement/removal
@export var world_bounds: int = 1000
## Enable debug visualization of grid
@export var debug_grid: bool = false

## Dictionary storing block instances [Vector2i position -> BlockInstance]
var _blocks: Dictionary = {}
## Dictionary storing block health [Vector2i position -> int]
var _block_health: Dictionary = {}
## Root node for all block mesh instances
var _block_container: Node3D
## Dictionary caching mesh instances [Vector2i position -> Node3D]
var _mesh_instances: Dictionary = {}
## Dictionary for collision shapes [Vector2i position -> StaticBody3D]
var _collision_bodies: Dictionary = {}
## Target indicator for block placement/removal
var _target_indicator: WireframeCube = null
## Dictionary tracking degradation timers [Vector2i position -> float]
var _degradation_timers: Dictionary = {}
## Dictionary tracking blocks that have player standing on them [Vector2i position -> bool]
var _blocks_with_player: Dictionary = {}
## Degradation processing timer
var _degradation_process_timer: float = 0.0
## How often to process degradation checks (in seconds)
var _degradation_check_interval: float = 0.1
## Dictionary storing wall instances [Vector2i position -> WallInstance]
var _walls: Dictionary = {}
## Root node for all wall mesh instances
var _wall_container: Node3D
## Dictionary caching wall mesh instances [Vector2i position -> Node3D]
var _wall_mesh_instances: Dictionary = {}
## Reference to the player for collision checking
var _player: CharacterBody3D = null

## Internal class to represent a block instance in the world
class BlockInstance:
	var position: Vector2i
	var block_id: String
	var block_resource: BlockResource
	var current_health: int
	var mesh_instance: Node3D
	var collision_body: StaticBody3D
	var custom_properties: Dictionary = {}
	
	func _init(pos: Vector2i, id: String, resource: BlockResource):
		position = pos
		block_id = id
		block_resource = resource
		current_health = resource.durability if resource else 100

## Internal class to represent a wall instance in the world (separate from blocks)
class WallInstance:
	var position: Vector2i
	var wall_id: String
	var wall_resource: BlockResource
	var mesh_instance: Node3D
	
	func _init(pos: Vector2i, id: String, resource: BlockResource):
		position = pos
		wall_id = id
		wall_resource = resource

func _ready():
	print("WorldGrid: Initializing world grid system...")
	_setup_container()
	_setup_target_indicator()
	
	# Connect to BlockRegistry signals to handle block type changes
	if BlockRegistry:
		BlockRegistry.block_registered.connect(_on_block_registered)
		BlockRegistry.block_unregistered.connect(_on_block_unregistered)
	
	# Connect to GameEvents for event-driven communication
	GameEvents.block_placement_requested.connect(_on_block_placement_requested)
	GameEvents.block_removal_requested.connect(_on_block_removal_requested)
	GameEvents.target_indicator_update_requested.connect(_on_target_indicator_update_requested)
	GameEvents.target_indicator_hide_requested.connect(_on_target_indicator_hide_requested)
	GameEvents.player_standing_on_block.connect(_on_player_standing_on_block)
	
	print("WorldGrid: World grid initialized with cell size: %f" % cell_size)
	
	# Find player reference for collision checking
	_find_player_reference()
	
	# Create starting platform with pre-placed blocks
	_create_starting_platform()

## Process degradation for degradable blocks
func _process(delta: float):
	_degradation_process_timer += delta
	
	# Process degradation at regular intervals
	if _degradation_process_timer >= _degradation_check_interval:
		_process_block_degradation(_degradation_process_timer)
		_degradation_process_timer = 0.0

## Process degradation for all degradable blocks
func _process_block_degradation(delta: float):
	var positions_to_remove: Array[Vector2i] = []
	
	for grid_pos in _blocks.keys():
		var block_instance = _blocks[grid_pos] as BlockInstance
		if block_instance == null:
			continue
			
		var block_resource = block_instance.block_resource
		
		# Only process degradable blocks that have a player standing on them
		if not block_resource.degradable:
			continue
		
		# Only degrade if player is standing on this block and it degrades under player
		var player_standing = _blocks_with_player.get(grid_pos, false)
		if not (player_standing and block_resource.degrades_under_player):
			continue
		
		# Initialize degradation timer if not exists
		if not _degradation_timers.has(grid_pos):
			_degradation_timers[grid_pos] = 0.0
		
		# Increment degradation timer only when player is standing on it
		_degradation_timers[grid_pos] += delta
		
		# Check if it's time to degrade this block
		var interval = block_resource.degradation_interval
		
		# Apply player multiplier if configured
		if block_resource.player_degradation_multiplier != 1.0:
			interval = interval / block_resource.player_degradation_multiplier
		
		if _degradation_timers[grid_pos] >= interval:
			_degradation_timers[grid_pos] = 0.0
			
			# Apply degradation damage
			var damage = block_resource.degradation_amount
			print("WorldGrid: Sand block at %s taking %d damage from player standing on it" % [grid_pos, damage])
			if damage_block(grid_pos, damage):
				# Block was destroyed, clean up degradation data
				positions_to_remove.append(grid_pos)
	
	# Clean up degradation data for removed blocks
	for grid_pos in positions_to_remove:
		_degradation_timers.erase(grid_pos)
		_blocks_with_player.erase(grid_pos)

## Handle player standing on block events
func _on_player_standing_on_block(grid_pos: Vector2i):
	# Clear all previous player positions
	for pos in _blocks_with_player.keys():
		_blocks_with_player[pos] = false
	
	# If this is a valid grid position, set current player position
	if grid_pos.x != -9999 and grid_pos.y != -9999:  # Check for invalid position (player not on any block)
		_blocks_with_player[grid_pos] = true
		print("WorldGrid: Player now standing on block at %s" % grid_pos)
	else:
		print("WorldGrid: Player no longer standing on any block")

## Setup the container nodes for blocks and walls
func _setup_container():
	_block_container = Node3D.new()
	_block_container.name = "BlockContainer"
	add_child(_block_container)
	
	_wall_container = Node3D.new()
	_wall_container.name = "WallContainer"
	add_child(_wall_container)

## Setup the target indicator for block placement/removal
func _setup_target_indicator():
	_target_indicator = WireframeCube.new()
	_target_indicator.name = "TargetIndicator"
	_target_indicator.cube_size = Vector3.ONE
	_target_indicator.line_thickness = 0.05
	_target_indicator.set_color(Color.YELLOW)
	_target_indicator.set_alpha(0.8)
	_target_indicator.visible = false
	
	# Add to world (not to block container to avoid conflicts)
	add_child(_target_indicator)
	print("WorldGrid: Created target indicator")

## Convert world position to grid coordinates (2D for 2.5D constraint)
func world_to_grid(world_pos: Vector3) -> Vector2i:
	var grid_x = int(round(world_pos.x / cell_size))
	var grid_y = int(round(world_pos.y / cell_size))
	return Vector2i(grid_x, grid_y)

## Convert grid coordinates to world position (for regular blocks)
func grid_to_world(grid_pos: Vector2i) -> Vector3:
	var world_x = grid_pos.x * cell_size
	var world_y = grid_pos.y * cell_size
	# Z is always 0 for 2.5D constraint
	return Vector3(world_x, world_y, 0.0)

## Convert grid coordinates to world position for a specific item type
func grid_to_world_for_item(grid_pos: Vector2i, block_resource: BlockResource) -> Vector3:
	var world_x = grid_pos.x * cell_size
	var world_y = grid_pos.y * cell_size
	var world_z = 0.0  # All items use the same grid position
	
	# Wall items use the same world position as blocks - the visual offset is handled in the mesh positioning
	return Vector3(world_x, world_y, world_z)

## Place a block or wall at the specified grid position
func place_block(grid_pos: Vector2i, block_id: String) -> bool:
	# Validate position
	if not _is_valid_position(grid_pos):
		push_warning("WorldGrid: Invalid position for block placement: %s" % grid_pos)
		return false
	
	# Get block resource to check type before validation
	var block_resource = BlockRegistry.get_block(block_id)
	if block_resource == null:
		push_error("WorldGrid: Block type not found: %s" % block_id)
		return false
	
	if not block_resource.placeable:
		push_warning("WorldGrid: Block type not placeable: %s" % block_id)
		return false
	
	# Route wall items to separate wall system (before checking for existing blocks)
	if block_resource.item_type == BlockResource.ItemType.WALL_ITEM:
		return _place_wall(grid_pos, block_id, block_resource)
	
	# Check if position is already occupied for regular blocks only
	if has_block(grid_pos):
		push_warning("WorldGrid: Position already occupied by block: %s" % grid_pos)
		return false
	
	# Check if placing this block would intersect with the player
	if _would_intersect_player(grid_pos):
		push_warning("WorldGrid: Cannot place block - would intersect with player: %s" % grid_pos)
		return false
	
	# Create block instance
	var block_instance = BlockInstance.new(grid_pos, block_id, block_resource)
	_blocks[grid_pos] = block_instance
	_block_health[grid_pos] = block_resource.durability
	
	# Create visual representation
	if not _create_block_visual(block_instance):
		# Cleanup on failure
		_blocks.erase(grid_pos)
		_block_health.erase(grid_pos)
		push_error("WorldGrid: Failed to create visual for block: %s" % block_id)
		return false
	
	# Create collision separately since we simplified the block structure
	if block_resource.has_collision:
		_create_block_collision(block_instance)
	
	block_placed.emit(grid_pos, block_id)
	print("WorldGrid: Placed block '%s' at %s" % [block_id, grid_pos])
	return true

## Remove a block or wall at the specified grid position
func remove_block(grid_pos: Vector2i) -> bool:
	# Try to remove a block first
	if has_block(grid_pos):
		return _remove_block_internal(grid_pos)
	# If no block, try to remove a wall
	elif has_wall(grid_pos):
		return _remove_wall(grid_pos)
	else:
		push_warning("WorldGrid: Nothing to remove at position: %s" % grid_pos)
		return false

## Internal function to remove a block (renamed from remove_block)
func _remove_block_internal(grid_pos: Vector2i) -> bool:
	
	var block_instance = _blocks[grid_pos] as BlockInstance
	var block_id = block_instance.block_id
	
	# Remove visual representation
	_remove_block_visual(grid_pos)
	
	# Remove collision
	_remove_block_collision(grid_pos)
	
	# Clean up data
	_blocks.erase(grid_pos)
	_block_health.erase(grid_pos)
	
	# Clean up degradation data
	_degradation_timers.erase(grid_pos)
	_blocks_with_player.erase(grid_pos)
	
	block_removed.emit(grid_pos, block_id)
	print("WorldGrid: Removed block '%s' from %s" % [block_id, grid_pos])
	return true

## Damage a block at the specified position
func damage_block(grid_pos: Vector2i, damage: int) -> bool:
	if not has_block(grid_pos):
		return false
	
	var block_instance = _blocks[grid_pos] as BlockInstance
	if not block_instance.block_resource.breakable:
		return false
	
	var current_health = _block_health.get(grid_pos, 0)
	current_health -= damage
	_block_health[grid_pos] = current_health
	
	block_damaged.emit(grid_pos, damage, current_health)
	
	# Check if block should be destroyed
	if current_health <= 0:
		# TODO: Drop items here
		remove_block(grid_pos)
		return true
	
	return false

## Check if there's a block at the specified position
func has_block(grid_pos: Vector2i) -> bool:
	return _blocks.has(grid_pos)

## Alias for has_block (for ProtoController compatibility)
func has_block_at(grid_pos: Vector2i) -> bool:
	return has_block(grid_pos)

## Get the block instance at the specified position
func get_block(grid_pos: Vector2i) -> BlockInstance:
	return _blocks.get(grid_pos, null)

## Get the block ID at the specified position
func get_block_id(grid_pos: Vector2i) -> String:
	var block_instance = get_block(grid_pos)
	return block_instance.block_id if block_instance else ""

## Get the block resource at the specified position
func get_block_resource(grid_pos: Vector2i) -> BlockResource:
	var block_instance = get_block(grid_pos)
	return block_instance.block_resource if block_instance else null

## Get the current health of a block
func get_block_health(grid_pos: Vector2i) -> int:
	return _block_health.get(grid_pos, 0)

## Get all block positions in the world
func get_all_block_positions() -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for pos in _blocks.keys():
		positions.append(pos)
	return positions

## Get blocks within a rectangular area
func get_blocks_in_area(top_left: Vector2i, bottom_right: Vector2i) -> Array[BlockInstance]:
	var blocks: Array[BlockInstance] = []
	
	for x in range(top_left.x, bottom_right.x + 1):
		for y in range(top_left.y, bottom_right.y + 1):
			var pos = Vector2i(x, y)
			if has_block(pos):
				blocks.append(get_block(pos))
	
	return blocks

## Clear all blocks from the world
func clear_world():
	for grid_pos in _blocks.keys():
		remove_block(grid_pos)
	
	print("WorldGrid: World cleared")

## Get the total number of blocks in the world
func get_block_count() -> int:
	return _blocks.size()

## Show target indicator at specified grid position
func show_target_indicator(grid_pos: Vector2i):
	if _target_indicator:
		var world_pos = grid_to_world(grid_pos)
		_target_indicator.global_position = world_pos
		_target_indicator.visible = true

## Hide target indicator
func hide_target_indicator():
	if _target_indicator:
		_target_indicator.visible = false

## Update target indicator position and visibility based on validity and item type
func update_target_indicator(grid_pos: Vector2i, is_valid: bool, selected_block_id: String = ""):
	if _target_indicator:
		var world_pos = grid_to_world(grid_pos)
		
		# Check if selected item is a wall item to change indicator display
		var is_wall_item = false
		if not selected_block_id.is_empty():
			var selected_resource = BlockRegistry.get_block(selected_block_id)
			if selected_resource and selected_resource.item_type == BlockResource.ItemType.WALL_ITEM:
				is_wall_item = true
				# Wall items use the same position as blocks - no Z offset
		
		# Set appropriate display mode
		if is_wall_item:
			_target_indicator.set_display_mode(WireframeCube.DisplayMode.WALL_BACK)
		else:
			_target_indicator.set_display_mode(WireframeCube.DisplayMode.CUBE)
		
		_target_indicator.global_position = world_pos
		_target_indicator.visible = is_valid
		
		# Change color based on validity and what exists at the position
		if is_valid:
			if has_block(grid_pos):
				_target_indicator.set_color(Color.RED)  # Block exists, can remove
			elif has_wall(grid_pos) and is_wall_item:
				_target_indicator.set_color(Color.ORANGE)  # Wall exists, can replace
			else:
				_target_indicator.set_color(Color.GREEN)  # Empty space, can place
		else:
			_target_indicator.set_color(Color.GRAY)  # Invalid target

## Check if target indicator is currently visible
func is_target_indicator_visible() -> bool:
	return _target_indicator != null and _target_indicator.visible

## Check if a position is valid for block placement
func _is_valid_position(grid_pos: Vector2i) -> bool:
	return abs(grid_pos.x) <= world_bounds and abs(grid_pos.y) <= world_bounds

## Create visual representation for a block
func _create_block_visual(block_instance: BlockInstance) -> bool:
	var block_resource = block_instance.block_resource
	
	
	if block_resource.mesh_scene == null:
		push_error("WorldGrid: No mesh scene defined for block: %s" % block_instance.block_id)
		return false
	
	
	# Instance the mesh scene
	var mesh_instance = block_resource.mesh_scene.instantiate()
	if mesh_instance == null:
		push_error("WorldGrid: Failed to instantiate mesh scene for block: %s" % block_instance.block_id)
		return false
	
	
	# Position the mesh instance at grid position
	var world_pos = grid_to_world(block_instance.position)
	mesh_instance.position = world_pos
	
	
	# Add to container
	_block_container.add_child(mesh_instance)
	
	# Store references
	_mesh_instances[block_instance.position] = mesh_instance
	block_instance.mesh_instance = mesh_instance
	
	return true

## Remove visual representation for a block
func _remove_block_visual(grid_pos: Vector2i):
	if _mesh_instances.has(grid_pos):
		var mesh_instance = _mesh_instances[grid_pos]
		if mesh_instance:
			mesh_instance.queue_free()
		_mesh_instances.erase(grid_pos)

## Create collision for a block (only called for regular blocks, not walls)
func _create_block_collision(block_instance: BlockInstance):
	var static_body = StaticBody3D.new()
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	
	# Regular blocks have full collision
	box_shape.size = Vector3(cell_size, cell_size, cell_size)
	
	collision_shape.shape = box_shape
	static_body.add_child(collision_shape)
	
	# Position collision at grid position (same for all items)
	var world_pos = grid_to_world(block_instance.position)
	static_body.position = world_pos
	
	_block_container.add_child(static_body)
	
	_collision_bodies[block_instance.position] = static_body
	block_instance.collision_body = static_body

## Remove collision for a block
func _remove_block_collision(grid_pos: Vector2i):
	if _collision_bodies.has(grid_pos):
		var collision_body = _collision_bodies[grid_pos]
		if collision_body:
			collision_body.queue_free()
		_collision_bodies.erase(grid_pos)

## Handle new block types being registered
func _on_block_registered(block_resource: BlockResource):
	print("WorldGrid: New block type registered: %s" % block_resource.block_id)

## Handle block types being unregistered
func _on_block_unregistered(block_id: String):
	print("WorldGrid: Block type unregistered: %s" % block_id)
	
	# TODO: Handle removal of blocks of this type from the world
	# This would be needed for mod support or dynamic block type changes

## Handle block placement requests from events
func _on_block_placement_requested(grid_pos: Vector2i, block_id: String):
	print("WorldGrid: Received block placement request at %s: %s" % [grid_pos, block_id])
	
	# Validate placement
	if not _is_valid_position(grid_pos):
		print("WorldGrid: Invalid position for placement: %s" % grid_pos)
		return
	
	# Check if this is a wall item - if so, allow placement even if block exists
	var block_resource = BlockRegistry.get_block(block_id)
	if block_resource != null and block_resource.item_type == BlockResource.ItemType.WALL_ITEM:
		# Wall items can be placed regardless of existing blocks
		pass
	elif has_block(grid_pos):
		print("WorldGrid: Position already occupied: %s" % grid_pos)
		return
	
	# Attempt to place the block
	if place_block(grid_pos, block_id):
		GameEvents.notify_block_placed(grid_pos, block_id)
	else:
		print("WorldGrid: Failed to place block at %s" % grid_pos)

## Handle block removal requests from events
func _on_block_removal_requested(grid_pos: Vector2i):
	print("WorldGrid: Received block removal request at %s" % grid_pos)
	
	# Try to remove block or wall at the position
	if remove_block(grid_pos):
		# The remove_block function handles both blocks and walls
		var block_id = get_block_id(grid_pos) if has_block(grid_pos) else ""
		if not block_id.is_empty():
			GameEvents.notify_block_removed(grid_pos, block_id)
	else:
		print("WorldGrid: Nothing to remove at %s" % grid_pos)

## Handle target indicator update requests from events
func _on_target_indicator_update_requested(grid_pos: Vector2i, is_valid: bool):
	update_target_indicator(grid_pos, is_valid)

## Handle target indicator hide requests from events
func _on_target_indicator_hide_requested():
	hide_target_indicator()

## Debug function to visualize the grid
func _draw_debug_grid():
	# This would be implemented for development debugging
	# Could show grid lines, block boundaries, etc.
	pass

## Place a wall at the specified grid position (separate from block system)
func _place_wall(grid_pos: Vector2i, wall_id: String, wall_resource: BlockResource) -> bool:
	# Walls can always be placed - they don't interfere with blocks
	# If a wall already exists at this position, replace it
	if _walls.has(grid_pos):
		_remove_wall(grid_pos)
	
	# Create wall instance
	var wall_instance = WallInstance.new(grid_pos, wall_id, wall_resource)
	_walls[grid_pos] = wall_instance
	
	# Create visual representation for wall
	if not _create_wall_visual(wall_instance):
		_walls.erase(grid_pos)
		push_error("WorldGrid: Failed to create visual for wall: %s" % wall_id)
		return false
	
	print("WorldGrid: Placed wall '%s' at %s" % [wall_id, grid_pos])
	return true

## Create visual representation for a wall
func _create_wall_visual(wall_instance: WallInstance) -> bool:
	var wall_resource = wall_instance.wall_resource
	
	if wall_resource.mesh_scene == null:
		push_error("WorldGrid: No mesh scene defined for wall: %s" % wall_instance.wall_id)
		return false
	
	# Instance the mesh scene
	var mesh_instance = wall_resource.mesh_scene.instantiate()
	if mesh_instance == null:
		push_error("WorldGrid: Failed to instantiate mesh scene for wall: %s" % wall_instance.wall_id)
		return false
	
	# Position the wall at grid position, then move to back face
	var world_pos = grid_to_world(wall_instance.position)
	# Move wall to back face of voxel (half a block back)
	world_pos.z += wall_resource.wall_placement_offset
	mesh_instance.position = world_pos
	
	# Add to wall container (separate from blocks)
	_wall_container.add_child(mesh_instance)
	
	# Store references
	_wall_mesh_instances[wall_instance.position] = mesh_instance
	wall_instance.mesh_instance = mesh_instance
	
	return true

## Remove a wall at the specified grid position
func _remove_wall(grid_pos: Vector2i) -> bool:
	if not _walls.has(grid_pos):
		return false
	
	var wall_instance = _walls[grid_pos] as WallInstance
	var wall_id = wall_instance.wall_id
	
	# Remove visual representation
	if _wall_mesh_instances.has(grid_pos):
		var mesh_instance = _wall_mesh_instances[grid_pos]
		if mesh_instance:
			mesh_instance.queue_free()
		_wall_mesh_instances.erase(grid_pos)
	
	# Clean up data
	_walls.erase(grid_pos)
	
	print("WorldGrid: Removed wall '%s' from %s" % [wall_id, grid_pos])
	return true

## Check if there's a wall at the specified position
func has_wall(grid_pos: Vector2i) -> bool:
	return _walls.has(grid_pos)

## Get the wall instance at the specified position
func get_wall(grid_pos: Vector2i) -> WallInstance:
	return _walls.get(grid_pos, null)

## Clear all walls from the world
func clear_walls():
	for grid_pos in _walls.keys():
		_remove_wall(grid_pos)
	print("WorldGrid: All walls cleared")

## Create the starting platform with pre-placed blocks
func _create_starting_platform():
	# Wait for BlockRegistry to be ready
	if not BlockRegistry or BlockRegistry.get_block_count() == 0:
		# Defer creation until next frame when BlockRegistry is ready
		call_deferred("_create_starting_platform")
		return
	
	print("WorldGrid: Creating starting platform...")
	
	# Platform dimensions: 20 wide x 5 tall
	var platform_width = 20
	var platform_height = 5
	
	# Center the platform around x=0, position it below player start (y=0.1)
	# Top row should be at y=0 (just below player), so bottom starts at y=-4
	var start_x = -(platform_width / 2)
	var start_y = -4
	
	for row in range(platform_height):
		for col in range(platform_width):
			var grid_pos = Vector2i(start_x + col, start_y + (platform_height - 1 - row))
			
			# First row (top) = grass blocks, rest = dirt blocks
			var block_type = "grass" if row == 0 else "dirt"
			
			# Place the block directly (bypass event system for initial setup)
			if place_block(grid_pos, block_type):
				pass # Success
			else:
				print("WorldGrid: Failed to place %s block at %s" % [block_type, grid_pos])
	
	print("WorldGrid: Starting platform created (%dx%d blocks)" % [platform_width, platform_height])

## Find and store reference to the player for collision checking
func _find_player_reference():
	# Look for ProtoController in the scene tree
	var proto_controller = get_node("../ProtoController")
	if proto_controller and proto_controller is CharacterBody3D:
		_player = proto_controller
		print("WorldGrid: Found player reference")
	else:
		push_warning("WorldGrid: Could not find player reference for collision checking")

## Check if placing a block at the given position would intersect with the player
func _would_intersect_player(grid_pos: Vector2i) -> bool:
	if _player == null:
		return false  # No player reference, allow placement
	
	# Convert grid position to world position
	var block_world_pos = grid_to_world(grid_pos)
	var player_pos = _player.global_position
	
	# Define block bounds (1x1x1 cube)
	var block_min = block_world_pos - Vector3(0.5, 0.5, 0.5)
	var block_max = block_world_pos + Vector3(0.5, 0.5, 0.5)
	
	# Define player bounds (assume player is roughly 0.6 wide x 1.8 tall x 0.6 deep)
	var player_min = player_pos - Vector3(0.3, 0.0, 0.3)
	var player_max = player_pos + Vector3(0.3, 1.8, 0.3)
	
	# Check for AABB intersection
	return (block_min.x < player_max.x and block_max.x > player_min.x and
			block_min.y < player_max.y and block_max.y > player_min.y and
			block_min.z < player_max.z and block_max.z > player_min.z)
