# Speak And Move Back 5 Playlists

- Group: Flo Tools
- UID: 6FE53814-0288-4606-9228-1992F9BD7557
- Enabled: True
- Triggers: Shift+Page Up

## Actions

- SimulateKeystroke: Shift+Page Up
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
      mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
      table = mix.tables.byName("Track List")
      tracks = table.rows.whose({selected:true}).uiElements[1].buttons[0].name()
      regex = /^Selected. (.*? - \w+) Track $/
      msg = ""
      tracks.forEach(track => {
      msg += regex.exec(track)[1]+". "
      })
      if (msg == "") msg = "No tracks are selected."
      vo.output(msg)
      }
      ```
