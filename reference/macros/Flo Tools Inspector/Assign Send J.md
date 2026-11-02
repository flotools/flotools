# Assign Send J

- Group: Flo Tools Inspector
- UID: DD561616-0FF2-4F82-9A8B-1BB3444BE045
- Enabled: True
- Triggers: Ctrl+Cmd+0

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  track = mix.groups.byName(vo.voCursor.textUnderCursor())
  track.groups["Sends F-J"].buttons[8].click()
  ```
