# Next Fade Out Shape Parameter

- Group: Flo Tools Fade Out
- UID: C2EC2E94-4907-4385-8A8C-B1657F0AB0F9
- Enabled: True
- Triggers: Down

## Actions

- SimulateKeystroke: Down
- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_contains:"Fade"}})[0]
  obj = window.groups.byName("Out Shape").radioButtons.whose({value:{_equals:1}}).name()
  vo.output(obj+", Out Shape .")
  ```
