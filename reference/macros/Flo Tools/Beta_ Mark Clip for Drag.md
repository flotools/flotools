# Beta: Mark Clip for Drag

- Group: Flo Tools
- UID: B2507D35-5F04-4159-9594-05F6ED5A9077
- Enabled: True
- Triggers: Opt+Shift+Cmd+,

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  kme = Application("Keyboard Maestro Engine")
  vo = Application("VoiceOver")
  bounds = vo.voCursor.bounds()
  x = bounds["x"]
  y = bounds["y"]
  h=bounds["height"]
  y+=h/2
  kme.setvariable("point1", {to:x+","+y})
  Application("VoiceOver").output("Marked for drag.")
  ```
- MouseMoveAndClick: {"Action": "MoveAndClick", "Button": 0, "ClickCount": 1, "DisplayMatches": false, "DragHorizontalPosition": "296", "DragVerticalPosition": "362", "Fuzz": 15, "HorizontalPositionExpression": "point1.x", "Modifiers": 2048, "MouseDrag": "Hold", "Relative": "Absolute", "RelativeCorner": "TopLeft", "RestoreMouseLocation": false, "VerticalPositionExpression": "point1.y"}
- PauseUntil: {"Conditions": {"ConditionList": [{"ConditionType": "Modifiers", "ModifiersDown": 0, "ModifiersUp": 2816}], "ConditionListMatch": "All"}, "TimeOutAbortsMacro": true}
- MouseMoveAndClick: {"Action": "MoveAndClick", "Button": 0, "ClickCount": -1, "DisplayMatches": false, "DragHorizontalPosition": "296", "DragVerticalPosition": "362", "Fuzz": 15, "HorizontalPositionExpression": "point1.x", "Modifiers": 2048, "MouseDrag": "Hold", "Relative": "Absolute", "RelativeCorner": "TopLeft", "RestoreMouseLocation": false, "VerticalPositionExpression": "point1.y"}
