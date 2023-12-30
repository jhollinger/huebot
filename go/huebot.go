package main

import (
    "os"
    //"gopkg.in/yaml.v3"
    "github.com/ogier/pflag"

    "github.com/jhollinger/huebot/cli"
    "github.com/jhollinger/huebot/subcommands"
)

func main() {
    cmd, args, opts := cli.GetInput()
    switch cmd {
    case "ls":
        if len(args) > 0 {
            helpAndExit()
        }
        // TODO get bridge
        retval := subcommands.List()
        os.Exit(retval)

    case "run":
        if len(args) < 1 {
            helpAndExit()
        }
        // TODO get bridge
        retval := subcommands.Run()
        os.Exit(retval)

    case "check":
        if len(args) < 1 {
            helpAndExit()
        }
        // TODO get bridge
        retval := subcommands.Check()
        os.Exit(retval)

    case "get-state":
        if len(opts.Inputs) < 1 || len(args) > 0 {
            helpAndExit()
        }
        // TODO if < 1 inputs show help and exit 1
        // TODO get bridge
        retval := subcommands.GetState()
        os.Exit(retval)

    case "set-ip":
        if len(args) != 1 || len(opts.Inputs) > 0 {
            helpAndExit()
        }
        retval := subcommands.SetIp()
        os.Exit(retval)

    case "clear-ip":
        if len(args) > 0 || len(opts.Inputs) > 0 {
            helpAndExit()
        }
        retval := subcommands.ClearIp()
        os.Exit(retval)

    case "unregister":
        if len(args) > 0 || len(opts.Inputs) > 0 {
            helpAndExit()
        }
        retval := subcommands.Unregister()
        os.Exit(retval)

    default:
        helpAndExit()
    }
}

func helpAndExit() {
    pflag.Usage()
    os.Exit(1)
}
