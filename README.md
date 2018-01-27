# Huebot

Orchestration and automation for Philips Hue devices. Huebot can be used as a Ruby library or a command line utility. Huebot programs are declared as YAML files.

    $ huebot dimmer.yml --light="Office Desk"

**dimmer.yml**

This (very simple) program starts with the light(s) on at full brightness, then enters an infinite loop of slowly dimming and raising the light(s). Since no color is specified, the light(s) will retain whatever color they last had.

```yaml
initial:
  switch: on
  brightness: 254

loop: true

transitions:
  - brightness: 150
    time: 100
    wait: 20

  - brightness: 254
    time: 100
    wait: 20
```

## UNDER ACTIVE DEVELOPMENT

**TODO**

* CLI command to list devices
* Multi-resource transitions
* Resource variables 
* Validate inputs against compiled programs
* Brief explanation various features
* Wiki entry with more examples
* Link to official Hue docs
