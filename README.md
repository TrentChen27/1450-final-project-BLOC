# BLOC — Rules Lab

A playable 3D, 2–4 player local hot-seat prototype of BLOC. Built with Godot 4.7.2 and GDScript; no plugins, downloads, or external art required.

## Run

Open `project.godot` in Godot and press **F5**. Choose 2, 3, or 4 players. You can operate every player yourself: all hands are visible and each prompt says who makes the decision.

At the start of a turn, click **Begin turn**. Resolve any legislation prompts, play one legal on-turn card or skip, place the required pieces, then click **End turn**. Four complete pieces falling in one physical action defeats that tower's owner; surviving towers are scored. When supply runs out, take pieces from your own tower and place them higher in the Collapse Phase.

## Placement controls

| Control | Action |
| --- | --- |
| W / A / S / D | Move one grid unit relative to the camera |
| R / F | Raise / lower by one unit |
| Q / E | Rotate around the vertical axis |
| Z / X | Rotate around the first horizontal axis |
| C / V | Rotate around the other horizontal axis |
| Space | Release a valid placement |
| Left mouse drag | Orbit the camera |
| Mouse wheel over the board | Zoom |

**Green** preview means valid; **red** means outside the footprint, overlapping something, or not high enough for Collapse. The instruction at upper left explains why. The camera automatically centers the destination tower beside the sidebar when placement starts, including transfers and harmful cards placed on opponents. It frames the tower and raised preview together; left-drag orbits and the wheel adjusts zoom. During placement and settling, other towers are hidden so only the destination tower and UI remain visible. Their physics and late-fall checks keep running; they reappear after settling. WASD follows the camera: W moves away, S toward, A left, and D right. Directions snap to the nearest perpendicular grid axes as you orbit, preserving exact one-cell movement. Rotate or translate until the entire piece fits inside the mat. There is no gameplay height limit. Blocs display their **ID and signed point value**; IDs match selection prompts when transferring or relocating pieces.

Physics runs after each release or removal. Input is locked until the affected tower is stable. The Board node in `scenes/Main.tscn` exposes the stability duration (0.75 seconds), velocity thresholds, and ten-second failsafe in the Inspector.

## Playtesting particular cards

Open **Playtest / debug controls** in the right sidebar. Scroll the sidebar to reach all controls. Mutations are enabled at the **Begin turn checkpoint**, where they cannot interrupt an in-progress effect.

- **Force next card:** choose a card, then click this button. The next Production legislation draw uses that card. Click Begin turn to draw it. A reaction enters the hand and waits for its legal trigger.
- **Give card to player:** select a card and player. An immediate card resolves right away; other cards enter the selected hand, enforcing overflow immediately.
- **Place supply bloc:** takes an actual remaining bloc of the selected point value, including the fallback rule, and lets the selected player place it.
- **Add test bloc:** creates an extra piece for constructing test towers without consuming supply. These are explicitly outside the standard 30-piece game.
- **Remove tower bloc:** choose a physical piece to remove permanently, then resolve the tower's physics.
- **Empty supply:** the next turn enters Collapse. Give each player some blocks first if you want to test relocation rather than empty-tower defeat.
- **Next player:** advances the active player at the checkpoint.
- **Pause after each physical action:** gives a Continue prompt after every removal and placement.
- **Slow physics:** runs simulation at 0.35× speed. Stability timers use simulation time.
- **Restart:** returns to player-count selection, including during a prompt or placement.

Example: start three players, give L12 to P2 and force L07 as the next draw. Begin the turn, choose P2's exemption when prompted, and verify that P1 and P3 each place two 1-point blocs while P2 does not. For transfers, first add some test blocs. For L13, create a discard by playing a card or forcing a hand-limit discard, then give L13 to the current player.

Physical cards cannot be duplicated by debug card-giving/forcing while already in a tower. Remove the physical object or restart first. Debug actions intentionally allow nonstandard scenarios; use Restart for a clean finite-supply game.

The discard dialog shows full card names and effects. Hover a card in the all-hands sidebar to read its effect. Legal playable cards appear as buttons in the decision prompt; sidebar cards are informational.

## Rule interpretations

