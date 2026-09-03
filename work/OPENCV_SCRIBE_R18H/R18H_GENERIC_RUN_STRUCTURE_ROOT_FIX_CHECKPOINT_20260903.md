# R18H generic run-structure root-fix checkpoint — 2026-09-03

Revision class: `DIAGNOSTIC_ONLY`

## Outcome

R18H corrects the Slot08 position-5 `T`/`7` failure image-first.  The result is
`1478T161SUG7`; checksum does not select or rewrite the glyph.

This is not a character-pair exception.  The correction applies the same rule
to every allowed body label:

1. retain frozen R18F appearance ranking and high-confidence topology override;
2. when the two best appearance labels are separated by no more than `0.02`,
   compare generic foreground branch/run structure to each label's median
   reference consensus;
3. permit the consensus winner only when it is one of those same two appearance
   labels and its structural-distance margin is at least `0.20`;
4. preserve the selected label's appearance score, so this rule cannot raise a
   blank or texture grid above the existing presence threshold.

The root cause was unrestricted best-single-exemplar dominance in sparse and
visually similar classes.  A favorable `7` exemplar narrowly beat `T` in
appearance even though the target has the horizontal branches and centered
stem of `T`.  Spatially ordered run structure retains that distinction; an
averaged foreground profile or width-sorted runs do not.

## Exact local artifacts

- `ArgosOpenCvScribeV1R18H.py`
  - SHA-256 `3AF68D778E297531DD527DD9D65C75FD17BD1FB9C2EC797CB840B10A674532AD`
- `Test-R18H.py`
  - SHA-256 `CB4090C4AAFB6BAA0D3E8B8716AB61FF5D411287889FC10A9D1561ECACCDFFB0`
- `R18H_FAST_GATE.json`
  - SHA-256 `33719DE1119BC87906B6BD0501B8F2A1A4462F1F111915C4E245B7BF789E4508`

Frozen predecessor R18F remains byte-for-byte unchanged:

- `ArgosOpenCvScribeV1R18F.py`
  - SHA-256 `0E2CD994BB389F1DB5A50FCB2C5C9D0DD6C906925E206C913CB0FCEC1B1543B1`

## Gate evidence

- 465 reference glyphs evaluated leave-one-physical-identity-out.
- R18F correct: 387.
- R18H correct: 387.
- R18H changes: 0.
- Previously correct references harmed: 0.
- Nine established frozen-grid visible regressions: 9 exact.
- Three R18G visible development cases: 3 exact.
- Slot08 position 5:
  - appearance first: `7`
  - structural consensus first: `T`
  - appearance gap: `0.008080854872381416`
  - structural consensus margin: `0.21965487504819514`
  - image-first final string: `1478T161SUG7`
- Python bytecode compilation passed.
- `git diff --check` passed.

The established blank holds are preserved by a score-nonincreasing invariant:
the new rule either keeps the current winner or chooses only the other
appearance-top-two label while retaining that label's lower appearance score.
The existing high-confidence topology path is not overridden.

## Authority boundary

No blind R18G acquisition was opened.  No JBOD, task, process, queue, portal,
production, activation, identity-acceptance, automatic-reference-admission,
XML, or training action was performed.  R18H is a local review-only diagnostic
provider and has not been published or activated.
