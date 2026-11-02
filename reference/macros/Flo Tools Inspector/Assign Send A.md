# Assign Send A

- Group: Flo Tools Inspector
- UID: 93157301-7A3A-431A-BAD4-0F814DF57840
- Enabled: True
- Triggers: Ctrl+Cmd+1

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  track = mix.groups.byName(vo.voCursor.textUnderCursor())
  track.groups["Sends A-E"].buttons[0].click()
  ```
