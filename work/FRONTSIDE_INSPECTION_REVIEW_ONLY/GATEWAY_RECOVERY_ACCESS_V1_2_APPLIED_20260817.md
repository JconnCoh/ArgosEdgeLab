# Gateway recovery and constrained access V1.2 applied

Date: 2026-08-17  
Revision: `GATEWAY_RESPONSE_PUBLICATION_REPAIR_AND_ACCESS_V1_2_APPLIED`  
Disposition: `RELEASED_REVIEW_ONLY`

The operator completed the single V1.2 gateway bootstrap on exact computer
`TXSH-DPMZ0295HR`. The persistent launcher log is
`C:\GWR12_LAUNCH\GWR12_20260817T192721411Z_b174a559.log`.

The constrained-access install reported
`PASS_ARGOS_GATEWAY_MAINTENANCE_ACCESS_INSTALLED`. Its result is
`C:\ProgramData\ArgosGatewayMaintenanceRO\audit\ACCESS_RESULT.json`, with
operator-reported SHA-256
`C9139E15F192E1325260D6BABC66A7D01321FB0366A2593B3892BBE807FEB2B4`.
The endpoint is `ArgosGatewayMaintenance`, permits only
`AMER\joshua.conn` from `10.66.0.0/16`, grants no general remote shell, and
changed no local Administrator membership.

The interrupted gateway response-publication repair reported
`PASS_GATEWAY_RESPONSE_PUBLICATION_REPAIR_V1_2`. Its result is
`C:\GWR\REPAIR_RESULT.json`, with operator-reported SHA-256
`DF88A64F446F15EA60AFE615C8D7AB66DD70C7DBE841F9E76D8F5F3A5ED131DE`.
Both the repair-process and exact scheduled-task-context alias write probes
passed. Only the bridge and share configuration changed; the response receiver
was not mutated.

An independent laptop-to-gateway Kerberos JEA connection then passed from this
workstation. The authenticated caller was `AMER\joshua.conn`; TCP 5985 was
reachable; exactly five Argos maintenance functions were visible; and zero
forbidden command leaks were found. Both portal gateway tasks were running.
The independently retrieved installed hashes were:

- bridge:
  `1C744925E4082E0D27CF8661830252EB5BDF49FF64FFCE16BD03BD85AD875FAA`;
- share configuration:
  `24102B5ABDB155D3BD2A44CA3A3215ED67353C68824370BB3447909171B939D9`;
- unchanged response-receiver configuration:
  `C2317E9C40FB51FDD24F3D765E60BFE2A6F9652C64AE5719FB5F2AFC379FFE5C`.

The one-time operator bootstrap is complete. The next action is a bounded
end-to-end response-publication route gate through the repaired gateway. The
41-file FM7P24A data pull remains unsigned until that gate passes.

No detector, alignment, composite, defect, Normal, mask, reviewer, XML,
training, or production authority changed.
