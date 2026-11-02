# pan left on mono/Left channel

- Group: Flo Tools Inspector
- UID: 9C149078-8675-401D-9CD7-E1457E482328
- Enabled: True
- Triggers: Ctrl+Cmd+Left

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  track = mix.groups.byName(vo.voCursor.textUnderCursor())
  sliders = track.sliders.whose({name:{_contains:"Pan Knob"}})()
  slider = sliders[0]
  slider.decrement()
  value = ""+slider.attributes["AXValueDescription"].value()+", "+slider.name()
  vo.output(value)
  ```
