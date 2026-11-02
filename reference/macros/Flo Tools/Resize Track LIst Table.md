# Resize Track LIst Table

- Group: Flo Tools
- UID: D46E6FCE-E517-4775-A4E3-30FBE17F4F9D
- Enabled: True
- Triggers: Ctrl+Shift+Cmd+T

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  kme = Application("Keyboard Maestro Engine")
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows[0]
  table = window.tables.byName("Track List")
  position = table.position()
  size = table.size()
  x = position[0]
  y = position[1]
  w = size[0]
  h = size[1]
  x=x+w+16
  y = y
  kme.setvariable("x", {to:""+x})
  kme.setvariable("y", {to:""+y})
  vo.output("Track list table is "+w+" points wide. Click and drag to resize.")
  ```
- MouseMoveAndClick: {"Action": "Move", "Button": 0, "ClickCount": 0, "DisplayMatches": false, "DragHorizontalPosition": "0", "DragVerticalPosition": "0", "Fuzz": 15, "HorizontalPositionExpression": "x", "Modifiers": 0, "MouseDrag": "None", "Relative": "Absolute", "RelativeCorner": "TopLeft", "RestoreMouseLocation": false, "VerticalPositionExpression": "y"}
