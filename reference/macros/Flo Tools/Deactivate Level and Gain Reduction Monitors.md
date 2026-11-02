# Deactivate Level and Gain Reduction Monitors

- Group: Flo Tools
- UID: 4C259C70-2924-4F17-AA74-C35B6FD8F556
- Enabled: True
- Triggers: FocussedWindow {"ChangeType": "FocussedWindowTitleChanges"}

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  kme = Application("Keyboard Maestro Engine")
  kme.setvariable("FTGRMonitor", {to:"%Delete%"})
  kme.setvariable("FTLevelMonitor", {to:"%Delete%"})
  ```
