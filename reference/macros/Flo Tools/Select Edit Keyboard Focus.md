# Select Edit Keyboard Focus

- Group: Flo Tools
- UID: B0B81561-D3AE-47C0-B9BF-F17DA4A63D7A
- Enabled: True
- Triggers: Opt+Cmd+1

## Actions

- SimulateKeystroke: Opt+Cmd+1
- IfThenElse (All):
  - if {"ConditionType": "FrontWindow", "FrontWindowConditionType": "TitleMatches", "FrontWindowTitle": "^Edit:", "IsFrontApplication": true}
  then:
    - ExecuteJavaScriptForAutomation
      ```javascript
      Application("VoiceOver").output("Edit Keyboard Focus")
      ```
