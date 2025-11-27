# Kitchen Defense - Project Context Document
> Last Updated: Current Session
> Godot Version: 4.4 (Compatibility Renderer)

## Project Overview
A 3D roguelike tower defense game built in Godot 4.4. The project serves dual purposes: creating an engaging game and exploring agentic AI workflows with LLM integration.

## Project Location
```
C:\Users\Christian\OneDrive\Documents\kitchen-defense
```

## Architecture & Design Decisions

### Rendering
- **Compatibility Renderer** - chosen for broader hardware support
- Keep materials simple (Principled BSDF translates well)
- Texture resolutions: 512x512 to 1024x1024

### Node Patterns
- **Node3D** for stationary objects (towers, projectiles)
- **CharacterBody3D** for physics-based movement (enemies)
- **StaticBody3D** for towers with collision

### State Management
- **AutoLoad Singleton**: `GameManager` handles global state
- **Signal-based communication** between systems and UI
- Tower types defined in `GameManager._init_tower_types()`

### Collision Layers
- Layer 1: Environment/Towers
- Layer 2: Enemies

---

## File Structure

### Core Scripts
| File | Purpose |
|------|---------|
| `game_manager.gd` | AutoLoad singleton - gold, lives, waves, tower selection |
| `map/map_grid.gd` | Grid system with `class_name MapGrid` |
| `map/tower_placement_manager.gd` | Handles preview, placement, UI click filtering |
| `map/camera_controller.gd` | Camera movement |
| `map/wave_manager.gd` | Wave progression |

### Tower System
| File | Purpose |
|------|---------|
| `objects/tower_data.gd` | Resource class for tower definitions |
| `objects/basic_tower.gd` | Simple tower with targeting |
| `objects/basic_tower.tscn` | Basic tower scene |
| `objects/wizard_tower.gd` | Tower with procedural cast animation |
| `objects/wizard_tower.tscn` | Wizard tower with 3D model |
| `objects/basic_projectile.gd` | Projectile logic |

### Enemy System
| File | Purpose |
|------|---------|
| `objects/enemy.gd` | Enemy logic with NavigationAgent3D |
| `objects/enemy.tscn` | Enemy scene |
| `objects/enemy_spawner.gd` | Spawning logic |

### UI System
| File | Purpose |
|------|---------|
| `ui/build_menu.gd` | Dynamic tower selection buttons |
| `ui/build_menu.tscn` | Build menu panel (bottom-left) |
| `ui/resource_display.gd` | Gold/Lives/Wave display |
| `ui/resource_display.tscn` | Resource display (top-left) |
| `ui/wave_announcement.gd` | Wave start announcements |

### 3D Models
| File | Source |
|------|--------|
| `models/wizard_tower.glb` | Exported from Blender (wizard gnome) |

---

## Current Tower Types

Defined in `GameManager._init_tower_types()`:

| ID | Name | Cost | Damage | Range | Speed |
|----|------|------|--------|-------|-------|
| `basic` | Basic Tower | 100 | 25 | 10 | 1.0/s |
| `wizard` | Wizard Tower | 200 | 40 | 12 | 0.8/s |

### Adding New Towers
1. Create tower script extending Node3D (copy `wizard_tower.gd` as template)
2. Create tower scene (.tscn) with:
   - Root: StaticBody3D or Node3D with script
   - CollisionShape3D for physics
   - NavigationObstacle3D for pathfinding
   - RangeArea3D (Area3D) for target detection
   - Model/mesh nodes
3. Add tower data in `GameManager._init_tower_types()`:
```gdscript
var new_tower := TowerData.new()
new_tower.id = "unique_id"
new_tower.display_name = "Display Name"
new_tower.cost = 150
new_tower.scene = preload("res://objects/new_tower.tscn")
# ... other stats
tower_types.append(new_tower)
```

---

## Key Systems Explained

