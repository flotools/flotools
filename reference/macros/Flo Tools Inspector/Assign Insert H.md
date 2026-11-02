# Assign Insert H

- Group: Flo Tools Inspector
- UID: FCC1BB1D-D756-45E4-BCD7-DC142F33126B
- Enabled: True
- Triggers: Cmd+8

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  track = mix.groups.byName(vo.voCursor.textUnderCursor())
  track.groups["Inserts F-J"].buttons[2].click()
  ```
