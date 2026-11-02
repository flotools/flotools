# Select Sub Counter

- Group: Flo Tools
- UID: 79A74652-734F-4F8F-9409-30B663A77457
- Enabled: True
- Triggers: Opt+Cmd+F6

## Actions

- ExecuteJavaScriptForAutomation
  ```javascript
  sys = Application("System Events")
  pt = sys.applicationProcesses.whose({name:{_contains:"Pro Tools"}})[0]
  windows = pt.windows
  edit = windows.whose({name:{_beginsWith:"Edit:"}})[0]
  edit.groups.byName("Counter Display Cluster").buttons.byName("Sub Counter selector").click()
  ```