### Tower Placement (`tower_placement_manager.gd`)
- Raycasts from camera to find grid position
- Shows preview mesh with color feedback (green=valid, red=invalid)
- Checks `GameManager.can_afford_selected_tower()`
- Uses `map_grid.is_valid_build_position()` and `map_grid.occupy_cell()`
- **UI Click Prevention**: `is_mouse_over_ui()` checks `get_viewport().gui_get_hovered_control()`
- Keyboard shortcuts: 1-5 for tower selection

### Grid System (`map/map_grid.gd`)
- `class_name MapGrid` for type inference
- `grid_to_world(Vector2i) -> Vector3`
- `world_to_grid(Vector3) -> Vector2i`
- `is_valid_build_position(Vector2i) -> bool`
- `occupy_cell(Vector2i)` / `free_cell(Vector2i)`
- Cell size: 2.0 units (configurable)

### Tower Targeting (shared pattern)
```gdscript
@onready var range_area: Area3D = $RangeArea3D
var current_target: CharacterBody3D = null

func find_new_target() -> void:
    var enemies_in_range := range_area.get_overlapping_bodies()
    # Find closest enemy in group "enemies"
```

### Procedural Animation (`wizard_tower.gd`)
- Creates Animation resources in code
- Uses AnimationPlayer with AnimationLibrary
- Cast animation: tilt back → thrust forward
- Idle animation: subtle sway

---

## Navigation Setup
- `NavigationRegion3D` with baked NavMesh
- Enemies use `NavigationAgent3D`
- Towers have `NavigationObstacle3D` to block paths
- **Important**: NavigationRegion3D requires "Static Colliders" as parsed geometry type

---

## UI Configuration Notes
- Parent containers need `mouse_filter = 2` (IGNORE) to allow click-through
- Interactive elements keep default `mouse_filter = 0` (STOP)
- Build menu anchored to bottom-left with proper anchor presets

---

## Blender to Godot Workflow
1. Model in Blender with origin at base
2. Apply all transforms (Ctrl+A)
3. Export as glTF 2.0 (.glb)
4. Place in `res://models/`
5. Godot auto-imports on next scan
6. Instance in scene, rotate if needed (model may face wrong direction)

### Model Orientation Fix
If model faces backwards when using `look_at()`:
- Rotate the mesh instance 180° (not the parent that gets animated)
- Transform: `Transform3D(-1, 0, 0, 0, 1, 0, 0, 0, -1, 0, 0, 0)`

---

## Main Scene Structure (`kitchen_defense.tscn`)
```
Main (Node3D)
├── World (Node3D) [group: "level"]
│   ├── Camera3D
│   ├── NavigationRegion3D
│   │   └── Ground (StaticBody3D)
│   ├── MapGrid
│   ├── Towers (container for placed towers)
│   ├── TowerPlacementManager
│   ├── Enemies (container for spawned enemies)
│   ├── PathManager
│   │   ├── SpawnPoint1
│   │   └── EndPoint
│   ├── Lighting
│   └── EnemySpawner
└── UI (CanvasLayer)
    └── HUD (Control, mouse_filter=IGNORE)
        ├── ResourceDisplay
        ├── BuildMenu
        └── WaveAnnouncement
```

---

## Known Patterns & Gotchas

### Godot 4.4 Specifics
- Set `global_position` AFTER adding node to scene tree
- Use typed variables with `:=` only when return type is known
- `class_name` declarations enable type inference across files

### Common Issues
- **Type inference fails**: Ensure referenced class has `class_name` or use explicit typing
- **Tower faces wrong way**: Rotate the mesh child, not the root (which uses `look_at()`)
- **Clicks blocked by UI**: Set `mouse_filter = 2` on container Controls
- **Navigation not working**: Check collision layers and NavMesh bake settings

---

## Development Environment
- AMD Ryzen 7 7800X3D, 32GB RAM, RTX 4080 Super
- Ollama for local LLM inference
- AI Assistant Hub plugin (in addons/)
- Blender 5.0 with MCP integration for 3D modeling

---

## Future Considerations
- Tower upgrades system
- More enemy types with varied stats
- Procedural content generation via LLM
- Sound effects and particles
- Meta-progression / roguelike elements
