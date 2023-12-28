package compiler

type Step struct {
    Transition TransitionStep `yaml:",omitempty"`
    Serial SerialStep `yaml:",omitempty"`
    Parallel ParallelStep `yaml:",omitempty"`
}

type TransitionStep struct {
    State DeviceState `yaml:",omitempty"`
    Wait bool
    Pause Pause
}

type SerialStep struct {
    Steps []Step
    Loop Loop
    Pause Pause
}

type ParallelStep struct {
    Steps []Step
    Loop Loop
    Pause Pause
}

type Loop struct {
    Pause Pause
    Infinite bool
    Counted int
    Random Random
    Timer Timer
    Deadline Deadline
}

type DeviceState struct {
    On bool
    Bri string
    Hue int
    Sat int
    Xy []float32
    Ct int
    Ctk int
    Transitiontime int
    Time float32
}

type Pause struct {
    Before TimeOption
    After TimeOption
}

type Timer struct {
    hours int
    minutes int
}

type Deadline struct {
    date string
    time string
}

type TimeOption struct {
    Seconds float32
    Random Random
}

type Random struct {
    min int
    max int
}
