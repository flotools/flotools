# Auto Toggle Flo Tools

- Group: Flo Tools Global
- UID: 025B4AFD-5340-492B-A7DF-6F526BE1252E
- Enabled: True
- Triggers: Application {"Application": {"BundleIdentifier": "com.apple.VoiceOver", "Name": "VoiceOver", "NewFile": "/System/Library/CoreServices/VoiceOver.app"}, "FireType2": "Quit", "RepeatTime": 60, "Target": "Specific"}; Application {"Application": {"BundleIdentifier": "com.apple.VoiceOver", "Name": "VoiceOver", "NewFile": "/System/Library/CoreServices/VoiceOver.app"}, "FireType2": "Launch", "RepeatTime": 60, "Target": "Specific"}

## Actions

- IfThenElse (All):
  - if {"Application": {"BundleIdentifier": "com.apple.VoiceOver", "Name": "VoiceOver", "NewFile": "/System/Library/CoreServices/VoiceOver.app"}, "ApplicationConditionType": "NotRunning", "ConditionType": "Application"}
  then:
    - ExecuteMacro: {"Asynchronously": false, "MacroUID": "C4A644CE-1DF7-4925-B364-679E00AB9E63", "TimeOutAbortsMacro": true, "UseParameter": false}
  else:
    - ExecuteMacro: {"Asynchronously": false, "MacroUID": "CDB03324-1E21-47E2-A96F-316AB5E737A3", "TimeOutAbortsMacro": true, "UseParameter": false}
