# Speak Record Safe Tracks

- Group: Flo Tools
- UID: 9014BA79-26AD-4E1F-92B4-1339D6405214
- Enabled: True
- Triggers: Opt+Shift+Cmd+R

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  start = new Date().getTime()
  kme = Application("Keyboard Maestro Engine")
  vo = Application("VoiceOver")
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  mix = windows.whose({name:{_beginsWith:"Mix:"}})[0]
  masterFilter = {name:{_contains:" - Master Track"}}
  auxFilter = {name:{_contains:" - Aux Track"}}
  auxiliaryFilter = {name:{_contains:" - Auxiliary Track"}}
  folderFilter = {name:{_contains:"Folder Track"}}
  armSpecifier = ObjectSpecifier().buttons["Track Record Enable"].value
  armFilter = {_match:[armSpecifier,""]}
  safeFilter = {_match:[armSpecifier,{_contains:"safe"}]}
  inactiveFilter = {_match:[armSpecifier,{_contains:"inactive"}]}
  tracks = mix.groups.whose({_and:[{_not:[auxFilter, auxiliaryFilter, folderFilter, masterFilter, armFilter, inactiveFilter]}, safeFilter]}).name()
  msg = ""
  for (t in tracks) {
  msg += tracks[t]+". "
  }
  msg = msg.replace(/ Track\. /g, ". ")
  if (msg=="") msg = msg+"No tracks are disarmed safe."
  else msg = tracks.length+" Disarmed safe: "+msg
  vo.output (msg)
  ```
