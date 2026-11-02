# Assign Insert G

- Group: Flo Tools Inspector
- UID: F2B12D67-8618-41ED-AEB7-0A77C8576CC1
- Enabled: True
- Triggers: Cmd+7

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  track = mix.groups.byName(vo.voCursor.textUnderCursor())
  track.groups["Inserts F-J"].buttons[1].click()
  ```
