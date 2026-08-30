# OCV-03 O3B10 R18 corpus complete / R19 actual-wafer regression ready

Date: 2026-08-29

Disposition: `PENDING_GATE`

The single signed R18 full-backside-corpus worker reached a terminal signed
file-backed result at create-new `D:/KLARFExport/_ArgosReview/C15RUN3` without
runtime or process observation. The corpus contains exactly 953 paired
backside inspections: 908 unique-notch passes, 23 multiple-pair holds, 21
not-found holds, one channel-analysis-failed hold, and zero source problems.

The terminal summary was returned by request
`REQ_20260829T211542362Z_13FB6416463C`, response
`R_CCDD88E534A2_20260829211612993_f3ebc4d1`, response ZIP SHA-256
`3404465A8515D33BF510B16F6742DE4841061A0AC2962E1117D66D5B49AF00E2`,
and summary SHA-256
`4E89774912D68C439225C412D5986F769A34F44BAE6D98E68FB21701F5E8B5BD`.
The exact terminal results and remaining evidence were returned by request
`REQ_20260829T212003368Z_23F143F3FF5A`, response
`R_42F0649F6B63_20260829212041230_7b17b293`, response ZIP SHA-256
`550C9992BBA0303744479DE0898625235CC8EF67B15F94257EE683C603485292`.
`RESULTS.csv` SHA-256 is
`6DC96A70DAB8EFA6D25208E2192F648168B90EDBF519F4B3BAC76FCE9099847A`.

Mechanical comparison of the complete identical 953-identity R15 and R18
sets proves 875 unchanged passes, 33 rescued wafers, 23 regressions, 22
unchanged holds, and zero changed-hold states. All 875 shared-pass notch angles
are byte-numerically unchanged at zero circular angular delta. Every one of
the 23 regressions is `HOLD_BACK_NOTCH_MULTIPLE_BF_DF_MATCHES`.

Exact BF/DF overlays and `RESULT.json` records were visually inspected for all
23 regressions and all 22 unchanged holds. Every regression contains the
physical notch plus one chuck-contact response; none is a pattern, chipout,
hotspot, or perimeter-fit failure. The 21 not-found holds genuinely lack one
unique cross-channel notch, and the one channel-analysis failure is an
abnormal full-metal BF/DF pair. No hold has been cleared.

Across the complete 23-case chuck-contact family, the false response has
paired exterior bright fractions of at least `0.09267241379310345`, one
channel angular support of at least `0.7291666666666666`, and the other channel
support of at least `0.2916666666666667`. Every corresponding physical-notch
candidate has zero exterior brightness and support in both channels.

R19 is a fresh local draft over frozen R18. It changes only the paired
fixture-contact decision: both channels must carry exterior brightness, one
channel must have primary sustained angular support, and the other must have
secondary sustained support. It consumes no lot, wafer, slot, side, angle, or
known notch-position prior. Static replay over all collected candidate records
classifies exactly 23 chuck-contact rows and retains all 24 physical-notch
rows; a lone candidate is never suppressed.

- R19 detector:
  `work/OPENCV_BACKSIDE_NOTCH_O3B10/Detect-BacksideNotchOpenCvR19.py`,
  SHA-256 `FD6ED2A8C52584490EAEBA6836581A15BAD9479732746039F14E4C175A9004B8`
- R7 config:
  `work/OPENCV_BACKSIDE_NOTCH_O3B10/BACKSIDE_NOTCH_CONFIG_R7.json`,
  SHA-256 `9C40E9FE99735B8E49BC3713204E0A301A82D68D3A80EEA37894F66EB284DE03`
- regression runner SHA-256:
  `6582B7ABB517F976CFC6D0E91963473D7F9E360975E4480D23AB9D426663728A`
- clone gate SHA-256:
  `1B751D635AE0EF42C3263004133C4B6C9A714A3C29750A84DC4AED353592F3DD`
- zero-recurrence preaction: `PASS_ARGOS_ZERO_RECURRENCE_PREACTION`

Next: publish one signed no-retry R19 ten-wafer actual-image regression using
the existing chipout, damage, split-channel, broad-channel, patterned, and
BowComp controls. Require its matching signed terminal response and inspect
the returned overlays. Only after that pass may one fresh R19 full 953-pair
backside corpus run at a create-new JBOD `D:` output root. Do not touch the
protected processor, any existing task/process, completed roots, source
images, holds, XML, training, or production state.
