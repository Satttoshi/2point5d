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

## Create basic block types for initial setup
func _create_basic_blocks():
	print("BlockRegistry: Creating basic block types...")
	
	# Create basic grass block
	var grass_block = BlockResource.new()
	grass_block.block_id = "grass"
	grass_block.block_name = "Grass Block"
	grass_block.block_description = "A basic grass block for building platforms"
	grass_block.durability = 100
	grass_block.break_time = 1.0
	grass_block.category = "Natural"
	grass_block.tags = ["grass", "natural", "platform"]
	grass_block.placeable = true
	grass_block.breakable = true
	grass_block.has_collision = true
	grass_block.is_solid = true
	grass_block.is_transparent = false
	
	# For now, we'll set the mesh_scene to null and handle it in the world grid
	# This will be properly connected to the actual mesh library later
	grass_block.mesh_scene = preload("res://assets/kenney_platformer-kit/Models/block-grass.glb")
	
	register_block(grass_block)
	
	# Create basic stone block (using grass model for now)
	var stone_block = BlockResource.new()
	stone_block.block_id = "stone"
	stone_block.block_name = "Stone Block"
	stone_block.block_description = "A durable stone block for solid construction"
	stone_block.durability = 200
	stone_block.break_time = 2.0
	stone_block.category = "Natural"
	stone_block.tags = ["stone", "natural", "durable"]
	stone_block.placeable = true
	stone_block.breakable = true
	stone_block.has_collision = true
	stone_block.is_solid = true
	stone_block.is_transparent = false
	stone_block.mesh_scene = preload("res://assets/kenney_platformer-kit/Models/block-snow.glb")
	
	register_block(stone_block)
	
	print("BlockRegistry: Created %d basic block types" % _blocks.size())
