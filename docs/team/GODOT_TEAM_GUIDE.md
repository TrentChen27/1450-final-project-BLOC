# Working on BLOC in Godot

This guide is for teammates using the editor as well as teammates writing GDScript. It describes the current project and gives proposed steps for making it easier to edit. **The new scenes and resources described below do not exist yet.** Creating a scene does not automatically connect it to the game.

## 1. Open, inspect, and make your first change

Follow [Get started](../../GETTING_STARTED.md) to clone and import the project. Use the team's Godot version, currently documented as 4.7.2. Run with F5. Pick two players and complete a turn before changing anything.

Useful editor areas:

| Area | What it is for |
| --- | --- |
| FileSystem | Project files; `res://` means the project folder |
| Scene tree | Nodes saved in the scene you are editing |
| Inspector | Properties of the selected node or resource |
| 2D / 3D workspace | Arrange UI / world objects |
| Signals panel | Connect events such as a button press to a receiving method |
| Output / Debugger | Messages, script errors and warnings |
| Local / Remote scene tree while running | Local is the saved scene; Remote shows the actual running objects |

Run the game and inspect **Remote** to see the generated HUD, camera and bodies. Remote edits are useful experiments, but do not save them as your implementation: they disappear when the game stops. Edit the source scene/resource, or ask the programmer to expose the runtime value.

A first edit that works today: stop the game, open `scenes/Main.tscn`, select `Board`, record Stable Duration, change it from 0.75 to 1.0, save and run. Release a piece and observe the longer stability wait. Restore the original if this was just practice. This setting controls the settlement check, not gravity or animation speed.

Godot's [nodes and scenes introduction](https://docs.godotengine.org/en/stable/getting_started/step_by_step/nodes_and_scenes.html) explains how these editor pieces fit together.

## 2. Working together without overwriting each other

1. Clone the repository rather than starting from a ZIP when contributing.
2. Update your local branch before starting. Use GitHub Desktop or Git in a terminal; a Godot Git plugin is not required.
3. Create a branch for one task, for example `ui/main-menu` or `art/tower-materials`.
4. Agree who owns the scene being edited. Avoid simultaneous edits to the same `.tscn`, `.tres` or shared script.
5. Save assets inside the project and move/rename them through Godot's FileSystem dock so references can be updated.
6. Commit the source scenes, scripts, materials and assets, including associated Godot UID files. Do not add generated `.godot/` cache files.
7. Push the branch and open a pull request with a screenshot, instructions to test, and any integration still needed.

A useful handoff says: “Open this scene with F6; these buttons are visual only; these node names must remain stable; this resource controls the colors.” F6 previews the current scene; F5 tests the integrated game. Both checks matter.

## 3. Menus, scene flow, and player controls

### Editor teammate: build a menu layout

1. Create a new **User Interface** scene with a `Control` root. Save it as a proposed `scenes/ui/MainMenu.tscn`.
2. Set the root to Full Rect. Add a full-rect `CenterContainer`, then a `VBoxContainer` inside it.
3. Add a title `Label`, help text, and Buttons named `TwoPlayers`, `ThreePlayers`, and `FourPlayers`. Set their Text values in the Inspector.
4. Add a shared Theme or local theme overrides for fonts, spacing and button appearance. Avoid relying on manual positions inside containers.
5. Preview with F6 and resize the preview window. Verify text stays readable.
6. Hand off the scene and desired button behavior. At this stage the buttons do not start a game.

### Programmer: integrate the flow

The current setup is `hud.setup_menu()` → `start_requested(count)` → `main._start(count)` → `game.configure(...)` → `game.run()`. Keep that contract while swapping in a scene-built menu. Load and instantiate the PackedScene rather than creating a second copy of the old menu. Connect each button once to emit the selected count; prevent repeated clicks from creating multiple managers.

Start by replacing a screen within the current main scene. Separate full gameplay scenes are optional; they are not required just to show a different screen. If the team later splits menu/gameplay scenes, explicitly pass the selected player count and clean up the old manager. Do not add another independent turn loop in a menu script. Test start, restart and return to menu while a choice or placement is pending.

Godot's [scene instantiation guide](https://docs.godotengine.org/en/stable/tutorials/scripting/nodes_and_scene_instances.html) covers loading reusable scenes. The [signals guide](https://docs.godotengine.org/en/stable/getting_started/step_by_step/signals.html) covers connecting events to methods; making a visual connection still requires a method that performs the action.

### Controls: editor configuration needs a code connection

