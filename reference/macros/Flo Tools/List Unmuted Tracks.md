# List Unmuted Tracks

- Group: Flo Tools
- UID: 35D75B3E-439E-4692-BC02-5E90F862F421
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
  muteSpecifier = ObjectSpecifier().buttons["Mute"].value
  muteFilter = {_match:[muteSpecifier,"on"]}
  soloFilter = {_match:[muteSpecifier,{_contains:"solo"}]}
  inactiveFilter = {_match:[muteSpecifier,{_contains:"inactive"}]}
  tracks = mix.groups.whose({_not:[masterFilter, muteFilter, soloFilter, inactiveFilter]}).name()
  if (tracks.length==0) vo.output("No tracks are unmuted.")
  else {
  title = tracks.length+" Unmuted"
  prompt = "Choose tracks to mute."
  ok = "Mute"
  selections = app.chooseFromList(tracks, {withTitle:title, withPrompt:prompt, okButtonName:ok, multipleSelectionsAllowed:true})
  }
  ```
