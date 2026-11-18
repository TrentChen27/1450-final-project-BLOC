# BLOC: Component Work Remaining

This breakdown separates existing functionality from remaining work. The [current design](PROJECT_STATUS.md) describes the running game; the [Godot guide](GODOT_TEAM_GUIDE.md) explains editor workflows and code integration.

## Proof-of-concept scope

The proposed focus is a **two-player couch hot-seat game** with shared controls, simple bloc dropping and basic visuals. The existing prototype already supports this through its two-player option. It also supports three and four players; removing those options is not necessary to test the two-player version.

The suggested invisible loss plane differs from the current defeat rule. Today, crossing the fall boundary counts a piece as fallen; four pieces falling in one physical action causes defeat. Immediate defeat when a piece crosses a plane is a proposed simplification, not implemented behavior.

## 1. Main: startup and scene flow

**Files:** `scripts/main.gd`, `scenes/Main.tscn`

**Exists:** startup wiring, player-count selection, creation of the game manager and restart to setup.

**Remaining work:**

- Create an editor-built menu and clear start/restart flow.
- Make the two-player starting path obvious for the proof of concept.
- Connect menu and result screens without creating duplicate game managers or leaving pending choices active.

**Editor work:** menu and result scene layouts. **Code work:** button connections, game initialization and cleanup.

**Complete when:** start → two-player game → result → restart works repeatedly, including restarting during placement.

## 2. HUD: prompts and player handoff

**File:** `scripts/hud.gd`

**Exists:** instructions, choices, scores, visible hands, discard dialog, event log and debug tools. Prompts identify the player making a decision.

**Remaining work:**

- Move generated controls into reusable UI scenes that can be edited visually.
- Make the active player and the person currently expected to act easy to identify. Card effects can make these different people.
- Make the handoff between players clear using the existing Begin turn checkpoint.
- Keep placement instructions, invalid-placement reasons and results readable without relying on the debug log.
- Check long card text, scrolling and mouse/keyboard focus.

**Editor work:** Control layouts, containers, fonts and theme. **Code work:** populate fields and connect choices to existing game methods.

**Complete when:** two players can follow turns and card decisions without someone explaining which button to press; UI interaction does not accidentally move or release a bloc.

## 3. Game manager: turns and win/loss

**File:** `scripts/game.gd`

**Exists:** turn order, Production and Collapse, legislation resolution, reactions, supply tracking, scoring and results. No separate controller or networking system is required for shared-keyboard hot-seat play.

**Remaining work:**

- Keep turn progression controlled by this component while screens are replaced.
- Verify that the next player cannot act until the current physical action settles.
- Resolve whether the proof of concept keeps the current rules or uses the proposed immediate-loss plane.
- If the rule changes, update defeat handling, result text, documentation and automated checks together.

**Editor work:** result and phase display mockups. **Code work:** rules, state transitions and tests.

**Complete when:** a two-player session starts, alternates correctly, ends under the agreed condition and restarts cleanly. Card reactions must still identify the correct decision-maker if cards remain enabled.

## 4. Board: tower, camera and fall detection

**File:** `scripts/board.gd`

**Exists:** foundations, focused placement view, orbit/zoom, camera-relative movement, placement validation, physics settlement and fall monitoring.

**Remaining work:**

- Extract the tower presentation into an editable scene while preserving the existing 4×4 footprint and collision geometry.
- Expose useful visual and camera settings in the Inspector.
- Keep the destination tower centered when UI layout changes.
- Test the simple drop-and-settle mechanic for predictable, readable results; high-fidelity simulation is not required.
- If adopted, implement the agreed loss-plane behavior and report the defeated owner to the game manager.

Current fall detection checks a placed body's center relative to its tower: below y = −0.3, or outside x/z bounds of −3 to 7. It is a coordinate check, not a saved plane or Area3D scene. A held preview does not count as fallen.

**Editor work:** foundation visuals, materials and lighting. **Code work:** scene integration, camera framing and fall detection. A loss zone could be an Area3D or a coordinate check; either needs logic connecting it to defeat.

**Complete when:** valid releases settle, invalid releases stay blocked, falls are reported once for the correct tower, and the camera remains usable throughout both players' turns.

## 5. Blocs: physical pieces and visuals

**File:** `scripts/bloc.gd`

**Exists:** a single rigid body per bloc, compound cube meshes/colliders, identity, ownership and point labels.

**Remaining work:**

- Provide reusable visual templates or exposed materials for editor-based changes.
- Keep simple cube-based shapes for the proof of concept.
- Preserve alignment between the visible shape, colliders and placement bounds.
- Test stacking, rotation and removing support pieces after any geometry or physics changes.

**Editor work:** materials and visual samples. **Code work:** connect templates to the generated bodies and preserve geometry offsets.

**Complete when:** each shape remains one physical piece, looks consistent with its collision shape, and behaves correctly when dropped or transferred.

## 6. Catalog: cards, shapes and supply

**File:** `scripts/catalog.gd`

**Exists:** ten shapes, 30 supply blocs, restricted draws and 11 cards with IDs L05–L15.

**Remaining work:**

- Keep the approved card list and shape definitions consistent with the rules.
- If non-coders need to edit definitions regularly, expose them as Inspector-editable resources with code support for loading them.
- Preserve unique piece IDs, supply quantities and draw fallback behavior during any data migration.

**Editor work:** resource values once resource classes exist. **Code work:** resource definitions, loading, validation and card effects. Editing card text alone does not implement an effect.

**Complete when:** the intended content loads without duplicates or missing entries, and supply and card checks pass. Data migration is optional for the first two-player playtest.

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

These decisions affect game behavior. They have not been applied by this documentation update.
