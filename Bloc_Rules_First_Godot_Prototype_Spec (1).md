# BLOC - Rules-First Godot Prototype Specification

## 1. Purpose

Current revision: the four retired cards L01–L04 have been removed. Remaining card IDs stay L05–L15.

Build a rough but fully playable 3D digital prototype of **BLOC** in Godot. The prototype exists to test the turn structure, legislation-card interactions, scoring, player targeting, finite block supply, and endgame rules. It is not intended to be a polished final game.

This specification is written for Codex to implement directly. If a behavior is not described here, Codex should choose the simplest implementation that preserves the rules and record the decision in `README.md`.

## 2. Prototype Approach

### Selected approach

Rules-first prototype.

### Approaches considered

- **Physics-first:** Prioritize realistic stacking, dragging, and collapse while implementing only a few representative cards. This would test dexterity well but would not test the complete legislation system within the time limit.
- **Rules-first (selected):** Use grid-assisted placement and simple compound rigid bodies so the full turn system and all legislation effects can be tested. Physical behavior may be less realistic, but this better matches the current goal.

### Priorities

1. A complete local hot-seat game can be played from start to finish.
2. Every legislation card in the current design document can be intentionally tested.
3. Random block selection uses the actual finite supply.
4. Turn order, reactions, targeting, hands, scoring, collapse, and the discard pile work correctly.
5. 3D stacking is understandable and functional, even if its physics are not perfectly realistic.

### Non-goals

- Online multiplayer
- Computer-controlled opponents
- Finished art, sound, animation, or historical presentation
- Mobile support
- Save/load
- Advanced physical simulation of real wooden pieces
- A level-up system
- Dice-based block selection

## 3. Technical Assumptions

- Engine: Godot 4.x
- Language: GDScript
- Target: desktop, keyboard and mouse
- Players: 2-4 local hot-seat players
- Presentation: simple 3D board with a fixed or orbiting camera
- Art: primitive meshes, flat colors, and text-only cards
- Resolution target: 1280x720 or larger
- All rules and content should be data-driven where practical, but speed and clarity are more important than an elaborate architecture.

## 4. Core Game Summary

Each player represents a business operating during the collapse of the USSR. Every player builds a separate tower on a 4x4 foundation. Players gain points by placing increasingly awkward blocks while legislation changes the rules, forces additional production, transfers blocks, or attacks another player's tower.

The game ends when more than three complete block pieces fall from one player's tower during the resolution of an action. The losing player cannot win. All surviving players total the point values currently present in their towers, and the surviving player with the highest score wins.

## 5. Prototype Rule Decisions

These rules resolve details that were absent or ambiguous in the original concept document.

1. There is no die and no business-level system.
2. The required block is selected randomly from the exact blocks remaining in the shared supply.
3. Legislation hand limit is three cards.
4. A player may voluntarily play no more than one `ON_TURN` card during their turn.
5. `IMMEDIATE` cards resolve as soon as they are drawn and never enter a hand.
6. `REACTION` cards may be played only when their trigger occurs. Each player may play at most one reaction during one reaction window.
7. All hands are visible in this prototype. Hidden information is not required for a local hot-seat test.
8. A complete polycube object counts as one bloc, regardless of how many unit cubes compose it.
9. Four or more blocs falling during one action causes defeat. One to three fallen blocs are removed from play and stop scoring.
10. After the shared block supply is empty, legislation stops and the game enters the Collapse Phase.
11. During the Collapse Phase, players relocate blocks from their own towers until someone loses.
12. The first defeat ends the game immediately so no player waits after elimination.

## 6. Setup

1. Ask for a player count from 2 to 4.
2. Create one 4x4 tower mat for each player.
3. Position the tower mats far enough apart that physics objects cannot collide with another tower.
4. Create and shuffle the finite block supply.
5. Create and shuffle the 11-card legislation deck, one copy of each card listed in Section 14.
6. Give each player an empty legislation hand.
7. Randomly choose the starting player.
8. Begin in the normal Production Phase.

## 7. Block Supply

### Random selection

The pool stores every remaining block instance. When a rule requires a random block, select one eligible instance uniformly from the remaining pool and remove it from the pool.

There is no die and no mapping table.

### Point-restricted draws

Some legislation requires a block with a particular point value.

