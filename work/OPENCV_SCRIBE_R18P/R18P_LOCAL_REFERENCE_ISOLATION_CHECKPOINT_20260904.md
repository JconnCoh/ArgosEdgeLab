# R18P Local Reference-Isolation Checkpoint — 2026-09-04

State: `PENDING_GATE`  
Authority: review-only local correction; not signed, packaged, published, or executed on JBOD.

## Scope and predecessor disposition

R18O is withdrawn as an OCR-validity experiment. Its exact-string leave-one-identity-out filter allowed references from aliases of the same physical lot/slot lineage, including an exact source-byte match in the supplemental bank. Correct-looking R18O output is diagnostic only and cannot establish OCR generalization. The published R18O runner remains byte-for-byte unchanged at SHA-256 `ABEBC2F85DAFC0E4F74CABD7E1CF6E929E30BE188B3C12972342B586223DCE6F`.

The operator reported the R18O run stopped. This local correction did not inspect or alter that process, its queue, its response root, JBOD, or any source/crop image bytes.

## R18P correction

`Run-R18PReferenceIsolatedCorpus.py`:

- canonicalizes a configured physical identity to a generic lot/product-and-slot lineage without embedding a production lot, product, slot, scribe truth, or Windows root;
- removes that lineage from all aligned appearance, topology, and structure reference banks before OCR;
- additionally removes supplemental references whose `sourceSha256` equals either configured BF/DF crop hash;
- validates configured BF/DF hashes before decoding each crop;
- obtains its exact bounded cohort only from configuration;
- treats `expectedTruth` as post-selection verify-only evidence;
- contains no full-wafer discovery, crop-location, or fallback job code; and
- preserves review-only authority with `identityAccepted=false`.

## Frozen local artifacts

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| `work/OPENCV_SCRIBE_R18P/Run-R18PReferenceIsolatedCorpus.py` | 22040 | `5B6AA224E844FCEA22DEC6A9D10C863437F039CA73EC258C263DF539905791D0` |
| `work/OPENCV_SCRIBE_R18P/Test-R18PReferenceIsolation.py` | 7831 | `7814316E929BC1B1390857461708FEA1589F725A0FF6EC47A68DF7F398B6DEAC` |
| `work/OPENCV_SCRIBE_R18P/R18P_REVIEW_COHORT.json` | 6875 | `62A5E864C174A6E2C7F368E784E8DD0F86A11828036401351B2FCBB6336A2661` |
| `work/OPENCV_SCRIBE_R18P/R18P_REFERENCE_ISOLATION_LOCAL_GATE.json` | 2358 | `5176CA629E8EA181CDDC72EAA403D7EF61C008E8380E9AE6CBB9F63700BDD81D` |
| `work/OPENCV_SCRIBE_R18P/R18P_COHORT_BINDING_GATE.json` | 484 | `5D522211612C03C617156FC10550C15BCA84B7476E68544E5512FC9B20B0227C` |

Frozen dependencies remain:

- R18H reader `3AF68D778E297531DD527DD9D65C75FD17BD1FB9C2EC797CB840B10A674532AD`;
- R18J crop sweep `EF4C58589CA8885B5CBDE0A989D3F94EE8C447925818DC0FA4E50B26B87A8B9F`;
- base reference ZIP `56DF00E37A195E7BC3E026E4950DFB5A0AA7E7AF49A6FF39020B071840CCFBD6` and its embedded manifest `AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229`;
- supplemental reference manifest `FD60D494A25B489A8F1D8581217457AD67B02C98D54CA0A5400FAC0611537114`.

## Mandatory pre-submission gates

Before any R18P package may be built or signed, the exact executable local gate must pass over the R18P runner and both executed frozen Python dependencies with their SHA-256 pins. It mechanically requires:

1. zero production-shaped lot/product, slot, or Windows-root literals in engine sources;
2. zero configured physical-identity or known-truth string values in engine sources;
3. exact engine, base-bundle, embedded-base-manifest, and supplemental-manifest hashes;
4. exactly 20 configured cases, 20 unique BF/DF source-hash pairs, and no duplicate physical identities;
5. zero same-lineage reference survivors for every configured case;
6. both known-truth controls to exclude at least one reference identity; and
7. alias-invariant and source-hash exclusion self-tests.

Latest execution state is `PASS_R18P_REFERENCE_ISOLATION_LOCAL_GATE`: three engine sources scanned, zero engine hash mismatches, zero hard-coded engine literals, zero configuration-literal leaks, zero same-lineage survivors, and minimum two excluded reference identities for each known-truth control. No image bytes were read.

Any future builder must invoke this exact test, pin the resulting gate and all engine hashes, and fail before package construction on any mismatch. Any future publisher must require the separate exact final-package, path, harness, pre-action, and publication gates. A mechanically cloned R18O builder is forbidden; the unexecuted draft clone was removed because it retained 54 predecessor namespace literals.

## Authority and next action

R18P has no request ID, package, signature, publication authority, publisher, output root, or external execution. Identity acceptance, automatic reference admission, hold clearance, training, activation, XML, production routing, source mutation/deletion, and retry remain unauthorized.

The next action is local package construction in a fresh R18P namespace after applying the complete Windows, path-budget, PowerShell harness, clone-remediation, zero-recurrence, and Project Portal round-trip gates. Publication requires a fresh operator message containing the literal word `PUBLISH`; there will be no retry.
