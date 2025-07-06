extends CharacterBody3D
class_name PlayerController

## Main player controller that coordinates movement, camera, and interactions
## Uses modular components for clean separation of concerns

@export_group("Movement Settings")
## Are we affected by gravity?
@export var has_gravity : bool = true
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

## Movement state
var move_speed : float = 0.0
var freeflying : bool = false

## Component references
var input_controller: InputController
var camera_controller: CameraController
var block_interaction_controller: BlockInteractionController
var player_inventory

## IMPORTANT REFERENCES
@onready var collider: CollisionShape3D = $Collider
@onready var head: Node3D = $Head

func _ready() -> void:
	# Configure collision layers for proper physics interactions
	collision_layer = 2  # Layer 2: Player
	collision_mask = 1   # Mask 1: Static World (blocks, terrain)
	
	# Initialize components
	setup_components()
	
	# Setup player inventory
	setup_inventory()
	
	print("PlayerController: Initialized with modular components")

func _unhandled_input(event: InputEvent) -> void:
	if not input_controller:
		return
	
	# Handle freefly toggle
	if input_controller.is_freefly_pressed():
		if not freeflying:
			enable_freefly()
		else:
			disable_freefly()
	
	# Handle block interaction input
	if block_interaction_controller:
		block_interaction_controller.handle_block_interaction_input(event)

func _physics_process(delta: float) -> void:
	if not input_controller:
		return
	
	# Update input state
	input_controller.update_input_state()
	var movement_input = input_controller.get_movement_input()
	
	# Handle freefly movement
	if freeflying:
		handle_freefly_movement(movement_input, delta)
		return
	
	# Handle normal movement
	handle_normal_movement(movement_input, delta)
	
	# Use velocity to actually move
	move_and_slide()
	
	# Enforce physics-based Z-axis constraint after collision resolution
	_enforce_z_axis_constraint()

## Setup all modular components
func setup_components():
	# Create input controller
	input_controller = InputController.new()
	input_controller.name = "InputController"
	add_child(input_controller)
	
	# Create camera controller
	camera_controller = CameraController.new()
	camera_controller.name = "CameraController"
	add_child(camera_controller)
	camera_controller.setup_camera(head)
	camera_controller.set_target(self)
	
	# Create block interaction controller
	block_interaction_controller = BlockInteractionController.new()
	block_interaction_controller.name = "BlockInteractionController"
	add_child(block_interaction_controller)

## Setup player inventory
func setup_inventory():
	# Create player inventory
	var inventory_script = preload("res://src/player/inventory_system.gd")
	player_inventory = inventory_script.new()
	player_inventory.name = "PlayerInventory"
	add_child(player_inventory)
	
	# Give starter items in creative mode, or enable infinite mode for testing
	player_inventory.set_infinite_mode(true)  # Enable for testing - can be changed later
	if not player_inventory.infinite_mode:
		player_inventory.give_starter_items()
	
	print("PlayerController: Created player inventory")
	
	# Setup block interaction with camera reference
	if camera_controller and block_interaction_controller:
		block_interaction_controller.setup_block_interaction(self, player_inventory, camera_controller.get_camera())

## Handle freefly movement (no collision, free movement in all axes)
func handle_freefly_movement(movement_input: Vector2, delta: float):
	var motion := Vector3(movement_input.x, movement_input.y, 0).normalized()
	motion *= freefly_speed * delta
	move_and_collide(motion)

## Handle normal movement (gravity, jumping, 2.5D constraints)
func handle_normal_movement(movement_input: Vector2, delta: float):
	var capabilities = input_controller.get_capabilities()
	
	# Apply gravity to velocity
	if has_gravity:
		if not is_on_floor():
			velocity += get_gravity() * gravity_multiplier * delta

	# Apply jumping
	if capabilities.can_jump and input_controller.is_jump_pressed() and is_on_floor():
		velocity.y = jump_velocity

	# Modify speed based on sprinting
	if capabilities.can_sprint and input_controller.is_sprint_pressed():
		move_speed = sprint_speed
	else:
		move_speed = base_speed

	# Apply desired movement to velocity
	if capabilities.can_move:
		# Only use X-axis movement, no Z-axis for 2D sidescroller
		if movement_input.x != 0:
			velocity.x = movement_input.x * move_speed
		else:
			velocity.x = move_toward(velocity.x, 0, move_speed)
		# Always keep Z velocity at 0 for 2D constraint
		velocity.z = 0
	else:
		velocity.x = 0
		velocity.z = 0

## Enable freefly mode
func enable_freefly():
	collider.disabled = true
	freeflying = true
	velocity = Vector3.ZERO
	if camera_controller:
		camera_controller.disable_follow()

## Disable freefly mode
func disable_freefly():
	collider.disabled = false
	freeflying = false
	if camera_controller:
		camera_controller.enable_follow()

## Enforce Z-axis constraint using physics-based correction
## This ensures the player stays on the 2D plane even with external forces
func _enforce_z_axis_constraint():
	# Skip constraint in freefly mode
	if freeflying:
		return
	
	# Force position to Z=0 with physics correction
	if global_position.z != 0.0:
		# Use a strong correction force to snap back to Z=0
		var z_offset = global_position.z
		global_position.z = 0.0
		
		# Also ensure velocity doesn't accumulate in Z direction
		velocity.z = 0.0
		
		# Log significant Z-axis deviations for debugging
		if abs(z_offset) > 0.01:
			print("PlayerController: Z-axis constraint applied, corrected offset: %f" % z_offset)
	
	# Ensure velocity stays constrained to 2D plane
	if velocity.z != 0.0:
		velocity.z = 0.0

## Get player inventory reference
func get_inventory():
	return player_inventory

## Get camera reference for external use
func get_camera() -> Camera3D:
	return camera_controller.get_camera() if camera_controller else null

## Get block interaction controller reference
func get_block_interaction_controller() -> BlockInteractionController:
	return block_interaction_controller

## Get currently selected block
func get_selected_block() -> String:
	return block_interaction_controller.get_selected_block() if block_interaction_controller else ""

## Get currently targeted block position
func get_targeted_block_position() -> Vector2i:
	return block_interaction_controller.get_targeted_block_position() if block_interaction_controller else Vector2i.ZERO

## Check if we have a valid block target
func has_block_target() -> bool:
	return block_interaction_controller.has_block_target() if block_interaction_controller else false
