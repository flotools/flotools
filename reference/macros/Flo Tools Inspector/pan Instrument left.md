# pan Instrument left

- Group: Flo Tools Inspector
- UID: 30F5DC4E-61A4-415A-8E44-1465EFD13573
- Enabled: True
- Triggers: Ctrl+Opt+Left

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
  slider.decrement()
  value = ""+slider.attributes["AXValueDescription"].value()
  vo.output(value)
  ```
