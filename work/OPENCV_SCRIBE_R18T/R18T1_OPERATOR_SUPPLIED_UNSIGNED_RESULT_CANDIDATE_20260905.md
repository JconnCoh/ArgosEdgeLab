# R18T1 operator-supplied unsigned result candidate

Created UTC: `2026-09-05T12:33:17.4741946Z`

State: `BLOCKED_UNSIGNED_R18T1_RESULT_CANDIDATE`

The operator supplied this exact candidate:

`\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs\ProjectPortalRO\responses\R18T1.zip`

The candidate is 116,912 bytes with whole-ZIP SHA-256 `B87C8E0A4DAF9E106C60C21FC5726DFE6671D28F7E321B3347E90C3DADC7F945`. It is distinct from the already frozen 3,299-byte signed launch response, SHA-256 `E642397BB1BA3DBD39E8B15248D8E5CB85E2239DC80796ECC06EEBC2EC909AF6`.

Only the ZIP central directory was inspected. It contains 48 entries: 22 directory entries and 26 file entries. The file-name set is:

- `R18T1/c/061E59583604B66E/RESULT.json`
- `R18T1/c/07007F95AB0811CC/RESULT.json`
- `R18T1/c/2B83EAF1CF7DB09B/RESULT.json`
- `R18T1/c/4D3AA5EBF7D10373/RESULT.json`
- `R18T1/c/6CC89D2942F8BF5E/RESULT.json`
- `R18T1/c/78A92CB774737D27/RESULT.json`
- `R18T1/c/88DD0E7F1BF6B274/RESULT.json`
- `R18T1/c/8C1611D92A42E578/RESULT.json`
- `R18T1/c/9FA1A0844FA3CFAC/RESULT.json`
- `R18T1/c/A930FE78026C8A8E/RESULT.json`
- `R18T1/c/B2D77803F2CA16B1/RESULT.json`
- `R18T1/c/BA207AE01077DCE0/RESULT.json`
- `R18T1/c/BC1FC7C67C230B23/RESULT.json`
- `R18T1/c/CE0A5D1314F3E2F5/RESULT.json`
- `R18T1/c/D13ED9B05187C37E/RESULT.json`
- `R18T1/c/D3E9AF15DF7E8E9D/RESULT.json`
- `R18T1/c/D772487FFB144590/RESULT.json`
- `R18T1/c/D8752BD6B66A6111/RESULT.json`
- `R18T1/c/D9CD191357366B35/RESULT.json`
- `R18T1/c/DBE8E9E8E9EE9483/RESULT.json`
- `R18T1/COMPLETE.json`
- `R18T1/INVENTORY.json`
- `R18T1/LAUNCH.json`
- `R18T1/RUNNING.json`
- `R18T1/WORKER.stderr.log`
- `R18T1/WORKER.stdout.log`

The archive contains no `PORTAL_RESPONSE_MANIFEST.json` and no `PORTAL_RESPONSE_MANIFEST.sig`, at its root or under its sole `R18T1/` prefix. Therefore its requestId, source role, signer, authority flags, exact declared member set, and member hashes cannot be authenticated. The filename and the presence of a central-directory member named `COMPLETE.json` are not execution proof.

No archive member body was opened. In particular, none of the 20 `RESULT.json` bodies, terminal-marker bodies, inventory, launch record, or logs were read. The candidate was not extracted or copied. No image members were present, and zero image member bodies were opened.

No publication, republication, retry, package execution, GUI/RDP access, direct JBOD access, queue mutation, task/process access, source-image access, identity acceptance, or R18S action occurred. The six holds, Slot24 package exclusion, no-retry rule, production prohibition, and unrelated-global-phase boundary remain unchanged.

Signed-evidence outcome remains `PENDING_UNPROVEN`: configured cases `20`; authenticated terminal per-case outcomes `0`; exact PASS/HOLD/failure counts unavailable.

Required next artifact: a portal response ZIP containing a valid RSA-SHA256-PKCS1 `PORTAL_RESPONSE_MANIFEST.json` and `PORTAL_RESPONSE_MANIFEST.sig` for requestId `REQ_R18T1`, signed by endpoint thumbprint `DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC`, with every returned file declared by exact byte length and SHA-256.
