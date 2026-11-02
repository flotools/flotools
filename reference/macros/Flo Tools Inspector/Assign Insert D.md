# Assign Insert D

- Group: Flo Tools Inspector
- UID: 02C3CC1C-9126-44D2-88D2-0AF962790972
- Enabled: True
- Triggers: Cmd+4

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  track = mix.groups.byName(vo.voCursor.textUnderCursor())
  track.groups["Inserts A-E"].buttons[3].click()
  ```
