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
4. Use a PIC programmer such as PICKit 2 or 3 to flash .hex to PIC (only required for blank PIC)
5. Connect PIC to RPi as described above

<sup>*</sup>NOTE: MPLABX v5.35 was the last version to support mpasmx; latest versions use pic-as.  VEEPROM source code was written for mpasmx and requires changes in order to compile with pic-as.

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

## Usage as Breakout
![Breakout diagram](doc/breakout.svg)
To use the breakout function, connect RA3 of the WS281X-Splitter to the end of a WS281X pixel strip/string (or directly to a WS281X controller port) and then connect 24 or 32 WS281X pixels to RA0.  The first 24-bit RGB WS281X pixel value received by WS281X-Splitter will be broken out as follows:
- the first 24 WS281X pixels on RA0 will show the 24-bit RGB pixel value received (msb first)
- if more than 24 pixels are connected to RA0, then the next 8 pixels will display the FPS (msb first)

In the breakout, white pixels represent an "on" bit and red/green/blue/cyan represents an "off" bit within the first/second/third/fourth bytes.  For example, a pixel value of 0xF0CC55 received at 30 FPS would be displayed as follows:
![Breakout example](doc/breakout-example.png)

In your sequencing software, the only change needed is to insert one WS281X pixel representing where the WS281X-Splitter is connected.

# Current Status
under development

# Build Instructions
To assemble the firmware use steps 1 - 4, below.  To use the pre-assembled .hex file, skip directly to step 4.
1. Clone this repo
2. Install Microchip MPLABX 5.35 or GPASM or equivalent tool chain.  Note that MPLABX 5.35 was the last version that supported *MPASM* rather than *MPASMX*.
3. Build the project.  NOTE: custom build steps assume Linux command line but can be adjusted for other O/S.  Utilities such as cat, awk, and tee are used.
4. Flash the dist/WS281X-Splitter.hex file onto a PIC16F15313<sup>*</sup>.

<sup>*</sup> PIC16F15313 is a newer device supported by PICKit3.  However, it can be programmed using the older PICKit2 and the very useful [PICKitPlus software](https://anobium.co.uk).  <br/>Example command line (for Linux):<br/>
sudo ./pkcmd-lx-x86_64.AppImage -w -p16f15313 -fdist/WS281X-Splitter.hex -mpc -zv

# Version History

- Version 0.21.11 11/10/21 abandon CLC; use EUSART sync xmit instead; add multi-threading; get breakout working
- Version 0.21.9 9/30/21 switched to 8-bit PIC with CLC. basic split and breakout functions working for PIC16F15313
- Version 0.15.0 ?/?/16 started working on a Xilinx XC9572XL CPLD (72 macrocells) on a Guzunty board

# Reference Docs
- [MPLABX older versions](https://www.microchip.com/en-us/development-tools-tools-and-software/mplab-ecosystem-downloads-archive)
- [PIC16F15313](https://www.microchip.com/en-us/product/PIC16F15313)
- [AN1606](https://ww1.microchip.com/downloads/en/AppNotes/00001606A.pdf)
- [PICKitPlus](https://github.com/Anobium/PICKitPlus)
- [PICKitPlus command line](https://github.com/Anobium/PICKitPlus/wiki/pkcmd_lx_introduction)

### (eof)
