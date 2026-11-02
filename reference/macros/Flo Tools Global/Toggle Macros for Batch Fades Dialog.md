# Toggle Macros for Batch Fades Dialog

- Group: Flo Tools Global
- UID: D31EAE62-2F59-4FBC-BC6F-F91D71F05DA3
- Enabled: True
- Triggers: FocussedWindow {"ChangeType": "FocussedWindowsTitleChanged"}

## Actions

- IfThenElse (All):
  - if {"Application": {"BundleIdentifier": "com.avid.ProTools", "Name": "Pro Tools", "NewFile": "/Applications/Pro Tools.app"}, "ConditionType": "FrontWindow", "FrontWindowConditionType": "TitleIs", "FrontWindowTitle": "Batch Fades", "IsFrontApplication": false}
  then:
    - SetMacroEnable: {"Action": "Disable", "MacroUID": "2B84BD4D-351A-43DA-90AC-189C8BC7B7B9"}
    - SetMacroEnable: {"Action": "Disable", "MacroUID": "B1D8EF63-1F31-4C68-B619-394E6A3C718C"}
- IfThenElse (None):
  - if {"ConditionType": "FrontWindow", "FrontWindowConditionType": "Exists", "IsFrontApplication": true}
  then:
    - SetMacroEnable: {"Action": "Enable", "MacroUID": "2B84BD4D-351A-43DA-90AC-189C8BC7B7B9"}
    - SetMacroEnable: {"Action": "Enable", "MacroUID": "B1D8EF63-1F31-4C68-B619-394E6A3C718C"}
