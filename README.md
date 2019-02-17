# clockmod-mcu-asm
A fun RISC assembler / microcontroller hardware design project, used to create a time illusion during a stage play.

## Technical Documentation - Introduction
The idea for this project was to take the average off-the-shelf clock and modify it to run twice as fast for use in the stage play 1940s Radio Hour, where the off-air scenes ran in real-time, but the on-air “hour” is acted out in a half-hour scene. This gives the illusion to the audience the play is running in normal time.

The simplest method I found to do this (without harming the clock for future use) was to remove the clock battery and alternately energize the gear-coil in opposing directions at the right intervals using a Motorola PIC microcontroller (MCU), much like the one operating the clock originally.  What resulted was the above design, including a few bells and whistles (normal speed mode, sleep mode and status LED's) to make the project more interesting.  

This is the first time I’ve employed a 12F509 MCU. One should understand the odd arrangement of buttons to LED's here when they understand the unique pin setup for this particular chip.  A very small price to pay for a highly useful chip. 

Two switches turn the circuit on and toggle the speed mode, respectively. The green and red LEDs light to indicate Fast or Normal speed, respectively. The two yellow LEDs to the left will alternately blink as the current reverses, as an indicator of the relative speed of the clock (in fast-mode the LEDs blink twice as fast). 

The circuit is mounted on a small perfboard and powered by a pair of triple-A batteries.
