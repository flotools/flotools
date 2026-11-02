# Increase Volume

- Group: Flo Tools Inspector
- UID: 5DA65AC1-5A53-4003-844E-75273F49916C
- Enabled: True
- Triggers: Ctrl+Cmd+Up

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
  slider.increment()
  value = ""+slider.attributes["AXValueDescription"].value()
  vo.output(value)
  ```
