# Assign Insert F

- Group: Flo Tools Inspector
- UID: E842D842-DD6A-4253-890B-E3F4D9C04D22
- Enabled: True
- Triggers: Cmd+6

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  track = mix.groups.byName(vo.voCursor.textUnderCursor())
  track.groups["Inserts F-J"].buttons[0].click()
  ```