- Filter the remaining pool by the requested point value.
- Select one eligible block randomly.
- If none exists, use the nearest lower point value that still has a remaining block.
- If no lower value exists, use the nearest higher value.
- If the pool is completely empty, skip that block placement and write the reason in the event log.
- If legislation empties the pool before the active player's normal draw, finish resolving that legislation, skip the normal draw, and enter the Collapse Phase at the end of the current turn.

### Recommended prototype quantities

Use 30 total blocks unless implementation or performance requires fewer:

- Eight 1-point blocs
- Seven 2-point blocs
- Six 3-point blocs
- Five 4-point blocs
- Four 5-point blocs

Point value should correlate with awkwardness, not only physical size.

### Minimum shape set

Provide at least two shapes for each point value. Each shape is a rigid body composed of unit cube meshes and unit cube collision shapes. Reusing a shape with different rotations or colors is acceptable for the prototype.

Suggested progression:

- 1 point: flat, compact two- or three-cube pieces
- 2 points: simple bars and L-shaped pieces
- 3 points: four-cube T, L, and stair pieces
- 4 points: asymmetric pieces with overhang risk
- 5 points: tall or unbalanced five-cube pieces

## 8. Towers and Placement

### Tower mat

- Each tower mat is a 4x4 unit grid.
- A newly placed bloc must begin inside the tower's 4x4 horizontal footprint.
- A bloc may extend vertically without a height limit.
- A placement preview must be shown before confirmation.
- Overlapping an existing solid bloc is invalid.

### Rules-first controls

Use keyboard grid controls rather than complex mouse dragging:

- `W/A/S/D`: move the active bloc horizontally by one grid unit
- `R/F`: move the bloc up or down by one grid unit
- `Q/E`: rotate 90 degrees around the vertical axis
- `Z/X`: rotate 90 degrees around one horizontal axis
- `C/V`: rotate 90 degrees around the other horizontal axis
- `Space`: confirm placement and release the bloc
- Right mouse drag: orbit camera, if time permits
- Mouse wheel: zoom, if time permits

Before confirmation, the bloc is frozen and snaps to the unit grid. After confirmation, enable physics and begin a settlement check. Do not use a fixed two-second delay.

### Physics settlement and action ownership

- Every physical manipulation receives a unique `action_id` when a bloc is released or removed.
- Disable placement and turn-advance input while that action is settling.
- An affected tower is stable when all of its non-fallen rigid bodies are sleeping, or remain below configurable linear and angular velocity thresholds, continuously for 0.75 seconds.
- A fall detected while an action is settling belongs to that `action_id` and resets the 0.75-second stability timer.
- Continue monitoring every tower between actions. A late fall that occurs before another physical action affects that tower is attributed to the most recent `action_id` for that tower. Reopen its fall count and immediately check whether it now causes defeat.
- Use a ten-second failsafe. At ten seconds, perform a final fall scan, put the remaining non-fallen rigid bodies to sleep, and close the action. Sleeping bodies must still be able to wake from a later collision.
- Keep the stability duration, velocity thresholds, and failsafe duration as exported debug settings rather than hard-coding them throughout the project.

### Falling detection

A bloc counts as fallen when either condition is true:

- Its center falls below the top surface of the tower mat minus a small tolerance.
- Its center leaves a generous detection boundary surrounding its owner's tower.

Count complete bloc bodies, not individual cubes. Fallen blocs are disabled, removed from the tower, removed from scoring, and recorded in the event log.

### Definition of one action

For fall counting, one action is exactly one physical manipulation and its settlement period:

- Removing one bloc is one action.
- Placing or replacing one bloc is one action.
- Transferring a bloc does not combine its removal and placement; they are two actions.
- A card that affects multiple blocs creates a separate action for each individual removal or placement, resolved in sequence.
- In the Collapse Phase, removing the selected bloc and placing it higher are separate actions. If the removal causes defeat, the replacement never occurs.

The fall counter for a tower resets when the next physical action affecting that tower begins. Card resolution, target selection, drawing, and discarding are not physical actions and do not reset it.

## 9. Scoring

- A player's score is the sum of the printed values of all blocs currently belonging to and remaining in that player's tower.
- A physical legislation object contributes its signed printed value to the tower: `-2` removes two points.
- Reserved, held, falling, removed, or unplaced objects do not score.
- The score display updates after every settled placement, removal, transfer, or fall.

### Tie-breakers

If surviving players have equal scores:

