# Assign Insert A

- Group: Flo Tools Inspector
- UID: A913784B-20F4-465C-BEEE-060DB4CE1B08
- Enabled: True
- Triggers: Cmd+1

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  track = mix.groups.byName(vo.voCursor.textUnderCursor())
  track.groups["Inserts A-E"].buttons[0].click()
  ```
