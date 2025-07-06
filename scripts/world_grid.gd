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

## Setup the container node for all block instances
func _setup_container():
	_block_container = Node3D.new()
	_block_container.name = "BlockContainer"
	add_child(_block_container)

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

## Convert grid coordinates to world position
func grid_to_world(grid_pos: Vector2i) -> Vector3:
	var world_x = grid_pos.x * cell_size
	var world_y = grid_pos.y * cell_size
	# Z is always 0 for 2.5D constraint
	return Vector3(world_x, world_y, 0.0)

## Place a block at the specified grid position
func place_block(grid_pos: Vector2i, block_id: String) -> bool:
	# Validate position
	if not _is_valid_position(grid_pos):
		push_warning("WorldGrid: Invalid position for block placement: %s" % grid_pos)
		return false
	
	# Check if position is already occupied
	if has_block(grid_pos):
		push_warning("WorldGrid: Position already occupied: %s" % grid_pos)
		return false
	
	# Get block resource
	var block_resource = BlockRegistry.get_block(block_id)
	if block_resource == null:
		push_error("WorldGrid: Block type not found: %s" % block_id)
		return false
	
	if not block_resource.placeable:
		push_warning("WorldGrid: Block type not placeable: %s" % block_id)
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

## Remove a block at the specified grid position
func remove_block(grid_pos: Vector2i) -> bool:
	if not has_block(grid_pos):
		push_warning("WorldGrid: No block to remove at position: %s" % grid_pos)
		return false
	
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

## Update target indicator position and visibility based on validity
func update_target_indicator(grid_pos: Vector2i, is_valid: bool):
	if _target_indicator:
		var world_pos = grid_to_world(grid_pos)
		_target_indicator.global_position = world_pos
		_target_indicator.visible = is_valid
		
		# Change color based on validity (green for valid placement, red for invalid)
		if is_valid:
			if has_block(grid_pos):
				_target_indicator.set_color(Color.RED)  # Block exists, can remove
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
	
	
	# Position the mesh instance
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

## Create collision for a block
func _create_block_collision(block_instance: BlockInstance):
	# For now, we'll use a simple box collision
	# This can be enhanced later with custom collision shapes
	var static_body = StaticBody3D.new()
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	
	box_shape.size = Vector3(cell_size, cell_size, cell_size)
	collision_shape.shape = box_shape
	static_body.add_child(collision_shape)
	
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
	
	if has_block(grid_pos):
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
	
	if not has_block(grid_pos):
		print("WorldGrid: No block to remove at %s" % grid_pos)
		return
	
	var block_id = get_block_id(grid_pos)
	
	# Attempt to remove the block
	if remove_block(grid_pos):
		GameEvents.notify_block_removed(grid_pos, block_id)
	else:
		print("WorldGrid: Failed to remove block at %s" % grid_pos)

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
