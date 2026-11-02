# Toggle And Speak Link Timeline And Edit Selection

- Group: Flo Tools
- UID: 6EF50BCB-FACB-4B57-807F-17138E576EBC
- Enabled: True
- Triggers: Shift+/

## Actions

- SimulateKeystroke: Shift+/
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
      windows = pt.windows
      value = pt.menuBars[0].menuBarItems.byName("Options").menus.byName("Options").menuItems.byName("Link Timeline and Edit Selection").attributes["AXMenuItemMarkChar"].value()
      if (value == null) vo.output("Timeline and Edit Selection Unlinked")
      else vo.output("Timeline and Edit Selection Linked")
      }
      ```
