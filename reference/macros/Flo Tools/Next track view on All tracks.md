# Next track view on All tracks

- Group: Flo Tools
- UID: 89A29EA2-31C4-4722-A104-CD3AAE66B19A
- Enabled: True
- Triggers: Ctrl+Opt+Cmd+Right

## Actions

- SimulateKeystroke: Ctrl+Opt+Cmd+Right
- ExecuteJavaScriptForAutomation
  ```javascript
  Application("VoiceOver").output("Next track view on All tracks.")
  ```
