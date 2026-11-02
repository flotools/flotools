# Next Crossfade Link,

- Group: Flo Tools Batch Fades
- UID: D65B8F56-D100-44AA-8D9D-10CC96B4F3FE
- Enabled: True
- Triggers: Opt+Cmd+Down

## Actions

- SimulateKeystroke: Opt+Cmd+Down
- ExecuteJavaScriptForAutomation
  ```javascript
  vo = Application("VoiceOver")
  pt = Application("System Events").applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  window = windows.whose({name:{_contains:"Fade"}})[0]
  obj = window.groups.byName("<<- Link ->>").radioButtons.whose({value:{_equals:1}}).name()
  vo.output(obj+", Crossfade Link.")
  ```
