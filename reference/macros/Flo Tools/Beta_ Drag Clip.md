# Beta: Drag Clip

- Group: Flo Tools
- UID: B3E2505A-C8C5-48EF-9E76-2500CBA36AB7
- Enabled: True
- Triggers: Opt+Shift+Cmd+.

## Actions

- PauseUntil: {"Conditions": {"ConditionList": [{"ConditionType": "Modifiers", "ModifiersDown": 0, "ModifiersUp": 2816}], "ConditionListMatch": "All"}, "TimeOutAbortsMacro": true}
- ExecuteJavaScriptForAutomation
  ```javascript
  kme = Application("Keyboard Maestro Engine")
  kme.playSound(Path("/System/Library/Sounds/Tink.aiff"))
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  edit = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  track = edit.groups.byName(vo.voCursor.textUnderCursor())
  position = track.position()
  size = track.size()
  x = position[0]
  y = position[1]
  w = size[0]
  h= size[1]
  kme.setvariable("point2", {to:x+","+y+","+w+","+h})
  ```
- MouseMoveAndClick: {"Action": "MoveAndClick", "Button": 0, "ClickCount": 1, "DisplayMatches": false, "DragHorizontalPosition": "296", "DragVerticalPosition": "362", "Fuzz": 15, "HorizontalPositionExpression": "point1.x", "Modifiers": 4096, "MouseDrag": "None", "Relative": "Absolute", "RelativeCorner": "TopLeft", "RestoreMouseLocation": false, "VerticalPositionExpression": "point1.y"}
- MouseMoveAndClick: {"Action": "MoveAndClick", "Button": 0, "ClickCount": 1, "DisplayMatches": false, "DragHorizontalPosition": "point2.x+point2.width", "DragVerticalPosition": "point2.y+point2.height/2", "Fuzz": 15, "HorizontalPositionExpression": "point1.x", "Modifiers": 4096, "MouseDrag": "Absolute", "Relative": "Absolute", "RelativeCorner": "TopLeft", "RestoreMouseLocation": false, "VerticalPositionExpression": "point1.y"}
- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  edit = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  start = edit.groups.byName("Counter Display Cluster").textFields.byName("Edit Selection Start").value()
  end = edit.groups.byName("Counter Display Cluster").textFields.byName("Edit Selection End").value()
  if (start == end) vo.output("Failed dragging.")
  else vo.output("Finished dragging")
  ```
