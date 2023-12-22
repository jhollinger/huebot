# Huebot

Program your Hue lights using YAML or JSON!

    $ huebot run dimmer.yaml --light="Office Desk"

A few examples are below. [See the Wiki](https://github.com/jhollinger/huebot/wiki) for full documentation.

**dimmer.yaml**

This (very simple) program starts with the light(s) on at full brightness, then enters an hour and a half long loop of slowly dimming and raising the light(s). It finishes by turning them off again. Since no color is specified, the light(s) will retain whatever color they last had.

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
          on: true
          bri: 254

    - serial:
        loop:
          timer:
            hours: 1
            minutes: 30
        steps:
          - transition:
              state:
                bri: 150
                time: 10 # 10 second transition
              pause:
                after: 2   # 2 second pause before the next step

          - transition:
              state:
                bri: 254
                time: 10 # 10 second transition
              pause:
                after: 2   # 2 second pause before the next step

    - transition:
        state:
          on: false
```

**party.yaml**

This more complicated program starts by switching devices on, then enters an infinite loop of two parallel steps. One branch fades up and down while the other branch is fading more lights down _then_ up.

```yaml
serial:
  steps:
    # Turn all inputs on to a mid brightness
    - transition:
        devices:
          inputs: $all
        state:
          on: true
          bri: 100

    # Run these steps in parallel in an infinite loop
    - parallel:
        loop:
          infinite: true
        steps:
          # Parallel branch 1: Fade inputs #1 and #3 up and down
          - serial:
              devices:
                inputs:
                  - $1
                  - $3
              steps:
                - transition:
                    state:
                      bri: 254
                      time: 10 # transition over 10 seconds
                    pause:
                      after: 5   # pause an extra 5 sec after the transition
                - transition:
                    state:
                      bri: 25
                      time: 10
                    pause:
                      after: 5

          # Parallel branch 2: Fade inputs #2 and #4 down and up
          - serial:
              devices:
                inputs:
                  - $2
                  - $4
              steps:
                - transition:
                    state:
                      bri: 25
                      time: 10
                    pause:
                      after: 5
                - transition:
                    state:
                      bri: 254
                      time: 10
                    pause:
                      after: 5
```

[See the Wiki](https://github.com/jhollinger/huebot/wiki) for more documentation and examples.

## Install

    gem install huebot

Having trouble with Hue Bridge auto discovery? Me too. If you know your bridge's IP (and ideally have assigned it a static one), you can set it manually:

    huebot set-ip <your bridge's IP>

Configuration is stored in `~/.config/huebot`.

## License

Huebot is licensed under the MIT license (see LICENSE file).
