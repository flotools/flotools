# List Hidden Tracks

- Group: Flo Tools
- UID: 8707D170-ADDA-46FA-A29E-7F98449F4A38
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
  allTracks = mix.tables.byName("Track List").rows.uiElements[1].buttons[0].name()
  show = ObjectSpecifier().uiElements[0].buttons[0].name
  tracks = mix.tables.byName("Track List").rows.whose({_match:[show,{_contains:"Hidden"}]}).uiElements[1].buttons[0].name()
  for (t in tracks) {
  tracks[t] = tracks[t].replace(/^Selected /, "")
  }
  if (tracks.length == 0) vo.output("No tracks are  hidden.")
  else {
  title = tracks.length+" hidden"
  prompt = "Choose tracks to show."
  ok = "Show"
  selections = app.chooseFromList(tracks, {withTitle:title, withPrompt:prompt, okButtonName:ok, multipleSelectionsAllowed:true})
  for (s in selections) {
  t = allTracks.indexOf(selections[s])
  track = mix.tables.byName("Track List").rows[t].uiElements[0].buttons[0].click()
  }
  }
  ```