1. The player with fewer fallen blocs wins.
2. If still tied, the player with the taller stable tower wins.
3. If still tied, declare a shared victory.

## 10. Normal Turn Sequence

The game is a state machine. Do not permit input belonging to a different state.

### Step 1: Begin turn

- Display the active player.
- Reset the active player's voluntary-card counter.
- Resolve any queued extra-turn or delayed effect.

### Step 2: Draw legislation

- Draw the top legislation card.
- If the deck is empty, shuffle the discard pile to form a new deck. Do not include cards currently held, resolving, or physically placed in towers.
- If the card is `IMMEDIATE`, reveal and resolve it now, then discard it.
- Otherwise, add it to the active player's hand.
- If the hand would exceed three cards, the player must choose one held card to discard before continuing.

### Step 3: Optional on-turn legislation

- The active player may play one `ON_TURN` card from their hand.
- The player may skip this step.
- Cards that change the required block placement resolve before continuing.

### Step 4: Random block draw

- Randomly select one bloc from the remaining shared supply.
- Display its point value and shape.
- Open the `AFTER_BLOCK_DRAW` reaction window.

### Step 5: Place required block

- The active player positions, rotates, and confirms the bloc on their tower.
- Release physics and wait for settling.
- Detect fallen blocs and update scores.
- If four or more blocs fell during this action, end the game.

### Step 6: Additional placements and pending effects

- Resolve required additional blocs, transferred blocs, card objects, or queued effects one at a time.
- After each placement or removal, settle physics, detect fallen blocs, update scoring, and check defeat.

### Step 7: End turn

- Discard resolved one-use legislation cards.
- Advance to the next player unless an extra-turn effect changes the order.
- If the shared block supply is empty, enter the Collapse Phase before the next turn.

## 11. Reaction Windows

The prototype supports only these explicit reaction windows:

- `AFTER_BLOCK_DRAW`: after the active player's random bloc is revealed but before placement
- `PLAYER_TARGETED`: after a single target is selected for legislation but before its effect resolves
- `AFTER_LEGISLATION_PLAYED`: after legislation is announced but before resolution
- `END_OF_TURN`: after all placements settle but before advancing the turn

When a reaction window opens:

1. Pause ordinary input.
2. Starting with the next player clockwise, offer each eligible player the choice to play one valid reaction or pass.
3. Resolve reactions in the order played.
4. Close the window and continue the interrupted action.

To keep the prototype manageable, a reaction cannot trigger another reaction window unless the card explicitly redirects or cancels the original legislation.

For an `IMMEDIATE` global card, open `AFTER_LEGISLATION_PLAYED` after revealing the card but before applying its effect. This gives each affected player an opportunity to use Personal Exemption. For legislation selecting one player, open `PLAYER_TARGETED` after the target is declared but before resolution.

## 12. Hand and Card Rules

- Maximum hand size: three.
- Immediate cards never enter a hand.
- A player may play at most one voluntary `ON_TURN` card per normal turn.
- Reactions do not consume the active player's on-turn card allowance.
- A stolen card is added to the thief's hand. If this exceeds the limit, the thief immediately discards one card.
- Used cards go to a visible discard pile unless they remain physically in a tower or are waiting as a delayed effect.
- The discard pile interface must show card names and effects.

## 13. Collapse Phase

The Collapse Phase begins when no blocs remain in the shared supply.

1. Stop drawing and playing legislation.
2. On each turn, the active player selects one bloc already in their tower.
3. Freeze that bloc and remove it from its current position.
4. The player must place it again so that at least part of it is higher than its previous maximum height.
5. Release physics and evaluate fallen blocs.
6. Continue clockwise until a player loses by causing four or more blocs to fall during one action.

If the selected removal itself causes a loss, do not continue to replacement.

If the active player begins a Collapse Phase turn with no bloc remaining in their tower, that player is immediately defeated because they cannot perform the required relocation. Under the prototype's first-defeat rule, the game ends and the surviving players proceed to scoring.

## 14. Legislation Card Catalog

The prototype must contain all cards below. Names are prototype names because the source document supplied effects but not titles.

### L05 - Forced Transfer

- Timing: `ON_TURN`
- Effect: Select one bloc from your own tower and choose an opponent. Remove the selected bloc and require the opponent to place it in their tower.
- Ownership and scoring transfer to the opponent after successful placement.
- Evaluate falling after removal and after replacement.

### L06 - Asset Seizure

