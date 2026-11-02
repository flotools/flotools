# Assign Send I

- Group: Flo Tools Inspector
- UID: 3047752C-0899-4962-A819-3797E6095707
- Enabled: True
- Triggers: Ctrl+Cmd+9

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  track = mix.groups.byName(vo.voCursor.textUnderCursor())
  track.groups["Sends F-J"].buttons[6].click()
  ```
