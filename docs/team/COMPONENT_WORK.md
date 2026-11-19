# BLOC: Component Work Remaining

This breakdown separates existing functionality from remaining work. The [current design](PROJECT_STATUS.md) describes the running game; the [Godot guide](GODOT_TEAM_GUIDE.md) explains editor workflows and code integration.

## Proof-of-concept scope

The proposed focus is a **two-player couch hot-seat game** with shared controls, simple bloc dropping and basic visuals. The existing prototype already supports this through its two-player option. It also supports three and four players; removing those options is not necessary to test the two-player version.

The suggested invisible loss plane differs from the current defeat rule. Today, crossing the fall boundary counts a piece as fallen; four pieces falling in one physical action causes defeat. Immediate defeat when a piece crosses a plane is a proposed simplification, not implemented behavior.

## 1. Main: startup and scene flow

![Player-count selection at startup](images-local/bloc_setup.png)

*The current setup screen offers 2, 3 or 4 players.*

**Files:** `scripts/main.gd`, `scenes/Main.tscn`

**Exists:** startup wiring, saved Board/HUD instances, editable player-count menu, creation of the game manager and restart to setup.

**Remaining work:**

- Polish the saved menu and start/restart presentation.
- Make the two-player starting path obvious for the proof of concept.
- Polish the dedicated Results scene and its final score presentation.

## 2. HUD: prompts and player handoff

![Begin turn prompt and player status sidebar](images-local/bloc_turn.png)

*The handoff prompt identifies P2, with phase, scores and hands in the sidebar.*

**Files:** `scripts/hud.gd`, `scenes/ui/HUD.tscn`, `MainMenu.tscn`, `ActionPrompt.tscn`, `Results.tscn`, `DiscardDialog.tscn` and reusable row templates

**Exists:** instructions, choices, scores, visible hands, discard dialog, event log and debug tools. Prompts identify the player making a decision.

**Remaining work:**

- Polish the saved UI scenes and introduce a shared theme if needed. Hand entries and legal choices are still populated dynamically from saved templates.
- Make the active player and the person currently expected to act easy to identify. Card effects can make these different people.
- Make the handoff between players clear using the existing Begin turn checkpoint.
- Keep placement instructions, invalid-placement reasons and results readable without relying on the debug log.
- Check long card text, scrolling and mouse/keyboard focus.

## 3. Game manager: turns and win/loss

![Production turn with supply and card state](images-local/bloc_placement.png)

*Visible game state during Production: one bloc has been drawn, and L08 is in P2’s hand. The manager itself has no separate screen.*

**File:** `scripts/game.gd`

**Exists:** turn order, Production and Collapse, legislation resolution, reactions, supply tracking, scoring and results. No separate controller or networking system is required for shared-keyboard hot-seat play.

**Remaining work:**

- Keep turn progression controlled by this component while screens are replaced.
- Verify that the next player cannot act until the current physical action settles.
- Resolve whether the proof of concept keeps the current rules or uses the proposed immediate-loss plane.
- If the rule changes, update defeat handling, result text, documentation and automated checks together.

## 4. Board: tower, camera and fall detection

![Focused tower and valid placement preview](images-local/bloc_placement.png)

*The destination tower is isolated during placement, with the camera centered beside the sidebar.*

**Files:** `scripts/board.gd`, `scenes/board/Board.tscn`, `scenes/board/Tower.tscn`

**Exists:** foundations, focused placement view, orbit/zoom, camera-relative movement, placement validation, physics settlement and fall monitoring.

**Remaining work:**

- Polish the saved tower scene while preserving its 4×4 footprint and collision geometry.
- Camera FOV, lighting, materials, player colors and settlement settings are editable. Orbit positioning and grid rules remain script-controlled.
- Verify camera framing after UI changes; sidebar width is now synchronized automatically.
- Test the simple drop-and-settle mechanic for predictable, readable results; high-fidelity simulation is not required.
- If adopted, implement the agreed loss-plane behavior and report the defeated owner to the game manager.

Current fall detection checks a placed body's center relative to its tower: below y = −0.3, or outside x/z bounds of −3 to 7. It is a coordinate check, not a saved plane or Area3D scene. A held preview does not count as fallen.

## 5. Blocs: physical pieces and visuals

![Compound bloc preview with piece ID and points](images-local/bloc_placement.png)

*The held 3-B shape is shown as one piece, labeled #21 / +3. This is a placement preview, before physics release.*

**Files:** `scripts/bloc.gd`, `scenes/blocs/Bloc.tscn`, `UnitCell.tscn`, `CardCell.tscn`

**Exists:** a single rigid body per bloc, compound cube meshes/colliders, identity, ownership and point labels.

**Remaining work:**

- Polish the saved cell templates and body label. All ten production shapes are saved scenes; tint, identity, centering and mass are assigned at runtime.
- Keep simple cube-based shapes for the proof of concept.
- Preserve alignment between the visible shape, colliders and placement bounds.
- Test stacking, rotation and removing support pieces after any geometry or physics changes.

## 6. Catalog: cards, shapes and supply

![Catalog-backed card selector and supply controls](images-local/bloc_debug.png)

*The debug selector uses catalog card entries. It is shown during placement here, so state-changing debug buttons are disabled.*

**Files:** `scripts/catalog.gd`, `scenes/blocs/shapes/`

**Exists:** ten shapes, 30 supply blocs, restricted draws and 11 cards with IDs L05–L15.

**Remaining work:**

- Keep the approved card list and shape definitions consistent with the rules.
- Shape geometry is now read from editable scenes. Card definitions, supply quantities and effect logic still require script changes.
- Preserve unique piece IDs, supply quantities and draw fallback behavior during any data migration.

## Integration checks

- Run a full two-player session using shared controls.
- Check player handoffs, placement, settlement, defeat and restart.
- Verify that edited scenes actually appear in the main game, rather than only in standalone previews.
- Run `python3 tests/run_tests.py` after gameplay or integration changes.
- Keep simple visuals as the baseline. Audio, elaborate animations, online play and additional controller support are not required for this proof of concept.

## Rule decisions still open

| Question | Current implementation |
| --- | --- |
| Does one piece crossing the loss plane cause immediate defeat? | Four falls within one physical action cause defeat |
| Is loss measured by the piece center or any part of its geometry? | Body center |
| Does the simplified version keep sideways fall detection? | Both vertical and horizontal fall bounds are checked |
| Does the proof of concept retain legislation and Collapse? | Both are active |
