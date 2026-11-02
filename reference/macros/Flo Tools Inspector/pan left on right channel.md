# pan left on right channel

- Group: Flo Tools Inspector
- UID: A22F2199-FA1E-480D-AB0C-87DF9159B485
- Enabled: True
- Triggers: Ctrl+Shift+Cmd+Left

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
  if (sliders.length == 1) {
  slider = sliders[0]
  } else slider = sliders[1]
  slider.decrement()
  value = ""+slider.attributes["AXValueDescription"].value()+", "+slider.name()
  vo.output(value)
  ```