The current controls use direct key checks in `board._unhandled_input()`. A programmer must first change those checks to named input actions. Then a teammate can use **Project → Project Settings → Input Map** to assign keys to actions such as `place_forward`, `place_back`, `place_left`, `place_right`, `place_raise`, `place_lower`, and `place_confirm`, plus the six rotation actions.

Preserve one grid move per press, camera-relative directions and the placement/settlement locks. Do not accidentally turn this into continuous movement by checking held input every frame. Orbit starts outside the UI and must end even when the mouse is released over UI.

Separate controllers also need a player-to-device mapping and decision-owner checks. That is additional logic, not just adding more Input Map entries. For card effects, the controller can differ from the tower owner. Online play would additionally need authority and synchronization design; it is outside the current implementation.

See Godot's [InputEvent and Input Map guide](https://docs.godotengine.org/en/stable/tutorials/inputs/inputevent.html).

## 4. Tower, camera, and environment

### Editor teammate: prototype a tower presentation

1. Create a 3D scene with a `Node3D` root named `Tower`. Save it as proposed `scenes/board/Tower.tscn`.
2. Add a `StaticBody3D` foundation with a `MeshInstance3D` and a `CollisionShape3D`.
3. Use a BoxMesh and BoxShape3D sized **(4, 0.44, 4)**. Place the foundation at **(2, −0.22, 2)** so its top is y=0 and its x/z footprint is 0–4, matching the current board.
4. Give the mesh a StandardMaterial3D through Material Override. Adjust color and roughness. Keep the physical size unchanged during an art-only task.
5. Add a `Label3D` for the player label and decorative children under a separate `Visuals` node. Decorative objects should not have colliders unless agreed.
6. For previewing only, make a separate showcase scene that instances the tower, adds a Camera3D and light, and runs with F6. A mesh alone may not be visible in a running scene without a camera/light.

### Programmer: replace the generated foundation safely

`board.setup(count)` currently creates each foundation, grid and label and records them in `tower_visuals`. Replace that creation with one Tower scene instance per player at the existing origin. Preserve references used to hide other towers during placement. Remove the corresponding procedural construction so there are no duplicate floors or colliders.

Keep the current board camera until it is deliberately extracted. `board._ready()` creates a camera, light and environment; adding another set to Main does not replace them. `_update_camera()` also overwrites the camera transform while running. Expose the intended tuning instead of asking artists to fight that script.

The camera centers the target tower in the space left of a **370-pixel sidebar**. Sidebar width currently appears in both HUD layout and Board settings. Changing only one will miscenter the tower; the integration task should share or calculate this value.

Acceptance checks: orbit from four sides, move with WASD, raise a piece high, place on another player's tower, release over a UI boundary, and verify all other towers reappear after settlement. Hidden towers must keep simulating physics.

## 5. Blocs: art, shape data, and physics

A bloc is one `RigidBody3D` with several mesh/collider children. Do not create a separate rigid body for every cube: that would make a shape fall apart. The catalog stores cell coordinates and point value; `bloc.build()` centers those cells and creates matching geometry. Mass currently depends on cell count.

### Editor teammate: make a visual sample

1. Create a `Node3D` scene for a bloc visual sample, with MeshInstance3D cube children.
2. Use one unit per cell. Put cube centers at integer coordinates to communicate the proposed shape clearly; record those coordinates in the handoff.
3. For an existing shape, copy its cell list from `catalog.gd` with a programmer's help. Keep its shape ID and point value in your notes.
4. Use shared materials for consistent appearance. If only one sample should change, make its material unique before editing it.
5. Save a showcase scene with camera and light and capture a screenshot. State whether it is an existing-shape reskin or a new shape proposal.

This sample is not automatically a playable bloc. A programmer must connect its visuals to `bloc.gd`, preserve the center offset and validate its colliders. Current regular collider/mesh dimensions are 0.98 per cube; the physical L08 card uses (1.8, 0.18, 1.1). Changing collider dimensions affects placement and stacking, not just appearance.

### Programmer: enable data editing in the Inspector

A possible next step is a custom `BlocDefinition` Resource exposing shape ID, point value, cell array and visual reference. Once the class exists, a designer can create `.tres` resources and fill them in through the Inspector. This is a proposed migration, not a feature currently available.

Convert definitions to the existing runtime data shape, and keep per-instance IDs/ownership separate from shared resource data. Keep the supply distribution at 8/7/6/5/4 pieces for values 1–5 unless the team changes the rules. A new entry must not silently create unlimited supply. Preserve one physical piece as one fall, regardless of cube count.

Run catalog and physics checks after shape integration. Test rotations, all footprint edges, stacking, overlap rejection, support removal and transfer between owners. Godot's [resources guide](https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html) explains reusable data assets and shared resource behavior.

