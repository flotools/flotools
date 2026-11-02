# Next Crossfade Out Shape Curve

- Group: Flo Tools Batch Fades
- UID: 1AB29A21-663B-4957-A19C-CE4F7DFA89F4
- Enabled: True
- Triggers: Opt+Shift+Right

## Actions

- SimulateKeystroke: Opt+Shift+Right
- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_contains:"Fade"}})[0]
  shape = window.groups.byName("Out Shape").popUpButtons.byName("Out Shape").value()
  vo.output(shape+", Crossfade Out Shape Curve.")
  ```
