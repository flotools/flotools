# Decrease Instrument Volume

- Group: Flo Tools Inspector
- UID: 213EE66F-86AC-462B-BB2C-3E3F0BAEE9AE
- Enabled: True
- Triggers: Ctrl+Opt+Down

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  track = mix.groups.byName(vo.voCursor.textUnderCursor())
  slider = track.groups.byName("Instrument").sliders[0]
  slider.decrement()
  value = ""+slider.attributes["AXValueDescription"].value()
  vo.output(value)
  ```
