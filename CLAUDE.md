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