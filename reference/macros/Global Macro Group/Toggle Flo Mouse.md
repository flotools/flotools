# Toggle Flo Mouse

- Group: Global Macro Group
- UID: 0D1179E6-67B7-4B3F-AF22-8220E83AABA1
- Enabled: True
- Triggers: Cmd+/

## Actions

- IfThenElse (All):
  - if {"ConditionType": "Macro", "MacroConditionType": "IsEnabled", "MacroUID": "82EB8E84-2FE7-4AB2-BB2F-3680048B08C2"}
  then:
    - SetMacroEnable: {"Action": "Disable", "MacroUID": "82EB8E84-2FE7-4AB2-BB2F-3680048B08C2"}
    - ExecuteJavaScriptForAutomation
      ```javascript
      Application("VoiceOver").output("Mouse Off")
      ```
  else:
    - SetMacroEnable: {"Action": "Enable", "MacroUID": "82EB8E84-2FE7-4AB2-BB2F-3680048B08C2"}
    - ExecuteJavaScriptForAutomation
      ```javascript
      Application("VoiceOver").output("Mouse On")
      ```
