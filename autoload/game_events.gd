extends Node

## Central event hub for game-wide communication
## Provides loose coupling between systems and prepares for multiplayer architecture
## All systems communicate through this singleton to avoid direct dependencies

# Block-related events
signal block_placement_requested(grid_pos: Vector2i, block_id: String)
signal block_removal_requested(grid_pos: Vector2i)
signal block_placed(grid_pos: Vector2i, block_id: String)
signal block_removed(grid_pos: Vector2i, block_id: String)

# Block breaking events (for future breaking animation system)
signal block_break_started(grid_pos: Vector2i, break_time: float)
signal block_break_progress(grid_pos: Vector2i, damage_percent: float, break_stage: int)
signal block_break_completed(grid_pos: Vector2i, block_id: String)
signal block_break_cancelled(grid_pos: Vector2i)

# Player interaction events
signal player_target_changed(target_pos: Vector2i, has_target: bool)
signal player_selected_block_changed(block_id: String, block_index: int)

# Inventory events
signal item_added_to_inventory(block_id: String, quantity: int)
signal item_removed_from_inventory(block_id: String, quantity: int)
signal inventory_updated()

# World events
signal world_loaded()
signal world_cleared()

# UI events
signal target_indicator_update_requested(grid_pos: Vector2i, is_valid: bool)
signal target_indicator_hide_requested()

func _ready():
	print("GameEvents: Event system initialized")

## Request block placement at specified position
func request_block_placement(grid_pos: Vector2i, block_id: String):
	print("GameEvents: Block placement requested at %s: %s" % [grid_pos, block_id])
	block_placement_requested.emit(grid_pos, block_id)

## Request block removal at specified position
func request_block_removal(grid_pos: Vector2i):
	print("GameEvents: Block removal requested at %s" % grid_pos)
	block_removal_requested.emit(grid_pos)

## Notify that a block was successfully placed
func notify_block_placed(grid_pos: Vector2i, block_id: String):
	print("GameEvents: Block placed at %s: %s" % [grid_pos, block_id])
	block_placed.emit(grid_pos, block_id)

## Notify that a block was successfully removed
func notify_block_removed(grid_pos: Vector2i, block_id: String):
	print("GameEvents: Block removed from %s: %s" % [grid_pos, block_id])
	block_removed.emit(grid_pos, block_id)

## Notify that player's target has changed
func notify_player_target_changed(target_pos: Vector2i, has_target: bool):
	player_target_changed.emit(target_pos, has_target)

## Notify that player's selected block has changed
func notify_player_selected_block_changed(block_id: String, block_index: int):
	print("GameEvents: Player selected block changed to %s (index %d)" % [block_id, block_index])
	player_selected_block_changed.emit(block_id, block_index)

## Request target indicator update
func request_target_indicator_update(grid_pos: Vector2i, is_valid: bool):
	target_indicator_update_requested.emit(grid_pos, is_valid)

## Request target indicator hide
func request_target_indicator_hide():
	target_indicator_hide_requested.emit()

## Notify that an item was added to inventory
func notify_item_added_to_inventory(block_id: String, quantity: int):
	item_added_to_inventory.emit(block_id, quantity)

## Notify that an item was removed from inventory
func notify_item_removed_from_inventory(block_id: String, quantity: int):
	item_removed_from_inventory.emit(block_id, quantity)

## Notify that inventory was updated
func notify_inventory_updated():
	inventory_updated.emit()

## Block breaking system events (for future implementation)
func notify_block_break_started(grid_pos: Vector2i, break_time: float):
	print("GameEvents: Block breaking started at %s (%.1fs)" % [grid_pos, break_time])
	block_break_started.emit(grid_pos, break_time)

func notify_block_break_progress(grid_pos: Vector2i, damage_percent: float, break_stage: int):
	block_break_progress.emit(grid_pos, damage_percent, break_stage)

func notify_block_break_completed(grid_pos: Vector2i, block_id: String):
	print("GameEvents: Block breaking completed at %s: %s" % [grid_pos, block_id])
	block_break_completed.emit(grid_pos, block_id)

func notify_block_break_cancelled(grid_pos: Vector2i):
	print("GameEvents: Block breaking cancelled at %s" % grid_pos)
	block_break_cancelled.emit(grid_pos)

## World management events
func notify_world_loaded():
	print("GameEvents: World loaded")
	world_loaded.emit()

func notify_world_cleared():
	print("GameEvents: World cleared")
	world_cleared.emit()