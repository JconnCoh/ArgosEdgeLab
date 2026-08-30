# OCV-03 O3B10 R18 corpus 137 / nine fixture regressions inspected

Date: 2026-08-29

Disposition: `PENDING_GATE`

The single signed R18 worker at create-new `C15RUN3` reached a signed
file-backed `137/953`: 128 unique notches, nine multiple-pair holds, and zero
source problems. It remains active and untouched.

All nine holds are exact R15 pass-to-hold regressions. Signed `RESULT.json`
and BF/DF review images were collected and visually inspected for every case.
Every physical notch is the bottom candidate near 90 degrees with zero
exterior brightness in both channels. Every second candidate is visibly on a
chuck contact near 134 or 226 degrees. These are not pattern responses and the
cyan trace continues to follow the physical wafer perimeter.

The false-pair metrics form one symmetric image-local family:

- maximum exterior angular support: one channel `0.7292` to `1.0`, the other
  `0.4167` to `0.6042`;
- exterior bright fractions: both nonzero, false-pair minima approximately
  `0.102` for the seven newer cases and `0.182` / `0.233` in the initial two;
- the real-notch pair has zero exterior bright fraction and zero exterior
  angular support in every inspected case.

The R18 both-channel `0.70` support requirement is therefore too strict for
partially illuminated fixture contacts. No detector/config change is permitted
until the current corpus is terminal and the complete regression/hold set is
known.

Latest signed summary:

- request: `REQ_20260829T200010357Z_7E11F84D197C`
- response: `R_B4EC94A9446A_20260829200037271_5266004b`
- response ZIP SHA-256: `A3A251909283D72615C44BC75DF8E644323223EFEF5BA4049B66BB681D78A871`
- summary SHA-256: `A0352A2D91C59074693A33CC3E6D0804F16125055838E3486188BE0D3972B0E6`

The next action is to continue the same worker through signed file-backed
summaries, compare every terminal identity to R15, inspect every new regression
and remaining hold, and only then freeze the smallest symmetric fixture-context
correction. Do not query/manage/retry/relaunch the worker or alter completed
roots, source bytes, tasks, processes, providers, thresholds, holds, XML,
training, or production state.