The implementation follows `Bloc_Rules_First_Godot_Prototype_Spec (1).md`. These clarify remaining cases:

1. **L13 + physical cards:** the selected original card stays in discard; replaying L08 creates a separate signed physical token. A normal L08 card stays out of the deck while its object exists and returns to discard when that object falls or is permanently removed by debug.
2. **Current deck:** the four retired cards L01–L04 are removed. The 11 remaining cards retain IDs L05–L15.
3. **L09 and exhaustion:** if interception consumes the last supply bloc, skip the unavailable replacement, finish queued effects, then enter Collapse. Replacement draws continue the current reaction window; they do not recursively open another one.
4. **Reaction nesting:** L09/L15 resolve directly inside their existing windows, without opening a second defensive window. This follows the specification's prohibition on reactions triggering new windows. L11 reopens targeted defenses with the same used-player set, so no player reacts twice to that redirected announcement.
5. **Self-only effects:** L10 remains self-only; L11 cannot redirect it to another player. L12 can exempt its owner before resolution.
6. **No legal effect:** impossible transfer/theft/restructuring choices are disabled; an effect that becomes impossible after reactions is skipped and logged. If all legislation cards are held or physical, an unavailable legislation draw is skipped.
7. **Exhaustion beats extra turns:** when the supply is empty at turn end, Collapse begins clockwise; L15 cannot prolong Production.
8. **L10 selection loss:** if a previously selected bloc falls while another selected bloc is being removed, the fallen bloc stays removed. Only successfully held, non-fallen pieces are replaced.
9. **Geometry:** all unit-cube extents must fit in the 4×4 footprint at release. Cube collision boxes are 0.98 units wide to avoid touching-grid overlap ambiguity; physical cards are 1.8×0.18×1.1 units for usable collision thickness. Body origins are at the average cube center, and the preview aligns the original cell coordinates to the grid.
10. **Scoring:** held and removed pieces do not score. Bodies moving downward faster than 0.5 units/second are temporarily excluded from score calculations; settled placements/removals/falls refresh the display. A completed transfer uses the destination owner for future falls.
11. **Late falls:** scan all towers continuously, and scan again before assigning a new physical action. A late fall is charged to the previous action until another action actually starts on that tower. Four fallen bodies in that action immediately end play.
12. **Prototype victory:** score, then fewer total falls, then stable physical height; equal results share victory. Empty towers lose at the start of their Collapse turn. There is no hidden information, networking, save/load, or AI.

## Files

- `scenes/Main.tscn`: runnable scene and editable Board physics settings.
- `scripts/main.gd`: startup and scene wiring.
- `scripts/catalog.gd`: all 11 cards, ten shapes, finite supply and restricted draws.
- `scripts/game.gd`: turn flow, reactions, card resolution, Collapse, victory, debug operations.
- `scripts/board.gd`: board, camera, placement validation, physical actions and fall monitoring.
- `scripts/bloc.gd`: compound rigid bodies and physical card pieces.
- `scripts/hud.gd`: setup, hands, prompts, discard, log, debug panel and results.
- `tests/`: dependency-free Godot test scripts and graphical preview capture.

## Verification

Run from this folder with Godot on PATH:

```sh
python3 tests/run_tests.py
```

The runner uses only Python's standard library and the installed Godot executable. It fails on Godot script errors even if the engine reports exit code zero. No test packages are installed.

The suites cover exact finite supply and fallback, all 11 card effects, replay identity, exemptions/redirection, theft overflow, full turn flow and extra-turn order, real physics bounds/overlap/settling/support removal, late-fall defeat, actual Space input, debug controls, restart during pending placement, and an automated three-player game through to a winner with real physics.

`godot --path . --script res://tests/preview.gd` captures UI screenshots under `/tmp` and exits.

## Playtest limitations

This is a rules prototype: stacking uses real rigid bodies but is not calibrated to wood. Physics outcomes can vary with placement and engine/platform. The automatic ten-second settlement failsafe puts bodies to sleep; later collisions can wake them. Visuals and labels are primitive, and there is no audio. All 11 cards are implemented; human playtesting is still useful for balance, readability, and unexpected multi-card combinations.
