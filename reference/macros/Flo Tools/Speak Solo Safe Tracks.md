# Speak Solo Safe Tracks

- Group: Flo Tools
- UID: 9C5DEED2-1FDD-425C-90BE-0F2F8533FB16
- Enabled: True
- Triggers: Opt+Shift+Cmd+S

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
  soloSpecifier = ObjectSpecifier().buttons["Solo"].value
  soloFilter = {_match:[soloSpecifier,""]}
  safeFilter = {_match:[soloSpecifier,{_contains:"safe"}]}
  inactiveFilter = {_match:[soloSpecifier,{_contains:"inactive"}]}
  tracks = mix.groups.whose({_and:[{_not:[masterFilter, soloFilter, inactiveFilter]}, safeFilter]}).name()
  msg = ""
  for (t in tracks) {
  msg += tracks[t]+". "
  }
  msg = msg.replace(/ Track\. /g, ". ")
  if (msg=="") msg = msg+"No tracks are solo safe."
  else msg = tracks.length+" Solo safe: "+msg
  vo.output(msg)
  ```
