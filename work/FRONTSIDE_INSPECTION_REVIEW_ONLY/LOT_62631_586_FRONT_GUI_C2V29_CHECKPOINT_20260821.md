# Lot 62631-586 FRONT GUI C2V29 checkpoint — 2026-08-21

Classification: `PENDING_GATE`

Signed C2V29 response `R_289136FAF367_20260821112336488_48f4bfcf`
is recorded in
`work/JBOD_FRONT_ROUTE_C2V29/C2V29_TERMINAL_RESPONSE_GATE.json`, SHA-256
`9F0CC567A46C72BD1106790DF569DA1B706D5B348592C439E3C73AE27DD91F84`.

It proves that all ten exact `62631-586_20260819173317_Slot01..10`
acquisitions now have confirmed scribe identities. Slots 01, 03, and 04 were
resolved from current pixels by exact unique MES/lot matches; the other seven
were admitted by the existing exact prior-human image-match contract. No
identity was hardcoded.

The exact C736 response was a compatibility candidate request for seven
unrelated acquisitions. Its transport kind was `CURRENT_IMAGE_CANDIDATE`, it
contained zero acquisition contexts, and none of its request keys belonged to
the target visit. The target has zero verified metadata rows and zero active
Insite holds. Therefore the old catalog's three scribe holds are stale, while
all ten target wafers are blocked solely because the automatic exporter gives
candidate verification priority over confirmed-scribe route lookup.

Installed exporter SHA-256 is
`39DF423DA7985C20950E6BDBFD1F852BB2094AD410FA52373FC04D79418EB714`.
Next, patch the established automatic bridge worker generically to export
confirmed-scribe metadata first and use current-image candidate lookup only
when no confirmed metadata is pending. Queue one fresh confirmed request,
import its exact response, refresh processing, and require signed live
`frontsideAssetWafers=10` acceptance.

No image was read, no queue was cleared, no source was deleted, no task was
restarted, no wafer was aborted, and XML, training, and production routing
remain disabled.
