# R17A signed terminal collection checkpoint — 2026-09-03

## Disposition

- State: `PASS_R17A_SIGNED_FAILURE_FIRST_EXISTING_CROPS_COLLECTED`
- Classification: `APPROVED_BASELINE`
- Request: `REQ_20260903T142600000Z_R17A`
- Response: `R_FF8226603AE2_20260903143643899_ed1b5eaa`
- Endpoint result: `PASS_DATA_PULL`
- Request count: exactly one
- Retry performed or authorized: no
- Publish gate SHA-256: `34E83799683A16195D17D1BC5E878802C20A393E8A16C9B5612EC47D17C6AED1`
- Terminal response gate SHA-256: `CF493D2B916F04E8806C94B809D053AF39765361223FAF4E8CB94D3C9F7E3AD2`
- Local extraction path gate SHA-256: `EBCED91BF0AEBA270CA374824AD86680EB61CFC2BEF8EA9DCF3087A9ACA5F912`

## Signed response

- Source ZIP: `U:\ProjectPortalRO\responses\R_FF8226603AE2_20260903143643899_ed1b5eaa.ready.zip`
- Source ZIP bytes: `30113997`
- Source ZIP SHA-256: `3AE8561E67B51D561D40816D3F534C814CEEA0B2B7D80BE5711ED78A25A63D41`
- Payload SHA-256: `39B72FF65F2E9127F623CD96E012C46215F23C75D2F23D0B5A13305459D43CAC`
- Response manifest SHA-256: `AA4C148C70FDD5613359E365987E39AC4C5083D11DA34BA6D6C021DCE02EEEAB`
- Response signature SHA-256: `71CE20C3C554DA9062494E41DB4026DCE0243C8FE341C7F4F689AEB26292DB78`
- Result SHA-256: `D22717A08D75AFFC75DCEC4513128E9CE8F3240B67AAB9AA91FBDEC31425436D`
- Signer thumbprint: `DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC`
- Source role: `JBOD`
- Signature verification: pass

The exact response manifest, signature, result rows, payload container hash,
24-member payload set, per-member sizes, and per-member SHA-256 values passed.
The response contains 8 proposal JSON files and 16 existing oriented scribe
crop PNG files totaling 30,110,789 source bytes.

## Local extraction

- Signed outer response root: `C:\R17A2R`
- Payload extraction root: `C:\R17A2`
- Outer response file count: `4`
- Extracted payload file count: `24`
- Maximum effective local extraction path length with 32-character reserve: `173`
- Maximum component length: `41`

`C:\R17A` already existed before collection and contains the unrelated
`REQ_20260829T191843905Z_87415E26B6C1.ready.zip`. Collection refused that
root before writing any bytes. The existing root was not deleted, changed, or
opened as image data. A fresh path-gated `C:\R17A2` / `C:\R17A2R` pair was
used for local collection only. The request was not republished.

## Partition boundary

Development acquisitions whose crop pixels may now be analyzed:

1. `Lot-62546-481-POST2_20260713155808_Slot02`
2. `Lot-62546-481-POST2_20260713155808_Slot18`
3. `62620-548_20260810154124_Slot01`
4. `dev-01-post-8-19_20260819164148_Slot01`

Blind-validation acquisitions remain sealed from pixel inspection until the
next detector revision is frozen:

1. `Lot-62546-481-POST2_20260713155808_Slot20`
2. `Lot-62546-481-POST2_20260713155808_Slot23`
3. `62627-193_20260820124250_Slot01`
4. `62625-956_20260729122701_Slot17`

The collector verified blind files cryptographically and extracted their bytes
without decoding or viewing their pixels.

## Authority

- Review-only: true
- Automatic identity assignment: false
- Training: not authorized
- XML: not eligible
- Production: not eligible
- Hold clearance: not authorized
- Provider activation: not performed
- Task or process action: none
- Source mutation: none

## Next action

Analyze only the four development acquisitions using the existing crop-first
geometry/OCR arbitration, keep the clear-control and misplaced-S17 regressions
mandatory, freeze the next detector revision, and only then inspect the four
blind-validation acquisitions exactly once.
