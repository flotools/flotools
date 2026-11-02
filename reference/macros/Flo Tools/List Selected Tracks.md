# List Selected Tracks

- Group: Flo Tools
- UID: 58C059EC-7A71-44C7-BDE8-C7E3CDCBF886
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
  select = ObjectSpecifier().uiElements[1].buttons[0].name
  tracks = mix.tables.byName("Track List").rows.whose({_match:[select,{_contains:"Selected"}]}).uiElements[1].buttons[0].name()
  for (t in tracks) {
  tracks[t] = tracks[t].replace(/^Selected /, "")
  }
  if (tracks.length == 0) vo.output("No tracks are selected.")
  else {
  for (t in tracks) {
  tracks[t] = tracks[t].replace(/^Selected /,"")
  }
  title = tracks.length+" Selected"
  prompt = "Choose tracks to deselect."
  ok = "Deselect"
  selections = app.chooseFromList(tracks, {withTitle:title, withPrompt:prompt, okButtonName:ok, multipleSelectionsAllowed:true})
  for (s in selections) {
  t = allTracks.indexOf("Selected "+selections[s])
  track = mix.tables.byName("Track List").rows[t].uiElements[1].buttons[0].click()
  }
  }
  ```
