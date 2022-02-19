# VEEPROM-PIC8

Emulator for 24C256-style serial EEPROM using 8-pin/8-bit Microchip PIC.  Acts like a bootloader using I2C instead of UART.  Any PIC with I2C that is self-programmable can be used.  Currently 16F15313 is supported.

NOTE: VEEPROM has lower write endurance than a real EEPROM and is not designed to be used for high volume writes.

# Usage

With RPi, 24C256 connections are normally as follows:
* EEPROM SDA -> RPi SDA (Pin 3)
* EEPROM SCL -> RPi SCL (Pin 5)
* EEPROM Vcc -> RPi 3.3V (Pin 1)
* EEPROM GND -> RPi GND (e.g. Pin 6)

With VEEPROM-PIC8, the connections change as follows:
* VEEPROM SDA (RA2) -> RPi SDA (Pin 3)
* VEEPROM SCL (RA1) -> RPi SCL (Pin 5)
* VEEPROM Vdd -> RPi 5V (Pin 2 or 4); 5V needed for low-voltage programming
* VEEPROM GND -> RPi GND (e.g. Pin 6)

![Connection diagram](doc/connections.svg)

# Build

1. Open VEEPROM project in MPLABX<sup>*</sup>
2. Edit veeprom-pic8.asm as needed (to support additional chips or add features)
3. Clean and build
4. Use a PIC programmer such as PICKit 2 or 3 to flash .hex to PIC (first time only)
5. Connect PIC to RPi as described above

<sup>*</sup>NOTE: MPLABX v5.35 was the last version to support mpasmx; later versions use pic-as.  VEEPROM source code was written for mpasmx and requires changes before it will compile with pic-as.

After the PIC has been initially programmed, it can be reflashed when connected to the RPi using I2C instead of the PIC programmer (optional).

# Testing

From a command prompt on Raspberry OS:
* i2cdetect -l  #list I2C devices
* i2cdetect -y 1  #list devices on I2C bus# 1
* cat a-file | sudo tee /sys/class/i2c-dev/i2c-1/device/1-0050/eeprom  #write
* sudo cat /sys/class/i2c-dev/i2c-1/device/1-0050/eeprom  #read veeprom

# Reference Docs
- [Using 24C256 EEPROM with Raspberry Pi](https://lektiondestages.art.blog/2020/03/20/using-a-24c256-24lc256-eeprom-on-raspberry-pi-with-device-overlays/)
- [Configuring I2C on Raspberry Pi](https://learn.adafruit.com/adafruits-raspberry-pi-lesson-4-gpio-setup/configuring-i2c)
- [MPLABX older versions](https://www.microchip.com/en-us/development-tools-tools-and-software/mplab-ecosystem-downloads-archive)
- [PIC16F15313](https://www.microchip.com/en-us/product/PIC16F15313)
- [PICKitPlus](https://github.com/Anobium/PICKitPlus)

### (eof)
