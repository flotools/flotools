# Zoom/Maximize Window

- Group: Flo Mouse
- UID: 688B5089-D4AD-403E-9114-57814553015A
- Enabled: True
- Triggers: Opt+Shift+Cmd+Z

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  finder = Application("Finder")
  bounds = finder.desktop.window.bounds()
  w=bounds["width"]
  h=bounds["height"]
  sys = Application("System Events")
  process = sys.processes.whose({frontmost:true})[0]
  window = process.windows[0]
  window.size.set([w,h])
  vo.output("Zoomed "+window.name())
  ```
