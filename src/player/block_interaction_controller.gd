extends Node
class_name BlockInteractionController

## Handles all block interaction logic: placement, removal, targeting, breaking
## Communicates with WorldGrid and manages block selection

## Block Interaction Variables
var world_grid: WorldGrid = null
var player_inventory = null
var player_node: Node3D = null
var camera: Camera3D = null

## Maximum range for block placement/removal in grid units
@export var block_interaction_range : float = 6.0
var current_targeted_block : Vector2i = Vector2i.ZERO
var has_targeted_block : bool = false
var selected_block_id : String = "grass"
var available_blocks : Array[String] = ["grass", "stone", "dirt", "snow"]
var current_block_index : int = 0

## Block breaking state
var is_breaking_block : bool = false
var breaking_target_position : Vector2i = Vector2i.ZERO

func _ready() -> void:
	# Connect to GameEvents for block management
	GameEvents.block_placed.connect(_on_block_placed)
	GameEvents.block_removed.connect(_on_block_removed)

func _physics_process(_delta: float) -> void:
	# Update block targeting
	update_block_targeting()

## Initialize block interaction system
func setup_block_interaction(player: Node3D, inventory, cam: Camera3D):
	player_node = player
	player_inventory = inventory
	camera = cam
	
	# Find or create world grid in the scene
	world_grid = player.get_node("../WorldGrid") as WorldGrid
	if world_grid == null:
		# Create world grid if it doesn't exist
		world_grid = WorldGrid.new()
		world_grid.name = "WorldGrid"
		player.get_parent().add_child(world_grid)
		print("BlockInteractionController: Created WorldGrid")
	else:
		print("BlockInteractionController: Found existing WorldGrid")
	
	# Initialize available blocks from registry
	update_available_blocks()

## Update the list of available blocks from the registry
func update_available_blocks():
	if not player_inventory or not BlockRegistry:
		return
	
	# Get blocks available in inventory
	if player_inventory.infinite_mode:
		# In infinite mode, all placeable blocks are available
		var placeable_blocks = BlockRegistry.get_placeable_blocks()
		available_blocks.clear()
		for block_resource in placeable_blocks:
			available_blocks.append(block_resource.block_id)
	else:
		# Only show blocks that the player has in inventory
		available_blocks = player_inventory.get_items_ordered()
	
	# Set initial selection
	if available_blocks.size() > 0:
		selected_block_id = available_blocks[0]
		current_block_index = 0
	
	print("BlockInteractionController: Updated available blocks: " + str(available_blocks))

## Handle block interaction input events
func handle_block_interaction_input(_event: InputEvent):
	if world_grid == null:
		return
	
	# Block placement
	if Input.is_action_just_pressed("place_block"):
		request_block_placement()
	
	# Block removal - start/stop breaking
	if Input.is_action_just_pressed("remove_block"):
		start_block_breaking()
	elif Input.is_action_just_released("remove_block"):
		stop_block_breaking()
	
	# Block selection
	if Input.is_action_just_pressed("block_selector_next"):
		cycle_selected_block(1)
	elif Input.is_action_just_pressed("block_selector_prev"):
		cycle_selected_block(-1)
	
	# Hotkey selection
	for i in range(1, 6):  # Hotkeys 1-5
		var action_name = "block_hotkey_%d" % i
		if Input.is_action_just_pressed(action_name):
			select_block_by_index(i - 1)

## Update block targeting based on mouse cursor position (Terraria-style)
func update_block_targeting():
	if world_grid == null or camera == null or player_node == null:
		has_targeted_block = false
		if world_grid:
			world_grid.hide_target_indicator()
		return
	
	# Get mouse position in screen coordinates
	var mouse_pos = player_node.get_viewport().get_mouse_position()
	
	# Convert mouse position to world position using camera projection
	var world_pos = camera.project_position(mouse_pos, camera.global_position.distance_to(player_node.global_position))
	
	# Convert world position to grid coordinates (2.5D constraint)
	var grid_target = world_grid.world_to_grid(Vector3(world_pos.x, world_pos.y, 0))
	
	# Check if target is within interaction range
	var target_world_pos = world_grid.grid_to_world(grid_target)
	var distance_to_target = player_node.global_position.distance_to(target_world_pos)
	
	if distance_to_target <= block_interaction_range:
		# Check if target changed while breaking
		if is_breaking_block and breaking_target_position != grid_target:
			stop_block_breaking()
		
		current_targeted_block = grid_target
		has_targeted_block = true
		
		# Update WorldGrid's target indicator
		world_grid.update_target_indicator(grid_target, true)
	else:
		# Cancel breaking if target is lost
		if is_breaking_block:
			stop_block_breaking()
		
		has_targeted_block = false
		
		# Hide WorldGrid's target indicator
		world_grid.hide_target_indicator()

