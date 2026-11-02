# Select Groups Keyboard Focus

- Group: Flo Tools
- UID: 2C851642-5FEA-49DD-9532-B8EAC403D111
- Enabled: True
- Triggers: Opt+Cmd+3

## Actions

- SimulateKeystroke: Opt+Cmd+3
- IfThenElse (All):
  - if {"ConditionType": "FrontWindow", "FrontWindowConditionType": "TitleMatches", "FrontWindowTitle": "^Edit:", "IsFrontApplication": true}
  then:
    - ExecuteJavaScriptForAutomation
      ```javascript
      Application("VoiceOver").output("Groups Keyboard Focus")
      ```
