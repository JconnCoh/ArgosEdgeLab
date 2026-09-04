# R18J2 signed terminal failure checkpoint

R18J2 was published exactly once as request `REQ_20260904T014700000Z_R18J2` and received signed terminal response `R_FB23C53B3405_20260904015444713_2661f644` from the JBOD signer `DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC`.

The canonical response verifier returned `PASS_SIGNED_PORTAL_RESPONSE`; the endpoint state is `FAILED`. The exact stderr is:

`R18J dependency absent: D:\AFCV1\review\identity\proposals`

The failure occurred in the entrypoint's dependency preflight before the corpus worker was started. No work root or output root was created, no scribe image was read or decoded, and no identity, reference, training, XML, production, task, process, queue, or source-image state was changed.

The request and its package are terminal and must not be retried. The reader, crop sweep, reference library, and validated Slot24 result remain unchanged. Before a fresh successor can be considered, obtain and pin a direct post-failure read-only observation of the installed processor state root and actual `identity\proposals` directory.

Machine-readable evidence: `R18J2_SIGNED_TERMINAL_FAILURE_GATE.json`.
