# Speak Tracks With 0DB Level

- Group: Flo Tools
- UID: 7053D5DD-60A3-444A-AB18-A54AA32DF625
- Enabled: True
- Triggers: Opt+Shift+0

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
  midiFilter = {name:{_contains:" - MIDI Track"}}
  values = mix.groups.whose({_not:[midiFilter]}).sliders["Peak"].attributes["AXValueDescription"].value()
  tracks = mix.groups.whose({_not:[midiFilter]}).name()
  msg = ""
  for (t in values) {
  if (values[t].replace("minus ","-")>=0) msg += tracks[t]+". "
  if (new Date().getTime()-start > 1000) {
  kme.playSound(Path("/System/Library/Sounds/Pop.aiff"))
  start = new Date().getTime()
  }
  }
  msg = msg.replace(/ Track\. /g, ". ")
  if (msg=="") msg = "No track reched 0db level."
  else msg = "0db on: "+msg
  vo.output(msg)
  ```
