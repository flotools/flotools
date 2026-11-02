# Bypass Flo Tools in Keyboard Shortcuts window

- Group: Flo Tools Global
- UID: 631D4577-668D-469E-AFA1-5D6535EB2B83
- Enabled: True
- Triggers: focused window: FocussedWindowChanges

## Actions

- IfThenElse "Turn off Flo Tools" (All):
  - if {"Application": {"BundleIdentifier": "com.avid.ProTools", "Name": "Pro Tools", "NewFile": "/Applications/Pro Tools.app"}, "ConditionType": "FrontWindow", "FrontWindowConditionType": "TitleIs", "FrontWindowTitle": "Keyboard Shortcuts", "IsFrontApplication": false}
  then:
    - ExecuteMacro: {"Asynchronously": false, "MacroUID": "C4A644CE-1DF7-4925-B364-679E00AB9E63", "TimeOutAbortsMacro": true, "UseParameter": false}
- IfThenElse "Turn on Flo Tools" (None):
  - if {"AnyWindowConditionType": "Is", "AnyWindowTitle": "Keyboard Shortcuts", "Application": {"BundleIdentifier": "com.avid.ProTools", "Name": "Pro Tools", "NewFile": "/Applications/Pro Tools.app"}, "ConditionType": "AnyWindow", "IsFrontApplication": false}
  then:
    - ExecuteMacro: {"Asynchronously": false, "MacroUID": "CDB03324-1E21-47E2-A96F-316AB5E737A3", "TimeOutAbortsMacro": true, "UseParameter": false}
