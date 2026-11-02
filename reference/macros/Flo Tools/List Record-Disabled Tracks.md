# List Record-Disabled Tracks

- Group: Flo Tools
- UID: 283AFC32-5847-45FB-8C2F-44CCA0531319
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
  armFilter = {_match:[armSpecifier,"armed"]}
  safeSpecifier = ObjectSpecifier().buttons["Track Record Enable"].value
  safeFilter = {_match:[safeSpecifier,{_contains:"safe"}]}
  inactiveFilter = {_match:[armSpecifier,{_contains:"inactive"}]}
  folderFilter = {name:{_contains:"Folder Track"}}
  tracks = mix.groups.whose({_not:[auxFilter, auxiliaryFilter, masterFilter, folderFilter, armFilter, safeFilter, inactiveFilter]}).name()
  edit = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  recordStatus = edit.groups.byName("Transport View Cluster").groups.byName("Normal Transport Buttons").buttons.whose({name:"Track Record Enabled"})
  title = tracks.length+" disarmed. Choose tracks to arm."
  selections = app.chooseFromList(tracks, {withPrompt:title, multipleSelectionsAllowed:true})
  for (s in selections) {
  track = mix.groups.byName(selections[s])
  track.buttons.byName("Track Record Enable").click()
  
  }
  ```
