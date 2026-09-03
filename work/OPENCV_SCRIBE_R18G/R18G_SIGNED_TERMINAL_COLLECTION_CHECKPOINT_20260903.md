# OCV-02 R18G signed terminal crop collection — 2026-09-03

Classification: `APPROVED_BASELINE`

Request `REQ_20260903T220000000Z_R18G` was published exactly once. Matching
response `R_5FAB56656B2D_20260903221148575_65bcc5ed`, ZIP SHA-256
`EDE6F6BD15762499621B013613915EB29981CF48C67A4D771AE94FAC280F2DE9`,
returned `PASS_DATA_PULL`.

The exact response passed RSA signature verification against pinned JBOD
thumbprint `DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC`, request/response identity,
four-member outer ZIP, exact 24-member payload, byte-count, and SHA-256 gates.
The response contains eight proposal JSON files and sixteen paired BF/DF
existing scribe crops totaling 27,411,116 source bytes.

The response was collected create-new under `C:\R18GR` and `C:\R18G`.
Terminal collection gate SHA-256 is
`4ED056AD8B7A1FD4FEA3494E82FBCA8D324AB21E5629524B1A4745418C39E873`.
No pixels were decoded or inspected during discovery, verification, or
collection.

R18G is terminal and no-retry/no-republish. Exact next action: verify frozen
R18F and every returned hash, then run only the four predeclared development
acquisitions. Freeze their outputs before opening any of the four blind
acquisitions. Do not run the full KLARF corpus.

Review-only remains true. No provider activation, identity acceptance,
automatic reference admission, automatic hold clearance, XML, training,
production, source mutation, task/process action, or wafer action is
authorized.
