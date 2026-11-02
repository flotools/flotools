# Select Clips Keyboard Focus

- Group: Flo Tools
- UID: DBDE27F3-52D3-4E14-B6A6-596831F0261E
- Enabled: True
- Triggers: Opt+Cmd+2

## Actions

- SimulateKeystroke: Opt+Cmd+2
- IfThenElse (All):
  - if {"ConditionType": "FrontWindow", "FrontWindowConditionType": "TitleMatches", "FrontWindowTitle": "^Edit:", "IsFrontApplication": true}
  then:
    - ExecuteJavaScriptForAutomation
      ```javascript
      Application("VoiceOver").output("Clips Keyboard Focus")
      ```
