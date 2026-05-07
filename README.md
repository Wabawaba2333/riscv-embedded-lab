# WRDS — Wireless Realtime Distance System

A UWB + LoRa-based distance monitoring system for railway shunting yards,
designed as a non-safety-critical auxiliary system to support shunting
operators with real-time distance data between rail cars.

> Project status: Early prototype / proof-of-concept.
> The current code in this repository implements a single-node HC-SR04
> ultrasonic distance demo on GD32VF103, used to validate the firmware
> framework before the actual UWB hardware (DWM3000) and LoRa hardware
> (SX1262) are integrated. This is **not** the final system 

---

## Context

This project is developed at KTH by first-year students in collaboration
with KTH Järnvägsgruppen, with planned stakeholder
discussions with Alstom and Green Cargo.

WRDS is positioned as a bottom-layer safety redundancy — a portable,
low-cost, non-invasive distance measurement layer that complements existing
camera-based shunting assistance systems rather than replacing them.

## Target Architecture (Vision)

Three-node wireless network:

| Node | Role | Hardware | Communication |
|------|------|----------|---------------|
| A — Beacon  | UWB reference point      | GD32VF103 + DWM3000             | UWB transmitter        |
| B — Eye     | Measurement & forwarding | GD32VF103 + DWM3000 + SX1262    | UWB (measure) + LoRa (send) |
| C — Display | Cab interface            | GD32VF103 + SX1262 + display + buzzer | LoRa receiver    |

UWB handles how precisely distance is measured (cm-level, ToF).
LoRa handles whether the result reaches the cab (robust, long-range).
These are two separate physical problems — hence two separate radios.

## Current Implementation (this repo)

- MCU: GD32VF103 (RISC-V, 108 MHz)
- Sensor: HC-SR04 ultrasonic distance sensor (placeholder for DWM3000)
- Output: UART @ 115200 baud, distance printed in cm
- Pins: Trig → PA0, Echo → PA1, Vcc → 5V (J17.20), GND (J16.1)
- Timing: TIMER1 at 1 MHz (1 µs/tick) for pulse measurement

The HC-SR04 is intentionally used here as a stand-in to:
1. Validate the GD32 toolchain, GPIO, timer, and UART framework.
2. Establish the firmware structure (sensor read → distance compute → output)
   that will later be reused with DWM3000 by swapping only the driver layer.

## Hardware

- MCU board: GD32VF103 daughtercard on KTH Flemingsberg Makerspace IO board
- Sensor: HC-SR04 (5V, 4-pin: Vcc / Trig / Echo / Gnd)
- Connection: Female-to-female jumper wires

## Dependencies

This project depends on the GD32VF103 Firmware Library V1.0 by GigaDevice,
which is not included in this repository. Download it from the
[GigaDevice website](https://www.gigadevice.com/) and place it under
`lib/GD32VF103_Firmware_Library/`.

## Build & Flash

(Toolchain instructions — fill in based on your IDE: PlatformIO / Eclipse / RV-Link)

## Authors
- YuXuan Li
