# VEEPROM-PIC8

Emulator for 24C256-style serial EEPROM (but lower capacity) using 8-pin/8-bit Microchip PIC.  Any PIC with I2C can be used - actual capacity depends on which PIC is used.  Initially only implemented on 16F15313 (which gives about 3KB of storage and is suited only for smaller storage needs) but other PICs can be added as needed.

NOTE: VEEPROM has lower write endurance than a real EEPROM and is not designed to be used for high frequency writes. A future version might support higher endurance.  VEEPROM currently only uses 100KHz ("standard") mode.  A future version might support "high speed" or "fast plus" modes.

# Usage

With a RPi hat, 24C256 connections are normally as follows:
* EEPROM SDA -> RPi SDA (Pin 3)
* EEPROM SCL -> RPi SCL (Pin 5)
* EEPROM A0-A2 -> 3-bit address
* EEPROM WP -> write-protect
* EEPROM Vcc -> RPi 3.3V (Pin 1) or 5V (pin 2 or 4)
* EEPROM GND -> RPi GND (e.g. Pin 6 or 39)

With VEEPROM-PIC8, the connections change as follows:
* VEEPROM SDA (RA0) -> RPi SDA (Pin 3); CAUTION: use voltage shifter if VDD > 3.3V
* VEEPROM SCL (RA1) -> RPi SCL (Pin 5); CAUTION: use voltage shifter if VDD > 3.3V
* VEEPROM VPP/MCLR (RA3) -> RPi EN (Pin 28); CAUTION: use voltage shifter if VDD > 3.3V; also used as Program pin -> pull-up to VDD (optional N/O push-button to ground for reset) for LVP reset
* 3 I/O pins (RA2/4/5) -> available for custom use
* VEEPROM VDD -> RPi 3.3V or 5V (Pin 1 or 2); 5V requires voltage shifter on RA0/1
* VEEPROM GND -> RPi GND (e.g. Pin 6)

The RPi itself also serves as an ICSP PIC programmer using the above connections.  You can actually use any RPi GPIO pins - I chose pins 3, 5, and 28 so VEEPROM would work with a DPI24 Pi Hat.

CAUTION: DO NOT CONNECT A 5V SIGNAL DIRECTLY TO RPI GPIO PINS.  If 5V is used, a simple resistor divider or other device can be used to shift the 5V SDA data signal down to 3.3V for RPi.  This is not needed if running the PIC at 3.3V, although a 470 ohm series resistor can be used for "safety".

![Connection diagram](doc/connections.svg)

There is an example Pi Hat/BBB Cape PCB in the DPI24Hat-PCB folder.

# Build/Setup

1. Open VEEPROM project in MPLABX<sup>*</sup>
2. Edit veeprom-pic8.asm as needed (to support additional chips or features)
3. Clean and build
4. Use the instructions at https://www.pedalpc.com/blog/program-pic-raspberry-pi/ to install Pickle on the RPi.
* ptest VPP 5  #verify VPP is working using Pickle
* ptest PGC 5  #verify PGC is working using Pickle
* ptest PGD 5  #verify PGD is working using Pickle
5. With PIC connected to RPi as described above:
* n14 select #verify that PIC device is listed
* n14 lvp id #verify PIC device is detected
6. Copy the VEEPROM.hex file onto the RPi where the Pi Hat VEEPROM is connected.  For example: sudo scp ../firmware/VE*.hex fpp@192.168.1.101:veeprom.hex
7. n14 lvp program veeprom.hex #program the PIC using RPi + Pickle
8. n14 lvp verify veeprom.hex #verify flash

A traditional PIC programmer such as PICKit 2 or 3 *can* be used to flash the .hex file to PIC.  *Alternatively*, the RPi can be used as the ICSP programmer instead of using a dedicated PIC programmer by using Pickle.

<sup>*</sup>NOTE: MPLABX v5.35 was the last version to support mpasmx; later versions use pic-as.  VEEPROM source code was written for mpasmx and requires changes before it will compile with pic-as.

# Testing

To test on RPi (using pins 3 + 5), from a command prompt on Raspberry OS:
* i2cdetect -l  #list I2C devices
* i2cdetect -y 1  #list devices on I2C bus# 1
* i2cdump -y 1 0x50  #dump first 256 bytes of veeprom
* ?? cat a-file | sudo tee /sys/class/i2c-dev/i2c-1/device/1-0050/eeprom  #write
* ?? sudo cat /sys/class/i2c-dev/i2c-1/device/1-0050/eeprom  #read veeprom
* sudo sh eepflash.sh -y -r -f=veeprom.eep -t=24c256 -d=1 -a=50
* hexdump -C veeprom.eep |more

NOTE: i2cdump does *not* work the same way as the RPi eeprom driver. i2cdump seems to send many 1-byte read requests and only reads 256 bytes, while eepflash/dd use page reads and gets the entire veeprom contents.

# Status

SOMEWHAT WORKING
- I2C working at 100 KHz; RPi doesn't handle clock-stretching :( so run i2c at slower "standard" speed
- JSON data: encoded okay, hard-coded for now (re-program PIC to change)
- TODO: clean up source code :P

Possible future changes:
- support additional PICs?
- implement higher eeprom endurance? (see Microchip AN1095)
- implement higher i2c speeds?
- detect BBB and respond with alternate eeprom contents
- PCB fixes
- bootloader? RPi + Pickle works now as ICSP programmer even with blank PICs; a bootloader would require pre-programmed PICs so maybe not worth the effort

# Reference Docs
- NOTE: PIC I2C examples are useless; they all use clock stretching, and have some weird logic as well
- *extremelely* helpful [How to Program a PIC Using a Raspberry Pi](https://www.pedalpc.com/blog/program-pic-raspberry-pi/)
- Raspberry Pi Hat info + utilities, eepromutils (https://github.com/raspberrypi/hats)
- Pickle Microchip PIC ICSP (https://wiki.kewl.org/dokuwiki/projects:pickle#)
- [Using 24C256 EEPROM with Raspberry Pi](https://lektiondestages.art.blog/2020/03/20/using-a-24c256-24lc256-eeprom-on-raspberry-pi-with-device-overlays/)
- [Configuring I2C on Raspberry Pi](https://learn.adafruit.com/adafruits-raspberry-pi-lesson-4-gpio-setup/configuring-i2c)

Other related:
- [PiPIC Pi<->PIC using I2C](https://github.com/oh7bf/PiPIC)
- [PIC I2C Examples](https://microcontrollerslab.com/i2c-communication-pic-microcontroller/)
- [Emulating High Endurance EEPROM](https://ww1.microchip.com/downloads/en/AppNotes/01095c.pdf)
- [24C256 Datasheet](https://ww1.microchip.com/downloads/en/DeviceDoc/doc0670.pdf)
- [MPLABX older versions](https://www.microchip.com/en-us/development-tools-tools-and-software/mplab-ecosystem-downloads-archive)
- [PIC16F15313](https://www.microchip.com/en-us/product/PIC16F15313)
- [PICKitPlus](https://github.com/Anobium/PICKitPlus)

##### (eof)
