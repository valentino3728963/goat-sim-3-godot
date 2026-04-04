# 🐐 Goat Sim 3 — Godot 4 Edition

A fully playable **Goat Simulator**-inspired open-world 3D game built entirely
in **Godot 4** with GDScript. Everything is procedurally generated from
polygon primitives — no external assets required.

---

## Features

| Category | Detail |
|---|---|
| **Player** | Goat built from box/cylinder/sphere primitives, third-person spring-arm camera, pointer lock |
| **Controls** | WASD move · Mouse look · Space jump · Shift sprint · LMB headbutt · R ragdoll · ESC pause |
| **World** | City with 15–20 polygon buildings, road grid, sandy beach, rolling hills, terrain |
| **Water** | Animated wave shader (translucent, reflective) |
| **NPCs** | 8 pedestrians walking AI with waypoints; react to headbutt with ragdoll physics |
| **Props** | Street lamps (with OmniLight3D), parked cars, benches, trees, fences, trash bins |
| **Graphics** | MSAA 2×, SSAO, glow/bloom, procedural sky, directional sun with 4-split shadows, fog |
| **HUD** | Score counter · Speed display · Mouse-lock hint |
| **Menus** | Animated start screen · Pause menu (Resume / Quit to Menu) |

---

## How to Play

### 1 — Download Godot 4

1. Go to <https://godotengine.org/download/>
2. Download **Godot 4.x** (Standard build, no Mono needed).
3. Extract/install as appropriate for your OS.

### 2 — Open the Project

1. Clone or download this repository:
   ```bash
   git clone https://github.com/valentino3728963/goat-sim-3-godot.git
   ```
2. Launch Godot 4.
3. Click **Import** → navigate to the cloned folder → select `project.godot` → **Open**.
4. Godot will import assets and open the project editor.

### 3 — Run the Game

- Press **F5** (or the ▶ Play button) to run from the main menu.
- The game starts with an animated title screen — press **Enter** to begin.

### 4 — Controls

| Key / Button | Action |
|---|---|
| **W A S D** | Move (camera-relative) |
| **Mouse** | Look around (pointer locked) |
| **Space** | Jump |
| **Shift** | Sprint |
| **Left Click** | Headbutt nearby NPCs / objects (+10 score) |
| **R** | Toggle ragdoll mode |
| **ESC** | Pause / release mouse |

### 5 — Export to .exe (Windows)

1. In Godot 4, open **Project → Export**.
2. Click **Add** → choose **Windows Desktop**.
3. If prompted, download the export templates (one-click in the dialog).
4. Set an output path and click **Export Project**.
5. Share the resulting `.exe` + `.pck` file.

---

## Project Structure

```
goat-sim-3-godot/
├── project.godot           ← Godot 4 project config, input map, MSAA
├── scenes/
│   ├── main_menu.tscn      ← Animated start screen
│   ├── game.tscn           ← Root game scene (loads world_builder)
│   ├── player.tscn         ← Goat CharacterBody3D
│   ├── npc.tscn            ← Pedestrian CharacterBody3D
│   ├── hud.tscn            ← Score / speed overlay
│   └── pause_menu.tscn     ← Pause screen
├── scripts/
│   ├── main_menu.gd        ← Title screen controller
│   ├── world_builder.gd    ← Procedural world generator
│   ├── player.gd           ← Goat movement, camera, headbutt, ragdoll
│   ├── npc.gd              ← NPC walking AI + headbutt reaction
│   ├── hud.gd              ← HUD updater
│   └── pause_menu.gd       ← Pause / resume / quit
├── shaders/
│   └── water.gdshader      ← Animated wave shader
└── README.md
```

---

## Tech Notes

- All geometry is built at runtime from Godot 4 primitive meshes
  (`BoxMesh`, `CylinderMesh`, `SphereMesh`, `PlaneMesh`).
- No external texture files — all materials use `StandardMaterial3D`
  with albedo colours, roughness, and metallic values.
- Water uses a custom `spatial` shader with vertex displacement for waves.
- NPCs use `CharacterBody3D` with a simple state machine
  (WALKING → RAGDOLL → RECOVERING).
- The world is seeded with `RandomNumberGenerator` on each run
  for slight variation in tree placement and NPC hair colour.