# OCV-02 R18G development run B timeout withdrawal — 2026-09-03

Classification: `WITHDRAWN`

Frozen runner B SHA-256
`3D32E23FE501CB8363B2D46D1536967A113D7F74F3C1C33B4BA27AA43D1A0582`
started exactly the four declared development acquisitions at create-new root
`C:\R18GDB`. The caller terminated the process at its declared 600-second
limit. It emitted no stdout and did not create the required aggregate gate.

The preserved partial root contains five files:

- POST2 Slot17 job `EA6049744E4CCBE6E0BFCEEE75DC0A68B8220C327918063D1C67BFC708E7CC0C`
  and result `4C5CCD108F6C22955360ADF15D784512429003BD8590A3018073F69DC83655B9`;
- 62620-548 Slot05 job `C2230183FDE467B7EBBD60766141482BCCC2503A556BED0E85E8F2671F639D29`
  and result `3C3C872484C89523F9FC993353E90EEDE2B12BEC681D9C38ABC2F4DDFC4D9403`;
- 62624-855 Slot08 job
  `1733BDB00FE5F5FE767854B9D99D304A7A4813D2DA95B712B1066A5DD2D72DB5`,
  with no result.

The fourth development case was not started. No aggregate gate exists. Zero
blind acquisitions were read. No development image was opened for visual
review, and the two partial results are not accepted detector evidence.

Run B and `C:\R18GDB` are withdrawn and must not be resumed, patched, deleted,
visually reviewed, or used as a detector gate. R18G remains published exactly
once and must never be retried or republished. No JBOD, portal, source, task,
process, queue, identity, provider, activation, training, XML, production,
wafer, or hold state changed during this local attempt.

Exact next action: stop. A later operator-authorized local continuation must
use a fresh namespace and execute one declared development case per bounded
run, followed by a separate hash-only aggregate step. It must continue to read
zero blind acquisitions until all development outputs are frozen.
