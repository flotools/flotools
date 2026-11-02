# Cleanup Variables

- Group: Flo Tools Global
- UID: 4285E9A2-24B6-4A7C-B65F-E0295B60D3B9
- Enabled: True
- Triggers: none

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  kme = Application("Keyboard Maestro Engine")
  kme.setvariable("command", {to:"%Delete%"})
  kme.setvariable("FTTimeout", {to:"%Delete%"})
  kme.setvariable("FTUrl", {to:"%Delete%"})
  kme.setvariable("FTPrompt", {to:"%Delete%"})
  kme.setvariable("FTPreference", {to:"%Delete%"})
  kme.setvariable("point2", {to:"%Delete%"})
  kme.setvariable("point1", {to:"%Delete%"})
  kme.setvariable("x", {to:"%Delete%"})
  kme.setvariable("y", {to:"%Delete%"})
  kme.setvariable("FTGRMonitor", {to:"%Delete%"})
  kme.setvariable("FTGRMax", {to:"%Delete%"})
  kme.setvariable("FTLevelMonitor", {to:"%Delete%"})
  kme.setvariable("FTEventIndex", {to:"%Delete%"})
  kme.setvariable("FTPluginMonitor", {to:"%Delete%"})
  kme.setvariable("FTPluginControlIndex", {to:"%Delete%"})
  kme.setvariable("FTPluginControlParameters", {to:"%Delete%"})
  ```
