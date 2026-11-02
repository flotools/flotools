# Load Plugin Parameters for Default View

- Group: Flo Tools Plugin
- UID: 703E2B8E-556F-4BBF-95B5-C447F55F1968
- Enabled: True
- Triggers: Cmd+0

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  kme = Application("Keyboard Maestro Engine")
  vo = Application("VoiceOver")
  app = Application.currentApplication()
  app.includeStandardAdditions = true
  sys = Application('System Events')
  home = sys.currentUser.homeDirectory()
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_beginsWith:"Plug-in:"}})[0]
  pluginName = window.name().replace("Plug-in: ","").replace("/"," ")
  fileName = home+"/Library/Application Support/Flo Tools/Plug-In Views/"+pluginName+".txt"
  try {
  str = app.read(Path(fileName))
  json = JSON.parse(str)
  view = json["view"]
  x = json["click"][0]
  y = json["click"][1]
  vo.output(view+" view for "+pluginName)
  } catch (err) {
  x = "-1"
  y = "-1"
  str=""
  }
  kme.setvariable("FTPluginControlIndex", {to:"-1,-1"})
  kme.setvariable("FTPluginControlParameters", {to:str})
  kme.setvariable("x", {to:""+x})
  kme.setvariable("y", {to:""+y})
  ```
- IfThenElse (All):
  - if {"ConditionType": "Variable", "Variable": "x", "VariableConditionType": "IsNot", "VariableValue": "-1"}
  then:
    - MouseMoveAndClick: {"Action": "MoveAndClick", "Button": 0, "ClickCount": 1, "DisplayMatches": false, "DragHorizontalPosition": "0", "DragVerticalPosition": "0", "Fuzz": 15, "HorizontalPositionExpression": "x", "Modifiers": 0, "MouseDrag": "None", "Relative": "Window", "RelativeCorner": "TopLeft", "RestoreMouseLocation": false, "VerticalPositionExpression": "y"}
