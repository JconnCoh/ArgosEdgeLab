ARGOS JEO1 — JBOD read-only evidence observation

This fresh package replaces neither CDM1 nor O2A2. Do not run either of those
packages again. JEO1 performs no deletion, install, task/process action, queue
or ledger mutation, source/image read, wafer action, or provider activation.

On the JBOD computer only:

1. Extract ARGOS_JEO1.zip to a fresh short D:\JEO1 folder.
2. Right-click D:\JEO1\RUN_JEO1.cmd and choose Run as administrator.
3. Leave the window visible until it reports completion or a failed-closed
   error. Do not run it a second time.

The launcher writes its persistent log to D:\A2\x\JEO1_LAUNCH.log. Evidence
stays under D:\A2\x\JEO1 and D:\A2\x\JEO1R_LOCAL.zip. On success it also
returns JEO1R.zip to InspectionRevs. The package reads only bounded metadata,
approved text/signature evidence, and the exact CDM1 result ZIP if present.
It never reads image bytes.
