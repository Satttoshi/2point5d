extends CharacterBody3D

## Can we move around?
@export var can_move : bool = true
## Are we affected by gravity?
@export var has_gravity : bool = true
## Can we press to jump?
@export var can_jump : bool = true
## Can we hold to run?
@export var can_sprint : bool = false
## Can we press to enter freefly mode (noclip)?
@export var can_freefly : bool = false

@export_group("Speeds")
## Look around rotation speed.
@export var look_speed : float = 0.002
## Normal speed.
@export var base_speed : float = 5
## Speed of jump.
@export var jump_velocity : float = 20
## Gravity multiplier for snappier jumps.
@export var gravity_multiplier : float = 5
## How fast do we run?
@export var sprint_speed : float = 10.0
## How fast do we freefly?
@export var freefly_speed : float = 25.0

@export_group("Camera Follow")
## How fast the camera follows the player.
@export var camera_follow_speed : float = 18
## Minimum distance before camera starts following.
@export var camera_deadzone : float = 0.3
## Camera offset from player position.
@export var camera_offset : Vector3 = Vector3(0, 2, 5)
## Enable smooth camera following.
@export var smooth_camera : bool = true
## Bezier curve easing strength (0.0 = linear, 1.0 = strong curve).
@export_range(0.0, 1.0) var camera_easing_strength : float = 0.6
## Camera acceleration curve (how quickly it starts moving).
@export_range(0.1, 3.0) var camera_acceleration_curve : float = 1.2
## Camera deceleration curve (how smoothly it stops).
@export_range(0.1, 3.0) var camera_deceleration_curve : float = 1.8

@export_group("Input Actions")
## Name of Input Action to move Left.
@export var input_left : String = "ui_left"
## Name of Input Action to move Right.
@export var input_right : String = "ui_right"
## Name of Input Action to move Up (Y-axis in freefly mode only).
@export var input_up : String = "ui_up"
## Name of Input Action to move Down (Y-axis in freefly mode only).
@export var input_down : String = "ui_down"
## Name of Input Action to Jump.
@export var input_jump : String = "ui_accept"
## Name of Input Action to Sprint.
@export var input_sprint : String = "sprint"
## Name of Input Action to toggle freefly mode.
@export var input_freefly : String = "freefly"

var move_speed : float = 0.0
var freeflying : bool = false
var camera_target_position : Vector3
var camera_velocity : Vector3 = Vector3.ZERO

## Block Interaction Variables
var world_grid: WorldGrid = null
var player_inventory: Inventory = null
## Maximum range for block placement/removal in grid units
@export var block_interaction_range : float = 6.0
var current_targeted_block : Vector2i = Vector2i.ZERO
var has_targeted_block : bool = false
var selected_block_id : String = "grass"
var available_blocks : Array[String] = ["grass", "stone", "dirt"]
var current_block_index : int = 0
## Camera reference for mouse to world conversion
var camera: Camera3D = null

## IMPORTANT REFERENCES
@onready var head: Node3D = $Head
@onready var collider: CollisionShape3D = $Collider

func _ready() -> void:
	check_input_mappings()
	# Initialize camera target position
	camera_target_position = global_position + camera_offset
	# Setup third-person camera position
	head.position = camera_offset
	head.rotation = Vector3(deg_to_rad(-15), 0, 0)
	
	# Get camera reference for mouse targeting
	camera = head.get_node("Camera3D") if head.has_node("Camera3D") else null
	if camera == null:
		# Create camera if it doesn't exist
		camera = Camera3D.new()
		camera.name = "Camera3D"
		head.add_child(camera)
		print("ProtoController: Created camera for block targeting")
	else:
		print("ProtoController: Found existing camera for block targeting")
	
	# Setup block interaction
	setup_block_interaction()

func _unhandled_input(event: InputEvent) -> void:
	
	# Toggle freefly mode
	if can_freefly and Input.is_action_just_pressed(input_freefly):
		if not freeflying:
			enable_freefly()
		else:
			disable_freefly()
	
	# Block interaction input
	handle_block_interaction_input(event)

