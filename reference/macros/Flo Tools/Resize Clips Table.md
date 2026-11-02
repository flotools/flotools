# Resize Clips Table

- Group: Flo Tools
- UID: 1BDAA1BB-6545-416F-8706-7C9C6128FC8C
- Enabled: True
- Triggers: Ctrl+Shift+Cmd+C

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  kme = Application("Keyboard Maestro Engine")
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  edit = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  table = edit.tables.byName("Clips")
  position = table.position()
  size = table.size()
  x = position[0]
  y = position[1]
  w = size[0]
  h = size[1]
  x=x-1
  y = y-3
  kme.setvariable("x", {to:""+x})
  kme.setvariable("y", {to:""+y})
  vo.output("Clips table is "+w+" points wide. Click and drag to resize.")
  ```
- MouseMoveAndClick: {"Action": "Move", "Button": 0, "ClickCount": 0, "DisplayMatches": false, "DragHorizontalPosition": "0", "DragVerticalPosition": "0", "Fuzz": 15, "HorizontalPositionExpression": "x", "Modifiers": 0, "MouseDrag": "None", "Relative": "Absolute", "RelativeCorner": "TopLeft", "RestoreMouseLocation": false, "VerticalPositionExpression": "y"}