## 6. Game state, cards, and winning

This is primarily a GDScript responsibility. `game.gd` already owns turn order, phase, deck/discard/hands, reactions, card effects and victory. The board reports falls and physical outcomes. The HUD presents questions and returns the chosen value.

A UI teammate can design a phase banner, active-player badge, scores and result panel without rewriting these rules. Use sample values in the preview and mark them as placeholders. Hand off fields for player number, phase, score, fallen count, winner and reason.

For integration, preserve these existing entry points:

| Entry point | Purpose |
| --- | --- |
| `hud.ask(question, choices)` | Wait for a choice; options carry IDs, labels and optional tooltips |
| `hud.choose(value)` | Complete the pending choice |
| `hud.refresh()` | Update visible state |
| `hud.log_event(text)` | Show an event |
| `hud.show_result(text)` | End-state presentation and pending-choice cancellation |
| `board.place(item, owner, controller, minimum_height)` | Placement with correct tower/control context |
| `board.remove_bloc()` / `board.settle()` | Physical operations resolved before continuing |

Do not advance a turn from an animation timer or button independently of `game.run()`. Do not judge defeat just from the total fallen counter: the rule tracks four falls within one physical action, including late falls. Collapse begins when supply is exhausted and requires relocation higher than before. Results use score, fewer total falls, then height among survivors.

Changing a card's displayed text in `catalog.gd` does not change its effect in `game.gd`. New rules need matching implementation and tests. Non-coders can write expected-outcome scenarios: starting state, action, expected hand/supply/tower changes, and whether anyone loses.

## 7. HUD, cards, art, and sound

### Editor teammate: build a reusable card panel

1. Create a scene rooted at `PanelContainer`, saved as proposed `scenes/ui/CardView.tscn`.
2. Add a `MarginContainer`, then a `VBoxContainer` with Labels for title, timing and effect. Enable word wrapping for the effect.
3. Add a Button for the action if this view is intended to be selectable. A hand display and a legal-action button have different roles in the current game.
4. Set sensible minimum widths and use container sizing settings to allow expansion. Test the longest remaining card text.
5. Save a Theme resource for shared fonts/colors/styles and assign it at a parent control. A programmer must reconcile existing hardcoded theme overrides when integrating it.
6. Create a showcase with several card instances: normal, disabled, hovered/focused and selected. Those states should be distinguishable without color alone.

Containers control their children's positions. Adjust container spacing, margins, minimum sizes and sizing flags instead of dragging those children around. See [Godot's container guide](https://docs.godotengine.org/en/stable/tutorials/ui/gui_containers.html).

For the HUD, preserve separate areas for instructions, scores, hands, choices and event log. Let long content scroll. Decorative full-screen controls should ignore mouse input; interactive panels should receive it. Test that clicking UI does not orbit the camera, and that Space still releases a piece after using debug controls.

Place source images, fonts and sound files inside proposed folders such as `assets/ui/`, `assets/fonts/`, `assets/materials/` and `assets/audio/`. Godot imports assets placed in the project automatically; select them in FileSystem to inspect import settings. Keep source/license attribution with third-party assets. See the [asset import guide](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/import_process.html).

There is no audio system yet. A teammate can prepare and preview sounds with AudioStreamPlayer nodes; a programmer must connect playback to events such as valid release, settled action and victory. Avoid playing an impact sound every physics frame. Sound is optional scope, not a prerequisite for the existing game to run.

## 8. Finish and verify a task

Include this checklist in the handoff:

- [ ] Scene/resource paths and owner recorded; new assets are in the repository.
- [ ] F6 preview works, or required parent dependencies are documented.
- [ ] F5 integration works, or the task is explicitly marked “visual prototype, integration pending.”
- [ ] Two-player and four-player layouts checked; long text and scrolling checked.
- [ ] Input works after interacting with UI; no accidental extra choices or releases.
- [ ] Normal placement, invalid placement and settlement checked if affected.
- [ ] Restart during a pending prompt/placement checked if flow or UI changed.
- [ ] Output/Debugger inspected for errors.
- [ ] Programmer ran `python3 tests/run_tests.py` for gameplay/integration changes and attached the result.

The debug tools in [README](../../README.md) let you force cards, add test blocs, remove supports and exhaust supply at turn checkpoints. They are the fastest way to reproduce an edge case. Report expected versus actual behavior, the card/piece IDs, player count and reproduction steps.

For release, a teammate must configure **Project → Export**, obtain the matching export templates, choose the agreed desktop target, and test the resulting build on that platform without the editor. Export presets are not currently checked in. Do not assume that passing the editor playtest also verifies a distributable build.
