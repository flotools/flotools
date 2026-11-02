# Toggle Plugin Monitor

- Group: Flo Tools Plugin
- UID: B54D31B8-DFAE-41A0-BD25-837A879C40D0
- Enabled: True
- Triggers: Opt+/

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  kme = Application("Keyboard Maestro Engine")
  if (kme.getvariable("FTPluginMonitor") == "1") {
  kme.setvariable("FTPluginMonitor", {to:"0"})
  vo.output("Deactivate plugin monitor.")
  } else {
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  try {
  window = windows.whose({name:{_beginsWith:"Plug-in:"}})[0]
  sliders = window.groups.byName("FXTDMEditView").sliders
  names = sliders.name()
  oldValues = sliders.attributes["AXValueDescription"].value()
  kme.setvariable("FTPluginMonitor", {to:"1"})
  vo.output("Watching "+window.name())
  while (true) {
  if (kme.getvariable("FTPluginMonitor") != "1") {
  vo.output("Deactivate Plugin Monitor")
  break;
  }
  currentValues= sliders.attributes["AXValueDescription"].value()
  for (v in currentValues) {
  if (oldValues[v] != currentValues[v]) {
  vo.output(currentValues[v]+": "+names[v])
  oldValues[v] = currentValues[v]
  }
  }
  delay(0.1)
  }
  } catch(err) {
  vo.output("Plugin monitor off")
  kme.setvariable("FTPluginMonitor", {to:"0"})
  }
  }
  
  ```
