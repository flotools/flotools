# Assign Insert E

- Group: Flo Tools Inspector
- UID: 2056F943-E789-4487-9013-97A3C9C521E6
- Enabled: True
- Triggers: Cmd+5

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  track = mix.groups.byName(vo.voCursor.textUnderCursor())
  track.groups["Inserts A-E"].buttons[4].click()
  ```
