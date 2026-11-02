# Track view toggled on all tracks

- Group: Flo Tools
- UID: B5FFCC82-ADE7-4A3C-9D77-7EADC3E1BE64
- Enabled: True
- Triggers: Opt+-

## Actions

- SimulateKeystroke: Opt+-
- IfThenElse (None):
  - if {"ConditionType": "FrontWindow", "FrontWindowConditionType": "TitleMatches", "FrontWindowTitle": "^Dashboard|^Save|Bounce$|^Open|^Get Info|Setup$|^Create Group|^Scroll To Track|^Name|^Metadata Inspector|^New Memory Location|^MIDI Event List|^Workspace|^Artist Chat", "IsFrontApplication": true}
  then:
    - ExecuteJavaScriptForAutomation
      ```javascript
      vo = Application("VoiceOver")
      text = vo.keyboardCursor.textUnderCursor()
      if (!text.endsWith("edit text")) {
      Application("VoiceOver").output("Track view toggled on all tracks.")
      }
      ```
