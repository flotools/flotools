# Load Plugin Parameters for Default View

- Group: Flo Tools
- UID: 9E527A76-E233-41E9-9B66-A17747F42646
- Enabled: True
- Triggers: focused window: FocussedWindowChanges

## Actions

- IfThenElse (All):
  - if {"ConditionType": "FrontWindow", "FrontWindowConditionType": "TitleMatches", "FrontWindowTitle": "^Plug-in:", "IsFrontApplication": true}
  then:
    - ExecuteMacro: {"Asynchronously": false, "MacroUID": "703E2B8E-556F-4BBF-95B5-C447F55F1968", "TimeOutAbortsMacro": true, "UseParameter": false}
