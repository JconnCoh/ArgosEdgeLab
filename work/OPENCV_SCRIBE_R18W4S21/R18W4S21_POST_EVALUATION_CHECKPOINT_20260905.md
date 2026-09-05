# R18W4S21 post-evaluation checkpoint — 2026-09-05

State: `PASS_R18W4S21_SLOT21_R18Z_IMAGE_FIRST_EVALUATION_HELD`

The exact request `REQ_S21_20260905212322_S9RHWN0X00G4K59QB7Q1120VDR` was published once and never retried. The sole matching response `R_8C756EDA3176_20260905231521702_f4fecab3` authenticated as JBOD-signed `PASS_DATA_PULL`. It returned exactly the frozen current-Slot21 BF/DF bytes and no incidental files.

The frozen R18Z 475-reference/49-exact-lineage evaluator decoded only those two returned PNGs. Truth `13HFX135SUE3` was compared only after image-first selection. BF produced `11HFX135SUE3`; it remained wrong at position 2 and was held at positions 2, 3, and 5, including the expected `HOLD_SELECTED_LABEL_SPARSE` for `X` at position 5. DF produced `8P2F0135SUE3`; positions 1, 2, 3, and 5 differed from truth and all 12 positions were held. DF position 12 is now the truthful `3`, unlike the prior R18T final image-first `4`. Neither channel passed the envelope, and there were zero wrong acceptances.

The exact evaluation evidence is `work/OPENCV_SCRIBE_R18W4S21/evidence/R18W4S21_SLOT21_R18Z_EVALUATION.json`, 246,283 bytes, SHA-256 `F91C6EC94C111301D4ACF13AEF8E523AB7D5610451D4B65F4D79902EAE392DCC`. The concise authoritative gate is `work/OPENCV_SCRIBE_R18W4S21/R18W4S21_SLOT21_R18Z_EVALUATION_GATE.json`, 3,914 bytes, SHA-256 `3133C468E3192848F143BF082272A1E7923DCC4687332BFEB5A1406F28D81765`.

The one-shot evaluator's console/top-level convenience projection looked for `ocrEnvelope.positions` and therefore printed empty held-position lists. The canonical saved `ocrEnvelope.heldPositions` rows were correct and are copied exactly into the concise gate. This projection issue did not change source bytes, image-first strings, per-position evidence, envelope decisions, or acceptance. The executed evaluator is non-reusable; no rerun was performed.

Slot21 remains diagnostic-only and unaccepted. No glyph was admitted, no provider was activated, and no training, XML, production routing, whole-wafer/full-KLARF, task, process, queue-management, or source-image mutation occurred. All inherited R18Z, R18T, R18W1, R18Y, R18W2, and R18W3 holds and prohibitions remain in force.
