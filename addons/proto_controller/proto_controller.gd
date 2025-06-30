# ProtoController v1.0 by Brackeys
# CC0 License
# Intended for rapid prototyping of first-person games.
# Happy prototyping!

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

## IMPORTANT REFERENCES
@onready var head: Node3D = $Head
@onready var collider: CollisionShape3D = $Collider

func _ready() -> void:
	check_input_mappings()
	# Setup third-person camera position
	head.position = Vector3(0, 2, 5)
	head.rotation = Vector3(deg_to_rad(-15), 0, 0)

func _unhandled_input(event: InputEvent) -> void:
	
	# Toggle freefly mode
	if can_freefly and Input.is_action_just_pressed(input_freefly):
		if not freeflying:
			enable_freefly()
		else:
			disable_freefly()

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



func enable_freefly():
	collider.disabled = true
	freeflying = true
	velocity = Vector3.ZERO

func disable_freefly():
	collider.disabled = false
	freeflying = false




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
