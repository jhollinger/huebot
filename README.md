# Huebot

Program your Hue lights!

    $ huebot run dimmer.yml --light="Office Desk"

**dimmer.yml**

This (very simple) program starts with the light(s) on at full brightness, then enters an hour long loop of slowly dimming and raising the light(s). It finishes by turning them off again. Since no color is specified, the light(s) will retain whatever color they last had.

```yaml
serial:
  devices:
    lights:
      - LR Lamp 1
      - LR Lamp 2
    groups:
      - Dining Room
  steps:
    - transition:
        state:
          switch: on
          bri: 254

    - serial:
        loop:
          timer:
            hours: 1
        steps:
          - transition:
              state:
                bri: 150
                time: 10 # 10 second transition
              pause: 2   # 2 second pause before the next step

          - transition:
              state:
                bri: 254
                time: 10 # 10 second transition
              pause: 2   # 2 second pause before the next step

    - transition:
        state:
          switch: off
```

[See the Wiki](https://github.com/jhollinger/huebot/wiki) for full documentation and examples.

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