- Timing: `ON_TURN`
- Effect: Choose an opponent. That opponent selects and removes one bloc from their own tower. The active player must place it in their tower in addition to their normal bloc.
- Ownership and scoring transfer to the active player after placement.

### L07 - Emergency Production Order

- Timing: `IMMEDIATE`
- Effect: Starting with the drawing player and proceeding clockwise, every player draws and places two separate random 1-point blocs.
- Fully settle and evaluate each placement before the next one.

### L08 - Bureaucratic Burden

- Timing: `ON_TURN`
- Effect: Choose an opponent and spawn a thin, rigid card-shaped object. The active player places it on the opponent's tower. It is worth -2 points to that tower while present.
- It counts as one bloc for falling and defeat.

### L09 - Supply Interception

- Timing: `REACTION` at `AFTER_BLOCK_DRAW`
- Effect: Take the active player's revealed bloc. The reacting player immediately places it in their own tower. The original active player then draws another random bloc and continues their turn.
- The intercepted bloc belongs to and scores for the reacting player.

### L10 - Restructuring Authority

- Timing: `ON_TURN`
- Effect: The active player may select between one and four blocs in their own tower. Remove the selected blocs one at a time, then replace those same blocs one at a time in any order.
- Evaluate falling after each removal and placement.
- The player may stop after replacing all removed blocs but may not keep a removed bloc unplaced.

### L11 - Administrative Reassignment

- Timing: `REACTION` at `PLAYER_TARGETED`
- Effect: When legislation selects exactly one player, choose a different legal player as the new target.
- This card cannot redirect global legislation that affects all players.

### L12 - Personal Exemption

- Timing: `REACTION` at `PLAYER_TARGETED` when the holder is the selected target, or at `AFTER_LEGISLATION_PLAYED` when a revealed global card will affect the holder.
- Effect: The holder ignores the complete effect of that legislation on themselves. For example, they do not draw, place, remove, transfer, or receive a bloc required by that card.
- Other targets remain affected.
- This may exempt the holder from an `IMMEDIATE` global card, but it does not cancel or discard the global card for other players.
- The exemption must be declared before the original legislation begins resolving. It cannot undo a completed part of an effect, a previous transfer, or a physical fall.

### L13 - Policy Reversal

- Timing: `ON_TURN`
- Effect: Select one eligible legislation card from the visible discard pile and resolve it immediately under the active player's control.
- An eligible card must have `ON_TURN` or `IMMEDIATE` timing. `REACTION` cards are ineligible because Policy Reversal does not create their required trigger.
- Treat a selected `ON_TURN` card as though the active player played it from their hand. Treat a selected `IMMEDIATE` card as though the active player had just drawn it.
- The replayed card must obey its normal target, supply, placement, and reaction-window rules.
- The replayed card remains in the discard pile; do not discard a second copy or move it into the active player's hand.
- Policy Reversal itself enters the discard pile after resolution.
- Policy Reversal is never eligible to select another Policy Reversal, including itself, to prevent loops.

### L14 - Political Espionage

- Timing: `ON_TURN`
- Effect: Choose another player and inspect their visible hand. Select one held card and add it to your hand.
- Resolve hand-limit overflow immediately.

### L15 - Extended Session

- Timing: `REACTION` at `END_OF_TURN` during another player's turn
- Effect: That same player takes one additional complete normal turn immediately after the current turn.
- Extra turns cannot be extended by another Extended Session.
- After the extra turn, play resumes with the player who would normally have followed the original turn.

## 15. Required User Interface

### Main HUD

- Current player
- Current phase and instruction
- Score and fallen-bloc count for every player
- Remaining shared blocs
- Legislation draw pile count
- Discard pile button
- End-turn button when legally available

### Player hand

- Show up to three cards for the active player.
- Each card shows name, timing, and full effect.
- Disable cards that are illegal in the current state.

### Prompts

Provide simple modal prompts for:

- Choosing a target player
- Choosing a tower bloc
- Choosing a card from a hand or discard pile
- Choosing whether to play a reaction or pass
- Discarding for hand-limit overflow
- Confirming an optional effect

### Event log

Display a scrolling text log containing:

- Card draws and plays
- Random block draws
- Placements and transfers
- Falls
- Score changes
- Reaction decisions
- Phase changes
- Victory result

## 16. Debug and Testing Controls

