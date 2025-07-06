class_name Entity
extends CharacterBody3D

## Base class for all interactive game entities
## Provides common functionality for players, NPCs, items, and other game objects
## Enforces 2.5D constraint and standardized collision handling

signal entity_spawned(entity: Entity)
signal entity_despawned(entity: Entity)
signal entity_moved(entity: Entity, old_position: Vector3, new_position: Vector3)

## Entity type enum for categorization
enum EntityType {
	PLAYER,
	NPC,
	ENEMY,
	ITEM,
	INTERACTIVE_OBJECT,
	PROJECTILE,
	TRIGGER
}

## Entity state enum
enum EntityState {
	INACTIVE,
	ACTIVE,
	SPAWNING,
	DESPAWNING,
	DISABLED
}

## Entity configuration
@export var entity_type: EntityType = EntityType.NPC
@export var entity_id: String = ""
@export var entity_name: String = ""
@export var enforce_2d_constraint: bool = true
@export var auto_configure_collision: bool = true

## Physics properties
@export var has_gravity: bool = true
@export var gravity_multiplier: float = 1.0
@export var can_move: bool = true
@export var base_speed: float = 5.0

## Health system (optional)
@export var has_health: bool = false
@export var max_health: int = 100
@export var current_health: int = 100

## Item displacement for future item system
@export var can_be_displaced: bool = false
@export var displacement_force: float = 10.0

## Internal state
var current_state: EntityState = EntityState.INACTIVE
var spawn_position: Vector3 = Vector3.ZERO
var is_initialized: bool = false

## Movement tracking
var last_position: Vector3 = Vector3.ZERO
var movement_threshold: float = 0.01

## Physics properties
var gravity_force: float = 9.8

func _ready():
	# Initialize entity
	spawn_position = global_position
	last_position = global_position
	
	# Configure collision layers if enabled
	if auto_configure_collision:
		_configure_collision_layers()
	
	# Set up physics
	if has_gravity:
		gravity_force = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8) * gravity_multiplier
	
	# Initialize health
	if has_health:
		current_health = max_health
	
	# Mark as initialized
	is_initialized = true
	current_state = EntityState.ACTIVE
	
	# Notify spawn
	entity_spawned.emit(self)
	GameEvents.notify_entity_spawned(self)

func _physics_process(delta: float):
	if current_state != EntityState.ACTIVE:
		return
	
	# Apply 2.5D constraint
	if enforce_2d_constraint:
		_enforce_2d_constraint()
	
	# Apply gravity
	if has_gravity and not is_on_floor():
		velocity.y -= gravity_force * delta
	
	# Move the entity
	if can_move:
		move_and_slide()
	
	# Check for movement and notify
	_check_movement()

## Configure collision layers based on entity type
func _configure_collision_layers():
	match entity_type:
		EntityType.PLAYER:
			collision_layer = 2  # Layer 2: Player
			collision_mask = 1   # Mask 1: Static World
		EntityType.NPC, EntityType.ENEMY:
			collision_layer = 4  # Layer 3: Entities (2^2 = 4)
			collision_mask = 1 | 2  # Mask 1: Static World, Mask 2: Player
		EntityType.ITEM:
			collision_layer = 8  # Layer 4: Items (2^3 = 8)
			collision_mask = 1   # Mask 1: Static World
		EntityType.INTERACTIVE_OBJECT:
			collision_layer = 16  # Layer 5: Interactive Objects (2^4 = 16)
			collision_mask = 1   # Mask 1: Static World
		EntityType.PROJECTILE:
			collision_layer = 32  # Layer 6: Projectiles (2^5 = 32)
			collision_mask = 1 | 4  # Mask 1: Static World, Mask 3: Entities
		EntityType.TRIGGER:
			collision_layer = 64  # Layer 7: Triggers (2^6 = 64)
			collision_mask = 2 | 4  # Mask 2: Player, Mask 3: Entities

## Enforce 2.5D constraint by keeping Z at 0
func _enforce_2d_constraint():
	# Keep Z position at 0
	if global_position.z != 0.0:
		global_position.z = 0.0
	
	# Keep Z velocity at 0
	if velocity.z != 0.0:
		velocity.z = 0.0

## Check if entity has moved and emit signal
func _check_movement():
	if global_position.distance_to(last_position) > movement_threshold:
		var old_pos = last_position
		last_position = global_position
		entity_moved.emit(self, old_pos, global_position)
		GameEvents.notify_entity_moved(self, old_pos, global_position)

## Spawn the entity at a specific position
func spawn_at(spawn_pos: Vector3):
	global_position = spawn_pos
	spawn_position = spawn_pos
	current_state = EntityState.SPAWNING
	
	# Enforce 2.5D constraint for spawn position
	if enforce_2d_constraint:
		global_position.z = 0.0
		spawn_position.z = 0.0
	
	# Transition to active state
	current_state = EntityState.ACTIVE
	
	# Notify spawn
	entity_spawned.emit(self)
	GameEvents.notify_entity_spawned(self)

## Despawn the entity
func despawn():
	current_state = EntityState.DESPAWNING
	
	# Notify despawn
	entity_despawned.emit(self)
	GameEvents.notify_entity_despawned(self)
	
	# Remove from scene
	queue_free()

## Get current world grid position
func get_grid_position() -> Vector2i:
	return Vector2i(int(round(global_position.x)), int(round(global_position.y)))

## Check if entity can be displaced (for item displacement system)
func can_be_displaced_by_block() -> bool:
	return can_be_displaced and entity_type == EntityType.ITEM

## Handle displacement when a block is placed (for future item system)
func handle_displacement(block_position: Vector3, available_directions: Array[Vector3]):
	if not can_be_displaced_by_block():
		return
	
	# Find the best displacement direction
	var best_direction: Vector3 = Vector3.ZERO
	var max_distance: float = 0.0
	
	for direction in available_directions:
		var distance = global_position.distance_to(block_position + direction)
		if distance > max_distance:
			max_distance = distance
			best_direction = direction
	
	# Apply displacement
	if best_direction != Vector3.ZERO:
		var displacement = best_direction.normalized() * displacement_force
		velocity += displacement
		print("Entity displaced: %s moved by %s" % [entity_name, displacement])

## Damage the entity (if health system is enabled)
func take_damage(amount: int) -> bool:
	if not has_health:
		return false
	
	current_health = max(0, current_health - amount)
	
	if current_health <= 0:
		despawn()
		return true
	
	return false

## Heal the entity (if health system is enabled)
func heal(amount: int):
	if not has_health:
		return
	
	current_health = min(max_health, current_health + amount)

## Get entity info for debugging
func get_entity_info() -> Dictionary:
	return {
		"entity_id": entity_id,
		"entity_name": entity_name,
		"entity_type": EntityType.keys()[entity_type],
		"position": global_position,
		"state": EntityState.keys()[current_state],
		"health": str(current_health) if has_health else "N/A",
		"can_be_displaced": can_be_displaced
	}

## Virtual method for subclasses to override
func _on_entity_spawned():
	pass

## Virtual method for subclasses to override
func _on_entity_despawned():
	pass

## Virtual method for subclasses to override
func _on_entity_moved(_old_pos: Vector3, _new_pos: Vector3):
	pass
