# Copy And Speak Mouse Absolute  Coordinates

- Group: Flo Mouse
- UID: FB50D089-B7A7-44BF-8E0B-D956D0CE8887
- Enabled: True
- Triggers: Opt+Shift+Cmd+A

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  kme = Application("Keyboard Maestro Engine")
  app = Application.currentApplication()
  app.includeStandardAdditions = true
  x = kme.calculate("MOUSEX()")
  y = kme.calculate("MOUSEY()")
  app.setTheClipboardTo(x+","+y)
  vo.output(x+", "+y)
  ```
