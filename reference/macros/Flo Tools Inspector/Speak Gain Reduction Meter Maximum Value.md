# Speak Gain Reduction Meter Maximum Value

- Group: Flo Tools Inspector
- UID: 7EC8653F-24A2-43FE-B45B-C9D3C5C77044
- Enabled: True
- Triggers: Shift+;

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  kme = Application("Keyboard Maestro Engine")
  max = kme.getvariable("FTGRMax")
  vo.output(max)
  kme.setvariable("FTGRMax", {to:"0"})
  ```
