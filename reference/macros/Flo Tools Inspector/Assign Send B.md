# Assign Send B

- Group: Flo Tools Inspector
- UID: A5CB767B-E3D8-4E77-B282-E24B68CB6E7E
- Enabled: True
- Triggers: Ctrl+Cmd+2

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  track = mix.groups.byName(vo.voCursor.textUnderCursor())
  track.groups["Sends A-E"].buttons[2].click()
  ```
