extends Node

## Singleton that manages all block types in the game
## Provides centralized access to block definitions and properties
## Call via BlockRegistry.method_name() from anywhere in the game

signal block_registered(block_resource: BlockResource)
signal block_unregistered(block_id: String)

## Dictionary storing all registered block types [block_id -> BlockResource]
var _blocks: Dictionary = {}
## Array of block IDs organized by category for quick filtering
var _blocks_by_category: Dictionary = {}
## Cache for commonly accessed block data
var _block_cache: Dictionary = {}

## Initialize the registry with default block types
func _ready():
	print("BlockRegistry: Initializing block registry...")
	_load_default_blocks()
	print("BlockRegistry: Loaded %d block types" % _blocks.size())

## Register a new block type in the registry
func register_block(block_resource: BlockResource) -> bool:
	if block_resource == null:
		push_error("BlockRegistry: Cannot register null block resource")
		return false
	
	if not block_resource.is_valid():
		push_error("BlockRegistry: Block resource failed validation: %s" % block_resource.block_id)
		return false
	
	if _blocks.has(block_resource.block_id):
		push_warning("BlockRegistry: Overwriting existing block: %s" % block_resource.block_id)
	
	_blocks[block_resource.block_id] = block_resource
	_add_to_category(block_resource)
	_invalidate_cache(block_resource.block_id)
	
	block_registered.emit(block_resource)
	print("BlockRegistry: Registered block '%s' (%s)" % [block_resource.block_name, block_resource.block_id])
	return true

## Unregister a block type from the registry
func unregister_block(block_id: String) -> bool:
	if not _blocks.has(block_id):
		push_warning("BlockRegistry: Attempted to unregister non-existent block: %s" % block_id)
		return false
	
	var block_resource = _blocks[block_id]
	_remove_from_category(block_resource)
	_blocks.erase(block_id)
	_invalidate_cache(block_id)
	
	block_unregistered.emit(block_id)
	print("BlockRegistry: Unregistered block: %s" % block_id)
	return true

## Get a block resource by its ID
func get_block(block_id: String) -> BlockResource:
	return _blocks.get(block_id, null)

## Get all registered block IDs
func get_all_block_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in _blocks.keys():
		ids.append(id)
	return ids

## Get all block resources
func get_all_blocks() -> Array[BlockResource]:
	var blocks: Array[BlockResource] = []
	for block_resource in _blocks.values():
		blocks.append(block_resource)
	return blocks

## Get blocks by category (Building, Natural, Decorative, etc.)
func get_blocks_by_category(category: String) -> Array[BlockResource]:
	var blocks: Array[BlockResource] = []
	var block_ids = _blocks_by_category.get(category, [])
	
	for block_id in block_ids:
		var block_resource = get_block(block_id)
		if block_resource != null:
			blocks.append(block_resource)
	
	return blocks

## Get all available categories
func get_categories() -> Array[String]:
	var categories: Array[String] = []
	for category in _blocks_by_category.keys():
		categories.append(category)
	return categories

## Get blocks that can be placed by the player
func get_placeable_blocks() -> Array[BlockResource]:
	var placeable: Array[BlockResource] = []
	for block_resource in _blocks.values():
		if block_resource.placeable:
			placeable.append(block_resource)
	return placeable

## Get blocks that can be broken by the player
func get_breakable_blocks() -> Array[BlockResource]:
	var breakable: Array[BlockResource] = []
	for block_resource in _blocks.values():
		if block_resource.breakable:
			breakable.append(block_resource)
	return breakable

## Get blocks that can be crafted
func get_craftable_blocks() -> Array[BlockResource]:
	var craftable: Array[BlockResource] = []
	for block_resource in _blocks.values():
		if block_resource.craftable:
			craftable.append(block_resource)
	return craftable

## Search for blocks by name or tag
func search_blocks(query: String) -> Array[BlockResource]:
	var results: Array[BlockResource] = []
	var query_lower = query.to_lower()
	
	for block_resource in _blocks.values():
		# Search in name
		if block_resource.block_name.to_lower().contains(query_lower):
			results.append(block_resource)
			continue
		
		# Search in description
		if block_resource.block_description.to_lower().contains(query_lower):
			results.append(block_resource)
			continue
		
		# Search in tags
		for tag in block_resource.tags:
			if tag.to_lower().contains(query_lower):
				results.append(block_resource)
				break
	
	return results

## Check if a block type exists
func has_block(block_id: String) -> bool:
	return _blocks.has(block_id)

## Get the total number of registered blocks
func get_block_count() -> int:
	return _blocks.size()

## Validate all registered blocks
func validate_all_blocks() -> bool:
	var all_valid = true
	for block_resource in _blocks.values():
		if not block_resource.is_valid():
			push_error("BlockRegistry: Invalid block found: %s" % block_resource.block_id)
			all_valid = false
	return all_valid

## Clear all registered blocks (use with caution)
func clear_registry():
	_blocks.clear()
	_blocks_by_category.clear()
	_block_cache.clear()
	print("BlockRegistry: Registry cleared")

## Reload blocks from resources (for development/modding)
func reload_blocks():
	clear_registry()
	_load_default_blocks()
	print("BlockRegistry: Blocks reloaded")

## Add block to category tracking
func _add_to_category(block_resource: BlockResource):
	var category = block_resource.category
	if not _blocks_by_category.has(category):
		_blocks_by_category[category] = []
	
	var category_blocks = _blocks_by_category[category]
	if not category_blocks.has(block_resource.block_id):
		category_blocks.append(block_resource.block_id)

