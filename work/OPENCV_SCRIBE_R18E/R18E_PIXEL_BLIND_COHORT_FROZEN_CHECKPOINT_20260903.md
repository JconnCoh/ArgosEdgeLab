# OCV-02 R18E pixel-blind cohort checkpoint — 2026-09-03

Classification: `PENDING_GATE`

R18E freezes the next small failure-first cohort from the exact signed
966-row current-reader queue. Selection read metadata only; it did not read,
decode, hash, or inspect any newly selected wafer pixels.

## Frozen selection

- Queue SHA-256:
  `BB740FEA504FCA97E1AA98EAF03C65B348875CF325D8EB7A671A80A41C05BA81`.
- R17A and R18A contribute sixteen excluded acquisitions. The remaining
  eligible unresolved paired-source population is 136 rows.
- R18E selects eight unique acquisitions across six lot families with zero
  prior-cohort overlap.
- Development partition:
  - `62633-726_20260818204139_Slot20` — adjacent unseen W-family case;
  - `62546-481-POST_20260713041740_Slot22` — fresh K/X-family case;
  - `62625-907-PRE_20260709123021_Slot14` — different-slot X-family case;
  - `62627-098_20260729105955_Slot16` — J/Q-family reader failure.
- Blind partition:
  - `62633-726_20260818204139_Slot21` — second adjacent unseen W-family case;
  - `Lot-62546-481-POST2_20260713155808_Slot14` — difficult Post2 case;
  - `62624-869_20260720115731_Slot02` — distinct BowComp reader failure;
  - `62625-956_20260729122701_Slot18` — J/Q-family reader failure.
- Lot-family context is selection vocabulary only. It does not assign a
  visible string or wafer identity.

## Frozen files

- Planner SHA-256:
  `5B599865577A7139847A03F32699ECBA5BFB79645E9537E4037B825F69BAC8BE`.
- Cohort:
  `work/OPENCV_SCRIBE_R18E/R18E_COHORT.json`, SHA-256
  `A36B94205B56CAF67B69D7CFB48651CC0D185AA74496CA4C7BF6EA2D5AC3931C`.
- Exact 24-file existing-crop pull definition:
  `work/OPENCV_SCRIBE_R18E/R18E_DATA_PULL_DEFINITION.json`, SHA-256
  `C4787C80AB9AFB05772112EED4D9DCAB83CFB26EEDF77317E1555B518B03AE5B`.
- Selection gate:
  `work/OPENCV_SCRIBE_R18E/R18E_SELECTION_GATE.json`, SHA-256
  `70C6862FDDBA435B77515266C31612F5819F51F333EE829E32843B13A3D38C0E`.
- A fresh external reproduction emitted byte-identical cohort, definition,
  and selection-gate JSON.

## Source and authority boundary

The future request is limited to each selected acquisition's already existing
`SCRIBE_PROPOSAL.json` and paired BF/DF oriented detector-input PNGs beneath
approved root `JBOD_PROCESSOR_REVIEW`: 24 files, 50 MiB maximum. It requests
no full-wafer BMP, new crop, source write, task/process action, or provider
activation.

Exact next action: build and locally gate one fresh signed R18E `DATA_PULL`
package. Publication remains blocked until the operator explicitly says
`PUBLISH` for R18E. After one publication, collect only the matching signed
terminal response; never retry.

R18D remains frozen. Blind pixels must remain unseen until its exact provider,
algorithm, supplement, and local gate are verified. Review-only remains true;
identity acceptance, automatic reference admission, automatic hold clearance,
XML, training, and production authority remain false.
