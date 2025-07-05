# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a 2.5D Godot project using Godot 4.4 engine. The project is configured as a 3D project with Forward Plus rendering pipeline, which is typical for 2.5D games that use 3D capabilities with constrained movement or camera perspectives.

## Essential Commands

### Running the Project
```bash
# Run in Godot editor (WSL - using Windows Godot executable)
"/mnt/c/Users/yoshi/Desktop/Godot/Godot_v4.4.1-stable_win64.exe" --editor project.godot

# Run project directly
"/mnt/c/Users/yoshi/Desktop/Godot/Godot_v4.4.1-stable_win64.exe" project.godot

# Alternative console version
"/mnt/c/Users/yoshi/Desktop/Godot/Godot_v4.4.1-stable_console_win64.exe" project.godot
```

### Export Commands
```bash
# Export for Linux
"/mnt/c/Users/yoshi/Desktop/Godot/Godot_v4.4.1-stable_win64.exe" --export "Linux/X11" build/game

# Export for Windows
"/mnt/c/Users/yoshi/Desktop/Godot/Godot_v4.4.1-stable_win64.exe" --export "Windows Desktop" build/game.exe
```

## Project Structure

- `project.godot` - Main project configuration (Godot 4.4, Forward Plus rendering)
- `main.tscn` - Primary scene file with Node3D root and basic BoxMesh
- `icon.svg` - Project icon

## Architecture Notes

This is a 2.5D platformer project with the following implemented systems:

### Core Architecture
- **Main Scene**: `main.tscn` - Primary game scene with environment, lighting, and player
- **ProtoController**: Custom character controller addon for 2.5D movement
- **Tilemap System**: GridMap-based level construction using Kenney's Platformer Kit
- **Physics**: Jolt Physics engine for 3D physics simulation

### Current Features
- **Player Movement**: 
  - 2D constraint movement (X-axis only, no Z-axis movement)
  - Gravity-based physics with jump mechanics
  - Sprint functionality
  - Freefly mode for debugging (noclip-style movement)
- **Camera System**: 
  - Third-person camera with smooth following
  - Bezier curve-based easing for natural movement
  - Configurable deadzone and follow speed
  - Acceleration/deceleration curves
- **Input System**: 
  - Custom input actions (WASD movement, Space jump, Shift sprint, N freefly)
  - Proper input validation and error handling

### Scene Structure
- **main.tscn**: Main game scene
  - ProtoController instance (player character)
  - WorldEnvironment with procedural sky
  - DirectionalLight3D with shadows
- **scenes/tiles.tscn**: MeshLibrary resource scene for tile generation
- **addons/proto_controller/**: Custom character controller addon
  - `proto_controller.gd` - Main controller script
  - `proto_controller.tscn` - Character controller scene

### Technical Implementation
- **Movement System**: CharacterBody3D-based with move_and_slide()
- **Camera Follow**: Custom bezier easing with configurable parameters
- **Physics**: Gravity multiplier for responsive jump feel
- **Input Handling**: Action-based input system with deadzone configuration
- **2.5D Constraint**: Movement locked to X-axis, camera positioned for side-scrolling view

## Development Setup

The project uses Godot 4.4 with Forward Plus rendering. No external dependencies or build systems are configured. All development happens within the Godot editor environment.

## Development Workflow

### Code Documentation Standards
**CRITICAL**: All code MUST be thoroughly documented with the following requirements:

#### Function Documentation
- **Every function** must have JSDoc-style comments explaining:
  - Purpose and behavior
  - Side effects or state changes

Example:
```gdscript
## Calculates the bezier curve easing for smooth camera movement
func bezier_ease(t: float, strength: float, accel_curve: float, decel_curve: float) -> float:
```

#### Complex Logic Documentation
- **Any complex logic** (loops, conditionals, algorithms) must have inline comments explaining:
  - What the logic does
  - Why it's implemented this way
  - Any non-obvious behavior or edge cases

Example:
```gdscript
# Calculate distance factor to create deadzone behavior
# This prevents camera jitter when player is barely moving
var distance_factor = distance / (distance + camera_deadzone)

# Apply bezier curve smoothing using custom easing
# This creates natural acceleration/deceleration patterns
var speed_factor = camera_follow_speed * delta
var t = clamp(speed_factor, 0.0, 1.0)
var bezier_factor = bezier_ease(t, camera_easing_strength, camera_acceleration_curve, camera_deceleration_curve)
```

#### Variable Documentation
- **Exported variables** must have descriptive comments
- **Complex or non-obvious variables** should be documented
- **State variables** should explain their purpose and lifecycle

#### Class/Script Documentation
- **Every script** must have a header comment explaining:
  - Purpose of the class/script
  - Main responsibilities
  - Key dependencies or relationships
  - Usage context

### Code Quality Standards
1. **Consistent Naming**: Use clear, descriptive names for variables, functions, and classes
2. **Type Hints**: Always use type hints for function parameters and return values
3. **Error Handling**: Implement proper error checking and user feedback
4. **Code Structure**: Organize code logically with clear separation of concerns
5. **Performance**: Consider performance implications, especially for _process() and _physics_process() methods

### Git Workflow
1. **Commit Messages**: Use clear, descriptive commit messages
2. **Small Commits**: Make focused commits with single responsibility
3. **Branch Strategy**: Use feature branches for new development
4. **Code Review**: All code should be reviewed before merging

### Testing Guidelines
1. **Manual Testing**: Test all features thoroughly in the Godot editor
2. **Edge Cases**: Test boundary conditions and error scenarios
3. **Performance Testing**: Verify smooth performance at target framerate
4. **Input Testing**: Verify all input combinations work correctly

### Documentation Maintenance
- Update documentation when changing functionality
- Keep CLAUDE.md current with architectural changes
- Document any breaking changes or migration steps
- Maintain clear README files for complex systems

## Godot MCP Integration

This project is configured with Godot MCP (Model Context Protocol) server that enables Claude Code to:

### Available MCP Tools
- **Launch Godot Editor**: Open the Godot editor for this project
- **Run Godot Projects**: Execute the project in debug mode
- **Capture Debug Output**: Retrieve console output and error messages for debugging
- **Control Execution**: Start and stop the project programmatically
- **Get Godot Version**: Retrieve the installed Godot version
- **List Godot Projects**: Find Godot projects in directories
- **Project Analysis**: Get detailed information about project structure
- **Scene Management**:
  - Create new scenes with specified root node types
  - Add nodes to existing scenes with customizable properties
  - Load sprites and textures into Sprite2D nodes
  - Export 3D scenes as MeshLibrary resources for GridMap
  - Save scenes with options for creating variants
- **UID Management** (Godot 4.4+):
  - Get UID for specific files
  - Update UID references by resaving resources

### Debug and Error Handling
- Claude Code can capture and analyze Godot debug output and error logs
- GDScript linting and error detection is supported through the MCP integration
- Real-time feedback loop for debugging and code generation

### Usage Notes
- All MCP tools are prefixed with `mcp__godot__` in Claude Code
- The MCP server handles WSL/Windows path translation automatically
- Debug output can be retrieved after running the project to analyze errors
- Error logs help Claude Code provide better debugging assistance and code fixes