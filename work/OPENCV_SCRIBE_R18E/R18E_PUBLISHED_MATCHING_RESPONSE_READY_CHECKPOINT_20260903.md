# OCV-02 R18E published once / matching response collection ready

Date: 2026-09-03

Disposition: `PENDING_GATE`

Exact signed request `REQ_20260903T192241716Z_R18E`, ZIP SHA-256
`C0218B20414CB2DF0B1C11F5273BD0C989CB6EE550D048C6163F5E21E8A2A502`,
was published once with create-new semantics at
`2026-09-03T19:47:58.9964113Z`. The processed-share copy hash-matches the
frozen request. R18E must never be retried or republished.

Matching response
`R_D1D4956AA344_20260903194752479_47abca21` arrived immediately:

- response ZIP bytes: `26079184`
- response ZIP SHA-256: `72FA6467CC8DF2020B7D21027BCEFEFC50B93AA0035FD74DF6B4619498C747C2`
- response manifest SHA-256: `44079A8FA69F9BF7E3C239F9389278363F04E16EB206D8F56B06459BA76162C4`
- response signature SHA-256: `F7D1FF9A1B50848DC0442D06D6012C8EA8AB7E5D1E6E65619D983EF6725BD40A`
- result SHA-256: `6F684002DA901D2980883CC0D62CF257268FBFCD7D6AC861598661FBE770EB1C`
- payload SHA-256: `E419F20505881EF95D2399C42FD62DE39B884C879458E34AFB5D29FE5141EE62`

Windows PowerShell 5.1 in-memory preflight verified the JBOD RSA signature,
expected signer `DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC`, exact request/response
identity, `PASS_DATA_PULL`, all 24 requested relative paths, all 24 payload
members, every byte count, and every member SHA-256. Total returned source
bytes are `26073436`. No pixels were decoded.

Publication gate SHA-256 is
`484FF80082F4C3CB97BA73F207A7157336FE67D851777C15019A459042B5E1A8`.
Collector SHA-256 is
`83A88201F88D8656438BA9AFD30C8F6A131A0AAAF873225A4F40D4AC75AD3F3F`;
collector tooling gate SHA-256 is
`5FF505E432BBE8D166365DEDB01893E96633D418FDFB75171416DA25D1C20953`.

Next action: commit/push the publication and exact response-collector tooling,
then collect create-new into `C:\R18ER` and `C:\R18E`. After collection,
verify the frozen R18D reader before viewing blind-validation pixels. No retry,
provider activation, identity acceptance, reference admission, hold clearance,
XML, training, production, task/process, source, or wafer action is authorized.
