extends Node3D
class_name CameraController

## Third-person camera controller with smooth following and bezier easing
## Handles camera positioning, movement, and smooth transitions

@export_group("Camera Follow")
## How fast the camera follows the player.
@export var camera_follow_speed : float = 18
## Minimum distance before camera starts following.
@export var camera_deadzone : float = 0.3
## Camera offset from player position.
@export var camera_offset : Vector3 = Vector3(0, 4, 10)
## Enable smooth camera following.
@export var smooth_camera : bool = true
## Bezier curve easing strength (0.0 = linear, 1.0 = strong curve).
@export_range(0.0, 1.0) var camera_easing_strength : float = 0.6
## Camera acceleration curve (how quickly it starts moving).
@export_range(0.1, 3.0) var camera_acceleration_curve : float = 1.2
## Camera deceleration curve (how smoothly it stops).
@export_range(0.1, 3.0) var camera_deceleration_curve : float = 1.8

## Internal camera state
var camera_target_position : Vector3
var camera_velocity : Vector3 = Vector3.ZERO
var target_node : Node3D
var camera: Camera3D

## Head node that holds the camera (will be set by parent)
var head: Node3D
var is_setup_complete: bool = false

func _ready() -> void:
	# Setup will be called by the player controller
	pass

## Setup the camera controller with a reference to the head node
func setup_camera(head_node: Node3D) -> void:
	head = head_node
	
	# Initialize camera target position
	camera_target_position = global_position + camera_offset
	
	# Setup third-person camera position
	head.position = camera_offset
	head.rotation = Vector3(deg_to_rad(-15), 0, 0)
	
	# Get or create camera reference
	camera = head.get_node("Camera3D") if head.has_node("Camera3D") else null
	if camera == null:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		head.add_child(camera)
		print("CameraController: Created camera")
	else:
		print("CameraController: Found existing camera")
	
	is_setup_complete = true

func _physics_process(delta: float) -> void:
	if smooth_camera and target_node and is_setup_complete:
		update_camera_follow(delta)

## Set the target node for the camera to follow
func set_target(node: Node3D) -> void:
	target_node = node
	if target_node:
		camera_target_position = target_node.global_position + camera_offset

## Update camera following with smooth bezier easing
func update_camera_follow(delta: float):
	if not target_node:
		return
	
	# Calculate desired camera position
	var desired_position: Vector3 = target_node.global_position + camera_offset
	
	# Calculate distance from current camera target to desired position
	var distance: float = camera_target_position.distance_to(desired_position)
	
	# Only move camera if outside deadzone
	if distance > camera_deadzone:
		# Calculate the direction vector
		var direction: Vector3 = (desired_position - camera_target_position).normalized()
		
		# Apply bezier curve smoothing using custom easing
		var _distance_factor: float = distance / (distance + camera_deadzone)
		var speed_factor: float = camera_follow_speed * delta
		
		# Create bezier-like curve with acceleration and deceleration
		var t = clamp(speed_factor, 0.0, 1.0)
		var bezier_factor: float = bezier_ease(t, camera_easing_strength, camera_acceleration_curve, camera_deceleration_curve)
		
		# Update camera velocity with smooth acceleration/deceleration
		var target_velocity: Vector3 = direction * distance * camera_follow_speed * bezier_factor
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
	var p1: float = 0.0 + (strength * 0.3) / accel_curve
	var p2: float = 1.0 - (strength * 0.3) / decel_curve
	
	# Cubic bezier calculation with custom control points
	var u: float = 1.0 - t
	var result = u * u * u * 0.0 + 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t * 1.0
	
	# Apply additional smoothing based on easing strength
	if strength > 0.0:
		result = lerp(t, result, strength)
	
	return result

## Get the camera reference for external use
func get_camera() -> Camera3D:
	return camera if is_setup_complete else null

## Enable camera following
func enable_follow() -> void:
	smooth_camera = true

## Disable camera following
func disable_follow() -> void:
	smooth_camera = false
	camera_velocity = Vector3.ZERO
