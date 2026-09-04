# R18N full-KLARF scribe launch — signed, unpublished, explicit PUBLISH required

Classification: `PENDING_GATE`

## Outcome

Fresh R18N corrects the two package-contract defects that prevented R18M from
reaching the reader. It uses short request ID `REQ_R18N1`, enumerates all 27
actual signed-ZIP members, explicitly includes the R18M-rejected supplemental
manifest leaf, and binds no-argument entrypoint defaults to the same R18N1
work/output roots declared in the signed request.

The signed package is local only. It has not been published, JBOD has not been
contacted by R18N, no work/output root exists because of R18N, no worker has
started, and no image bytes have been read by R18N.

## Frozen product bytes

- Reader: `work/OPENCV_SCRIBE_R18H/ArgosOpenCvScribeV1R18H.py`
  - SHA-256 `3AF68D778E297531DD527DD9D65C75FD17BD1FB9C2EC797CB840B10A674532AD`
- Crop sweep: `work/OPENCV_SCRIBE_R18J/ArgosOpenCvScribeCropSweepR18J.py`
  - SHA-256 `EF4C58589CA8885B5CBDE0A989D3F94EE8C447925818DC0FA4E50B26B87A8B9F`
- Corpus worker: `work/OPENCV_SCRIBE_R18J/Run-R18JScribeCorpus.py`
  - SHA-256 `E8C193024317C683EA0E8DC999F3D632BF113B65C1E6F528949AE5B33F83A069`

None of those bytes or the reference library changed.

## R18N correction

- Entrypoint: `work/OPENCV_SCRIBE_R18N/Invoke-R18NCorpusLaunch.ps1`
  - SHA-256 `0B75F178A4D73668DBD76E0F07A820E16897DA40D0466A6FBA84806A8AFCD746`
  - default work root `D:\A2\w\ocv\R18N1`
  - default output root `D:\A2\o\ocv\R18N1`
  - default proposal root
    `C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\identity\proposals`
- Definition SHA-256
  `640230EECD8CA8C65767E52C9C436791EE10AEAA5EDB35F89B1A5D1D414292E1`
- Entrypoint-default gate SHA-256
  `02A9106C5D7FDC568C94D8A2B41C62AC62A7F0735F445E4A967CE4C51D83AF92`

## Exact path proof

- Planned member-set SHA-256
  `02D888A6921BF16695C262B821FF894DE5BCF3AF42F5E192B544491C233003B8`
- Actual final ZIP member count: `27`
- Actual final ZIP member-set SHA-256: exact match to plan
- Expanded member/work candidate count: `127`
- Full request/response round-trip candidate count: `26`
- Maximum effective length with 32-character reserve: `196`
- Unsafe path count: `0`
- Exact final-ZIP membership gate SHA-256
  `2FA7FA6D98C7EA8320D6931FE1F9F4FD67B3E15A06A781A604CAB7C82C6552D2`
- Full round-trip gate SHA-256
  `D7230106F89C80062E2C64D018441554A0ED64D5FD25959792930F3DA71C7967`
- Independent Windows PowerShell 5.1 package-path gate SHA-256
  `7265749BAF77759B973CB58BDCAA33094B4A7A353AE165E8B1E3AC095891AF74`

The prior failing leaf is now the measured longest endpoint leaf at length
164, effective length 196. It is not represented by a shorter proxy.

## Signed package

- Request ID: `REQ_R18N1`
- ZIP: `work/OPENCV_SCRIBE_R18N/final/REQ_R18N1.ready.zip`
- ZIP bytes: `150135`
- ZIP SHA-256
  `198F365EF1B21739A9D6D7E67628F45751641ECE17112C01CE9A3F586431BEE4`
- Request manifest SHA-256
  `2031B32D26DF561F3A8ADD35C3D60EF853CB9A630B1993F899A71ECF993B8A0E`
- Request signature SHA-256
  `DE65F4464919E1B2730CEA81DAFE87EEF2378E01E5F8229F30A21D0C5DBD9632`
- Final-package gate SHA-256
  `865B96A8775F30A7D4DC7B81A65C428B4CB2B816EF3B5D5160F4CE221BD41A73`

Exact ZIP extraction, request signature verification, packaged entrypoint
rehearsal, PowerShell parser/harness safety, clone remediation, recovery
intent, zero-recurrence preaction, exact member enumeration, and full
round-trip path checks passed.

## Authority and next action

The signed request records `explicitOperatorAuthorityPresent=false` and is
unpublished. Publication requires a new explicit operator instruction
containing `PUBLISH`. After that instruction only: create and pin the R18N
publication-authority record and exact publisher, require clean local/origin
branch equality and zero pending requests, publish this ZIP once, and collect
only the matching signed response. Retry is false.

If the signed response reports launch PASS, first prove `LAUNCH.json` names
`D:\A2\o\ocv\R18N1` before monitoring corpus progress. Review-only remains
true. Identity acceptance, automatic reference admission, hold clearance,
training, activation, XML, source mutation/deletion, and production remain
false.
