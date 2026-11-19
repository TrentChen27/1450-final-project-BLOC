# Working on BLOC in Godot

The game presentation is saved as editable Godot scenes. Start with [the scene directory guide](../../scenes/README.md) for a concise editing map. Open `scenes/Main.tscn` to see the board and HUD before pressing Play. Use the **3D** workspace for towers and the **2D** workspace for UI. F5 runs the complete game.

The full scene tree is rooted at **BLOC**. If the root says **Board**, you have opened only `Board.tscn`; open `scenes/Main.tscn` to see **Board and HUD together**. Both player instances and Main's Board/HUD instances have editable children enabled.

`EditorBlocPreviews` contains two tower examples and an `AllShapes` library visible before Play. They are removed immediately at runtime and never count toward supply, scores or collisions. Actual pieces appear when drawn. Edit the source scenes under `scenes/blocs/shapes/` to change production shapes. Moving library instances only changes the editor display layout.

## Which scene to open

| File | What to edit |
| --- | --- |
| `scenes/Main.tscn` | Overall composition: Board and HUD instances |
| `scenes/board/Board.tscn` | Camera, environment, sunlight, player colors, tower layout and settlement settings |
| `scenes/board/Tower.tscn` | Shared foundation mesh/collider, grid and player-label appearance |
| `scenes/ui/HUD.tscn` | Sidebar, title, scores, hands area, prompts, debug controls and log |
| `scenes/ui/MainMenu.tscn` | Setup instructions and 2/3/4-player buttons |
| `scenes/ui/ActionPrompt.tscn` | In-game decision panel and choices area |
| `scenes/ui/Results.tscn` | Game-over heading, result text and restart button |
| `scenes/ui/DiscardDialog.tscn` | Discard window, empty state and scrolling area |
| `scenes/ui/DiscardEntry.tscn` | One discarded card's text formatting |
| `scenes/ui/PlayerHand.tscn` | Player heading, empty-hand message and cards area |
| `scenes/ui/GameTheme.tres` | Shared UI theme, including default font size |
| `scenes/ui/ChoiceButton.tscn` | Appearance of dynamically generated action buttons |
| `scenes/ui/CardView.tscn` | Appearance of cards displayed in hands |
| `scenes/blocs/BlocLibrary.tscn` | All ten bloc shapes and the physical card together |
| `scenes/blocs/shapes/Bloc1A.tscn` through `Bloc5B.tscn` | Individual production shapes: cell positions, meshes and colliders |
| `scenes/blocs/PhysicalCard.tscn` | The production L08 physical card |
| `scenes/blocs/Bloc.tscn` | Rigid-body settings and piece-label appearance |
| `scenes/blocs/UnitCell.tscn` | Mesh, material and collider used for each regular bloc cell |
| `scenes/blocs/CardCell.tscn` | Mesh, material and collider used for the physical L08 card |

Double-click a scene in FileSystem to open its source. Nodes instanced from another scene are edited in that source scene; use the scene icon beside the instance to open it. For an intentional per-instance change, enable **Editable Children** on that instance. A shared source change affects every instance unless that property has a local override.

## First UI edit

1. Open `scenes/ui/MainMenu.tscn` in the 2D workspace.
2. Expand `Padding → Content`. Select `PromptLabel` and edit **Text** in the Inspector.
3. Expand `ChoicesScroll → Options`. Select `Players2` and edit its button text or theme overrides.
4. Save, then run the full project with F5. The same saved menu and buttons appear in the running game.
5. Keep the buttons' `player_count` metadata values at 2, 3 and 4; those values choose the game size.

Use `HUD.tscn` for the sidebar and overall prompt placement. ActionPrompt and Results are separate saved scenes, hidden in HUD until needed. Open their source scenes to edit them visibly. The menu is visible initially and hidden after selection. DiscardDialog is also saved and hidden in HUD until opened.

