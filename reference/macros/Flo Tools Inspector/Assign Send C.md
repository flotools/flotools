# Assign Send C

- Group: Flo Tools Inspector
- UID: 86933FB3-55A5-43C3-A319-E0EFB4DFEB57
- Enabled: True
- Triggers: Ctrl+Cmd+3

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  track = mix.groups.byName(vo.voCursor.textUnderCursor())
  track.groups["Sends A-E"].buttons[4].click()
  ```
