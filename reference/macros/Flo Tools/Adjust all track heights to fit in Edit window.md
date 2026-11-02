# Adjust all track heights to fit in Edit window

- Group: Flo Tools
- UID: 78CC12A0-8C45-495D-8DF0-11EC41F3BCB1
- Enabled: True
- Triggers: Ctrl+Opt+Cmd+Up; Ctrl+Opt+Cmd+Down

## Actions

- SimulateKeystroke: Ctrl+Opt+Cmd+Down
- ExecuteJavaScriptForAutomation
  ```javascript
  Application("VoiceOver").output("Adjust all track heights to fit in Edit window..")
  ```
