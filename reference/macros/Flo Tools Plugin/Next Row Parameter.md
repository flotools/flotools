# Next Row Parameter

- Group: Flo Tools Plugin
- UID: 8FD5FC78-AEF7-4BED-82AF-E178124E8996
- Enabled: True
- Triggers: Ctrl+Down

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  kme = Application("Keyboard Maestro Engine")
  index = kme.getvariable("FTPluginControlIndex")
  str = kme.getvariable("FTPluginControlParameters")
  sys = Application('System Events')
  vo = Application("VoiceOver")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_beginsWith:"Plug-in:"}})[0]
  json = JSON.parse(str)
  parameters = json["parameters"]
  r = index.split(/,/)[0]
  c = index.split(/,/)[1]
  
  r++
  if (r<0) r=0
  else if (r>parameters.length-1) r=parameters.length-1
  row = parameters[r]
  if (c<0) c=0
  else if (c>row.length-1) c = row.length-1
  
  name = row[c][0]
  x = row[c][1]
  y = row[c][2]
  kme.setvariable("FTPluginControlIndex", {to:r+","+c})
  kme.setvariable("x", {to:""+x})
  kme.setvariable("y", {to:""+y})
  try {
  value = window.groups.byName("FXTDMEditView").sliders.byName(name).attributes["AXValueDescription"].value()
  vo.output(name+": "+value)
  } catch(err) {
  vo.output(name)
  }
  ```
- MouseMoveAndClick: {"Action": "Move", "Button": 0, "ClickCount": 0, "DisplayMatches": false, "DragHorizontalPosition": "0", "DragVerticalPosition": "0", "Fuzz": 15, "HorizontalPositionExpression": "x", "Modifiers": 0, "MouseDrag": "None", "Relative": "Window", "RelativeCorner": "TopLeft", "RestoreMouseLocation": false, "VerticalPositionExpression": "y"}
