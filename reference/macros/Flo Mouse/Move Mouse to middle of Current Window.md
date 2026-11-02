# Move Mouse to middle of Current Window

- Group: Flo Mouse
- UID: C5D8D15D-1E1C-4989-8661-30C6EF54C50F
- Enabled: True
- Triggers: Opt+Shift+Cmd+M

## Actions

- MouseMoveAndClick: {"Action": "Move", "Button": 0, "ClickCount": 0, "DisplayMatches": false, "DragHorizontalPosition": "0", "DragVerticalPosition": "0", "Fuzz": 15, "HorizontalPositionExpression": "0", "Modifiers": 0, "MouseDrag": "To", "Relative": "Window", "RelativeCorner": "Center", "RestoreMouseLocation": false, "VerticalPositionExpression": "0"}
- ExecuteJavaScriptForAutomation
  ```javascript
  Application("VoiceOver").output("Mouse moved to center of current window.")
  ```
