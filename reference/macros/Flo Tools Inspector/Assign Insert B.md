# Assign Insert B

- Group: Flo Tools Inspector
- UID: E7C506D4-F2CF-4032-BE01-B7A2DBDE4098
- Enabled: True
- Triggers: Cmd+2

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  track = mix.groups.byName(vo.voCursor.textUnderCursor())
  track.groups["Inserts A-E"].buttons[1].click()
  ```
