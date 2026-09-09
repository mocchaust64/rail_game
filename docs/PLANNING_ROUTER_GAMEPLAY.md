# Flow Factory — Planning Router Gameplay

This document is the gameplay source of truth for the planning-router rebuild.

## Core loop

1. **PLAN** — Cargo is stationary. The player can see the upcoming cargo colours.
2. **PROGRAM** — Tap a junction to choose which colour that junction sends to branch A. Every other allowed colour goes to branch B.
3. **RUN** — Press RUN once. Manual junction input is disabled.
4. **WATCH** — Cargo moves automatically. When cargo reaches a junction, the physical conveyor rotates to the route required by the programmed rule. Cargo waits until the conveyor has connected before continuing.
5. **RESULT** — Correct cargo reaches its matching machine. Wrong cargo is placed in the buffer. Any wrong cargo at the end of the run means the setup was incorrect and the player retries.

## What skill should win

The game rewards tracing routes and configuring a system before execution.

It must **not** reward waiting for a coloured ball to approach a junction and tapping quickly.

Cargo speed is presentation pressure, not the main difficulty control.

## Junction rule

A junction stores one filter colour.

Example:

- Junction filter = RED
- Branch A = RED
- Branch B = every other allowed colour

For a three-colour tree:

- J1: RED -> red machine, others -> J2
- J2: BLUE -> blue machine, others -> yellow machine

Once RUN starts, these rules are fixed for the whole attempt.

## Interaction contract

### During PLAN

- Junctions are tappable.
- Each tap cycles through that junction's allowed filter colours.
- Coloured markers on the physical branches show the programmed rule.
- RUN is visible.

### During RUN

- Junction taps do nothing.
- A junction automatically rotates for incoming cargo according to its filter rule.
- Cargo waits at the junction while the physical rail is moving.
- Visual rail state and gameplay route must never disagree.

## Failure and buffer

Wrong cargo enters the waiting buffer and stays there for the attempt.

- Buffer overflow can fail immediately.
- If the run ends with any cargo in the buffer, the attempt fails and returns to planning on retry.
- Cargo does not return to the source during the same run.

## Difficulty progression

Difficulty comes from route reasoning, not reaction speed:

1. One router, two colours.
2. Two routers, three colours.
3. Same rules with shuffled destination layout.
4. Multiple sources merging into one network.
5. Parallel first-stage rules plus a shared downstream rule.
6. Three sources and five programmed routers.
7–10. Different source colour sets, shared routes, merges and asymmetric machine layouts.

## Visual target

The reference video remains the visual target:

- warm cream full-screen environment
- smooth pale guide rails
- dark moving conveyor on active paths
- long physical rotating conveyor sections
- glossy coloured cargo balls
- large red/blue/yellow destination machines
- sparse HUD

Visual polish may change. The PLAN -> PROGRAM -> RUN gameplay contract must not be changed without an explicit gameplay redesign decision.
