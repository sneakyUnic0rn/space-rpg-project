# Backlog

Ideas and QoL items to build later. Newest at the bottom of each section.

## Combat / UI

### Position-based cover preview (flagged 2026-11-19)
**Now:** hovering a tile shows the cover of the block itself (crate = half, wall = full).
**Wanted:** when hovering a destination tile, show the cover that tile gives *against each enemy that can see it*, not the block type.

- Cover is directional: it comes from cover objects adjacent to the tile, on the side facing the enemy.
- Per enemy, show one of: **No cover (flanked)**, **Half**, **Full**, or **Out of sight** (enemy has no line of sight at all).
- Show it as icons on the hovered tile (XCOM-style shields), plus a short summary in the HUD.
- Example from playtest: Player_1 standing next to the big block was effectively full cover from both enemies, but the HUD only described the block.
- **Depends on:** line of sight / enemy FOV (comes with the shoot action, step 3.4).
