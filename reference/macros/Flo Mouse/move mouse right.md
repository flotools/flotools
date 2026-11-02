# move mouse right

- Group: Flo Mouse
- UID: 1CF720B7-7E56-46BF-865B-ECAFBD023EED
- Enabled: True
- Triggers: Opt+Shift+Cmd+Right

## Actions

- MouseMoveAndClick: {"Action": "Move", "Button": 0, "ClickCount": 0, "DisplayMatches": false, "DragHorizontalPosition": "0", "DragVerticalPosition": "0", "Fuzz": 15, "HorizontalPositionExpression": "10", "IsDisclosed": false, "Modifiers": 0, "MouseDrag": "None", "Relative": "Mouse", "RelativeCorner": "TopLeft", "RestoreMouseLocation": true, "VerticalPositionExpression": "0"}
- ExecuteJavaScriptForAutomation
  ```javascript
  Application("VoiceOver").output("Right")
  ```
