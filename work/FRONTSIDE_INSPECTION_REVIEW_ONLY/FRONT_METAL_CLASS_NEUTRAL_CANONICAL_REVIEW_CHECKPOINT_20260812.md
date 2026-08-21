# Front-metal class-neutral canonical review checkpoint — 2026-08-12

## State

`PASS_FRONT_METAL_CLASS_NEUTRAL_CANONICAL_REVIEW_LIVE_GATE_REVIEW_ONLY`

Created UTC: `2026-08-12T21:05:26.9371062Z`

This checkpoint locks the first live-gated class-neutral front-metal review built from the operator-approved BowComp highlighter. It is a staged review artifact only. It does not alter detector thresholds, apply human feedback, train a model, create XML, or authorize production.

## Locked review artifact

- Review root: `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/outputs/review_only/FRONT_METAL_CLASS_NEUTRAL_CANONICAL_REVIEW_V1_20260812T210321Z`
- Launcher: `START_CLASS_NEUTRAL_FRONT_METAL_REVIEW.cmd`
- Manifest SHA-256: `37D330D83B489A06585A71FC857CCA78CF45DA55BCABFEECF3650BD9E797526E`
- App SHA-256: `9DE7809CCC903608D5075898770641801CC3704654427C972B0CC7DC44976F5D`
- Index SHA-256: `7402590D786591E722CFE4AD303B9BF21FBF0C7BA19ED4259E37C9A3051C2CE8`
- Styles SHA-256: `F0D1C31FE2DA28D00857486C9678A642B7AD1C837BB9249A1FB50BAB9036777E`
- Builder SHA-256: `1C91A2F36A768C61DA5CB8520D89434F4A443A888687D44C536A793674EDAB69`
- Canonical feedback SHA-256: `D642D9F64F0F45BDF8CB3518DCD49E6A42AA05B1AF5E62942973D99467DEB320`
- Class-neutral event result SHA-256: `8872CCE3935A35A1A0D8EA87C23447A464293D767CCD4FCA66F9E618483903B2`
- Feedback audit SHA-256: `13B478BED7078A45587294170CF3E4A9F4A00DAC5B7EB3850FE636CFEA44D000`

## Detector and review contract

- Native BF/DF scoring and physical extent remain `14411 x 10995`, `scaleX=1`, `scaleY=1`.
- The native tile reviewer contains 11 feedback-selected `2400 x 2000` BF/DF fields.
- Raw BF/DF define physical defect size and affected die.
- Enhanced/composite evidence is co-registered localization evidence only.
- Class-neutral candidate pixels are not automatic rejects.
- Unmarked pixels are not Normal truth.
- No size, shape, recurring-grid, or nearest-neighbor suppression is used.
- Only the exact human-confirmed scribe footprint is excluded.
- Common lot/line conditions remain `HOLD_PENDING_APPROVED_GOLDEN_SENTINEL`.
- The existing frontside chipout branch is unchanged.
- All feedback remains staged; automatic application is false.

## Evidence counts

- Native candidate pixels: `1,773,129` (`3.3582%` of the native active field).
- Connected event pixels: `1,637,159` (`3.10068%`).
- Weak confirmation-hold pixels: `135,970`.
- Internal candidate components: `161,352`; intentionally kept out of the browser payload.
- Prior human positive contexts: `70`.
- Connected-event supported positives: `69`.
- Fail-closed hold-only positives: `1`.
- Exact scribe controls cleared: `4/4`.
- No native image was duplicated into the new review root.

## Release gates

- Canonical UI source hashes verified before adaptation.
- `styles.css` is byte-for-byte identical to the canonical BowComp highlighter.
- Required canonical tabs, controls, highlighter actions, zoom/pan, native-coordinate capture, queue workflow, and staged-feedback contract are present.
- Static asset gate: `11/11` tiles, zero missing assets, zero embedded/base64 payloads.
- Live browser gate: no load error; 11 tile choices; six feedback canvases; native BF and DF load at `2400 x 2000`; candidate, connected-event, and weak-hold masks all load at `2400 x 2000`.
- Disk free after build: approximately `107 GiB`.

## Build failures caught before handoff

These are recorded so the same errors are not repeated:

1. The derived manifest schema must be explicitly accepted by the copied canonical app; otherwise it emits `unsupported manifest schema`.
2. Both `noticed` and `confirmation` evidence layers must be enabled in the default UI state; otherwise the weak-hold mask exists but is not displayed.
3. The canonical lock property is `requiredActions`, not a guessed alternate property name.
4. PowerShell path conversion uses string replacement rather than an invalid single-backslash regular expression.
5. Generic lists are converted with `.ToArray()` before assignment to PowerShell object properties.
6. The build refuses overwrite and references existing native image assets instead of duplicating them.

## Next authorized action

Operator review of the 11 native tiles is the next step. Use the canonical highlighters to mark missed defects, false detections, real-defect reclassification, or display/alignment issues. This review does not require reviewing all 161,352 internal components and must not be interpreted as production or XML authority.
