# pan Instrument Right

- Group: Flo Tools Inspector
- UID: AC85B840-27F7-4476-9EC2-9B25E615052D
- Enabled: True
- Triggers: Ctrl+Opt+Right

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  track = mix.groups.byName(vo.voCursor.textUnderCursor())
  slider = track.groups.byName("Instrument")
  .sliders.whose({name:{_contains:"MIDI Pan indicator"}})[0]
  slider.increment()
  value = ""+slider.attributes["AXValueDescription"].value()
  vo.output(value)
  ```
