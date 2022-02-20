# VEEPROM-PIC8

Emulator for 24C256-style serial EEPROM (but lower capacity) using 8-pin/8-bit Microchip PIC.  Acts like a bootloader using I2C instead of UART.  Any PIC with I2C that is self-programmable can be used.  Actual capacity depends on which PIC is used.  Initially only 16F15313 is supported, which gives about 3KB of storage and is suited only for smaller storage needs.

NOTE: VEEPROM has lower write endurance than a real EEPROM and is not designed to be used for high volume writes. A future version might support higher endurance.  VEEPROM currently only uses 100KHz ("standard") speed.  A future version might support "fast" or "high-speed" speeds.

# Usage

With RPi, 24C256 connections are normally as follows:
* EEPROM SDA -> RPi SDA (Pin 3)
* EEPROM SCL -> RPi SCL (Pin 5)
* EEPROM A0-A2 -> 3-bit address
* EEPROM WP -> write-protect bit
* EEPROM Vcc -> RPi 3.3V (Pin 1)
* EEPROM GND -> RPi GND (e.g. Pin 6)

With VEEPROM-PIC8, the connections change as follows:
* VEEPROM SDA (RA2) -> RPi SDA (Pin 3); CAUTION: voltage shifter needed
* VEEPROM SCL (RA1) -> RPi SCL (Pin 5)
* 3 I/O pins -> available for custom use
* MCLR -> pull-up to 5V (optional push-button to ground for reset) for LVP
* VEEPROM Vdd -> RPi 5V (Pin 2 or 4); 5V needed for low-voltage programming
* VEEPROM GND -> RPi GND (e.g. Pin 6)

5V is needed for LVP (low-voltage programming).  A simple resistor divider can be used to shift the 5V SDA data signal down to 3.3V for RPi.  DO NOT CONNECT A 5V SIGNAL DIRECTLY TO RPI GPIO PINS.  TBD: maybe change veeprom to run at 3.3V to avoid the voltage issues.

![Connection diagram](doc/connections.svg)

# Build

1. Open VEEPROM project in MPLABX<sup>*</sup>
2. Edit veeprom-pic8.asm as needed (to support additional chips or add features)
3. Clean and build
4. Use a PIC programmer such as PICKit 2 or 3 to flash .hex to PIC (first time only)
5. Connect PIC to RPi as described above

After the PIC has been initially programmed, it can be reflashed while connected to the RPi using I2C instead of using a dedicated PIC programmer.

<sup>*</sup>NOTE: MPLABX v5.35 was the last version to support mpasmx; later versions use pic-as.  VEEPROM source code was written for mpasmx and requires changes before it will compile with pic-as.

# Testing

From a command prompt on Raspberry OS:
* i2cdetect -l  #list I2C devices
* i2cdetect -y 1  #list devices on I2C bus# 1
* cat a-file | sudo tee /sys/class/i2c-dev/i2c-1/device/1-0050/eeprom  #write
* sudo cat /sys/class/i2c-dev/i2c-1/device/1-0050/eeprom  #read veeprom

# Status

UNDER DEVELOPMENT

Possible future changes:
- support additional PICs?
- implement higher endurance? (see AN1095)
- implement higher speeds?
- run at 3.3V and eliminate voltage shifter?

# Reference Docs
- [Using 24C256 EEPROM with Raspberry Pi](https://lektiondestages.art.blog/2020/03/20/using-a-24c256-24lc256-eeprom-on-raspberry-pi-with-device-overlays/)
- [Configuring I2C on Raspberry Pi](https://learn.adafruit.com/adafruits-raspberry-pi-lesson-4-gpio-setup/configuring-i2c)
- [PiPIC Pi<->PIC using I2C](https://github.com/oh7bf/PiPIC)
- [PIC I2C Examples](https://microcontrollerslab.com/i2c-communication-pic-microcontroller/)
- [Emulating High Endurance EEPROM](https://ww1.microchip.com/downloads/en/AppNotes/01095c.pdf)
- [24C256 Datasheet](https://ww1.microchip.com/downloads/en/DeviceDoc/doc0670.pdf)
- [MPLABX older versions](https://www.microchip.com/en-us/development-tools-tools-and-software/mplab-ecosystem-downloads-archive)
- [PIC16F15313](https://www.microchip.com/en-us/product/PIC16F15313)
- [PICKitPlus](https://github.com/Anobium/PICKitPlus)

### (eof)
