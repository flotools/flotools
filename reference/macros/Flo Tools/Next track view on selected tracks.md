# Next track view on selected tracks

- Group: Flo Tools
- UID: C035969D-E50C-4671-AFBA-CFF648FD3A48
- Enabled: False
- Triggers: Ctrl+Cmd+Right

## Actions

- IfThenElse (All):
  - if {"ConditionType": "Macro", "MacroConditionType": "IsInactive", "MacroUID": "A873DB58-32B1-4730-B0D4-9C89056CB5F7"}
  then:
    - SimulateKeystroke: Ctrl+Cmd+Right
    - ExecuteJavaScriptForAutomation
      ```javascript
      Application("VoiceOver").output("Next track view on selected tracks.")
      ```
  else:
    - ExecuteMacro: {"Asynchronously": false, "MacroUID": "38AC5CB1-9C5F-4973-B8D1-20259CF38989", "TimeOutAbortsMacro": true, "UseParameter": false}