func _physics_process(delta: float) -> void:
	# If freeflying, handle freefly with X and Y axis movement
	if can_freefly and freeflying:
		var input_x := Input.get_action_strength(input_right) - Input.get_action_strength(input_left)
		var input_y := Input.get_action_strength(input_up) - Input.get_action_strength(input_down)
		var motion := Vector3(input_x, input_y, 0).normalized()
		motion *= freefly_speed * delta
		move_and_collide(motion)
		return
	
	# Apply gravity to velocity
	if has_gravity:
		if not is_on_floor():
			velocity += get_gravity() * gravity_multiplier * delta

	# Apply jumping
	if can_jump:
		if Input.is_action_just_pressed(input_jump) and is_on_floor():
			velocity.y = jump_velocity

	# Modify speed based on sprinting
	if can_sprint and Input.is_action_pressed(input_sprint):
			move_speed = sprint_speed
	else:
		move_speed = base_speed

	# Apply desired movement to velocity
	if can_move:
		var input_x := Input.get_action_strength(input_right) - Input.get_action_strength(input_left)
		# Only use X-axis movement, no Z-axis for 2D sidescroller
		if input_x != 0:
			velocity.x = input_x * move_speed
		else:
			velocity.x = move_toward(velocity.x, 0, move_speed)
		# Always keep Z velocity at 0 for 2D constraint
		velocity.z = 0
	else:
		velocity.x = 0
		velocity.z = 0
	
	# Use velocity to actually move
	move_and_slide()
	
	# Update camera follow (skip in freefly mode)
	if smooth_camera and not freeflying:
		update_camera_follow(delta)
	
	# Update block targeting
	update_block_targeting()



func update_camera_follow(delta: float):
	# Calculate desired camera position
	var desired_position = global_position + camera_offset
	
	# Calculate distance from current camera target to desired position
	var distance = camera_target_position.distance_to(desired_position)
	
	# Only move camera if outside deadzone
	if distance > camera_deadzone:
		# Calculate the direction vector
		var direction = (desired_position - camera_target_position).normalized()
		
		# Apply bezier curve smoothing using custom easing
		var distance_factor = distance / (distance + camera_deadzone)
		var speed_factor = camera_follow_speed * delta
		
		# Create bezier-like curve with acceleration and deceleration
		var t = clamp(speed_factor, 0.0, 1.0)
		var bezier_factor = bezier_ease(t, camera_easing_strength, camera_acceleration_curve, camera_deceleration_curve)
		
		# Update camera velocity with smooth acceleration/deceleration
		var target_velocity = direction * distance * camera_follow_speed * bezier_factor
		camera_velocity = camera_velocity.lerp(target_velocity, 0.1)
		
		# Apply velocity to camera position
		camera_target_position += camera_velocity * delta
		
		# Prevent overshooting
		if camera_target_position.distance_to(desired_position) < 0.1:
			camera_target_position = desired_position
			camera_velocity = Vector3.ZERO
	else:
		# Gradual deceleration when within deadzone
		camera_velocity = camera_velocity.lerp(Vector3.ZERO, 0.2)
		camera_target_position += camera_velocity * delta
	
	# Apply the smooth position to the camera head
	head.global_position = camera_target_position

## Custom bezier-like easing function for smooth camera movement
func bezier_ease(t: float, strength: float, accel_curve: float, decel_curve: float) -> float:
	# Normalize t to 0-1 range
	t = clamp(t, 0.0, 1.0)
	
	# Create control points for bezier curve
	var p1 = 0.0 + (strength * 0.3) / accel_curve
	var p2 = 1.0 - (strength * 0.3) / decel_curve
	
	# Cubic bezier calculation with custom control points
	var u = 1.0 - t
	var result = u * u * u * 0.0 + 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t * 1.0
	
	# Apply additional smoothing based on easing strength
	if strength > 0.0:
		result = lerp(t, result, strength)
	
	return result

func enable_freefly():
	collider.disabled = true
	freeflying = true
	velocity = Vector3.ZERO

func disable_freefly():
	collider.disabled = false
	freeflying = false


## Initialize block interaction system
func setup_block_interaction():
	# Find or create world grid in the scene
	world_grid = get_node("../WorldGrid") as WorldGrid
	if world_grid == null:
		# Create world grid if it doesn't exist
		world_grid = WorldGrid.new()
		world_grid.name = "WorldGrid"
		get_parent().add_child(world_grid)
		print("ProtoController: Created WorldGrid")
	else:
		print("ProtoController: Found existing WorldGrid")
	
	# Create player inventory
	var inventory_script = preload("res://scripts/inventory.gd")
	player_inventory = inventory_script.new()
	player_inventory.name = "PlayerInventory"
	add_child(player_inventory)
	
	# Give starter items in creative mode, or enable infinite mode for testing
	player_inventory.set_infinite_mode(true)  # Enable for testing - can be changed later
	if not player_inventory.infinite_mode:
		player_inventory.give_starter_items()
	
	print("ProtoController: Created player inventory")
	
	# Connect to GameEvents for inventory management
	GameEvents.block_placed.connect(_on_block_placed)
	GameEvents.block_removed.connect(_on_block_removed)
	
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
	
	print("ProtoController: Updated available blocks: " + str(available_blocks))

