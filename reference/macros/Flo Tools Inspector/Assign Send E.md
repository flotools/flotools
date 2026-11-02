# Assign Send E

- Group: Flo Tools Inspector
- UID: 853A4B13-CD0A-408B-8532-C8A77D2DA7DB
- Enabled: True
- Triggers: Ctrl+Cmd+5

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  track = mix.groups.byName(vo.voCursor.textUnderCursor())
  track.groups["Sends A-E"].buttons[8].click()
  ```
