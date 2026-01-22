
## FPGA Note Generator, UART Transmitter, and Real-Time Audio Playback
 
**Hardware:** DE10-Lite FPGA + Arduino Uno (USB to Serial bridge)

---

## Project Overview

This project generates selectable musical notes on an FPGA as a square wave derived from the **50 MHz** onboard clock. The system measures the note frequency by timing consecutive rising edges, then:

- Displays the measured frequency on the **6-digit seven-segment display**
- Sends the data over **UART (115200, 8N1)** to a laptop
- A custom laptop program plays the tone in real time through the laptop speakers

---

## Directory Structure (Top Level)

This repository contains a Quartus FPGA design for a note (tone) generator. At the top level you will find Verilog RTL modules, Quartus project/config files, build artifacts, simulation resources, a small C++ helper component, and documentation/submission packages.

├── 3201_Report.pdf
├── db
├── Freq_Measure.v
├── Freq_Measure.v.bak
├── incremental_db
├── Note_Generator.qpf
├── note_player
├── note_player.cpp
├── Note_Reader_assignment_defaults.qdf
├── Note_Reader.qsf
├── Note_Reader.qws
├── Note_Reader.v
├── Note_Reader.v.bak
├── output_files
├── Project Verilog.zip
├── qar_info.json
├── README.md
├── simulation
├── sketch_dec1a
├── Square_Wave_Generator.v
├── Square_Wave_Generator.v.bak
├── UART_TX.v
└── UART_TX.v.bak


### RTL Source (Verilog)
- `Note_Reader.v`  
  Main RTL logic for reading/handling note data and driving playback behavior.
- `Square_Wave_Generator.v`  
  Tone generation block (square-wave output at target note frequencies).
- `Freq_Measure.v`  
  Frequency measurement/verification logic (used for validation or calibration).
- `UART_TX.v`  
  UART transmit module for serial output (debug/status/data).

- `*.v.bak`  
  Backup copies of Verilog files (manual snapshots).

### Quartus Project Files
- `Note_Generator.qpf`  
  Quartus project file.
- `Note_Reader.qsf`  
  Quartus settings (device selection, pin assignments, compile options).
- `Note_Reader.qws`  
  Quartus workspace metadata.
- `Note_Reader_assignment_defaults.qdf`  
  Default assignment configuration.

### Build Outputs and Quartus Databases
- `output_files/`  
  Compilation outputs (e.g., programming files and reports).
- `db/`  
  Quartus compilation database.
- `incremental_db/`  
  Incremental compilation cache.
- `qar_info.json`  
  Quartus archive/packaging metadata.

### Simulation
- `simulation/`  
  Simulation-related files (testbenches, scripts, wave configs, or outputs).

### Host/Software Components
- `note_player.cpp`  
  C++ helper program (typically used to generate/send note sequences or assist testing).
- `note_player/`  
  Folder containing additional files for the note player component (source/build/assets).

### Documentation and Submissions
- `README.md`  
  Project overview and usage instructions.
- `3201_Report.pdf`  
  Course report document.
- `Project Verilog.zip`  
  Packaged Verilog sources for submission/sharing.

### Misc
- `sketch_dec1a/`  
  Likely an Arduino (or similar) sketch folder used for interfacing/testing.
  
---

## Top-Level Entity

The top-level Verilog module is:

- **`Note_Reader`**

It interfaces directly with DE10-Lite hardware signals (CLOCK_50, switches, push buttons, UART TX, LEDs, and 7-seg). All internal components are instantiated inside `Note_Reader`, including:

- UART transmitter
- Square-wave tone generator
- Frequency measurement unit
- ASCII formatting logic
- Debounced input handling
- Seven-segment display scan logic

---

## Logic Breakdown

### Combinational Logic
- Pitch lookup table (one octave, C through B)
- Octave scaling (shift-based) to compute divider `N`
- Binary to BCD conversion for seven-segment display
- ASCII formatting for UART output
- Simple multiplexers for display and status

### Sequential Logic
- Divider counter toggling the square-wave output every `N` cycles
- Free-running timestamp counter
- Synchronized edge detectors
- Period and high-time capture registers
- Integer division to compute frequency (Hz) once per new period
- Seven-segment scan timer
- Debounced two-button interface
- UART transmitter shift register plus baud-tick generator

---

## Features

- Manual selection of **48 musical notes**
  - 12 pitch classes (C through B) across 4 octaves (O3 to O6)
- Frequency measurement using **50 MHz timestamping** (rising-edge period capture)
  - Example: **A4 ≈ 0440** shown on the seven-seg display
- UART transmission at **115200 bps (8N1)** sending ASCII lines such as:
  - `A4,0440,0441\r\n`
- Real-time laptop audio playback using a custom C++ program with **PortAudio**
- Freeze and mute controls
- Force-A4 verification switch
- LED status indicators
- Arduino Uno used as a **USB to Serial bridge** between FPGA and laptop

---

## UART Output Format

The FPGA transmits ASCII text lines at **115200 8N1**. Example:

`A4,0440,0441\r\n`

(Format includes the selected note label and measured frequency fields.)

---

## Build and Run (Laptop Program)

**Compile:**
```bash
g++ -std=c++17 -Wall -O2 note_player.cpp -o note_player -lportaudio
```
**Run (example):**
```bash
./note_player /dev/ttyACM0
```

## Pins ##
- PIN_AA8 (GPIO_[24]): GPIO for UART message

- PIN_AA9 (GPIO_[22]): GPIO for square wave


