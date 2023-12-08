# Huebot

Program your Hue lights in YAML!

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

Having trouble with Hue Bridge auto discovery? Me too. If you know your bridge's IP (and ideally have assigned it a static one), you can set it manually:

    huebot set-ip <your bridge's IP>

Configuration is stored in `~/.config/huebot`.

## License

Huebot is licensed under the MIT license (see LICENSE file).

**TODO**

* Validate number of inputs against compiled programs
* More explanation various features in Wiki
* More examples in Wiki
