# Assign Send D

- Group: Flo Tools Inspector
- UID: 37E30067-D8FD-41C8-BB5F-FEDFDA9A7A7A
- Enabled: True
- Triggers: Ctrl+Cmd+4

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  track = mix.groups.byName(vo.voCursor.textUnderCursor())
  track.groups["Sends A-E"].buttons[6].click()
  ```
