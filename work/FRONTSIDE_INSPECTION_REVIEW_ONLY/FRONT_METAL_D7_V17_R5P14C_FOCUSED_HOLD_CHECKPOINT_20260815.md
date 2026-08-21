# Front-metal D7 V17 R5P14C focused S13 hold checkpoint

Date: 2026-08-15

Revision: `FM7V17R5P14C`

Disposition: `DIAGNOSTIC_ONLY`

R5P14C reproduces the unchanged R5P14B fail-closed peer result and adds one
focused native-source operator sheet for the exact three held S13 panels.

S03 and S18 pass all four BF and DF fiducial sites. S13 remains held only at:

- S25 BF L02: 74/78, maximum gap 1 px;
- S20 BF L02: 74/78, maximum gap 1 px; and
- S25 DF L02: 74/78, maximum gap 1 px.

Every other S13 edge is complete. S13 BF/DF global rigid RMS remains
0.045436/0.058188 px and topology correlation remains 0.998837/0.998656.
No composite was built.

## Focused operator gate

Review first:

`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P14C/S13_L02_HOLD.png`

The 2160 x 760 sheet shows only S25 BF, S20 BF, and S25 DF at the native-source
fiducial crops. Magenta is the directly observed first-transition support and
green is the fitted six-edge solution. It is intended to answer whether the
three L02 lines are visually thin and coherent enough to retain the same
bounded, non-autonomous 74/78 exception already accepted for S26 BF L02.

The broader peer sheet is:

`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P14C/PEER_REGISTRATION.png`

No gate has been relaxed. If the operator accepts the focused panels, one
fresh three-peer target-excluded composite may be built without changing any
other threshold or eligibility rule. If not, preserve
`HOLD_INSUFFICIENT_TOPOLOGY_QUALIFIED_PEERS`.

## Provenance

- audit SHA-256:
  `8DF9F9D516CCC8C992DEDE29F256F9390245E92E5C628F643148DADF09485FDD`;
- focused sheet SHA-256:
  `5031701D52B3E90C40A31C8E8E119FBE11C289C0E8B7691659CE556950AD6803`;
- peer sheet SHA-256:
  `3014F9F0F496DF4A7C701A3B279D78FE087C0559E0BBF24526209420E2264D8B`;
- input SHA-256:
  `A761A9C112BE4F86F321082E13B3E433A7E1DFD5A64558F88240ABFEC7F600AB`;
- source SHA-256:
  `F303DD8B2E6DB08A6E0D315917AE3FF1065B32C298BE26B6AC2C158533C77FE7`;
- executable SHA-256:
  `9893217FD59D9C2988A56CD294476AA1AB52EA14A9E1C565CC5BFF3C4BFCA387`.

The target remains excluded from its own reference, BF/DF remain independent,
the live target remains unresampled, and the possible Argos stitch issue was
not evaluated. Masks, thresholds, classifier, saved feedback, deferred stroke
278, XML, JBOD, production routing, and the strict chipout sibling are
unchanged.
