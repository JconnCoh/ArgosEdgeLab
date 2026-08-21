# JBOD C2T2 signed singleton/task-state failure — 2026-08-19

Disposition: `PENDING_GATE`

Matching signed response `R_D2B0F0F9AD8A_20260820012815352_53bbbbef`
terminally failed after the exact tray scheduled-task restart call. Its signed
stderr says `C2T tray task is not Running after restart.` The portal queue is
empty and the response signature and all three declared response files passed.

- response ZIP SHA-256:
  `77814270038E731963789FCA2CBA3ADE5F4EB5DBABFF234E87E4A435C76955AB`;
- response manifest SHA-256:
  `A0DA37C5BD8C1AD8A25D21B1F8186E86DFB2128C19B7F86DE55B63D2140E8C1A`;
- response signature SHA-256:
  `D76B7B1EB9E7C340A88BEFB6F32B998BA0E6095C598D1FEB3D9D926F8B2ED13D`;
- response route gate SHA-256:
  `C4F04FCCD7CAED1E97EF31AB87477A2607913DDDD5804C4736D867C167E41056`;
- terminal failure gate SHA-256:
  `345831E792F8E07B8074877258EFC959E495EAD4E5D450DDC67279A3DF57CA42`;
- exact stderr SHA-256:
  `1F3C60F5DC9DB29777493BF6998341E9F97DE676C1F8860048FAE9F189DBAF43`.

The installed tray source is pinned at SHA-256
`81C54306E06F7160BD953B7D21149FFD4D1059CB2672EE4FECC0B4A108E3DA2B`.
It owns named mutex `Local\ArgosEdgeLabAllWaferTrayReviewOnlyV2`; when another
tray process already owns that mutex, a scheduled instance signals the existing
process and exits. Therefore a subsequent scheduled-task state of `Ready` does
not prove that the visible tray is absent, and `Running` is not a sufficient
restart postcondition by itself.

Because C2T2 failed after the restart call, it is not safe to infer whether the
visible singleton process was replaced. The cooperative storage hold was not
cleared, C: sources were not deleted, inspection tasks were not authorized to
change, and production routing remains disabled. Completed Lot was not probed
by this attempt because execution stopped at the task-state assertion.

Withdraw `REQ_C2T2`. The fresh successor must audit the exact tray process by
the pinned script and state-root command line, reject ambiguity, stop only that
exact tray process/task, start the pinned tray task, and prove one fresh stable
exact tray process plus the three Completed Lot launcher probes. It must not
touch processor, scribe, Insite, inspection, portal, or copy tasks. C2B remains
blocked until that matching signed terminal pass is collected.
