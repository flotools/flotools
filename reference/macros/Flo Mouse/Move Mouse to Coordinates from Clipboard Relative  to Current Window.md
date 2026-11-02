# Move Mouse to Coordinates from Clipboard Relative  to Current Window

- Group: Flo Mouse
- UID: 9A3CDDA9-C5E6-4846-8ED6-BB2B4AA3C4C5
- Enabled: True
- Triggers: Ctrl+Shift+Cmd+C

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
  left = wPosition[0]
  top = wPosition[1]
  coordinates = app.theClipboard()
  coordinates = coordinates.split(/,/)
  x = parseInt(coordinates[0])+left
  y = parseInt(coordinates[1])+top
  kme.setvariable("x", {to:""+x})
  kme.setvariable("y", {to:""+y})
  ```
- Pause: {"Time": "0.1", "TimeOutAbortsMacro": true}
- MouseMoveAndClick: {"Action": "Move", "Button": 0, "ClickCount": 0, "DisplayMatches": false, "DragHorizontalPosition": "0", "DragVerticalPosition": "0", "Fuzz": 15, "HorizontalPositionExpression": "x", "Modifiers": 0, "MouseDrag": "To", "Relative": "Absolute", "RelativeCorner": "TopLeft", "RestoreMouseLocation": false, "VerticalPositionExpression": "y"}
