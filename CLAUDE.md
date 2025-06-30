# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a 2.5D Godot project using Godot 4.4 engine. The project is configured as a 3D project with Forward Plus rendering pipeline, which is typical for 2.5D games that use 3D capabilities with constrained movement or camera perspectives.

## Essential Commands

### Running the Project
```bash
# Run in Godot editor
godot --editor project.godot

# Run project directly
godot project.godot
```

### Export Commands
```bash
# Export for Linux
godot --export "Linux/X11" build/game

# Export for Windows
godot --export "Windows Desktop" build/game.exe
```

## Project Structure

- `project.godot` - Main project configuration (Godot 4.4, Forward Plus rendering)
- `main.tscn` - Primary scene file with Node3D root and basic BoxMesh
- `icon.svg` - Project icon

## Architecture Notes

This is a minimal starter project with:
- Single 3D scene containing a box mesh
- No scripting layer implemented yet
- No camera configured
- No input handling or game logic

For 2.5D development, typical patterns include:
- Fixed or orthographic camera setup
- Constrained movement axes
- Sprite-based characters in 3D space
- Limited rotation/movement planes

## Development Setup

The project uses Godot 4.4 with Forward Plus rendering. No external dependencies or build systems are configured. All development happens within the Godot editor environment.