# Start here: editing BLOC

Open **Main.tscn**. Its root is **BLOC**, with **Board**, **HUD** and **GameManager** underneath. If the root says Board, only the board scene is open. Use 3D for world objects, 2D for UI, and F5 for the full game.

## Scene map

| What you want to change | Open |
| --- | --- |
| Whole game composition | `Main.tscn` |
| Camera, lighting, background, tower positions | `board/Board.tscn` |
| Shared foundation, grid, player label style | `board/Tower.tscn` |
| Menu text and player-count buttons | `ui/MainMenu.tscn` |
| Sidebar, scores, hand area, log, debug controls | `ui/HUD.tscn` |
| Decision prompt layout | `ui/ActionPrompt.tscn` |
| Game-over screen and restart button | `ui/Results.tscn` |
| Discard window | `ui/DiscardDialog.tscn` |
| Discarded card text layout | `ui/DiscardEntry.tscn` |
| Player hand heading and empty state | `ui/PlayerHand.tscn` |
| Card appearance in a hand | `ui/CardView.tscn` |
| Generated action button appearance | `ui/ChoiceButton.tscn` |
| Shared fonts and UI styling | `ui/GameTheme.tres` |
| All bloc shapes together | `blocs/BlocLibrary.tscn` |
| A particular playable shape | `blocs/shapes/Bloc1A.tscn` through `Bloc5B.tscn` |
| Physical −2 legislation card | `blocs/PhysicalCard.tscn` |
| Shared body physics and label style | `blocs/Bloc.tscn` |
| Shared cube mesh/material/collider | `blocs/UnitCell.tscn` |
| Shared physical-card mesh/material/collider | `blocs/CardCell.tscn` |

Both player towers and Main's Board/HUD instances have editable children enabled. Open a source scene to change all instances, or use a local override for one instance. Preserve script-referenced node names and unique names marked `%`.

## What you will see before Play

Main contains two towers, a visible menu and editor-only bloc examples. Expand **Board → EditorBlocPreviews → AllShapes** to browse all shapes, or open BlocLibrary directly. Select an object and use the editor's frame-selection command to find it in the 3D view.

ActionPrompt, Results and DiscardDialog are hidden inside HUD until needed. Open their source scenes to edit them separately. Empty Cards/Options/Entries containers are intentional: the game fills them with instances of the saved row/button scenes.

BlocLibrary and EditorBlocPreviews are layout previews, not playable scenes. Their instances have collisions disabled and the Board removes the entire preview group before gameplay. Change the source shape scene, not the preview's position, to change a playable shape. F5 always runs the full game; F6 is only useful for scenes with a suitable standalone setup.

## What scripts still control

- Turn order, card effects, supply quantities, point values and win/loss rules.
- Which cards and choices appear, player IDs, scores and log text.
- Camera orbit/focus, piece centering, mass and ownership/validity tint.

GameManager is a saved node so its location is clear, but its rules are GDScript. Geometry and layout edits are saved in scenes; changing displayed text alone does not change a rule.

Keep tower rotations at zero, scale at one and the foundation footprint at 4×4. For bloc shapes, use direct CollisionShape3D children with BoxShape3D shapes, integer cell positions and a Mesh child per cell. Move cell roots rather than moving meshes away from their colliders.

Detailed steps: [Godot team guide](../docs/team/GODOT_TEAM_GUIDE.md). Run `python3 tests/run_tests.py` after integration or gameplay changes.
