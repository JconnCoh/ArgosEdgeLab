# Front-metal D7 V17 R5P26 physical-domain recovery gate — 2026-08-17

- Disposition: `PENDING_GATE`
- Planned revision: `FM7V17R5P26`
- Approved method parent: `FM7V17R5P24A_COMPOSITE_BASELINE`
- Corrected failed diagnostic: `FM7V17R5P25`
- Target: `62546-481_POST2_SLOT02`
- Scope: the same eleven frozen 2400 by 2000 native S02 fields.

R5P26 changes only the control-pixel validity and edge-cell coverage domain exposed by R5P25. The fitted S02 wafer disk, at the unchanged R5P21/R5P22 geometry, is the physical inspection domain. There is no generic inward surface inset. Every pixel in that disk remains eligible through the perimeter; rectangle pixels outside it are explicitly outside-domain, not blank, unassigned, held, inspected Normal, or detector evidence.

Every 128-pixel contribution cell that intersects the physical disk must exist. If its geometric center is outside the disk, its spatial-evidence representative is clamped inside the disk without changing the pixel coordinate being scored. An analytic non-mutating preflight must prove that every in-domain pixel in all eleven fields maps to one of these cells.

All other R5P25/R5P24A behavior is frozen: S02 target only; the other eleven wafers as target-excluded references; independent BF/DF transforms; strict unique-clique primary route; separately labeled one-low/one-high trimmed fallback route; 4-DN residual deadband; native 1:1 target pixels; no old V16 mask or feedback as detector input; and no detector class/outcome authority. Zero direct-native and zero unassigned valid pixels remain mandatory.

Outside-domain pixels must have separate counts and a distinct route color/legend. The residual union remains class-neutral `CONFIRM_FRONT_METAL_TARGET_EXCLUDED_RESIDUAL`. A successful R5P26 run still requires regression audit and a canonical reviewer before any 12-wafer transfer proposal.