## Remove block from category tracking
func _remove_from_category(block_resource: BlockResource):
	var category = block_resource.category
	if _blocks_by_category.has(category):
		var category_blocks = _blocks_by_category[category]
		category_blocks.erase(block_resource.block_id)
		
		# Remove empty categories
		if category_blocks.is_empty():
			_blocks_by_category.erase(category)

## Invalidate cached data for a block
func _invalidate_cache(block_id: String):
	_block_cache.erase(block_id)

## Load default block types from the existing tile system
func _load_default_blocks():
	# First, let's check if we have existing block resources in the project
	# If not, we'll create some basic ones programmatically
	
	# Try to load existing block resources
	var resource_dir = "res://resources/blocks/"
	if DirAccess.open(resource_dir) != null:
		_load_blocks_from_directory(resource_dir)
	else:
		# Create basic block types based on the existing tiles
		_create_basic_blocks()

## Load block resources from a directory
func _load_blocks_from_directory(dir_path: String):
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var resource_path = dir_path + file_name
			var block_resource = load(resource_path) as BlockResource
			if block_resource != null:
				register_block(block_resource)
		file_name = dir.get_next()

## Create basic block types for initial setup using debug blocks
func _create_basic_blocks():
	print("BlockRegistry: Creating basic debug block types...")
	
	# Create basic grass block using debug block resource
	var grass_block = DebugBlockResource.create_debug_block(
		"grass",
		"Grass Block",
		Color.GREEN
	)
	grass_block.block_description = "A basic grass block for building platforms"
	grass_block.durability = 100
	grass_block.break_time = 1.0
	grass_block.category = "Natural"
	grass_block.tags = ["grass", "natural", "platform"]
	
	register_block(grass_block)
	
	# Create basic stone block using debug block resource
	var stone_block = DebugBlockResource.create_debug_block(
		"stone",
		"Stone Block",
		Color.GRAY
	)
	stone_block.block_description = "A durable stone block for solid construction"
	stone_block.durability = 200
	stone_block.break_time = 2.0
	stone_block.category = "Natural"
	stone_block.tags = ["stone", "natural", "durable"]
	
	register_block(stone_block)
	
	# Create dirt block for variety
	var dirt_block = DebugBlockResource.create_debug_block(
		"dirt",
		"Dirt Block",
		Color.SADDLE_BROWN
	)
	dirt_block.block_description = "Basic dirt block for quick construction"
	dirt_block.durability = 50
	dirt_block.break_time = 0.5
	dirt_block.category = "Natural"
	dirt_block.tags = ["dirt", "natural", "quick"]
	
	register_block(dirt_block)
	
	# Create sand block with degradation properties
	var sand_block = DebugBlockResource.create_debug_block(
		"sand",
		"Sand Block",
		Color(0.8, 0.7, 0.4, 1.0)  # Yellowish brown color
	)
	sand_block.block_description = "Unstable sand block that degrades when stepped on"
	sand_block.durability = 30  # Lower durability for quick breaking
	sand_block.break_time = 0.3
	sand_block.category = "Natural"
	sand_block.tags = ["sand", "natural", "unstable", "degradable"]
	
	# Configure degradation properties
	sand_block.degradable = true
	sand_block.degradation_amount = 10  # Lose 10 health per tick (30 health / 10 damage = 3 ticks to break)
	sand_block.degradation_interval = 1.0  # Every 1 second
	sand_block.degrades_under_player = true
	sand_block.player_degradation_multiplier = 1.0  # Same rate when player is standing on it
	
	register_block(sand_block)
	
	# Create brick wall item
	var brick_wall = DebugBlockResource.create_debug_block(
		"brick_wall",
		"Brick Wall",
		Color(0.7, 0.4, 0.3, 1.0)  # Brick red-brown color
	)
	brick_wall.block_description = "Decorative brick wall that can be placed behind blocks"
	brick_wall.durability = 80
	brick_wall.break_time = 1.5
	brick_wall.category = "Decorative"
	brick_wall.tags = ["wall", "decorative", "brick"]
	
	# Configure as wall item
	brick_wall.item_type = BlockResource.ItemType.WALL_ITEM
	brick_wall.wall_placement_offset = -0.5  # Half a block back (back face of voxel)
	brick_wall.blocks_placement = false  # Allow blocks to be placed in front
	brick_wall.has_collision = false  # No collision for decorative wall items
	
	# Regenerate mesh now that item_type is set to WALL_ITEM
	brick_wall.regenerate_mesh()
	
	register_block(brick_wall)
	
	# Create wood platform item
	var wood_platform = DebugBlockResource.create_debug_block(
		"wood_platform",
		"Wood Platform",
		Color(0.6, 0.4, 0.2, 1.0)  # Wood brown color
	)
	wood_platform.block_description = "Thin wooden platform that can be placed between coordinates"
	wood_platform.durability = 60
	wood_platform.break_time = 1.0
	wood_platform.category = "Building"
	wood_platform.tags = ["platform", "wood", "building"]
	
	# Configure as platform item
	wood_platform.item_type = BlockResource.ItemType.PLATFORM
	wood_platform.platform_thickness = 0.1  # 2/20 of block height
	wood_platform.platform_y_offset = 0.0  # Centered vertically
	wood_platform.has_collision = true  # Platforms should have collision for walking on
	
	# Regenerate mesh now that item_type is set to PLATFORM
	wood_platform.regenerate_mesh()
	
	register_block(wood_platform)
	
	print("BlockRegistry: Created %d debug block types" % _blocks.size())
