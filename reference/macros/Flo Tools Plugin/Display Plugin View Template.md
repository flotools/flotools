# Display Plugin View Template

- Group: Flo Tools Plugin
- UID: A7A67CAF-F0DE-4563-99C8-1AB611B9FF93
- Enabled: True
- Triggers: StatusMenu {}

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_beginsWith:"Plug-in:"}})[0]
  msg = window.name().replace("Plug-in: ","").replace("/"," ")+"\n"
  sliders = window.groups.byName("FXTDMEditView").sliders
  names = sliders.name()
  msg+="{\"view\":\"Default\", \"click\":[-1,-1], \"parameters\":[\n[\n"
  for (n in names) {
  if (names[n] == null) continue
  msg+="[\""+names[n]+"\",0,0],\n"
  }
  msg = msg.substring(0,msg.length-2)+"\n"
  msg+="]\n]}"
  console.log(msg)
  ```
