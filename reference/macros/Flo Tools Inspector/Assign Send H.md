# Assign Send H

- Group: Flo Tools Inspector
- UID: 5178C660-214B-4F18-B46C-3EC9E66EB955
- Enabled: True
- Triggers: Ctrl+Cmd+8

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  track = mix.groups.byName(vo.voCursor.textUnderCursor())
  track.groups["Sends F-J"].buttons[4].click()
  ```
