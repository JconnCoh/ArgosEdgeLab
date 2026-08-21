# Codex Keep Awake

Double-click `Run-KeepCodexAwake.cmd` to start. Keep the console window open
while Codex is working. Press `Ctrl+C` or close the window to stop.

By default, the utility sends an unassigned `F15` key pulse every four minutes
and asks Windows to keep the display and system awake. It does not type text,
move the pointer, modify Argos files, or run any Argos inspection workflow.

To use a different interval, open a Command Prompt in this folder and run:

```bat
Run-KeepCodexAwake.cmd -IntervalSeconds 120
```

The interval must be between 15 and 3600 seconds. The utility only works in an
interactive Windows desktop session. It cannot unlock a locked computer and
does not bypass a forced restart, a lost network connection, or a Codex task
limit unrelated to Windows idle/sleep.
