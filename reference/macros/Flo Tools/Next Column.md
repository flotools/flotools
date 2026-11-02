# Next Column

- Group: Flo Tools
- UID: E8AB3E42-E437-4636-BE59-3B8EE83E0812
- Enabled: True
- Triggers: Opt+Shift+]

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  kme = Application("Keyboard Maestro Engine")
  c = kme.getvariable("FTEventIndex")
  if (c!=5) {
  c++
  if (c>5) c=5
  kme.setvariable("FTEventIndex", {to:""+c})
  kme.doScript("0FCAC0B8-1482-4A8F-A388-280908A39AE6")
  } else Application("VoiceOver").output("End")
  ```
