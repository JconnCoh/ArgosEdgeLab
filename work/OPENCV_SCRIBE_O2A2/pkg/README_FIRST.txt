ARGOS O2D4 DIRECT ADMIN READ-ONLY OBSERVATION - O2A2

Purpose: collect the exact current O2D4 endpoint, ledger, response-return,
D-drive work/output, X: alias, and portal task/process evidence without changing
JBOD state or reading image bytes.

1. Extract this ZIP to a short fresh local folder on the JBOD computer.
2. Right-click RUN_O2A2.cmd and choose Run as administrator.
3. The launcher verifies the exact package and runs a non-mutating preflight.
4. After PASS it performs one read-only observation, writes evidence only under
   C:\O2A2, and returns O2A2R.zip to InspectionRevs automatically.
5. Leave the final window visible. If the return share is unavailable, retain
   O2A2R_LOCAL.zip beside the launcher and report the displayed failure.

O2A2 installs nothing; starts, stops, or restarts no task or process; changes no
queue or ledger; reads no image bytes; and performs no source or wafer action.
Review-only. Production routing remains disabled.

