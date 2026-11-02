# move mouse down

- Group: Flo Mouse
- UID: 748E416B-8D0B-486A-983D-D727E9BEA2FB
- Enabled: True
- Triggers: Opt+Shift+Cmd+Down

## Actions

- MouseMoveAndClick: {"Action": "Move", "Button": 0, "ClickCount": 0, "DisplayMatches": false, "DragHorizontalPosition": "0", "DragVerticalPosition": "0", "Fuzz": 15, "HorizontalPositionExpression": "0", "Modifiers": 0, "MouseDrag": "None", "Relative": "Mouse", "RelativeCorner": "TopLeft", "RestoreMouseLocation": true, "VerticalPositionExpression": "10"}
- ExecuteJavaScriptForAutomation
  ```javascript
  Application("VoiceOver").output("Down")
  ```
