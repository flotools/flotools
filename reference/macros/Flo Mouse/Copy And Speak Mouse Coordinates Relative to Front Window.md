# Copy And Speak Mouse Coordinates Relative to Front Window

- Group: Flo Mouse
- UID: 8984B1F4-C9FA-4E27-AFEF-A316BD2EE0D1
- Enabled: True
- Triggers: Opt+Shift+Cmd+C

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  kme = Application("Keyboard Maestro Engine")
  app = Application.currentApplication()
  app.includeStandardAdditions = true
  sys = Application("System Events")
  process = sys.processes.whose({frontmost:true})[0]
  window = process.windows[0]
  wPosition = window.position()
  
  //left = kme.calculate("WINDOW(1,Left)")
  //top = kme.calculate("WINDOW(1,top)")
  
  left = wPosition[0]
  top = wPosition[1]
  
  x = kme.calculate("MOUSEX()")
  y = kme.calculate("MOUSEY()")
  
  wx = x-left
  wy = y-top
  
  app.setTheClipboardTo(wx+","+wy)
  vo.output(wx+", "+wy)
  ```
