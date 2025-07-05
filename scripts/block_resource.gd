class_name BlockResource
extends Resource

## Resource class that defines the properties and data for different block types
## This serves as the blueprint for all block types in the game (dirt, stone, wood, etc.)

@export var block_id: String = ""
@export var block_name: String = ""
@export var block_description: String = ""

@export_group("Visual Properties")
## Reference to the 3D mesh used for this block type
@export var mesh_scene: PackedScene
## Texture override for the block (optional)
@export var texture_override: Texture2D
## Material override for the block (optional)
@export var material_override: Material

@export_group("Gameplay Properties")
## How much health this block has before it breaks
@export var durability: int = 100
## How long it takes to break this block (in seconds)
@export var break_time: float = 1.0
## Can this block be placed by the player?
@export var placeable: bool = true
## Can this block be broken by the player?
@export var breakable: bool = true
## Does this block have collision?
@export var has_collision: bool = true

@export_group("Item Drops")
## Items that drop when this block is destroyed
@export var drop_items: Array[BlockResource] = []
## How many items to drop (corresponds to drop_items array)
@export var drop_quantities: Array[int] = []
## Chance to drop items (0.0 to 1.0)
@export var drop_chance: float = 1.0

@export_group("Block Categories")
## Category this block belongs to (Building, Natural, Decorative, etc.)
@export var category: String = "Building"
## Tags for filtering and searching
@export var tags: PackedStringArray = []
## Is this a solid block that prevents movement?
@export var is_solid: bool = true
## Is this block transparent (affects lighting and rendering)?
@export var is_transparent: bool = false

@export_group("Crafting")
## Can this block be crafted?
@export var craftable: bool = false
## Recipe ingredients (if craftable)
@export var recipe_ingredients: Array[BlockResource] = []
## Recipe ingredient quantities
@export var recipe_quantities: Array[int] = []
## How many of this block does the recipe produce?
@export var recipe_output_quantity: int = 1

## Validates that the block resource has all required properties
func is_valid() -> bool:
	if block_id.is_empty():
		push_error("BlockResource: block_id cannot be empty")
		return false
	
	if block_name.is_empty():
		push_error("BlockResource: block_name cannot be empty")
		return false
	
	if mesh_scene == null:
		push_error("BlockResource: mesh_scene is required")
		return false
	
	if drop_items.size() != drop_quantities.size():
		push_error("BlockResource: drop_items and drop_quantities arrays must have the same size")
		return false
	
	if craftable:
		if recipe_ingredients.size() != recipe_quantities.size():
			push_error("BlockResource: recipe_ingredients and recipe_quantities arrays must have the same size")
			return false
	
	return true

## Gets the display name for UI
func get_display_name() -> String:
	return block_name if not block_name.is_empty() else block_id

## Gets a formatted description for tooltips
func get_formatted_description() -> String:
	var desc = block_description
	if desc.is_empty():
		desc = "A %s block" % block_name.to_lower()
	
	desc += "\n\nDurability: %d" % durability
	desc += "\nBreak Time: %.1fs" % break_time
	desc += "\nCategory: %s" % category
	
	if drop_items.size() > 0:
		desc += "\n\nDrops:"
		for i in range(drop_items.size()):
			if drop_items[i] != null:
				desc += "\n  • %s x%d" % [drop_items[i].get_display_name(), drop_quantities[i]]
	
	return desc

## Gets the total crafting cost for this block
func get_crafting_cost() -> Dictionary:
	var cost = {}
	if craftable:
		for i in range(recipe_ingredients.size()):
			if recipe_ingredients[i] != null:
				var ingredient_id = recipe_ingredients[i].block_id
				cost[ingredient_id] = recipe_quantities[i]
	return cost

## Checks if this block can be crafted with the given inventory
func can_craft_with_inventory(inventory: Dictionary) -> bool:
	if not craftable:
		return false
	
	var cost = get_crafting_cost()
	for ingredient_id in cost:
		var required_quantity = cost[ingredient_id]
		var available_quantity = inventory.get(ingredient_id, 0)
		if available_quantity < required_quantity:
			return false
	
	return true
