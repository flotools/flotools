# Assign Insert I

- Group: Flo Tools Inspector
- UID: 9A62399E-80C2-4784-94F1-C32CAE5FCF92
- Enabled: True
- Triggers: Cmd+9

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  track = mix.groups.byName(vo.voCursor.textUnderCursor())
  track.groups["Inserts F-J"].buttons[3].click()
  ```
