# R18J2 full-KLARF scribe run — publication ready

Classification: `PENDING_GATE`

## Slot24 acceptance condition

The operator-confirmed Slot24 truth is `143B0083SUE6`. The unchanged R18H
reader returns that exact image-first string from the corrected source-derived
crop. The full corpus wrapper also returns it from the existing-crop fast path
and preserves the close DF alternative `103B0083SUE6` as
`HOLD_SCRIBE_MULTIPLE_CLOSE_IMAGE_FIRST_STRINGS`. No identity was accepted.

- Local corpus gate:
  `work/OPENCV_SCRIBE_R18J/R18J_CORPUS_LOCAL_GATE.json`
- Gate SHA-256:
  `2803AEE7EF2C1C8993BF279F4F3C1F305B375E4018E1DFC344A8A678A76EA03E`
- Frozen reader SHA-256:
  `3AF68D778E297531DD527DD9D65C75FD17BD1FB9C2EC797CB840B10A674532AD`
- Crop sweep SHA-256:
  `EF4C58589CA8885B5CBDE0A989D3F94EE8C447925818DC0FA4E50B26B87A8B9F`
- Corpus runner SHA-256:
  `E8C193024317C683EA0E8DC999F3D632BF113B65C1E6F528949AE5B33F83A069`

The worker uses existing scribe crops first. Missing, blank, boundary-incomplete,
or below-floor crops alone use the bounded 2000x800 whole-wafer source-pixel
sweep. Structure can prove paired-crop geometry but cannot choose OCR channel
or polarity. No notch, wafer grid, solid line, synthetic dot reconstruction,
checksum correction, or lot string selects the image-first characters.

## Exact signed request

- Request: `REQ_20260904T014700000Z_R18J2`
- ZIP:
  `work/OPENCV_SCRIBE_R18J/final/REQ_20260904T014700000Z_R18J2.ready.zip`
- Bytes: `150052`
- ZIP SHA-256:
  `5014D4C117042AFDB23C9E2E02A83B1135227D6FCCCBE474FC203C86F8DB825E`
- Manifest SHA-256:
  `86C528A9EFA5AEE8D24A573261B52C131C9A756C5C68EB61336834DD99BA1290`
- Signature SHA-256:
  `B9D4543850A82431DFEDC6108410A220397AB1451D3ACA792AD55907D6E5828D`
- Final-package gate SHA-256:
  `C5772BEC9A64FF4A5E81F35C26CB8528C5E8F78B6DB48529B55BD71CB71FD110`
- Complete-route gate SHA-256:
  `6D4704A882DFAF4C5A1D851391FA56F4A5F48E0C5620158644445F3DAA761144`
- Publication authority SHA-256:
  `DD4A7D2753A4618FA89053B335AB4BEBF3CA5B0A870471DA76FFC24B4AF75210`

The signed ZIP contains 25 payload files plus its manifest and signature. Exact
ZIP extraction, signature verification, packaged entrypoint preflight, Windows
PowerShell 5.1 parser/harness checks, the 90-signature zero-recurrence audit,
and the full 26-hop route/path gate pass. Maximum effective path length is 191
with a 32-character reserve.

## Execution contract

The portal request may create only:

- installed entrypoint
  `C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV02_R18J.ps1`;
- work root `D:\A2\w\ocv\R18J1`;
- output root `D:\A2\o\ocv\R18J1`; and
- one owned background `Run-R18JScribeCorpus.py` process.

The process inventories paired frontside BF/DF full-wafer sources under
`D:\KLARFExport`, checkpoints each case, groups explicit hold states, and writes
`RUNNING.json` and eventually `COMPLETE.json`. The portal response proves launch,
not corpus completion. Completion must be collected separately from the fresh
output root.

Missing body-reference labels `I/O/V/Y` remain explicit coverage limitations;
they are not guessed or admitted automatically.

## Withdrawn draft

The locally signed R18J request `REQ_20260904T014500000Z_R18J` was rejected by
the canonical verifier before ZIP creation because its create-only change had
an empty allowed-installed hash set. It was never published. Its exact signed
stage is preserved at `C:\R18JP` and is non-reusable. R18J2 permits only an
absent destination or the exact target hash for idempotent validation.

## Authority

One publication is authorized; retry is false. Review-only is true. Identity
acceptance, automatic reference admission, training, activation, hold clearance,
XML, production routing, source mutation, and source deletion remain false.
