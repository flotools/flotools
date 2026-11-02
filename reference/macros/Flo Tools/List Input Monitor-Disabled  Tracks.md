# List Input Monitor-Disabled  Tracks

- Group: Flo Tools
- UID: A06B8ECE-792B-48A5-A3E2-BA979594C1FA
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
  inputFilter = {_match:[inputSpecifier, ""]}
  audioFilter = {name:{_contains:" - Audio Track"}}
  tracks = mix.groups.whose({_and:[audioFilter, inputFilter]}).name()
  if (tracks.length==0) vo.output("No tracks are input monitor disabled.")
  else {
  title = tracks.length+" input monitor Disabled"
  prompt = "Choose tracks to enable input monitor."
  ok = "Enable Input Monitor"
  selections = app.chooseFromList(tracks, {withTitle:title, withPrompt:prompt, okButtonName:ok, multipleSelectionsAllowed:true})
  for (s in selections) {
  track = mix.groups.byName(selections[s])
  track.buttons["TrackInput Monitor"]().click()
  }
  }
  ```
