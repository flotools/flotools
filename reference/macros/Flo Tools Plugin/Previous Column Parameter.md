# Previous Column Parameter

- Group: Flo Tools Plugin
- UID: 7554D587-CC96-4A94-AA1F-ADBDFA396543
- Enabled: True
- Triggers: Ctrl+Left

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  kme = Application("Keyboard Maestro Engine")
  index = kme.getvariable("FTPluginControlIndex")
  str = kme.getvariable("FTPluginControlParameters")
  vo = Application("VoiceOver")
  sys = Application('System Events')
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_beginsWith:"Plug-in:"}})[0]
  json = JSON.parse(str)
  parameters = json["parameters"]
  r = index.split(/,/)[0]
  c = index.split(/,/)[1]
  
  if (r<0) r=0
  else if (r>parameters.length-1) r=parameters.length-1
  row = parameters[r]
  c--
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
