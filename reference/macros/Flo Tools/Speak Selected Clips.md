# Speak Selected Clips

- Group: Flo Tools
- UID: 365E4ABC-2658-495C-A98F-14AF724B0E0F
- Enabled: True
- Triggers: Opt+Shift+,

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  edit = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  clips = edit.tables.byName("clip list").rows.whose({selected:true}).uiElements[1].uiElements[0].name()
  var regex = /(\".*?\")/;
  selected = []
  clips.forEach(clip => {
  selected.push(regex.exec(clip)[1])
  })
  msg = ""
  if (selected.length == 0) msg = "No clips are currently selected."
  else msg = selected.length+" Selected: "+selected
  vo.output (msg)
  ```
