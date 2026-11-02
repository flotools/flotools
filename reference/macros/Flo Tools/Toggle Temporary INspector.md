# Toggle Temporary INspector

- Group: Flo Tools
- UID: E63048EB-FBD0-41A9-A4C7-8922216F11D3
- Enabled: True
- Triggers: `; ` (released)

## Actions

- IfThenElse (All):
  - if {"ConditionType": "FrontWindow", "FrontWindowConditionType": "TitleMatches", "FrontWindowTitle": "^Mix:|Edit:", "IsFrontApplication": true}
  then:
    - IfThenElse (All):
      - if {"ConditionType": "Key", "KeyCode": 50, "KeyConditionType": "Down"}
      then:
        - MacroGroupToggle: {"DisplayToggle": false, "MacroGroupUID": "A873DB58-32B1-4730-B0D4-9C89056CB5F7", "ToggleMode": "Activate"}
      else:
        - MacroGroupToggle: {"DisplayToggle": false, "MacroGroupUID": "A873DB58-32B1-4730-B0D4-9C89056CB5F7", "ToggleMode": "Deactivate"}
  else:
    - SetMacroEnable: {"Action": "Disable", "MacroUID": "E63048EB-FBD0-41A9-A4C7-8922216F11D3"}
    - SimulateKeystroke: `
    - SetMacroEnable: {"Action": "Enable", "MacroUID": "E63048EB-FBD0-41A9-A4C7-8922216F11D3"}
