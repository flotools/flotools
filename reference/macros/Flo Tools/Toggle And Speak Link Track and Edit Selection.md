# Toggle And Speak Link Track and Edit Selection

- Group: Flo Tools
- UID: 503B8B13-77A3-45BF-BC78-3F8E6EFD6B40
- Enabled: True
- Triggers: Shift+T

## Actions

- SimulateKeystroke: Shift+T
- IfThenElse (None):
  - if {"ConditionType": "FrontWindow", "FrontWindowConditionType": "TitleMatches", "FrontWindowTitle": "^Dashboard|^Save|Bounce$|^Open|^Get Info|Setup$|^Create Group|^Scroll To Track|^Name|^Metadata Inspector|^New Memory Location|^MIDI Event List|^Workspace|^Artist Chat", "IsFrontApplication": true}
  then:
    - ExecuteJavaScriptForAutomation
      ```javascript
      vo = Application("VoiceOver")
      text = vo.keyboardCursor.textUnderCursor()
      if (!text.endsWith("edit text")) {
      sys = Application("System Events")
      pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
      value = pt.menuBars[0].menuBarItems.byName("Options").menus.byName("Options").menuItems.byName("Link Track and Edit Selection").attributes["AXMenuItemMarkChar"].value()
      if (value == null) vo.output("Track and Edit Selection Unlinked")
      else vo.output("Track and Edit Selection Linked")
      }
      ```
