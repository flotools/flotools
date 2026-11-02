# List Muted Tracks

- Group: Flo Tools
- UID: ECA3C361-676D-4CB1-AEB6-BF0B2D188ED8
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
  muteFilter = {_match:[muteSpecifier,""]}
  soloFilter = {_match:[muteSpecifier,{_contains:"solo"}]}
  inactiveFilter = {_match:[muteSpecifier,{_contains:"inactive"}]}
  tracks = mix.groups.whose({_not:[masterFilter, muteFilter, soloFilter, inactiveFilter]}).name()
  if (tracks.length==0) vo.output("No tracks are muted.")
  else {
  title = tracks.length+" Muted"
  prompt = "Choose tracks to unmute."
  ok = "Unmute"
  selections = app.chooseFromList(tracks, {withTitle:title, withPrompt:prompt, okButtonName:ok, multipleSelectionsAllowed:true})
  for (s in selections) {
  track = mix.groups.byName(selections[s])
  track.buttons.byName("Mute").click()
  }
  }
  ```
