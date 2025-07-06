extends Node
class_name InputController

## Handles input validation and processing for player actions
## Validates input mappings and manages input state

@export_group("Input Actions")
## Name of Input Action to move Left.
@export var input_left : String = "move_left"
## Name of Input Action to move Right.
@export var input_right : String = "move_right"
## Name of Input Action to move Up (Y-axis in freefly mode only).
@export var input_up : String = "move_up"
## Name of Input Action to move Down (Y-axis in freefly mode only).
@export var input_down : String = "move_down"
## Name of Input Action to Jump.
@export var input_jump : String = "jump"
## Name of Input Action to Sprint.
@export var input_sprint : String = "sprint"
## Name of Input Action to toggle freefly mode.
@export var input_freefly : String = "freefly"

## Input state
var input_enabled : bool = true
var movement_input : Vector2 = Vector2.ZERO
var jump_pressed : bool = false
var sprint_pressed : bool = false
var freefly_pressed : bool = false

## Capability flags (set based on input mapping validation)
var can_move : bool = true
var can_jump : bool = true
var can_sprint : bool = true
var can_freefly : bool = true

func _ready() -> void:
	check_input_mappings()

func _input(_event: InputEvent) -> void:
	if not input_enabled:
		return
	
	# Update input state
	update_input_state()

## Update input state based on current input actions
func update_input_state():
	# Movement input
	if can_move:
		var input_x := Input.get_action_strength(input_right) - Input.get_action_strength(input_left)
		var input_y := Input.get_action_strength(input_up) - Input.get_action_strength(input_down)
		movement_input = Vector2(input_x, input_y)
	else:
		movement_input = Vector2.ZERO
	
	# Action inputs
	jump_pressed = can_jump and Input.is_action_just_pressed(input_jump)
	sprint_pressed = can_sprint and Input.is_action_pressed(input_sprint)
	freefly_pressed = can_freefly and Input.is_action_just_pressed(input_freefly)

## Get normalized movement input vector
func get_movement_input() -> Vector2:
	return movement_input

## Check if jump was just pressed
func is_jump_pressed() -> bool:
	return jump_pressed

## Check if sprint is being held
func is_sprint_pressed() -> bool:
	return sprint_pressed

## Check if freefly toggle was just pressed
func is_freefly_pressed() -> bool:
	return freefly_pressed

## Enable input processing
func enable_input() -> void:
	input_enabled = true

## Disable input processing
func disable_input() -> void:
	input_enabled = false
	movement_input = Vector2.ZERO
	jump_pressed = false
	sprint_pressed = false
	freefly_pressed = false

## Checks if some Input Actions haven't been created.
## Disables functionality accordingly.
func check_input_mappings():
	if not InputMap.has_action(input_left):
		push_error("Movement disabled. No InputAction found for input_left: " + input_left)
		can_move = false
	if not InputMap.has_action(input_right):
		push_error("Movement disabled. No InputAction found for input_right: " + input_right)
		can_move = false
	if not InputMap.has_action(input_up):
		push_error("Freefly Y-axis disabled. No InputAction found for input_up: " + input_up)
		# Don't disable freefly completely, just warn
	if not InputMap.has_action(input_down):
		push_error("Freefly Y-axis disabled. No InputAction found for input_down: " + input_down)
		# Don't disable freefly completely, just warn
	if not InputMap.has_action(input_jump):
		push_error("Jumping disabled. No InputAction found for input_jump: " + input_jump)
		can_jump = false
	if not InputMap.has_action(input_sprint):
		push_error("Sprinting disabled. No InputAction found for input_sprint: " + input_sprint)
		can_sprint = false
	if not InputMap.has_action(input_freefly):
		push_error("Freefly disabled. No InputAction found for input_freefly: " + input_freefly)
		can_freefly = false

## Get capability flags
func get_capabilities() -> Dictionary:
	return {
		"can_move": can_move,
		"can_jump": can_jump,
		"can_sprint": can_sprint,
		"can_freefly": can_freefly
	}
