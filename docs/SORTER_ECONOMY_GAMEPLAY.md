# Flow Factory — Sorter Economy Vertical Slice

This file is the source of truth for the new core loop.

## Player loop

1. **READ** — See the cargo colours, machines, pale guide rails and empty build foundations.
2. **BUILD** — Tap a foundation to spend gold and construct a sorter.
3. **CONFIGURE** — A sorter has three numbered exits. Red, blue and yellow are assigned exactly once across those exits.
4. **READ THE PLAN** — As soon as a sorter is built, continuous dark conveyor belts appear from that sorter along all three outgoing routes. Colour markers at the exits show the current assignment.
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

## Difficulty authoring

Difficulty must come from reasoning, not ball speed.

Useful knobs:

- number of build foundations
- number of foundations that are unnecessary in the optimal solution
- number of mixed-colour sources
- budget slack above the optimal cost
- visually plausible but inefficient alternate routes
- source colour sets that leave one sorter exit unused

The verifier exhaustively tests every build/no-build choice and every 3-colour permutation for Levels 1–3. It rejects a level if the declared optimal cost is wrong.

## Vertical slice progression

### Level 1 — Build the Sorter

One source, one required sorter, three machines. Teaches build + three-lane colour assignment.

### Level 2 — Two Feeds

Two mixed-colour sources. Each needs its own sorter. Teaches that separate incoming flows may require separate infrastructure.

### Level 3 — Spend Smart

Four possible sorter sites but only two are necessary. Each source emits only two colours, so the unused third colour should be assigned to the route that leads toward an unnecessary downstream sorter. Players can still build the extra sorters and solve the level, but they lose stars.

## Visual contract

- Empty site = small warm foundation with a plus and gold tokens.
- Built sorter = compact toy classifier house.
- Possible route = pale silver guide rails.
- Built/active route = continuous dark conveyor from sorter to the next machine or sorter.
- Every built sorter shows three coloured exit markers.
- Bottom setup panel mirrors those three numbered exits.
- During RUN, setup UI disappears and cannot change.
