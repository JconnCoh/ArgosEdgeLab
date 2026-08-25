CDM1 - exact retired C: stage1 duplicate deletion

This one-shot package is authorized to delete only the 93,709 files and
232,912,232,897 logical bytes in these retired JBOD roots:

  C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\cache
  C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\metadata
  C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\dashboard_outputs

It does not delete the historical outputs root or any Windows/system path.

On the JBOD computer only:

1. Create the fresh folder D:\CDM1.
2. Extract every file from ARGOS_CDM1.zip into D:\CDM1.
3. Right-click D:\CDM1\RUN_CDM1.cmd and choose Run as administrator.
4. Leave the window open. Exact D: SHA-256 verification may take a long time.

The launcher first runs a non-mutating preflight. Deletion begins only after
the locked 93,709-row manifest, exact retired C: set and metadata, every D:
mirror SHA-256, exact D-path config, and healthy processor PID/creation time
all pass. It starts, stops, and restarts no task or process; installs nothing;
changes no queue or ledger; decodes no images; and performs no wafer, XML,
training, provider-activation, or production-routing action.

Run it once only. Do not run ARGOS_CDO1.zip, O2A2, or retry REQ_O2D4.
