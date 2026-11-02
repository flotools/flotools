# Toggle Inspector

- Group: Flo Tools
- UID: 8F157FEB-069E-465B-9AA5-92C4A59D23C4
- Enabled: True
- Triggers: /

## Actions

- IfThenElse (All):
  - if {"ConditionType": "FrontWindow", "FrontWindowConditionType": "TitleMatches", "FrontWindowTitle": "^Mix:|Edit:", "IsFrontApplication": true}
  then:
    - IfThenElse (All):
      - if {"ConditionType": "Macro", "MacroConditionType": "IsActive", "MacroUID": "A873DB58-32B1-4730-B0D4-9C89056CB5F7"}
      then:
        - MacroGroupToggle: {"DisplayToggle": false, "MacroGroupUID": "A873DB58-32B1-4730-B0D4-9C89056CB5F7", "ToggleMode": "Deactivate"}
        - SetMacroEnable: {"Action": "Enable", "MacroUID": "C035969D-E50C-4671-AFBA-CFF648FD3A48"}
        - SetMacroEnable: {"Action": "Enable", "MacroUID": "1FF40247-C860-471D-BACC-DFB16C9A65A1"}
        - ExecuteJavaScriptForAutomation
          ```javascript
          Application("VoiceOver").output("Inspector Off")
          ```
      else:
        - MacroGroupToggle: {"DisplayToggle": false, "MacroGroupUID": "A873DB58-32B1-4730-B0D4-9C89056CB5F7", "ToggleMode": "Activate"}
        - SetMacroEnable: {"Action": "Disable", "MacroUID": "C035969D-E50C-4671-AFBA-CFF648FD3A48"}
        - SetMacroEnable: {"Action": "Disable", "MacroUID": "1FF40247-C860-471D-BACC-DFB16C9A65A1"}
        - ExecuteJavaScriptForAutomation
          ```javascript
          Application("VoiceOver").output("Inspector On")
          ```
  else:
    - SetMacroEnable: {"Action": "Disable", "MacroUID": "8F157FEB-069E-465B-9AA5-92C4A59D23C4"}
    - SimulateKeystroke: /
    - SetMacroEnable: {"Action": "Enable", "MacroUID": "8F157FEB-069E-465B-9AA5-92C4A59D23C4"}
