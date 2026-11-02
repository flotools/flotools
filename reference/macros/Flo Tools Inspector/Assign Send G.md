# Assign Send G

- Group: Flo Tools Inspector
- UID: 6063BA2E-6C29-4E66-8458-96DF2323E14F
- Enabled: True
- Triggers: Ctrl+Cmd+7

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  track = mix.groups.byName(vo.voCursor.textUnderCursor())
  track.groups["Sends F-J"].buttons[2].click()
  ```
