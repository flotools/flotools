# Previous Column

- Group: Flo Tools
- UID: 9725F627-F2C9-4CC4-8244-771E5793A8A8
- Enabled: True
- Triggers: Opt+Shift+[

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  kme = Application("Keyboard Maestro Engine")
  c = kme.getvariable("FTEventIndex")
  if (c!=-1) {
  c--
  if (c<-1) c = -1
  kme.setvariable("FTEventIndex", {to:""+c})
  if (c== -1) Application("VoiceOver").output("No report")
  else kme.doScript("0FCAC0B8-1482-4A8F-A388-280908A39AE6")
  } else Application("VoiceOver").output("No report")
  ```
