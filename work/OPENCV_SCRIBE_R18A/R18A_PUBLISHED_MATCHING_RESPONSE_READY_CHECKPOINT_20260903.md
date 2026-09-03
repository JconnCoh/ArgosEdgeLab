# R18A published once / matching response collection ready

## Disposition

- State: `PASS_R18A_PUBLISHED_MATCHING_RESPONSE_COLLECTION_PREFLIGHT`
- Classification: `PENDING_GATE`
- Request: `REQ_20260903T171128612Z_R18A`
- Response: `R_84B9CB78722E_20260903172040421_2b8e31ed`
- Retry: forbidden

The exact 1,429-byte signed request was published once at
`2026-09-03T17:20:50.3314910Z`. The request moved to the processed share and
its SHA-256 remained
`FBE411874B3772B807CD7F4BE6F7AD0730C3311CFAB902A997E842992CC463B5`.
That proves gateway acceptance only.

The exact matching response is 28,454,970 bytes with SHA-256
`CBA4E0A078D867BD13FD77F49628B32F83B72FC203BC6C302C39D33352600F7B`.
The pinned Windows PowerShell 5.1 collector preflight verified the JBOD signer
`DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC`, response/request identity,
`PASS_DATA_PULL`, the exact 24-member set, every member size and SHA-256, and
the 28,446,826-byte source total. No pixels were decoded.

Collector SHA-256:
`3391DF83E6856108BC7A4FD3162B68E355F285A9AAE497AD1DD6265C8E76EBE9`.
Collector clone gate SHA-256:
`5E660AC906E36B2BA1795F22E6B15215AC7877D2DDBFEDB1FB1587C886E22DF5`.
Publication gate SHA-256:
`288CA976B1F6A743ADB0F7A73765C695CC33597BB3D839BC2359A37CAEBFC954`.

## Next action

Commit/push the exact collector and publication evidence, then perform one
create-new local collection into `C:\R18AR` and `C:\R18A`. Do not republish
or retry the request. Review-only and all identity/activation/training/XML/
production/hold restrictions remain unchanged.
