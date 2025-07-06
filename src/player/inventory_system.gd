class_name Inventory
extends Node

## Basic inventory system for managing player's blocks and items
## Handles item storage, retrieval, and quantity management for the block system

signal item_added(block_id: String, quantity: int)
signal item_removed(block_id: String, quantity: int)
signal item_quantity_changed(block_id: String, new_quantity: int)
signal inventory_full(block_id: String, attempted_quantity: int)

## Maximum number of different item types the inventory can hold
@export var max_item_types: int = 50
## Maximum stack size for each item type
@export var max_stack_size: int = 999
## Enable infinite mode for creative gameplay
@export var infinite_mode: bool = false

## Dictionary storing item quantities [block_id -> int]
var _items: Dictionary = {}
## Array storing the order of items for UI display
var _item_order: Array[String] = []

## Add items to the inventory
func add_item(block_id: String, quantity: int = 1) -> int:
	if quantity <= 0:
		return 0
	
	# In infinite mode, just emit the signal and return the full quantity
	if infinite_mode:
		item_added.emit(block_id, quantity)
		return quantity
	
	# Check if we can add this item type
	if not _items.has(block_id):
		if _items.size() >= max_item_types:
			inventory_full.emit(block_id, quantity)
			return 0
		
		# Add new item type
		_items[block_id] = 0
		_item_order.append(block_id)
	
	# Calculate how much we can actually add
	var current_quantity = _items[block_id]
	var available_space = max_stack_size - current_quantity
	var added_quantity = min(quantity, available_space)
	
	if added_quantity > 0:
		_items[block_id] = current_quantity + added_quantity
		item_added.emit(block_id, added_quantity)
		item_quantity_changed.emit(block_id, _items[block_id])
	
	# If we couldn't add everything, emit inventory full signal
	if added_quantity < quantity:
		inventory_full.emit(block_id, quantity - added_quantity)
	
	return added_quantity

## Remove items from the inventory
func remove_item(block_id: String, quantity: int = 1) -> int:
	if quantity <= 0:
		return 0
	
	# In infinite mode, just emit the signal and return the full quantity
	if infinite_mode:
		item_removed.emit(block_id, quantity)
		return quantity
	
	if not _items.has(block_id):
		return 0
	
	var current_quantity = _items[block_id]
	var removed_quantity = min(quantity, current_quantity)
	
	if removed_quantity > 0:
		_items[block_id] = current_quantity - removed_quantity
		item_removed.emit(block_id, removed_quantity)
		item_quantity_changed.emit(block_id, _items[block_id])
		
		# Remove item type if quantity reaches zero
		if _items[block_id] <= 0:
			_items.erase(block_id)
			_item_order.erase(block_id)
	
	return removed_quantity

## Get the quantity of a specific item
func get_item_quantity(block_id: String) -> int:
	if infinite_mode:
		return max_stack_size  # Return max in infinite mode
	return _items.get(block_id, 0)

## Check if the inventory has at least the specified quantity of an item
func has_item(block_id: String, quantity: int = 1) -> bool:
	if infinite_mode:
		return true
	return get_item_quantity(block_id) >= quantity

## Get all items in the inventory
func get_all_items() -> Dictionary:
	if infinite_mode:
		# Return all placeable blocks with max quantity
		var all_blocks = {}
		if BlockRegistry:
			var placeable_blocks = BlockRegistry.get_placeable_blocks()
			for block_resource in placeable_blocks:
				all_blocks[block_resource.block_id] = max_stack_size
		return all_blocks
	
	return _items.duplicate()

## Get items in display order
func get_items_ordered() -> Array[String]:
	if infinite_mode:
		# Return all placeable blocks in order
		if BlockRegistry:
			var placeable_blocks = BlockRegistry.get_placeable_blocks()
			var ordered_blocks: Array[String] = []
			for block_resource in placeable_blocks:
				ordered_blocks.append(block_resource.block_id)
			return ordered_blocks
		return []
	
	return _item_order.duplicate()

## Check if the inventory is full (can't accept new item types)
func is_full() -> bool:
	if infinite_mode:
		return false
	return _items.size() >= max_item_types

## Check if a specific item stack is full
func is_item_stack_full(block_id: String) -> bool:
	if infinite_mode:
		return false
	return get_item_quantity(block_id) >= max_stack_size

