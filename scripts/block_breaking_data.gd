class_name BlockBreakingData
extends Resource

## Data structure for tracking block breaking progress
## Manages breaking state, damage accumulation, and visual feedback stages
## Designed to be easily serializable for multiplayer synchronization

@export var grid_position: Vector2i
@export var block_id: String
@export var total_break_time: float
@export var time_remaining: float
@export var current_damage: float  # 0.0 to 1.0 (percentage)
@export var break_stage: int  # 0-4 (visual damage stages)
@export var is_breaking: bool = false

## Create new breaking data for a block
func _init(pos: Vector2i = Vector2i.ZERO, id: String = "", break_time: float = 1.0):
	grid_position = pos
	block_id = id
	total_break_time = break_time
	time_remaining = break_time
	current_damage = 0.0
	break_stage = 0
	is_breaking = false

## Start breaking process
func start_breaking():
	is_breaking = true
	current_damage = 0.0
	break_stage = 0
	time_remaining = total_break_time
	print("BlockBreakingData: Started breaking %s at %s (%.1fs)" % [block_id, grid_position, total_break_time])

## Update breaking progress with delta time
## Returns true if block should be destroyed
func update_breaking(delta: float) -> bool:
	if not is_breaking:
		return false
	
	time_remaining -= delta
	current_damage = 1.0 - (time_remaining / total_break_time)
	current_damage = clamp(current_damage, 0.0, 1.0)
	
	# Calculate break stage (0-4 based on damage percentage)
	var new_break_stage = int(current_damage * 5.0)
	new_break_stage = clamp(new_break_stage, 0, 4)
	
	# Emit event if break stage changed
	if new_break_stage != break_stage:
		break_stage = new_break_stage
		GameEvents.notify_block_break_progress(grid_position, current_damage, break_stage)
	
	# Check if breaking is complete
	if time_remaining <= 0.0:
		complete_breaking()
		return true
	
	return false

## Complete the breaking process
func complete_breaking():
	is_breaking = false
	current_damage = 1.0
	break_stage = 4
	time_remaining = 0.0
	print("BlockBreakingData: Completed breaking %s at %s" % [block_id, grid_position])

## Cancel the breaking process
func cancel_breaking():
	is_breaking = false
	current_damage = 0.0
	break_stage = 0
	time_remaining = total_break_time
	print("BlockBreakingData: Cancelled breaking %s at %s" % [block_id, grid_position])

## Reset breaking progress without canceling
func reset_progress():
	current_damage = 0.0
	break_stage = 0
	time_remaining = total_break_time

## Get damage percentage (0.0 to 1.0)
func get_damage_percent() -> float:
	return current_damage

## Get current break stage (0-4)
func get_break_stage() -> int:
	return break_stage

## Get time remaining in seconds
func get_time_remaining() -> float:
	return time_remaining

## Check if breaking is in progress
func is_currently_breaking() -> bool:
	return is_breaking

## Get progress percentage (0.0 to 1.0)
func get_progress_percent() -> float:
	if total_break_time <= 0.0:
		return 1.0
	return 1.0 - (time_remaining / total_break_time)

## Get visual break stage name for debugging
func get_break_stage_name() -> String:
	match break_stage:
		0: return "Intact"
		1: return "Light Damage"
		2: return "Medium Damage"
		3: return "Heavy Damage"
		4: return "About to Break"
		_: return "Unknown"

## Get break stage color for visual feedback
func get_break_stage_color() -> Color:
	match break_stage:
		0: return Color.WHITE
		1: return Color.YELLOW
		2: return Color.ORANGE
		3: return Color.RED
		4: return Color.DARK_RED
		_: return Color.WHITE

## Create a copy of this breaking data
func duplicate_data() -> BlockBreakingData:
	var copy = BlockBreakingData.new(grid_position, block_id, total_break_time)
	copy.time_remaining = time_remaining
	copy.current_damage = current_damage
	copy.break_stage = break_stage
	copy.is_breaking = is_breaking
	return copy

## Serialize to dictionary for network/save data
func to_dict() -> Dictionary:
	return {
		"grid_position": [grid_position.x, grid_position.y],
		"block_id": block_id,
		"total_break_time": total_break_time,
		"time_remaining": time_remaining,
		"current_damage": current_damage,
		"break_stage": break_stage,
		"is_breaking": is_breaking
	}

## Deserialize from dictionary
func from_dict(data: Dictionary):
	if data.has("grid_position"):
		var pos_array = data["grid_position"]
		grid_position = Vector2i(pos_array[0], pos_array[1])
	
	block_id = data.get("block_id", "")
	total_break_time = data.get("total_break_time", 1.0)
	time_remaining = data.get("time_remaining", total_break_time)
	current_damage = data.get("current_damage", 0.0)
	break_stage = data.get("break_stage", 0)
	is_breaking = data.get("is_breaking", false)

## Create breaking data from dictionary
static func from_dictionary(data: Dictionary) -> BlockBreakingData:
	var breaking_data = BlockBreakingData.new()
	breaking_data.from_dict(data)
	return breaking_data