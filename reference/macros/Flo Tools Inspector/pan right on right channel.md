# pan right on right channel

- Group: Flo Tools Inspector
- UID: 7549F3CC-362E-4A2A-AB47-9CA0F30F7BB4
- Enabled: True
- Triggers: Ctrl+Shift+Cmd+Right

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
  slider.increment()
  value = ""+slider.attributes["AXValueDescription"].value()+", "+slider.name()
  vo.output(value)
  ```
