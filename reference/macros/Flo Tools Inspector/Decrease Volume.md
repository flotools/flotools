# Decrease Volume

- Group: Flo Tools Inspector
- UID: 387783D0-17E0-4868-97BC-FC20712BEBDF
- Enabled: True
- Triggers: Ctrl+Cmd+Down

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  track = mix.groups.byName(vo.voCursor.textUnderCursor())
  slider = track.sliders.byName("Volume")
  slider.decrement()
  value = ""+slider.attributes["AXValueDescription"].value()
  vo.output(value)
  ```
