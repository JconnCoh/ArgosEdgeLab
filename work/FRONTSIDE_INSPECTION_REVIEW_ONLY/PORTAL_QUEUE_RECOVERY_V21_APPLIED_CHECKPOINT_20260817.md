# Project Portal JBOD queue-recovery V2.1 applied checkpoint

Date: 2026-08-17  
Revision: `PORTAL_JBOD_QUEUE_RECOVERY_V2_1_APPLIED`  
Disposition: `DIAGNOSTIC_ONLY`

## Operator-reported live result

The operator completed `RUN_RECOVERY.cmd` on the JBOD and reported the
terminal success message with recovery audit path `C:\Q\A\RECOVERY_RESULT.json`.
The terminal explicitly reported that the expired signed request was preserved
in quarantine and not executed, the current signed request remained queued,
and no duplicate request was created.

This establishes successful live application of the rehearsed V2.1 recovery
workflow from the operator-visible terminal. The local workstation has not
retrieved or independently hashed the JBOD audit file, so this checkpoint does
not claim byte-level verification of `C:\Q\A\RECOVERY_RESULT.json`.

## Queue state and next gate

- Expired patterned request `REQ_20260816T033053168Z_802B9D0EC0B4` remains
  ineligible for execution and must never be replayed or bypass expiry.
- Current FM7P24A maintenance request
  `REQ_20260817T153923252Z_2EB5616C2942` remains the sole queued request to
  verify.
- A response-directory probe immediately after apply found no new shared
  response ZIP yet; the newest existing response remained dated
  2026-08-16T03:19:16Z. This is `RESPONSE_PENDING`, not an inspection pass or
  failure.
- Only a valid signed terminal response for the exact current request may
  establish endpoint health and authorize the bounded FM result pull.

No image, alignment, composite, defect, mask, threshold, reviewer, XML,
training, or production authority changed.