Containers arrange their children. Change padding, separation, minimum size and sizing flags instead of manually dragging controls inside a container. The HUD uses `GameTheme.tres`. Some nodes have local font-size overrides; edit or remove those if you want them to inherit the theme. [Godot container reference](https://docs.godotengine.org/en/stable/tutorials/ui/gui_containers.html).

The sidebar width is read by Main and passed to the board camera, including when resized. For a width change, adjust Sidebar's left offset in `HUD.tscn`; camera centering follows its actual width. Preserve the right-side anchoring for this layout.

## Towers and environment

1. Open `scenes/board/Board.tscn` in 3D.
2. Select `Sun` to adjust light color, energy and shadows, or `WorldEnvironment` to edit background and ambient lighting.
3. Select `Camera3D` to change lens properties such as FOV. Camera position and rotation are controlled by orbit/focus logic at runtime, so use the camera controls in-game to change viewing angle.
4. Open `Tower.tscn`. Select `Foundation/Mesh` to edit its material or replace its visual mesh. Grid and PlayerLabel are saved children.
5. Save and run F5. Check placement on both players' towers.

Board contains two saved tower instances. Runtime setup reuses them, creates third/fourth towers when selected, and removes unused authored extra towers for smaller games. Player 2's foundation has a local material override in Board; edit that override to change its color. Materials on saved tower instances are preserved at startup. Additional generated towers receive their player color.

Tower layout supports translations. Keep Board, Towers and Tower rotation at zero and scale at one: the rules use an axis-aligned 4×4 grid. Keep each foundation's top at local y=0 and footprint at x/z=0–4. Changing those dimensions is a gameplay change that also needs placement/fall-rule updates. Add purely decorative objects without colliders unless they are meant to affect gameplay.

Player label text and tint come from the player index and Board's **Player Colors** array; font, size and other appearance settings remain editable in the scene. Hidden towers still simulate physics during another tower's placement.

## Bloc visuals and physics

Open `Bloc.tscn` to inspect a rigid body, a sample cube and its label. The sample cube makes the scene visible in the editor. At runtime it is replaced with the selected shape's cells; it is not an extra gameplay piece.

Edit `UnitCell.tscn` for regular cube visuals, and `CardCell.tscn` for physical-card visuals. Each template has a CollisionShape3D root and a Mesh child. A cell is part of a compound bloc body, not an independent rigid body. Decorative children can be added beneath Mesh.

- Regular cell mesh and collider sizes are currently 0.98 units per side.
- The physical card size is (1.8, 0.18, 1.1).
- Keep the mesh centered on its collider and visual dimensions aligned with physical dimensions.
- Material roughness, textures and other appearance properties come from the template. Runtime tint indicates validity while held and player ownership after release.
- `Bloc.tscn` exposes the unit/card PackedScene references and saved damping/friction settings. Runtime mass is derived from the number of cells.
- The label's font and appearance are saved; its ID and points are filled in by the game.

All ten complete shapes are saved in `scenes/blocs/shapes/`. They inherit the shared Bloc body and instance the UnitCell template. Gameplay loads these exact scenes, and the catalog reads their collider positions for supply data, so there is no second hardcoded shape list to edit.

To change a shape, open its source scene and move its CollisionShape3D cell roots to integer grid coordinates; move the mesh with the collider, not separately. The cell nodes must remain direct children of the rigid body. Keep each collider's `Mesh` child and use BoxShape3D colliders. `SampleCell` is the first real cell in an authored shape; it is only a removable preview in the generic Bloc fallback. Add cells by instancing `UnitCell.tscn`. Avoid duplicate coordinates or empty shapes. Changes to geometry affect balance and require playtesting.

At runtime, collider positions are centered around their average, preserving the existing rotation behavior. The value label remains at its authored offset relative to that centered body. All cell materials keep their own textures/roughness, with runtime tint applied to each. Point values, shape IDs, supply quantities and legislation effects remain rule data in GDScript; editing label text does not change them.

## What still happens in scripts

| Dynamic content | Why it remains dynamic |
| --- | --- |
| Turns, card effects, victory and phase changes | Game rules and state belong to `game.gd` |
| Hand entries and legal action buttons | Contents depend on the current state; saved templates provide their appearance |
| Score text, logs and instructions | Values change during play |
| Discard entries | Saved DiscardEntry scenes are populated inside the saved dialog |
| Bloc identity and centering | Saved shape geometry is centered and assigned its instance ID when drawn |
| Third/fourth tower instances | Created only when those player counts are selected |
| Camera orbit/focus and placement preview | Follow input and the current destination tower |

Keep named nodes used by scripts (including `%` unique names) intact when rearranging layouts. Main uses `Board`, `HUD`, `GameManager` and HUD's `Root/MainMenu`; Board uses `Camera3D`, `Towers`, and each tower's `Foundation/Mesh` and `PlayerLabel`; bloc templates use `Mesh`, `SampleCell` and `ValueLabel`. Renaming these requires updating the corresponding script references.

The board still uses direct key checks. Changing Input Map alone will not remap controls. Shared-keyboard hot-seat play is implemented; separate devices and online play are not.

## Adding assets

Place source images, fonts, materials and models inside project folders such as `assets/ui/`, `assets/fonts/`, `assets/materials/` and `assets/models/`. Godot imports files placed in the project automatically. Add imported visuals to the appropriate saved scene, then test in the full game. Keep source/license attribution for third-party assets. [Godot asset import guide](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/import_process.html).

A new decorative model should not silently introduce collision geometry or change the playable footprint. Use a unique material when changing only one instance; shared materials affect all users of that resource. [Godot resources guide](https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html).

## Working together and testing

- Clone and use a task branch. Agree who is editing each scene to avoid simultaneous changes to the same file.
- Move and rename files through Godot's FileSystem dock so references can be updated.
- Commit source scenes, scripts, assets and associated UID files. Do not commit the generated `.godot/` cache.
- F6 previews a standalone scene's layout; menu/game behavior is wired by Main, so use F5 for actual play.
- Check two- and four-player setup, readable long text, camera orbit, placement, settlement and restart after UI/world changes.
- Preserve GUI mouse filtering: decorative overlays should not block board input, while interactive panels should receive clicks.
- Run `python3 tests/run_tests.py` for integration or gameplay changes. Eight suites cover rules, physics, UI, camera, full playthrough, saved-scene editing and presentation integration.

Use the in-game debug tools described in [README](../../README.md) to force cards, add blocs and reproduce edge cases. [Component Work Remaining](COMPONENT_WORK.md) records remaining work; [Current Design](PROJECT_STATUS.md) describes the systems and rules.
