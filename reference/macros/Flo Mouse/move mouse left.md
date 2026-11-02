# move mouse left

- Group: Flo Mouse
- UID: 1A768AB9-BAE8-40D8-B636-9C74DC615B05
- Enabled: True
- Triggers: Opt+Shift+Cmd+Left

## Actions

- MouseMoveAndClick: {"Action": "Move", "Button": 0, "ClickCount": 0, "DisplayMatches": false, "DragHorizontalPosition": "0", "DragVerticalPosition": "0", "Fuzz": 15, "HorizontalPositionExpression": "-10", "IsDisclosed": false, "Modifiers": 0, "MouseDrag": "None", "Relative": "Mouse", "RelativeCorner": "TopLeft", "RestoreMouseLocation": true, "VerticalPositionExpression": "0"}
- ExecuteJavaScriptForAutomation
  ```javascript
  Application("VoiceOver").output("Left")
  ```
