# List Input Monitor-Enabled Tracks

- Group: Flo Tools
- UID: B885D11D-EB9B-4F6D-8312-00BEAE8FB669
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
  inputSpecifier = ObjectSpecifier().buttons["TrackInput Monitor"].value
  inputFilter = {_match:[inputSpecifier, "on"]}
  audioFilter = {name:{_contains:" - Audio Track"}}
  tracks = mix.groups.whose({_and:[audioFilter, inputFilter]}).name()
  if (tracks.length==0) vo.output("No tracks are input monitor enabled.")
  else {
  title = tracks.length+" Input Monitor Enabled."
  prompt = "Choose tracks to disable input monitor."
  ok = "Disable Input Monitor"
  selections = app.chooseFromList(tracks, {withTitle:title, withPrompt:prompt, okButtonName:ok, multipleSelectionsAllowed:true})
  for (s in selections) {
  track = mix.groups.byName(selections[s])
  track.buttons["TrackInput Monitor"]().click()
  }
  }
  ```
