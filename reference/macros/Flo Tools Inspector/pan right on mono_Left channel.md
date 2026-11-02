# pan right on mono/Left channel

- Group: Flo Tools Inspector
- UID: 38AC5CB1-9C5F-4973-B8D1-20259CF38989
- Enabled: True
- Triggers: Ctrl+Cmd+Right

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
  slider.increment()
  value = ""+slider.attributes["AXValueDescription"].value()+", "+slider.name()
  vo.output(value)
  ```
