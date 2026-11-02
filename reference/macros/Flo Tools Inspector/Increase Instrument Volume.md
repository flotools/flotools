# Increase Instrument Volume

- Group: Flo Tools Inspector
- UID: 03CF90B2-C388-4F4F-9550-2D74C570597B
- Enabled: True
- Triggers: Ctrl+Opt+Up

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
  slider.increment()
  value = ""+slider.attributes["AXValueDescription"].value()
  vo.output(value)
  ```
