# SEMI M12 Scribe Validation Method

Status: deterministic review-only methodology resource  
Source standard: `SEMI M12-0998E SPECIFICATION FOR SERIAL ALPHANUMERIC MARKING (1).pdf`  
Local validator: `tools/Test-SemiM12Scribe.ps1`  
Regression vectors: `SEMI_M12_VERIFIED_TEST_VECTORS_20260730.csv`

## Purpose

Argos frontside scribe reading uses two independent evidence layers:

1. image-derived character recognition with a score for every candidate
   character at every position; and
2. SEMI M12 whole-string verification for a 12-character scribe.

The checksum is a deterministic validator and bounded reranking constraint.
It is not an OCR engine, an MES lookup, training, or permission to silently
replace an image-derived character.

## SEMI M12 calculation

For character `A_i`, assign:

```text
a_i = ASCII(A_i) - 32
```

The M12 character set has values from 0 through 58. For the current Argos
scribe profile, the observed strings use uppercase letters and digits.

Starting with `c_0 = 0`, update the checksum for each of the 12 positions:

```text
c_i = (8 * c_(i-1) + a_i) mod 59
```

A complete 12-character string is checksum-valid when:

```text
c_12 = 0
```

For an Argos identity decision, remainder zero is necessary but the observed
positions 11-12 must also equal the unique check pair generated from positions
1-10 by the rule below. This rejects a modulo-59 remainder alias that was not
generated as the canonical SEMI M12 check pair.

Positions 11 and 12 are the check characters. To generate them from the
first ten characters:

1. Append the assumed check characters `A0`.
2. Calculate the final checksum `r`.
3. If `r = 0`, the check characters are `A0`.
4. Otherwise calculate `q = 59 - r`.
5. Add the upper three bits of `q` to `A` for position 11.
6. Add the lower three bits of `q` to `0` for position 12.

The resulting check-character profile is `A` through `H` followed by `0`
through `7`.

## Built-in reading contract

The scribe reader must preserve these stages and fields:

1. Locate a notch-relative scribe crop.
2. If the expected crop fails, run a bounded exception search rather than
   declaring the scribe absent.
3. Preserve raw BF and DF crops and label every enhanced crop as
   detector-input or display-only.
4. Record the top candidate and score for every character independently.
5. Record a bounded list of alternate candidates and scores per character.
6. Assemble the independently highest-scoring 12-character string without
   changing it to satisfy the checksum.
7. Test that string with SEMI M12.
8. If it fails, search only the recorded near-scoring combinations for
   checksum-valid alternatives and retain their joint image scores.
9. Display the image-first string, per-character scores, checksum result,
   and any checksum-valid alternatives together.
10. Require human confirmation when the image-first string changes, more
    than one plausible checksum-valid string remains, MES conflicts, or the
    crop/segmentation is insufficient.

The checksum must never invent a character that was not supported by the
image candidate list. A checksum match is strong whole-string evidence, but
it is not sufficient by itself when the crop is damaged, obscured, poorly
localized, or nonstandard.

## Required decision states

Use explicit states instead of a generic OCR pass/fail:

- `SCRIBE_M12_CONFIRMED`: the independently highest-scoring image string is
  checksum-valid and all required image-confidence gates pass.
- `SCRIBE_M12_RERANKED_CONFIRMATION_REQUIRED`: the image-first string fails,
  but a near-scoring checksum-valid alternative exists.
- `SCRIBE_M12_AMBIGUOUS_MULTIPLE_VALID`: more than one plausible
  checksum-valid alternative remains.
- `SCRIBE_M12_CHECKSUM_FAILED`: no bounded image-supported combination
  passes.
- `SCRIBE_NONSTANDARD_FORMAT_HOLD`: the observed format is not eligible for
  the 12-character M12 method.
- `SCRIBE_LOCALIZATION_HOLD`: the scribe could not be localized with
  sufficient evidence.
- `SCRIBE_SEGMENTATION_HOLD`: twelve defensible character positions were not
  obtained.
- `SCRIBE_MES_CONFLICT_HOLD`: image/checksum evidence conflicts with MES,
  lot, slot, or other authoritative metadata.

No hold is an accepted wafer identity. Never silently use low-confidence OCR
for filenames, MES lookup, KLA retention, map alignment, or XML output.

## GUI review requirements

The eventual reviewer must show:

- the lossless-derived scribe crop;
- the independently highest-scoring string;
- the top candidates and scores for each of the 12 positions;
- observed and expected check characters;
- `M12 PASS`, `M12 FAIL`, or an explicit nonstandard/coverage hold;
- every bounded checksum-valid alternate and its image-score difference;
- MES/lot-slot agreement when available; and
- a human correction control that records the original read, correction,
  operator, timestamp, crop provenance, and checksum state.

Human confirmation may create an eligible scribe-character reference, but
training remains separately controlled. The current project-wide prohibition
means `TrainingAuthorized=0` and `TrainingExecuted=0`.

## Verified regression set

The 19 human-approved strings in
`SEMI_M12_VERIFIED_TEST_VECTORS_20260730.csv` all pass this calculation.
The correction from `8369N004FEC6` to `8365N004FEC6` is preserved as a
demonstration of the method: the former fails, while the corrected string
produces the observed `C6` check characters.

Any future implementation change must run the fixed vectors and report:

```text
Expected vectors: 19
Required passes: 19
Allowed failures: 0
```

New human-confirmed vectors may be appended with provenance. Existing
vectors must not be rewritten to manufacture a pass.
