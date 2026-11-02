# Assign Send F

- Group: Flo Tools Inspector
- UID: F3E88078-4DA4-45ED-8333-D9B756C5C296
- Enabled: True
- Triggers: Ctrl+Cmd+6

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  track = mix.groups.byName(vo.voCursor.textUnderCursor())
  track.groups["Sends F-J"].buttons[0].click()
  ```
