# List Record-Enabled Tracks

- Group: Flo Tools
- UID: 5CC51E1E-500D-4767-B719-4AD544667A89
- Enabled: True
- Triggers: none

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  app = Application.currentApplication()
  app.includeStandardAdditions = true
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  masterFilter = {name:{_contains:" - Master Track"}}
  auxFilter = {name:{_contains:" - Aux Track"}}
  auxiliaryFilter = {name:{_contains:" - Auxiliary Track"}}
  armSpecifier = ObjectSpecifier().buttons["Track Record Enable"].value
  armFilter = {_match:[armSpecifier,""]}
  safeFilter = {_match:[armSpecifier,{_contains:"safe"}]}
  inactiveFilter = {_match:[armSpecifier,{_contains:"inactive"}]}
  folderFilter = {name:{_contains:"Folder Track"}}
  tracks = mix.groups.whose({_not:[folderFilter, auxFilter, auxiliaryFilter, masterFilter, armFilter, safeFilter, inactiveFilter]}).name()
  edit = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  recordStatus = edit.groups.byName("Transport View Cluster").groups.byName("Normal Transport Buttons").buttons.whose({name:"Track Record Enabled"})
  if (tracks.length==0 & recordStatus.length == 1) vo.output("Some tracks are  armed.")
  else if (recordStatus.length == 0) vo.output("No tracks are  armed.")
  else {
  title = tracks.length+" armed. Choose tracks to disarm."
  selections = app.chooseFromList(tracks, {withPrompt:title, multipleSelectionsAllowed:true})
  for (s in selections) {
  track = mix.groups.byName(selections[s])
  track.buttons.byName("Track Record Enable").click()
  }
  
  }
  ```
