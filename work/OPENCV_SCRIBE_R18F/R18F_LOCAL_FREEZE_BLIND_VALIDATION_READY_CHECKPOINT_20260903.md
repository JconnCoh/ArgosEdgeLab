# OCV-02 R18F local freeze / blind validation ready checkpoint — 2026-09-03

Classification: `DIAGNOSTIC_ONLY`

## Operator-confirmed K reference

- The operator explicitly confirmed Slot22 position 2 is `3` and position 5
  is `K` in visible string `13DCK060SUF5`.
- Only the native position-5 K glyph was admitted as a diagnostic reference.
  This does not accept the wafer identity or authorize training, activation,
  XML, production, or hold clearance.
- Exact clean BF source SHA-256:
  `3D41F41B0E6F99940ED8C7243DE665FC063EDB4A8408A442C3EDBDD844E40F18`.
- Native 96x230 K reference SHA-256:
  `CEDA3D3F88C13E1566ED993D6C50D7EBBC2DEFB2B877DD4F77FA10CA98C9A640`.
- Operator-confirmation record SHA-256:
  `52A97C34215A75040D1347A946972BB45DFF5557309A78FD661A9CE3522E4CA1`.
- R18F supplemental manifest SHA-256:
  `FD60D494A25B489A8F1D8581217457AD67B02C98D54CA0A5400FAC0611537114`.
  It contains nine references: J=2, K=2, Q=2, W=1, X=1, Z=1. Missing
  body-reference labels remain `I/O/V/Y`.
- Reference build gate SHA-256:
  `8F627A1039D4B0DDC624A3D2890A691B21EF5FBE94B88763558AFF316A375AAB`.

## R18F provider

- R18F retains the unchanged R18C post-grid image algorithm SHA-256
  `44654C1B3136F8BF93E84D93D272DA020D6C33E26E7DC5B66EF7F00D32518C17`.
- The only glyph-arbitration change is the generic topology-override minimum
  margin from `0.15` to `0.12`. It is not lot-, slot-, position-, or
  character-specific.
- R18F provider SHA-256:
  `0E2CD994BB389F1DB5A50FCB2C5C9D0DD6C906925E206C913CB0FCEC1B1543B1`.
- R18F loader SHA-256:
  `D458E7D97B846A6DE44175CDDC70928E48632C3EFBE3014DC5555026C64BE2D5`.
- Checksum remains `VERIFY_IMAGE_FIRST_ONLY` and cannot rewrite a glyph or
  choose a hypothesis.

## Complete local gate

- Frozen regression gate SHA-256:
  `9DF78659381A17CFCB45D5F8205D96D64B87836B1FBB0C0FEFFC23CB083A5036`.
- All nine known-visible regression strings remain exact.
- All five blank/wrong-location controls remain no-string holds. Maximum
  blank selection score is `0.4153806639783699`, below the frozen `0.60`
  presence floor.
- All four R18E development cases pass:
  - `148AW102SUG6` exact, retaining independent W validation;
  - `13DCK060SUF5` exact, including operator-confirmed `3` and `K`;
  - one blank crop remains empty with `HOLD_SCRIBE_NOT_LOCALIZED`;
  - `1480J017SUH0` exact.
- R18F local gate SHA-256:
  `5D2C076F47F0555DE7C23EA049DF1C49B144096A85308153A7E173B9EED5BD76`.
- Gate harness SHA-256:
  `8970D118E1EC97D11D6F8BA84CEE32C62769773A6D7C58CE2160911C3648B33D`.
- The first draft harness invocation stopped before image evaluation because
  its reused finalizer expected the predecessor loader attribute name. The
  local draft adapter was corrected in place; that attempt produced no gate
  or result artifact and changed no source/provider/external state.

## Exact next action

Commit and push this exact frozen R18F state, require a clean branch matching
origin, then run R18F on only the four already-frozen R18E blind-validation
acquisitions. Freeze every blind result before visual review. Do not run the
full KLARF directory. Missing `I/O/V/Y` coverage remains an explicit hold.

R18D remains unchanged. R18E remains no-retry/no-republish. Review-only is
true; automatic reference admission, identity acceptance, activation,
automatic hold clearance, XML, training, production, JBOD, portal, queue,
task/process, source-image, and wafer authority remain false.
