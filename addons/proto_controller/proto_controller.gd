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
	
	# Update camera follow (skip in freefly mode)
	if smooth_camera and not freeflying:
		update_camera_follow(delta)



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
