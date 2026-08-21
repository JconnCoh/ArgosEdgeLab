# FM7P24A signed JBOD response pass and data-pull route hold

Date: 2026-08-17  
Revision: `FM7V17R5P24A_SIGNED_RESPONSE`  
Disposition: `PENDING_GATE`

## Signed terminal response

Bounded manifest-only discovery selected exactly
`R_EBBC802898BE_20260817172314860_a6d4f1c7.ready.zip` from the shared response
root. The ZIP is 2,505 bytes with SHA-256
`D9589172B8BD00B722AF52FA5FF5C7E096107810E2C7D3462C036D7D56738F24`.
It was extracted alone through a verified persistent short share mapping; the
mapping was removed afterward.

The exact Windows PowerShell 5.1 response verifier passed all three declared
payload files against the pinned JBOD endpoint certificate:

- request ID `REQ_20260817T153923252Z_2EB5616C2942`;
- source role `JBOD`;
- endpoint state `PASS_MAINTENANCE_PATCH`;
- signer thumbprint `DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC`;
- production routing disabled.

The signed maintenance stdout contains the required terminal state
`PASS_FM7P24_T16_T17_ZERO_BLANK_TARGET_EXCLUDED_COMPOSITES_REVIEW_ONLY`.
It reports output root
`C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\diagnostics\FM7P24\outputs\FM7P24_20260817T153800Z`,
12 targets processed, zero skipped, 24 control composites, 12 targets using a
fallback reference, and zero unassigned control pixels. The reported final
`AUDIT.json` SHA-256 is
`07CE75FB964E24416E827145A40594A545AFDB317E0E2140B1666E8DC0A7C712`.
The signed stderr is empty.

## Result-pull planning hold

The full planned 41-file `DATA_PULL` route was evaluated before definition,
request, or share publication writes. The source, endpoint work, response
partial/ready, sender, receiver, archive, share, laptop receipt, extraction,
and final result paths were evaluated. Two gateway publication paths fail.
The current temporary ZIP formula produces a 92-character
`<response>.ready.zip.partial.<32-hex-guid>` component, above the mandatory
80-character hard stop. Separately, the gateway's direct engineering-share
`.upload` response path is 212 characters before reserve and 244 effective
characters with the mandatory 32-character reserve, above the 230 hard stop.
A laptop-only mapped share drive does not prove visibility in the gateway
scheduled-task context.

No result-pull request was created, signed, or published. FM7P24A remains
`PENDING_GATE` until a separately rehearsed gateway-only repair both shortens
the staging leaf and establishes a verified short share alias in the exact
gateway task context. The signed FM terminal response proves the JBOD endpoint
and existing response route recovered; it does not waive either newly detected
planning hard stop.

No detector, source image, transform, reference mask, defect result, reviewer,
XML, training, or production authority changed.