## Request block placement at the currently targeted position
func request_block_placement():
	if not has_targeted_block:
		return
	
	if selected_block_id.is_empty():
		push_warning("BlockInteractionController: No block type selected")
		return
	
	# Check if player has the item in inventory
	if not player_inventory.has_item(selected_block_id, 1):
		print("BlockInteractionController: No %s blocks in inventory" % selected_block_id)
		return
	
	# Check if we're trying to place inside the player (minimum distance check)
	var target_world_pos = world_grid.grid_to_world(current_targeted_block)
	if player_node.global_position.distance_to(target_world_pos) < 0.5:  # Player collision radius
		return  # Too close to player
	
	# Request placement via event system
	GameEvents.request_block_placement(current_targeted_block, selected_block_id)

## Start breaking block at the currently targeted position
func start_block_breaking():
	if not has_targeted_block:
		return
	
	# Check if there's actually a block to break
	if not world_grid.has_block(current_targeted_block):
		return
	
	# Start breaking process
	is_breaking_block = true
	breaking_target_position = current_targeted_block
	
	# Request breaking start via event system
	GameEvents.request_block_breaking_start(current_targeted_block)
	print("BlockInteractionController: Started breaking block at %s" % current_targeted_block)

## Stop breaking block (cancels the breaking process)
func stop_block_breaking():
	if not is_breaking_block:
		return
	
	# Stop breaking process
	is_breaking_block = false
	
	# Request breaking stop via event system
	GameEvents.request_block_breaking_stop(breaking_target_position)
	print("BlockInteractionController: Stopped breaking block at %s" % breaking_target_position)
	
	breaking_target_position = Vector2i.ZERO

## Request block removal at the currently targeted position (kept for compatibility)
func request_block_removal():
	if not has_targeted_block:
		return
	
	# Request removal via event system
	GameEvents.request_block_removal(current_targeted_block)

## Cycle through available block types
func cycle_selected_block(direction: int):
	if available_blocks.size() == 0:
		return
	
	current_block_index = (current_block_index + direction) % available_blocks.size()
	if current_block_index < 0:
		current_block_index = available_blocks.size() - 1
	
	selected_block_id = available_blocks[current_block_index]
	print("BlockInteractionController: Selected block: %s (%d/%d)" % [selected_block_id, current_block_index + 1, available_blocks.size()])
	
	# Notify via events
	GameEvents.notify_player_selected_block_changed(selected_block_id, current_block_index)

## Select a block by index in the available blocks array
func select_block_by_index(index: int):
	if index < 0 or index >= available_blocks.size():
		return
	
	current_block_index = index
	selected_block_id = available_blocks[current_block_index]
	print("BlockInteractionController: Selected block: %s (%d/%d)" % [selected_block_id, current_block_index + 1, available_blocks.size()])
	
	# Notify via events
	GameEvents.notify_player_selected_block_changed(selected_block_id, current_block_index)

## Get the currently selected block type
func get_selected_block() -> String:
	return selected_block_id

## Get the currently targeted block position
func get_targeted_block_position() -> Vector2i:
	return current_targeted_block if has_targeted_block else Vector2i.ZERO

## Check if we have a valid block target
func has_block_target() -> bool:
	return has_targeted_block

## Handle block placement events (for inventory management)
func _on_block_placed(_grid_pos: Vector2i, block_id: String):
	# Remove item from inventory (unless in infinite mode)
	player_inventory.remove_item(block_id, 1)
	print("BlockInteractionController: Inventory updated after placing %s block" % block_id)
	
	# Update available blocks if inventory changed
	if not player_inventory.infinite_mode:
		update_available_blocks()
	
	# Notify via events
	GameEvents.notify_item_removed_from_inventory(block_id, 1)

## Handle block removal events (for inventory management)
func _on_block_removed(_grid_pos: Vector2i, block_id: String):
	# Add item to inventory
	var added_quantity = player_inventory.add_item(block_id, 1)
	if added_quantity > 0:
		print("BlockInteractionController: Added %s block to inventory after removal" % block_id)
	else:
		print("BlockInteractionController: Could not add %s block to inventory (full)" % block_id)
	
	# Update available blocks if inventory changed
	if not player_inventory.infinite_mode:
		update_available_blocks()
	
	# Notify via events
	GameEvents.notify_item_added_to_inventory(block_id, added_quantity)