## Handle block interaction input events
func handle_block_interaction_input(event: InputEvent):
	if world_grid == null:
		return
	
	# Block placement
	if Input.is_action_just_pressed("place_block"):
		request_block_placement()
	
	# Block removal
	if Input.is_action_just_pressed("remove_block"):
		request_block_removal()
	
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
	if world_grid == null or camera == null:
		has_targeted_block = false
		if world_grid:
			world_grid.hide_target_indicator()
		return
	
	# Get mouse position in screen coordinates
	var mouse_pos = get_viewport().get_mouse_position()
	
	# Convert mouse position to world position using camera projection
	var world_pos = camera.project_position(mouse_pos, camera.global_position.distance_to(global_position))
	
	# Convert world position to grid coordinates (2.5D constraint)
	var grid_target = world_grid.world_to_grid(Vector3(world_pos.x, world_pos.y, 0))
	
	# Check if target is within interaction range
	var target_world_pos = world_grid.grid_to_world(grid_target)
	var distance_to_target = global_position.distance_to(target_world_pos)
	
	if distance_to_target <= block_interaction_range:
		current_targeted_block = grid_target
		has_targeted_block = true
		
		# Update WorldGrid's target indicator
		world_grid.update_target_indicator(grid_target, true)
	else:
		has_targeted_block = false
		
		# Hide WorldGrid's target indicator
		world_grid.hide_target_indicator()

## Request block placement at the currently targeted position
func request_block_placement():
	if not has_targeted_block:
		return
	
	if selected_block_id.is_empty():
		push_warning("ProtoController: No block type selected")
		return
	
	# Check if player has the item in inventory
	if not player_inventory.has_item(selected_block_id, 1):
		print("ProtoController: No %s blocks in inventory" % selected_block_id)
		return
	
	# Check if we're trying to place inside the player (minimum distance check)
	var target_world_pos = world_grid.grid_to_world(current_targeted_block)
	if global_position.distance_to(target_world_pos) < 0.5:  # Player collision radius
		return  # Too close to player
	
	# Request placement via event system
	GameEvents.request_block_placement(current_targeted_block, selected_block_id)

## Request block removal at the currently targeted position
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
	print("ProtoController: Selected block: %s (%d/%d)" % [selected_block_id, current_block_index + 1, available_blocks.size()])
	
	# Notify via events
	GameEvents.notify_player_selected_block_changed(selected_block_id, current_block_index)

## Select a block by index in the available blocks array
func select_block_by_index(index: int):
	if index < 0 or index >= available_blocks.size():
		return
	
	current_block_index = index
	selected_block_id = available_blocks[current_block_index]
	print("ProtoController: Selected block: %s (%d/%d)" % [selected_block_id, current_block_index + 1, available_blocks.size()])
	
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
func _on_block_placed(grid_pos: Vector2i, block_id: String):
	# Remove item from inventory (unless in infinite mode)
	player_inventory.remove_item(block_id, 1)
	print("ProtoController: Inventory updated after placing %s block" % block_id)
	
	# Update available blocks if inventory changed
	if not player_inventory.infinite_mode:
		update_available_blocks()
	
	# Notify via events
	GameEvents.notify_item_removed_from_inventory(block_id, 1)

## Handle block removal events (for inventory management)
func _on_block_removed(grid_pos: Vector2i, block_id: String):
	# Add item to inventory
	var added_quantity = player_inventory.add_item(block_id, 1)
	if added_quantity > 0:
		print("ProtoController: Added %s block to inventory after removal" % block_id)
	else:
		print("ProtoController: Could not add %s block to inventory (full)" % block_id)
	
	# Update available blocks if inventory changed
	if not player_inventory.infinite_mode:
		update_available_blocks()
	
	# Notify via events
	GameEvents.notify_item_added_to_inventory(block_id, added_quantity)

## Checks if some Input Actions haven't been created.
## Disables functionality accordingly.
func check_input_mappings():
	if can_move and not InputMap.has_action(input_left):
		push_error("Movement disabled. No InputAction found for input_left: " + input_left)
		can_move = false
	if can_move and not InputMap.has_action(input_right):
		push_error("Movement disabled. No InputAction found for input_right: " + input_right)
		can_move = false
	if can_freefly and not InputMap.has_action(input_up):
		push_error("Freefly Y-axis disabled. No InputAction found for input_up: " + input_up)
		# Don't disable freefly completely, just warn
	if can_freefly and not InputMap.has_action(input_down):
		push_error("Freefly Y-axis disabled. No InputAction found for input_down: " + input_down)
		# Don't disable freefly completely, just warn
	if can_jump and not InputMap.has_action(input_jump):
		push_error("Jumping disabled. No InputAction found for input_jump: " + input_jump)
		can_jump = false
	if can_sprint and not InputMap.has_action(input_sprint):
		push_error("Sprinting disabled. No InputAction found for input_sprint: " + input_sprint)
		can_sprint = false
	if can_freefly and not InputMap.has_action(input_freefly):
		push_error("Freefly disabled. No InputAction found for input_freefly: " + input_freefly)
		can_freefly = false