## Get the total number of different item types
func get_item_type_count() -> int:
	if infinite_mode:
		return BlockRegistry.get_block_count() if BlockRegistry else 0
	return _items.size()

## Get the total number of items across all stacks
func get_total_item_count() -> int:
	if infinite_mode:
		return max_stack_size * get_item_type_count()
	
	var total = 0
	for quantity in _items.values():
		total += quantity
	return total

## Clear all items from the inventory
func clear_inventory():
	var old_items = _items.duplicate()
	_items.clear()
	_item_order.clear()
	
	# Emit removed signals for all items
	for block_id in old_items:
		item_removed.emit(block_id, old_items[block_id])
		item_quantity_changed.emit(block_id, 0)

## Set the quantity of a specific item (for debugging/admin commands)
func set_item_quantity(block_id: String, quantity: int):
	if infinite_mode:
		return  # Can't set quantities in infinite mode
	
	var old_quantity = get_item_quantity(block_id)
	
	if quantity <= 0:
		# Remove the item
		if _items.has(block_id):
			_items.erase(block_id)
			_item_order.erase(block_id)
		quantity = 0
	else:
		# Add item type if it doesn't exist
		if not _items.has(block_id):
			if _items.size() >= max_item_types:
				push_warning("Inventory: Cannot add new item type, inventory full")
				return
			_item_order.append(block_id)
		
		_items[block_id] = min(quantity, max_stack_size)
		quantity = _items[block_id]
	
	if old_quantity != quantity:
		if quantity > old_quantity:
			item_added.emit(block_id, quantity - old_quantity)
		else:
			item_removed.emit(block_id, old_quantity - quantity)
		
		item_quantity_changed.emit(block_id, quantity)

## Move an item to a different position in the display order
func move_item_order(from_index: int, to_index: int):
	if infinite_mode:
		return  # Can't reorder in infinite mode
	
	if from_index < 0 or from_index >= _item_order.size() or to_index < 0 or to_index >= _item_order.size():
		return
	
	var item = _item_order[from_index]
	_item_order.remove_at(from_index)
	_item_order.insert(to_index, item)

## Get a formatted string representation of the inventory
func get_inventory_string() -> String:
	if infinite_mode:
		return "Inventory (Infinite Mode): All blocks available"
	
	var result = "Inventory (%d/%d types):\n" % [_items.size(), max_item_types]
	for block_id in _item_order:
		var quantity = _items[block_id]
		var block_resource = BlockRegistry.get_block(block_id) if BlockRegistry else null
		var display_name = block_resource.get_display_name() if block_resource else block_id
		result += "  %s: %d/%d\n" % [display_name, quantity, max_stack_size]
	
	return result

## Save inventory data to a dictionary (for persistence)
func save_data() -> Dictionary:
	return {
		"items": _items.duplicate(),
		"item_order": _item_order.duplicate(),
		"infinite_mode": infinite_mode
	}

## Load inventory data from a dictionary (for persistence)
func load_data(data: Dictionary):
	if data.has("items"):
		_items = data["items"].duplicate()
	
	if data.has("item_order"):
		_item_order = data["item_order"].duplicate()
	
	if data.has("infinite_mode"):
		infinite_mode = data["infinite_mode"]
	
	# Emit quantity changed signals for all items
	for block_id in _items:
		item_quantity_changed.emit(block_id, _items[block_id])

## Give the player some starter items (for testing/new game)
func give_starter_items():
	if infinite_mode:
		return  # No need for starter items in infinite mode
	
	# Give some basic blocks to start with
	add_item("grass", 50)
	add_item("stone", 25)
	
	print("Inventory: Gave starter items")

## Toggle infinite mode
func set_infinite_mode(enabled: bool):
	infinite_mode = enabled
	print("Inventory: Infinite mode %s" % ("enabled" if enabled else "disabled"))
	
	# Emit quantity changed signals for all items to update UI
	if infinite_mode:
		# Emit signals for all available blocks
		if BlockRegistry:
			var placeable_blocks = BlockRegistry.get_placeable_blocks()
			for block_resource in placeable_blocks:
				item_quantity_changed.emit(block_resource.block_id, max_stack_size)
	else:
		# Emit signals for current inventory items
		for block_id in _items:
			item_quantity_changed.emit(block_id, _items[block_id])
