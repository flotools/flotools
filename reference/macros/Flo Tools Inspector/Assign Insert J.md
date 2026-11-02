# Assign Insert J

- Group: Flo Tools Inspector
- UID: 9D34C1E5-DB04-4BA4-A6E5-0AF3EA0213D7
- Enabled: True
- Triggers: Cmd+0

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  track = mix.groups.byName(vo.voCursor.textUnderCursor())
  track.groups["Inserts F-J"].buttons[4].click()
  ```
