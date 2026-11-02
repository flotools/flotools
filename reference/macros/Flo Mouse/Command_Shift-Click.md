# Command+Shift-Click

- Group: Flo Mouse
- UID: 0A87CF74-8359-4073-A6F2-FF3DDB0AA6FD
- Enabled: True
- Triggers: Shift+Cmd+`

## Actions

- SetVariableToText: command = '%ExecutingThisMacro%'
- ExecuteJavaScriptForAutomation
  ```javascript
  kme = Application("Keyboard Maestro Engine")
  vo = Application("VoiceOver")
  sys = Application("System Events")
  process = sys.processes.whose({frontmost:true})[0]
  window = process.windows[0]
  wPosition = window.position()
  wSize = window.size()
  
  tlx = wPosition[0]
  tly = wPosition[1]
  brx=tlx+wSize[0]
  bry=tly+wSize[1]
  
  x = kme.calculate("MOUSEX()")
  y = kme.calculate("MOUSEY()")
  command = kme.getvariable("command")
  if (x>tlx&x<brx&y>tly&y<bry) {
  vo.output(command)
  } else {
  vo.output("Object is outside the window, "+window.name())
  x=-1
  y=-1
  }
  
  kme.setvariable("x", {to:""+x})
  kme.setvariable("y", {to:""+y})
  ```
- MouseMoveAndClick: {"Action": "MoveAndClick", "Button": 0, "ClickCount": 1, "DisplayMatches": false, "DragHorizontalPosition": "0", "DragVerticalPosition": "0", "Fuzz": 15, "HorizontalPositionExpression": "x", "Modifiers": 768, "MouseDrag": "None", "Relative": "Absolute", "RelativeCorner": "TopLeft", "RestoreMouseLocation": false, "VerticalPositionExpression": "y"}
