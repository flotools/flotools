# Load Plugin Parameters for View 7

- Group: Flo Tools Plugin
- UID: 109C3740-24AD-483D-9131-BD09A53E06B3
- Enabled: True
- Triggers: Cmd+7

## Actions

- SetVariableToText: command = '%ExecutingThisMacro%'
- ExecuteJavaScriptForAutomation
  ```javascript
  kme = Application("Keyboard Maestro Engine")
  command = kme.getvariable("command")
  command = command.substring(command.length-1)
  
  vo = Application("VoiceOver")
  app = Application.currentApplication()
  app.includeStandardAdditions = true
  sys = Application('System Events')
  home = sys.currentUser.homeDirectory()
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_beginsWith:"Plug-in:"}})[0]
  pluginName = window.name().replace("Plug-in: ","").replace("/"," ")
  fileName = home+"/Library/Application Support/Flo Tools/Plug-In Views/"+pluginName+"-"+command+".txt"
  try {
  str = app.read(Path(fileName))
  json = JSON.parse(str)
  view = json["view"]
  x = json["click"][0]
  y = json["click"][1]
  vo.output(view+" view for "+pluginName)
  } catch(err) {
  x = "-1"
  y = "-1"
  str=""
  }
  kme.setvariable("FTPluginControlParameters", {to:str})
  kme.setvariable("FTPluginControlIndex", {to:"-1,-1"})
  kme.setvariable("x", {to:""+x})
  kme.setvariable("y", {to:""+y})
  ```
- IfThenElse (All):
  - if {"ConditionType": "Variable", "Variable": "x", "VariableConditionType": "IsNot", "VariableValue": "-1"}
  then:
    - MouseMoveAndClick: {"Action": "MoveAndClick", "Button": 0, "ClickCount": 1, "DisplayMatches": false, "DragHorizontalPosition": "0", "DragVerticalPosition": "0", "Fuzz": 15, "HorizontalPositionExpression": "x", "Modifiers": 0, "MouseDrag": "None", "Relative": "Window", "RelativeCorner": "TopLeft", "RestoreMouseLocation": false, "VerticalPositionExpression": "y"}
