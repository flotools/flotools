# List Unselected Tracks

- Group: Flo Tools
- UID: 55DD1145-A398-4F55-8395-B60E701170C3
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
  tracks = mix.tables.byName("Track List").rows.whose({_not:[{_match:[select,{_contains:"Selected"}]}]}).uiElements[1].buttons[0].name()
  if (tracks.length == 0) vo.output("No tracks are unselected.")
  else {
  title = tracks.length+" Unselected"
  prompt = "Choose tracks to select."
  ok = "Select"
  selections = app.chooseFromList(tracks, {withTitle:title, withPrompt:prompt, okButtonName:ok, multipleSelectionsAllowed:true})
  for (s in selections) {
  t = allTracks.indexOf(selections[s])
  track = mix.tables.byName("Track List").rows[t].uiElements[1].buttons[0].click()
  }
  }
  ```
