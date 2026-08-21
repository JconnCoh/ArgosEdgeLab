# Front-metal raw footprint and edge-branch checkpoint — 2026-08-12

## Outcome

The front-metal surface physical-damage branch now covers all 70 locked
operator-positive paths while preserving zero contact with the four exact T21
scribe false controls. Accepted footprint pixels remain direct connected
native raw BF/DF evidence. Two previously untouched paths are represented only
by class-specific confirmation masks derived from independent raw periodic-peer
departure; they do not gain autonomous reject authority or human-brush-sized
geometry.

This work did **not** disable, replace, retune, or absorb the existing
frontside chipout/edge branch. The strict physical-edge method remains a frozen
sibling branch and is unioned with the surface branch only after each branch has
made its own decision.

All results remain review-only, training-ineligible, XML-ineligible, and
production-ineligible.

## Locked operator input

- feedback: `human_feedback/ARGOS_CANONICAL_DEFECT_REVIEW_20260811T172156Z/ARGOS_CANONICAL_DEFECT_REVIEW_COORDINATES.json`
- SHA-256: `D642D9F64F0F45BDF8CB3518DCD49E6A42AA05B1AF5E62942973D99467DEB320`
- 70 positive paths: 53 Scratch, 8 ResidueStreak, 5 Contamination, 4 Residue
- 4 exact false controls: T21 scribe marks
- human coordinates were consumed only by the audit; detector output was not
  built from the drawings.

## Surface accepted footprint

Accepted raw-native branch:

`analysis/FRONT_METAL_CONNECTED_NATIVE_FOOTPRINT_V3_K_20260812T003000Z`

- direct accepted positive paths: 68/70;
- false scribe controls touched: 0/4;
- active fraction over the 11 native review tiles: 8.569636%;
- mean / median exact drawn-path coverage: 67.5803% / 86.31995%;
- unsupported gaps remain empty;
- no image was resampled before scoring;
- raw BF and DF remain the sole physical-size authority.

## Bounded class-specific confirmation recovery

Periodic raw-neighbor diagnostic:

`analysis/FRONT_METAL_PERIODIC_NEIGHBOR_DEVIATION_V1_2_20260812T012000Z`

Final accepted-or-confirmation result:

`analysis/FRONT_METAL_PERIODIC_CONFIRMATION_V1_20260812T024000Z`

The raw periodic shifts are derived from fixed geometry-only interior samples
of each tile, never from operator paths or detector masks. Candidate components
must depart from their periodic raw peers. A component already overlapping the
accepted raw footprint adds no new confirmation mask.

- elongated BF-supported component gate:
  `CONFIRM_SCRATCH_PERIODIC_BF_ELONGATED`;
- cross-channel, strong-second-channel component gate:
  `CONFIRM_RESIDUE_OR_CONTAMINATION_MULTICHANNEL`;
- combined audit: 70/70 positives touched, 0/4 false controls touched;
- combined active fraction: 8.858848%;
- mean / median exact drawn-path coverage: 68.2997% / 86.31995%;
- the formerly untouched T29 Scratch path receives only a Scratch confirmation
  mask;
- the formerly untouched T17 ResidueStreak path receives only a
  Residue/Contamination confirmation mask.

These class-specific confirmations are not accepted defect pixels and do not
define exact size. They preserve direct evidence without copying the human
brush, filling the enhanced halo, or inventing complete line geometry.

## Grid and recurrence contract

No component is declared Normal merely because its size, direction, pitch, or
recurrence resembles the front-metal grid. No same-lot or production-line
recurrence suppresses a candidate. Pattern context can suppress only a locally
explained pattern response with no independent raw physical departure.

If a condition recurs on every wafer in a lot or production line, it remains
eligible as common-mode manufacturing evidence. Until an approved product /
step / material-state golden sentinel exists, its disposition is:

`CONFIRM_FRONT_METAL_COMMON_MODE_PHYSICAL_DAMAGE_UNTIL_APPROVED_GOLDEN_SENTINEL`

## Preserved frontside chipout / edge branch

Frozen implementation:

`tools/Run-Post2FrontsideStrictEdgeBevelRescanV1.mjs`

SHA-256:

`900881A6AA5E43690D77B780C93279F47980E013738DCEEA6BD71486BDFA6366`

Frozen authority records:

- `FRONTSIDE_POST2_STRICT_EDGE_BEVEL_RESCAN_CHECKPOINT_20260807.md`;
- `FRONTSIDE_POST2_STRICT_EDGE_BEVEL_EXPANSION_CHECKPOINT_20260807.md`;
- anchor manifest SHA-256
  `1387FA98A6D66A2ED492ABAD776CAAC6AE05FCF7DDE351FE488A2B9B514FAE99`.

The branch still requires independent BF/DF physical boundary displacement
and the outside-dark corridor. Its frozen regression retains the one confirmed
Slot01 chipout and suppresses all 22/22 reviewed narrow edge/noise controls.
It is not changed by the surface work. Frontside bevel remains separate and
confirmation-only; it is never silently promoted by a surface finding.

## Final branch composition contract

1. Run strict frontside physical edge/chipout evidence independently.
2. Run front-metal surface accepted-footprint and class-specific confirmation
   evidence independently.
3. Apply scribe, holder, and physical-boundary exclusions inside the branch
   that owns them, before candidate formation.
4. Union reportable findings after branch decisions; never let surface tuning
   erase an edge finding or let edge logic erase a compact surface finding.
5. Preserve class and authority separately: accepted surface pixels,
   `CONFIRM_SCRATCH`, `CONFIRM_RESIDUE_OR_CONTAMINATION`,
   `CONFIRM_EDGE_CHIPOUT`, and confirmation-only bevel evidence remain distinct.

## Hashes

- connected-footprint run result:
  `11223C8F664E1AB589D49EF841019285218BAD2CC0DF18AFF5D3531882FBADA4`
- periodic confirmation run result:
  `B442E9AC7071DC34E0B86DD56BCD0F72ADEADA61EB3161E6A62F87809B9D2C48`
- connected-footprint source / executable:
  `1F6081A0D7547E9FD23AE9B3D197F2C7654DD48528DD0CAF83F9A6BCF79333B4` /
  `4999FAF435F98A9FE11157423F3BD50DB3970BE1725E4638331553AAE2C10786`
- periodic-neighbor source / executable:
  `CA975F4179FAA2726C19D3D47B6F1265027908A0FA9BEA95C90AD0C55D9E1637` /
  `1D989F08BDA14BA55E024C19C36E47F7700C1EE9D10F3DF68C66DA4D4C89E563`
- confirmation source / executable:
  `6DE61B3CA577E06C93BAC6FF4A6BC98F62C94A64FC0148A3E28B17CAC00B1523` /
  `A6BD8919A8C1936A0885F26153A9EFE229E3B0C3B1AA841E72DAB967AAAAC752`.

