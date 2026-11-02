# Previous track view on selected tracks

- Group: Flo Tools
- UID: 1FF40247-C860-471D-BACC-DFB16C9A65A1
- Enabled: False
- Triggers: Ctrl+Cmd+Left

## Actions

- IfThenElse (All):
  - if {"ConditionType": "Macro", "MacroConditionType": "IsInactive", "MacroUID": "A873DB58-32B1-4730-B0D4-9C89056CB5F7"}
  then:
    - SimulateKeystroke: Ctrl+Cmd+Left
    - ExecuteJavaScriptForAutomation
      ```javascript
      Application("VoiceOver").output("Previous track view on selected tracks.")
      ```
  else:
    - ExecuteMacro: {"Asynchronously": false, "MacroUID": "9C149078-8675-401D-9CD7-E1457E482328", "TimeOutAbortsMacro": true, "UseParameter": false}
