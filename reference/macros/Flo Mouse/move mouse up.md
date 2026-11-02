# move mouse up

- Group: Flo Mouse
- UID: FD05B6A9-F846-4D25-8851-FB18997E6DD4
- Enabled: True
- Triggers: Opt+Shift+Cmd+Up

## Actions

- MouseMoveAndClick: {"Action": "Move", "Button": 0, "ClickCount": 0, "DisplayMatches": false, "DragHorizontalPosition": "0", "DragVerticalPosition": "0", "Fuzz": 15, "HorizontalPositionExpression": "0", "IsDisclosed": false, "Modifiers": 0, "MouseDrag": "None", "Relative": "Mouse", "RelativeCorner": "TopLeft", "RestoreMouseLocation": true, "VerticalPositionExpression": "-10"}
- ExecuteJavaScriptForAutomation
  ```javascript
  Application("VoiceOver").output("Up")
  ```