The prototype must include a collapsible debug panel. This is required because testing every card through random draws would be too slow.

Debug actions:

- Start a 2-, 3-, or 4-player game
- Draw a chosen legislation card
- Give a chosen card to a chosen player
- Spawn a chosen point-value bloc
- Empty the shared block pool
- Advance to the next player
- Add or remove a test bloc from a tower
- Reset the current game
- Toggle slow physics or pause after each resolution

## 17. Suggested Godot Structure

This is architectural guidance, not a demand for excessive abstraction.

### Main scenes

- `Main.tscn`: menus and game root
- `GameBoard.tscn`: board, lighting, cameras, and tower positions
- `Tower.tscn`: one player's mat, detection zones, and owned objects
- `Bloc.tscn`: rigid polycube block
- `CardBloc.tscn`: physical positive or negative legislation object
- `HUD.tscn`: scores, hands, prompts, event log, and debug panel

### Main scripts

- `game_manager.gd`: overall game state, setup, victory, and phase changes
- `turn_manager.gd`: turn order and action-state machine
- `bloc_pool.gd`: finite pool and point-restricted random draws
- `placement_controller.gd`: preview, grid movement, rotations, and release
- `tower.gd`: ownership, settling, fall detection, and scoring
- `legislation_manager.gd`: deck, hands, discard pile, reaction windows, and card resolution
- `ui_controller.gd`: prompts and HUD updates

For a rapid prototype, legislation effects may be implemented with an `effect_id` and one central `match` statement. Do not build a large plugin or scripting framework.

## 18. Thirty-Minute Implementation Order

Codex should work in this order and keep the project runnable after every stage:

1. Create project, game board, camera, lighting, and two tower mats.
2. Generate primitive polycube blocs and finite random pool.
3. Implement grid preview, rotations, placement, physics release, and fall detection.
4. Implement player setup, turn order, scores, defeat, and victory.
5. Implement legislation data, deck, hand limit, discard pile, and timing categories.
6. Implement target selection and the simplest card effects.
7. Implement transfers, reactions, redirection, rearrangement, card stealing, and extra turns.
8. Implement Collapse Phase.
9. Add the debug panel and test every card.
10. Fix only blocking errors. Do not spend the sprint polishing visuals.

If the 30-minute limit is reached before every card works, Codex must preserve the playable core and list incomplete cards in `README.md` rather than breaking the project.

## 19. Acceptance Checklist

The prototype is acceptable when:

- A new 2-4 player game can start without editor setup.
- Players receive random blocks from a finite pool.
- Players can position, rotate, and place 3D blocs.
- Towers settle and fallen bloc bodies are detected.
- Settlement uses sleeping/velocity checks rather than a fixed delay, and late falls remain assigned to the correct physical action.
- Scores update correctly.
- Four fallen blocs during one action end the game.
- Removals and placements are counted as separate physical actions, including during multi-bloc effects and the Collapse Phase.
- Immediate, on-turn, and reaction timings are distinguishable.
- Hands enforce a three-card limit.
- The discard pile is visible and reusable.
- All 11 legislation cards can be forced through the debug panel.
- Transfer and targeting cards update ownership and scoring.
- The Collapse Phase starts when the pool is empty.
- A player with an empty tower at the start of their Collapse Phase turn is defeated.
- Policy Reversal cannot replay reaction cards or another Policy Reversal.
- Personal Exemption works at both targeted and global pre-resolution reaction windows.
- The winner screen identifies the loser and highest-scoring survivor.
- Restart returns the game to a clean state.

## 20. Known Risks

- Godot rigid-body behavior may be unstable for compound polycube collisions.
- L10 Restructuring Authority is the most interaction-heavy card.
- Reactions create nested states and are the most likely source of turn-locking bugs.
- L08 requires a physical card-shaped rigid body; its thin dimensions may need thicker prototype collision shapes.
- Thirty minutes is enough for a rough vertical slice but may not be enough to debug all card combinations.

## 21. Decisions Requiring Team Confirmation

The implementation may proceed with the defaults above, but the team should later confirm:

1. Whether the three-card hand limit becomes an official rule.
2. Whether legislation stops during the Collapse Phase.
3. Whether the first defeat ends the game or play continues until one player remains.
4. Whether hands are hidden in the final tabletop version.
5. Final physical block quantities and shapes.
6. Whether an attacker or tower owner physically places harmful legislation on a tower.

