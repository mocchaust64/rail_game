# Flow Factory — Sorter Economy Vertical Slice

This file is the source of truth for the new core loop.

## Player loop

1. **READ** — See the cargo colours, machines, pale guide rails and empty build foundations.
2. **BUILD** — Tap a foundation to spend gold and construct a sorter.
3. **CONFIGURE** — A sorter has three numbered exits. Red, blue and yellow are assigned exactly once across those exits.
4. **READ THE PLAN** — As soon as a sorter is built, continuous dark conveyor belts appear from that sorter along all three outgoing routes. Colour markers physically touch the exits so the plan can be read from the board, not only from UI.
5. **RUN** — Configuration is locked. Cargo moves automatically. The player no longer reacts to individual balls.
6. **RESULT** — Every cargo must reach its matching machine. The final rating rewards lower gold spend.

## Economy

Each level declares:

- `gold_budget`: maximum gold available for the attempt.
- `sorter_cost`: default price of one sorter.
- `optimal_cost`: cheapest proven solution.
- `two_star_cost`: spend threshold for two stars.

Rating:

- 3 stars: spend <= `optimal_cost`.
- 2 stars: spend <= `two_star_cost`.
- 1 star: any valid solution within the level budget.

Removing a sorter during planning refunds its full cost. This makes experimentation safe.

`optimal_cost` is deliberately **not shown during planning**. The player should discover the cheapest network themselves; BEST is revealed on the result screen as proof/feedback.

## Difficulty authoring

Difficulty must come from reasoning, not ball speed.

Useful knobs:

- number of build foundations
- number of foundations that are unnecessary in the optimal solution
- number of mixed-colour sources
- budget slack above the optimal cost
- visually plausible but inefficient alternate routes
- source colour sets that leave one sorter exit unused
- number of valid plans versus number of optimal plans

The verifier exhaustively tests every build/no-build choice and every 3-colour permutation for Levels 1–3. It rejects a level if the declared optimal cost is wrong or if the cheapest solution is ambiguous.

## Vertical slice progression

The onboarding follows **one new idea per level**.

### Level 1 — BUILD ONE SORTER

One source, one foundation, one required sorter, three machines. The initial colour assignment is already correct.

Learning goal: **Tap the foundation → see the dark network appear → RUN.**

Do not require colour programming yet.

### Level 2 — MATCH THE COLORS

Same simple topology, but the three lane colours start deliberately wrong.

Learning goal: **Read where each black rail goes and swap the three colours until Red → Red, Blue → Blue, Yellow → Yellow.**

No extra foundations or economy trick yet.

### Level 3 — SPEND SMART

Two sources and four possible sorter sites, but only two are necessary. Each source emits only two colours. The third exit can point toward an unnecessary downstream foundation.

Learning goal: **Not every buildable site should be built. Find the unique cheapest plan.**

The player has enough gold to build wastefully and still finish, so stars measure optimization rather than blocking experimentation.

## Visual contract

- Empty site = warm foundation with a clear plus, gold halo and visible build-cost tokens.
- Built sorter = compact toy classifier house with three colour lights.
- Possible route = pale silver guide rails.
- Built/active route = continuous dark conveyor from sorter to the next machine or sorter.
- Each exit has a coloured strip touching the dark belt plus a larger colour marker.
- Bottom setup panel mirrors those three numbered exits with matching button colours.
- During RUN, setup UI disappears and cannot change.
- Planning HUD shows `GOLD`, `USED` and `BUILD COST`; it does not expose the optimal answer.

## Product-quality rule

Before adding more mechanics or more levels, a new player should be able to understand Levels 1–3 without external explanation:

- Level 1 teaches **BUILD**.
- Level 2 teaches **CONFIGURE**.
- Level 3 teaches **OPTIMIZE**.

If any of those lessons needs a paragraph of tutorial text, the board/interaction is not clear enough yet.
