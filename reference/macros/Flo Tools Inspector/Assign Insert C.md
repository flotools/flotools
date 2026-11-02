# Assign Insert C

- Group: Flo Tools Inspector
- UID: EF605A53-014F-4FD5-9C1B-14E2220383C1
- Enabled: True
- Triggers: Cmd+3

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  track = mix.groups.byName(vo.voCursor.textUnderCursor())
  track.groups["Inserts A-E"].buttons[2].click()
  ```
