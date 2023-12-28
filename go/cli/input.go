package cli

import (
    "fmt"
    "os"
    "github.com/ogier/pflag"
)

type deviceInput struct {
    Type string
    Name string
}

type deviceInputsVar struct {
    Type string
    Inputs *[]deviceInput
}

func (i *deviceInputsVar) String() string {
    return i.Type
}

func (i *deviceInputsVar) Set(value string) error {
    input := deviceInput{i.Type, value}
    *i.Inputs = append(*i.Inputs, input)
    return nil
}

type Options struct {
    Inputs *[]deviceInput
}

func GetInput() (string, []string, *Options) {
    var inputs []deviceInput
    var lights = deviceInputsVar{"Light", &inputs}
    var groups = deviceInputsVar{"Group", &inputs}

    pflag.VarP(&lights, "light", "l", "Name or ID of light")
    pflag.VarP(&groups, "group", "g", "Name or ID of group")
    pflag.Usage = usage

    pflag.Parse()
    all_args := pflag.Args()
    opts := Options{Inputs: &inputs}

    var cmd string
    var args []string
    if len(all_args) > 0 {
        cmd = all_args[0]
        args = all_args[1:]
    }
    return cmd, args, &opts
}

func usage() {
    fmt.Fprintf(os.Stderr, "Usage of %s:\n", os.Args[0])
    fmt.Fprintf(os.Stderr, `List all lights and groups:
    huebot ls

Run program(s):
    huebot run prog1.yaml [prog2.yml [prog3.json ...]] [options]

Run program from STDIN:
    cat prog1.yaml | huebot run [options]
    huebot run [options] < prog1.yaml
    huebot run -i [options]

Validate programs and inputs:
    huebot check prog1.yaml [prog2.yaml [prog3.yaml ...]] [options]

Print the current state of the given lights and/or groups:
    huebot get-state [options]

Manually set/clear the IP for your Hue Bridge (useful when on a VPN):
    huebot set-ip 192.168.1.20
    huebot clear-ip

Clear all connection config:
  huebot unregister

Options:
`)
    pflag.PrintDefaults()
}
