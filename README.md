# Huebot

Orchestration and automation for Philips Hue devices. Huebot can be used as a Ruby library or a command line utility. Huebot programs are declared as YAML files.

    $ huebot run dimmer.yml --light="Office Desk"

**dimmer.yml**

This (very simple) program starts with the light(s) on at full brightness, then enters an infinite loop of slowly dimming and raising the light(s). Since no color is specified, the light(s) will retain whatever color they last had.

```yaml
initial:
  switch: on
  brightness: 254
  device: $all

loop: true

transitions:
  - device: $all
    brightness: 150
    time: 100
    wait: 20

  - device: $all
    brightness: 254
    time: 100
    wait: 20
```

The variable `$all` refers to all lights and/or groups passed in on the command line. They can be also referred to individually as `$1`, `$2`, `$3`, etc. The names of lights and groups can also be hard-coded into your program. [See examples in the Wiki.](https://github.com/jhollinger/huebot/wiki)

## Install

    gem install huebot

## License

Huebot is licensed under the MIT license (see LICENSE file).

A patched version of the "hue" gem is bundled in huebot's codebase (to remove a dependency that's unnecessarily annoying to install). The license for it can be found at `lib/hue/LICENSE`.

## UNDER ACTIVE DEVELOPMENT

**TODO**

* Validate number of inputs against compiled programs
* Brief explanation various features
* Wiki entry with more examples
* Link to official Hue docs
