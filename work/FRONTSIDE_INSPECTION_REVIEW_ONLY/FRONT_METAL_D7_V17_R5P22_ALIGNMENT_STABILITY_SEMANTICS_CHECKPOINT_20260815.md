# Front-metal D7 V17 R5P22 alignment-stability semantics checkpoint

Date: 2026-08-15  
Revision: `FM7V17R5P22`  
Parent: `FM7V17R5P21_JBOD_RESULT`  
Disposition: `LOCKED_INPUT`

The exact R5P21 return is exposed and may be used only for this review-only
gate-semantics correction. It cannot support an independent transfer claim.
The frozen machine-readable contract is
`work/FM7P21/result/R5P22_ALIGNMENT_STABILITY_CONTRACT.json`, 1529 bytes,
SHA-256
`DBB7220752DDF26C1E76E922F5068F7E5B1D00269241E9C0780E2534E770AB27`.

R5P22 preserves the target-first site selection, all local identity and
six-edge line-quality thresholds, deterministic direct-site consensus, and
independent BF/DF transforms. It does not rescore pixels, change a transform,
select a site from peer outcomes, remove an observation by final residual
rank, or apply the five-edge fallback.

A wafer's alignment stability requires, independently in each channel:

- at least six direct consensus sites;
- at least three wafer quadrants;
- rigid RMS no greater than 1.25 px;
- maximum leave-one-site whole-wafer/control mapping change no greater than
  0.35 px.

The independently solved BF and DF transforms must also disagree by no more
than 0.35 px at the wafer center and every ten degrees around 95% radius.

Selected-site fraction and the final-refit maximum single-site residual remain
reported as local evidence diagnostics. They are not independent wafer-level
pose holds after the retained distributed global stability gates pass. This
does not relabel a failed local observation as passing and does not erase it.

The deterministic implementation must prove that deficient count, deficient
quadrants, excessive RMS, excessive leave-one sensitivity, and excessive
BF/DF mapping disagreement each remain fail-closed. Any R5P22 pass remains
review-only and training-, XML-, and production-ineligible; later independent
transfer evidence is required.
