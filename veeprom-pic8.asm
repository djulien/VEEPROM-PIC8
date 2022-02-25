    title  "VEEPROM-PIC8 - serial EEPROM emulator for 8-pin/8-bit Microchip PIC"
;================================================================================
; File:     veeprom-pic8.asm
; Date:     2/19/2022
; Version:  0.22.02
; Author:   djulien@thejuliens.net, (c)2022 djulien@thejuliens.net
; Device:   PIC16F15313 (midrange Microchip 8-pin PIC) or equivalent running @8 MIPS
;
; Peripherals used: Timer0, Timer2, MSSP, NVM
; Compiler: mpasmx(v5.35), NOT pic-as; NOTE: custom build line is used for source code fixups
; IDE:      MPLABX v5.35 (last one to include mpasm)
; Description:
;   VEEPROM-PIC8 is a 24C256-style EEPROM emulator for 8-pin/8-bit Microchip PIC processors.
;   It uses LVP and flash storage to emulate EEPROM storage, but with lower capacity and endurance.
;   Capacity depends on the device used.  For example, a 16F15313 would give about 3KB storage.
;   Flash tolerates fewer write cycles than EEPROM, but software mods could compensate in future.
; Build instructions:
; 1. Open project in MPLABX
; 2. Edit as needed to support other devices (@line ~4200) or additional features.  In general,
;    adding new devices just involves renaming symbols for consistency or changing memory size.
; 3. Clean + build.
;    Use mpasmx, not pic-as.  Builds .hex file in Absolute mode.
;    Custom pre- and post- build steps are used to help preprocessing or declutter .LST file
; 4. Flash .hex to PIC.  Use PICKit2 or 3 or equivalent; PICKit2 requires PICKitPlus for newer PICs.
;    After initial programming, PIC can be reflashed using I2C in-circuit.
; Wiring:
;  RA0 = I2C data (open drain); use voltage shifter if VDD != 3.3V
;  RA1 = I2C clock (open drain); use voltage shifter if VDD != 3.3V
;  RA2 = debug output (1 or more WS281X pixels), comment out #define to disable
;  RA3 = MCLR/VPP (LVP)
;  RA4 - RA5 = available for custom usage
; Testing:
;  i2cdetect -l
;  sudo i2cdetect -y 1
;  i2cget -y 1 0x50 0x00  or  i2cset
;  i2cdump -y 1 0x50
;================================================================================
    NOLIST; reduce clutter in .LST file
    NOEXPAND; don't show macro expansions until requested
;NOTE: ./Makefile += AWK, GREP
;check nested #if/#else/#endif; @__LINE__: grep -vn ";#" this-file | grep -e "#if" -e "#else" -e "#endif; @__LINE__"
;or:    sed 's/;.*//' < ~/MP*/ws*/wssplitter.asm | grep -n -e " if " -e " else" -e " end" -e " macro" -e " while "
;grep -viE '^ +((M|[0-9]+) +)?(EXPAND|EXITM|LIST)([ ;_]|$$)'  ./build/${ConfName}/${IMAGE_TYPE}/wssplitter.o.lst > wssplitter.LST
;see also ~/Doc*s/mydev/_xmas2014/src/firmware, ~/Doc*s/ESOL-fog/src/Ren*Chipi*Firmware
;custom build step:
;pre: cat wssplitter.asm  |  awk '{gsub(/__LINE__/, NR)}1' |  tee  "__FILE__ 1.ASM"  "__FILE__ 2.ASM"  "__FILE__ 3.ASM"  "__FILE__ 4.ASM"  "__FILE__ 5.ASM"  "__FILE__ 6.ASM"  "__FILE__ 7.ASM"  >  __FILE__.ASM
;post: rm -f nope__FILE__* &amp;&amp; cp ${ImagePath} /home/dj/Documents/ESOL-fog/ESOL21/tools/PIC/firmware &amp;&amp;  awk 'BEGIN{IGNORECASE=1} NR==FNR { if ($$2 == "EQU") EQU[$$1] = $$3; next; } !/^ +((M|[0-9]+) +)?(EXPAND|EXITM|LIST)([ ;_]|$$)/  { if ((NF != 2) || !match($$2, /^[0-9A-Fa-f]+$$/) || (!EQU[$$1] &amp;&amp; !match($$1, /_[0-9]+$$/))) print; }'  /opt/microchip/mplabx/v5.35/mpasmx/p16f15313.inc  ./build/${ConfName}/${IMAGE_TYPE}/wssplitter.o.lst  >  wssplitter.LST
#ifndef HOIST
#define HOIST  0; //HOIST is used to rearrange source code top-down => bottom-up order
#include __FILE__; self
;    messg no hoist, app config/defs @46
    LIST_PUSH TRUE, @__LINE__
;    EXPAND_PUSH FALSE, @__LINE__
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;//compile-time options:
#define WANT_DEBUG; //DEV/TEST ONLY; shows status on RA2
;//#define WANT_ISR  10; //ISR not used; uncomment to reserve space for ISR (or jump to)
#define FOSC_FREQ  (32 MHz); //max speed; lower speed might work

;//pin assignments:
#define FRPANEL  RA4; //debug "front panel" display
#define SDA1_PIN  RA0; //make I2C consistent with ICSP (defaults to RA2)
#define SCL1_PIN  RA1; //make I2C consistent with ICSP
#define RGB_ORDER  0x213; //R = byte[1-1], G = byte[2-1], B = byte[3-1]; default = 0x123 = RGB

;    EXPAND_POP @__LINE__
;    LIST_DEBUG @63
    LIST_POP @__LINE__
;    LIST_DEBUG @65
;    messg end of !hoist @64
#undefine HOIST; //preserve state for plumbing @eof
#else
#if HOIST == 555; //top-level; mpasm must see this last
;    LIST_DEBUG @__LINE__
    LIST_PUSH TRUE, @__LINE__
;    LIST_DEBUG @__LINE__
;    EXPAND_PUSH TRUE, @__LINE__
;; custom main ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;    NOLIST
;mac1 macro arg
;    EXPAND_PUSH TRUE, @__LINE__
;    movlw arg
;    EXPAND_POP @__LINE__
;    endm; @__LINE__
;    LIST
;    mac1 11
;    LIST_PUSH FALSE, @__LINE__
;    mac1 22
;    LIST_POP @__LINE__

;    messg djdebug @__LINE__
    at_init TRUE
    PinMode FRPANEL, OutLow; //set asap to avoid junk on line
loop: DROP_CONTEXT;
    ws1_sendpx BITWRAP(LATA, FRPANEL), LITERAL(0x010000), FIRSTPX, RESERVE(0), RESERVE(0); NOP 2, NOP 4; //ORG$, ORG$;
; messg here1 @__LINE__
;    setbit LATA, FRPANEL, FALSE;
; messg here2 @__LINE__
;    WAIT 4 sec, RESERVE(0), RESERVE(0); busy wait
    CALL wait4sec;
    ws1_sendpx BITWRAP(LATA, FRPANEL), LITERAL(0x000100), FIRSTPX, RESERVE(0), RESERVE(0); NOP 2, NOP 4; //ORG$, ORG$;
;    setbit LATA, FRPANEL, FALSE;
;CURRENT_FPS_usec = -1
;    WAIT 4 sec, RESERVE(0), RESERVE(0); busy wait
    CALL wait4sec;
    ws1_sendpx BITWRAP(LATA, FRPANEL), LITERAL(0x000001), FIRSTPX, RESERVE(0), RESERVE(0); NOP 2, NOP 4; //ORG$, ORG$;
;    setbit LATA, FRPANEL, FALSE;
;CURRENT_FPS_usec = -1
;    WAIT 4 sec, RESERVE(0), RESERVE(0); busy wait
    CALL wait4sec;
    ws1_sendpx BITWRAP(LATA, FRPANEL), LITERAL(0), FIRSTPX, RESERVE(0), RESERVE(0); NOP 2, NOP 4; //ORG$, ORG$;
;    setbit LATA, FRPANEL, FALSE;
;    WAIT 4 sec, RESERVE(0), RESERVE(0); busy wait
    CALL wait4sec;
    ws1_sendpx BITWRAP(LATA, FRPANEL), LITERAL(0x010001), FIRSTPX, RESERVE(0), RESERVE(0); NOP 2, NOP 4; //ORG$, ORG$;
;    setbit LATA, FRPANEL, FALSE;
;    WAIT 4 sec, RESERVE(0), RESERVE(0); busy wait
    CALL wait4sec;
    ws1_sendpx BITWRAP(LATA, FRPANEL), LITERAL(0x000101), FIRSTPX, RESERVE(0), RESERVE(0); NOP 2, NOP 4; //ORG$, ORG$;
;    setbit LATA, FRPANEL, FALSE;
;    WAIT 4 sec, RESERVE(0), RESERVE(0); busy wait
    CALL wait4sec;
    GOTO loop;
    at_init FALSE

wait4sec: DROP_CONTEXT;
    WAIT 4/2 sec, RESERVE(0), RESERVE(0); busy wait
;    set_timeout 1 sec/2, NOP 1; RESERVE(0); YIELD; //display for 1/2 sec
    RETURN;

;    EXPAND_POP @__LINE__
    LIST_POP @__LINE__
;    messg end of hoist 5 @__LINE__
;#else; too deep :(
#endif; @__LINE__
#if HOIST == 5; //top-level; mpasm must see this last
;    messg hoist 5: custom main @__LINE__
    LIST_PUSH TRUE, @__LINE__
;    EXPAND_PUSH FALSE, @__LINE__
;; custom main ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    at_init TRUE
    PinMode FRPANEL, OutLow; //set asap to prevent junk on line
    at_init FALSE

    THREAD_DEF front_panel, 4;

    BITDCL fpdirty;
    nbDCL24 fpcolor;

#if 0
fptest macro
;    setbit LATA, RA0, TRUE;
;    mov24 fpcolor, LITERAL(0x020000);
    ws1_sendpx BITWRAP(LATA, FRPANEL), LITERAL(0x020000), FIRSTPX, RESERVE(0), RESERVE(0); NOP 2, NOP 4; //ORG$, ORG$;
    WAIT 1 sec, YIELD, YIELD_AGAIN
;    setbit LATA, RA0, FALSE;
;    mov24 fpcolor, LITERAL(0x000200);
    ws1_sendpx BITWRAP(LATA, FRPANEL), LITERAL(0x000200), FIRSTPX, RESERVE(0), RESERVE(0); NOP 2, NOP 4; //ORG$, ORG$;
    WAIT 1 sec, YIELD, YIELD_AGAIN
;    mov24 fpcolor, LITERAL(0x000002);
    ws1_sendpx BITWRAP(LATA, FRPANEL), LITERAL(0x000002), FIRSTPX, RESERVE(0), RESERVE(0); NOP 2, NOP 4; //ORG$, ORG$;
    WAIT 1 sec, YIELD, YIELD_AGAIN
    ws1_sendpx BITWRAP(LATA, FRPANEL), LITERAL(0), FIRSTPX, RESERVE(0), RESERVE(0); NOP 2, NOP 4; //ORG$, ORG$;
    WAIT 1 sec, YIELD, YIELD_AGAIN
    endm; @__LINE__
#endif; @__LINE__

;//show LED for 1/10 sec then turn off:
front_panel: DROP_CONTEXT;
;    fptest
    whilebit BITPARENT(fpdirty), FALSE, YIELD; //wait for new data
    setbit BITPARENT(fpdirty), FALSE;
;//    ws1_sendpx BITWRAP(LATA, FRPANEL), fpcolor, FIRSTPX, RESERVE(0), RESERVE(0); NOP 2, NOP 4; //ORG$, ORG$;
    setbit LATA, FRPANEL, TRUE;
;NOTE: assumes >= 50 usec until next update, so no explicit wait 50 usec here
;    GOTO front_panel;
;    messg ^^^ remove @__LINE__
;    CALL sendpx;
;working:    GOTO front_panel;
    set_timeout 1 sec/2, YIELD; //display for 1/2 sec
;    GOTO front_panel;
;    whilebit is_timeout FALSE, ORG$+3
;        CONTEXT_RESTORE before_whilebit
;        ifbit BITPARENT(fpdirty), TRUE, GOTO front_panel;
;	YIELD;
;        CONTEXT_RESTORE after_whilebit
;    whilebit is_timeout FALSE, ORG$;
;    ws1_sendpx BITWRAP(LATA, FRPANEL), LITERAL(0), FIRSTPX, RESERVE(0), RESERVE(0); NOP 2, NOP 4; //ORG$, ORG$; //clear display
    setbit LATA, FRPANEL, FALSE;
;    mov24 fpcolor, LITERAL(0);
;    CALL sendpx;
    set_timeout 50 usec, YIELD;
    GOTO front_panel;
;sendpx: DROP_CONTEXT;
;    ws1_sendpx BITWRAP(LATA, FRPANEL), fpcolor, ORG$-1, ORG$, ORG$;
;    return;
    
    THREAD_END;


;    nbDCL8 eepromAddress;
    BITDCL is_addr; //initialized to 0
    nbDCL8 i2c_data; //non-banked to reduce bank switching during i2c processing
    b0DCL veepbuf, :16; //NOTE: addressing is simpler if this is placed @start of bank 0
    
    at_init TRUE;
;    mov24 fpcolor, LITERAL(0);
;    PinMode SDA1_PIN, OutOpenDrain;
;    PinMode SCL1_PIN, OutOpenDrain;
    i2c_init LITERAL(0x50); FPP looks for capes/hats @0x50
;    mov8 eepromAddress, LITERAL(0);
    LDI veepbuf;
    DW 0x012, 0x345, 0x678, 0x9ab, 0xcde, 0xf00;
    DW 0x55A, 0xA55, 0xAA5, 0x5AA | LDI_EOF;
;//    mov8 slaveWriteType, LITERAL(SLAVE_NORMAL_DATA);
    mov16 FSR0, LITERAL(LINEAR(veepbuf)); //CAUTION: LDI uses FSR0/1
    at_init FALSE;

    THREAD_DEF veeprom, 6; 4 levels

#if 0
test macro
    mov24 fpcolor, LITERAL(0x020000);
    setbit BITPARENT(fpdirty), TRUE;
;    ws1_sendpx BITWRAP(LATA, FRPANEL), fpcolor, ORG$-1, ORG$, ORG$;
;    WAIT 4 sec;
;    fps_init 4 sec;
;    WAIT 4 sec, YIELD, YIELD_AGAIN;
    CALL wait4sec;
;    wait4frame YIELD, YIELD_AGAIN;
    mov24 fpcolor, LITERAL(0x000200);
    setbit BITPARENT(fpdirty), TRUE;
;    ws1_sendpx BITWRAP(LATA, FRPANEL), fpcolor, ORG$-1, ORG$, ORG$;
;    WAIT 4 sec, YIELD, YIELD_AGAIN;
    CALL wait4sec;
;    wait4frame YIELD, YIELD_AGAIN;
    mov24 fpcolor, LITERAL(0x000002);
    setbit BITPARENT(fpdirty), TRUE;
;    ws1_sendpx BITWRAP(LATA, FRPANEL), fpcolor, ORG$-1, ORG$, ORG$;
;    WAIT 4 sec, YIELD, YIELD_AGAIN;
    CALL wait4sec;
    GOTO veeprom;
;    wait4frame YIELD, YIELD_AGAIN;
    mov24 fpcolor, LITERAL(0);
    setbit BITPARENT(fpdirty), TRUE;
;    ws1_sendpx BITWRAP(LATA, FRPANEL), fpcolor, ORG$-1, ORG$, ORG$;
;    WAIT 4 sec, YIELD, YIELD_AGAIN;
    CALL wait4sec;
;    wait4frame YIELD, YIELD_AGAIN;
    GOTO veeprom;
    endm; @__LINE__

wait4sec: DROP_CONTEXT;
    WAIT 4 sec/4, YIELD, YIELD_AGAIN; RESERVE(0), RESERVE(0); busy wait
;    set_timeout 1 sec/2, NOP 1; RESERVE(0); YIELD; //display for 1/2 sec
    RETURN;
#endif


i2c_wrdone: DROP_CONTEXT;
    setbit BITPARENT(is_addr), FALSE;
i2c_done: DROP_CONTEXT;
    setbit SSP1CON1, CKP, TRUE; // release SCL
;    setbit LATA, FRPANEL, FALSE;
veeprom: DROP_CONTEXT;
;//    test
    wait4i2c YIELD, YIELD_AGAIN; //NO-nothing else to do so just busy-wait
    mov8 i2c_data, SSP1BUF; //read SSPBUF to clear BF
;    setbit LATA, FRPANEL, TRUE;
;    mov24 fpcolor, LITERAL(0);
    setbit BITPARENT(fpdirty), TRUE;
    ifbit SSP1STAT, R_NOT_W, TRUE, GOTO i2c_read
    ifbit SSP1STAT, D_NOT_A, TRUE, GOTO i2c_write
;//prepare to receive data from the master
;//    I2C1_StatusCallback(I2C1_SLAVE_WRITE_REQUEST);
;// master will send eeprom address next
;//    mov8 slaveWriteType, LITERAL(SLAVE_DATA_ADDRESS);
    setbit BITPARENT(is_addr), TRUE;
    GOTO i2c_done;
i2c_write:
;    I2C1_slaveWriteData = i2c_data;
;//process I2C1_slaveWriteData from the master
;//    I2C1_StatusCallback(I2C1_SLAVE_WRITE_COMPLETED);
    ifbit BITPARENT(is_addr), TRUE, GOTO i2c_write_addr;
;// master has written data to store in the eeprom
    mov8 INDF0_postinc, i2c_data;
    cmp16 FSR0, LITERAL(LINEAR(veepbuf + SIZEOF(veepbuf)));
    ifbit BORROW TRUE, GOTO i2c_wrdone; //EQUALS0 TRUE, ADDFSR -SIZEOF(veepbuf);
;//    LED_blink(I2C1_slaveWriteData);
    mov16 FSR0, LITERAL(LINEAR(veepbuf)); //wrap
    GOTO i2c_wrdone;
i2c_write_addr:
;    mov8 WREG, i2c_data;
;    ANDLW 0x0F;
;    mov8 FSR0L, WREG; //i2c_data;
    mov16 FSR0, LITERAL(LINEAR(veepbuf));
    cmp8 i2c_data, LITERAL(SIZEOF(veepbuf));
    ifbit BORROW FALSE, CLRF i2c_data; //wrap; ADDWF i2c_data, F; //clamp
    add16_8 FSR0, i2c_data;
    GOTO i2c_wrdone;
i2c_read:
    ifbit SSP1STAT, D_NOT_A, FALSE, GOTO i2c_rddata;
    ifbit SSP1CON2, ACKSTAT, FALSE, GOTO i2c_rddata;
;// perform any post-read processing
;//    I2C1_StatusCallback(I2C1_SLAVE_READ_COMPLETED);
    GOTO i2c_done;
i2c_rddata:
;//write data into SSPBUF
;//    I2C1_StatusCallback(I2C1_SLAVE_READ_REQUEST);
    mov8 SSP1BUF, INDF0_postinc;
    cmp16 FSR0, LITERAL(LINEAR(veepbuf + SIZEOF(veepbuf)));
    ifbit BORROW TRUE, GOTO i2c_done; //ADDFSR -SIZEOF(veepbuf)[0];
    mov16 FSR0, LITERAL(LINEAR(veepbuf));
    GOTO i2c_done;

    THREAD_END;

;    EXPAND_POP @__LINE__
    LIST_POP @__LINE__
;    messg end of hoist 5 @__LINE__
;#else; too deep :(
#endif; @__LINE__
#if HOIST == 4; //ws1 24bpp WS281X xmit helpers (used for front panel)
;    messg hoist 4: ws1 24 bpp WS281X xmit helpers @__LINE__
    LIST_PUSH FALSE, @__LINE__; //TRUE; don't show this section in .LST file
;    EXPAND_PUSH FALSE, @__LINE__
;; 1 bpp wsplayer helpers ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;only 2 colors are supported @1 bpp:
;    constant FGCOLOR = 0x010101;
;    constant BGCOLOR = 0x000000;
;    messg [TODO] allow var colors @__LINE__

ws1_sendbit macro latbit, databit, idler2, idler4; pre_idler4, idler2
;    CONTEXT_SAVE wsbit_idler4
;    pre_idler4; glue or prep for next bit
;    nopif $ == CONTEXT_ADDR(wsbit_idler4), 4
;    setbit REGOF(latbit), BITOF(latbit), TRUE; bit start
    biton latbit;
    if databit <= 1; special cases
	if !databit
	    NOP 1
;	    setbit REGOF(latbit), BITOF(latbit), FALSE; bit data + end
	    bitoff latbit; bit data + end
	else
	    NOP 2
	endif; @__LINE__
    else
	ifbit REGOF(databit), BITOF(databit), FALSE, bitoff latbit; RESERVE(1)
;	    ORG$-1; kludge: fill in placeholder using stmt with params
;	    setbit REGOF(latbit), BITOF(latbit), FALSE; bit data
    endif; @__LINE__
    CONTEXT_SAVE wsbit_idler2
    idler2; other processing
    nopif $ == CONTEXT_ADDR(wsbit_idler2), 2
;    setbit REGOF(latbit), BITOF(latbit), FALSE; bit end
    bitoff latbit; bit end
    CONTEXT_SAVE wsbit_idler4
    idler4; glue or prep for next bit
    nopif $ == CONTEXT_ADDR(wsbit_idler4), 4
    CONTEXT_SAVE wsbit_after
    endm; @__LINE__


    nbDCL8 pxbits8;
;    ERRIF(BANKOF(pxbits8) != BANKOF(LATA), [ERROR] ws vars must be in same bank as LATA @__LINE__);
;WREG must contain byte to send
ws1_sendbyte macro latbit, glue2, glue4
;first bit inlined to allow more prep time:
    ws1_sendbit latbit, #v(BITWRAP(WREG, log2(0x80))), RESERVE(2), RESERVE(4)
        CONTEXT_RESTORE wsbit_idler2
        LSLF WREG, F;
        LSLF WREG, F; 0x40 -> C for loop
        CONTEXT_RESTORE wsbit_idler4
	MOVWF pxbits8; kludge: save WREG in target then swap (need to preserve WREG)
;	swapreg WREG, pxgrp8;
	XORLW 6; WREG ^ 6
	XORWF pxbits8, F; == 6
	XORWF pxbits8, W; == WREG
        CONTEXT_RESTORE wsbit_after
    LOCAL bitloop6;
 EMITL bitloop6: ;//6x
    ws1_sendbit latbit, #v(BITWRAP(STATUS, Carry)), RESERVE(0), RESERVE(4)
        CONTEXT_RESTORE wsbit_idler4
        LSLF WREG, F
;	ifbit EQUALS0 FALSE, goto bitloop;
	DECFSZ pxbits8, F
	    GOTO bitloop6;
;        CONTEXT_SAVE wsbyte_preload1
	NOP 1
;        nopif $ == CONTEXT_ADDR(wsbyte_preload1), 1
        CONTEXT_RESTORE wsbit_after
;last bit inlined to allow custom glue logic:
    ws1_sendbit latbit, #v(BITWRAP(STATUS, Carry)), glue2, glue4;
    endm; @__LINE__


#ifndef RGB_ORDER
 EMITL #define RGB_ORDER  0x123; //R = byte[1-1], G = byte[2-1], B = byte[3-1]; default = 0x123 = RGB
#endif; @__LINE__

#define RGB_BYTE(n)  RGB_#v(n); (n) % 3); controls byte order (BYTEOF)
;#ifdef RGSWAP; set color order
;line too long :( #define RGB_ORDER(n)  (((RGSWAP >> (8 - 4 * (n))) & 0xF) - 1)
    CONSTANT RGB_#v(0) = (((RGB_ORDER >> 8) & 0xF) - 1);
    CONSTANT RGB_#v(1) = (((RGB_ORDER >> 4) & 0xF) - 1);
    CONSTANT RGB_#v(2) = (((RGB_ORDER >> 0) & 0xF) - 1);
#if RGB_ORDER != 0x123
    messg [INFO] custom rgb order RGB_ORDER: R [#v(RGB_BYTE(0))], G [#v(RGB_BYTE(1))], B [#v(RGB_BYTE(2))] @__LINE__
#endif; @__LINE__
;#else; default color order R,G,B (0x123)
; #define RGB_ORDER(n)  ((n) % 3)
;    CONSTANT RGB_#v(0) = 0;
;    CONSTANT RGB_#v(1) = 1;
;    CONSTANT RGB_#v(2) = 2;
;#endif; @__LINE__
;R/G/B offsets within pal ent for each RGB order:
;mpasm !like consts for MOVIW [FSR] offsets :(
;    constant ROFS_#v(0) = 1-1, GOFS_#v(0) = 2-1, BOFS_#v(0) = 3-1; //default 0x123 = RGB
;    constant ROFS_#v(0x123) = 1-1, GOFS_#v(0x123) = 2-1, BOFS_#v(0x123) = 3-1;
;    constant ROFS_#v(0x132) = 1-1, GOFS_#v(0x132) = 3-1, BOFS_#v(0x132) = 2-1;
;    constant ROFS_#v(0x213) = 2-1, GOFS_#v(0x213) = 1-1, BOFS_#v(0x213) = 3-1;
;    constant ROFS_#v(0x231) = 3-1, GOFS_#v(0x231) = 1-1, BOFS_#v(0x231) = 2-1;
;    constant ROFS_#v(0x312) = 2-1, GOFS_#v(0x312) = 3-1, BOFS_#v(0x312) = 1-1;
;    constant ROFS_#v(0x321) = 3-1, GOFS_#v(0x321) = 2-1, BOFS_#v(0x321) = 1-1;


#define FIRSTPX  ORG $-1; //flag to set up WREG and BSR for first pixel
;ws1_sendpx macro rgb24, wait_first, first_idler, more_idler
ws1_sendpx macro latbit, rgb24, prep_first, glue2, glue4
; messg HIBYTE(rgb24)
; messg MIDBYTE(rgb24)
; messg LOBYTE(rgb24)
;    LOCAL HI;
;HI = HIBYTE(rgb24); line too long :(
;    LOCAL MID;
;MID = MIDBYTE(rgb24);
;    LOCAL LO;
;LO = LOBYTE(rgb24);
    LOCAL FIRST_BYTE
FIRST_BYTE = BYTEOF(rgb24, 2 - RGB_BYTE(0));
    LOCAL MID_BYTE
MID_BYTE = BYTEOF(rgb24, 2 - RGB_BYTE(1));
    LOCAL LAST_BYTE
LAST_BYTE = BYTEOF(rgb24, 2 - RGB_BYTE(2));
    LOCAL before_prep = $
    prep_first; prep first byte
    if $ < before_prep; auto-setup for first px
	ORG before_prep
;    messg WREG_TRACKER, #v(FIRST_BYTE) @__LINE__
	DROP_WREG; force WREG to load (ensure WREG is correct value, tracker might have got confused)
        mov8 WREG, FIRST_BYTE; //only enough time to do first time
;should already be done:
;	setbit REGOF(latbit), BITOF(latbit), FALSE; //start low
;        setbit TRISA + REGOF(latbit) - LATA, BITOF(latbit), 0; //make it an output
	BANKCHK REGOF(latbit)
    endif; @__LINE__
    LOCAL bitloop22;
    if rgb24 == LITERAL(0); special case
        ws1_sendbit latbit, 0, RESERVE(2), NOP 4; //RESERVE(0)
            CONTEXT_RESTORE wsbit_idler2
	    DROP_WREG; force WREG to load (need 2 instr here)
	    mov8 pxbits8, LITERAL(24-2)
            CONTEXT_RESTORE wsbit_after
 EMITL bitloop22: ;//22x
        ws1_sendbit latbit, 0, NOP 2, RESERVE(4); //RESERVE(0), RESERVE(4)
        CONTEXT_RESTORE wsbit_idler4
	NOP 1
	DECFSZ pxbits8, F
	    GOTO bitloop22;
	NOP 1
        CONTEXT_RESTORE wsbit_after
;last bit inlined to allow custom glue logic:
        ws1_sendbit latbit, 0, glue2, glue4;
	exitm; @__LINE__
    endif; @__LINE__
;    ws1_send_byte FIRST_BYTE, wait_first, first_idler, more_idler; REGHI(rgb24);
;    ws1_send_byte MID_BYTE, wait_first, first_idler, more_idler; REGMID(rgb24);
;    ws1_send_byte LAST_BYTE, wait_first, first_idler, more_idler; REGLO(rgb24);
    ws1_sendbyte latbit, RESERVE(2), NOP 4; //RESERVE(0); ORG$+2, ORG$;
        CONTEXT_RESTORE wsbit_idler2
	DROP_WREG; force WREG to load (need 2 instr here)
	mov8 WREG, MID_BYTE
	NOP CONTEXT_ADDR(wsbit_idler2)+2 - $
        CONTEXT_RESTORE wsbit_after
    ws1_sendbyte latbit, RESERVE(2), NOP 4; //RESERVE(0); ORG$+2, ORG$;
        CONTEXT_RESTORE wsbit_idler2
	DROP_WREG; force WREG to load (need 2 instr here)
	mov8 WREG, LAST_BYTE
	NOP CONTEXT_ADDR(wsbit_idler2)+2 - $
        CONTEXT_RESTORE wsbit_after
    ws1_sendbyte latbit, glue2, glue4;
;    ws1_send_byte MID_BYTE, wait_first, first_idler, more_idler; REGMID(rgb24);
;    ws1_send_byte LAST_BYTE, wait_first, first_idler, more_idler; REGLO(rgb24);
    endm; @__LINE__

    
;    EXPAND_POP @__LINE__
    LIST_POP @__LINE__
;    messg end of hoist 4 @__LINE__
;#else; too deep :(
#endif; @__LINE__
#if HOIST == 3
;    messg hoist 3: app helpers @__LINE__
    LIST_PUSH FALSE, @__LINE__; don't show this section in .LST file
;    EXPAND_PUSH FALSE, @__LINE__
;; fps helpers ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;    nbDCL FPS,; breakout value (used as counter until breakout is refreshed)
;    nbDCL numfr,; internal counter

    VARIABLE CURRENT_FPS_usec = -1;
WAIT macro duration_usec, idler, idler2
    if duration_usec != CURRENT_FPS_usec
        fps_init duration_usec;
;	NOP 2; give T0IF time to settle?
;    else
;	mov8 TMR0, LITERAL(0);
;	setbit elapsed_fps, FALSE;
    endif; @__LINE__
;    LOCAL here;
;here:
;    wait4frame ORG$, goto here; //busy wait; use YIELD for multi-tasking
;    whilebit elapsed_fps, FALSE, idler; more efficient than goto $-3 + call
;    setbit elapsed_fps, FALSE;
    wait4frame idler, idler2;
    endm; @__LINE__


;set up recurring frames:
;uses Timer 0 rollover as recurring 1 sec elapsed timer
;also used for frame timer during power-on breakout animation
;nope-uses NCO for 1 sec interval; other timers are busy :(
;#define NICKS_FOSC  b'0000'; should be in p16f15313.inc
;#define NCO_ROLLOVER  FOSC_FREQ
;#define wait4_1sec  ifbit PIR7, NCO1IF, FALSE, goto $-1
;#define T2SRC_FOSC  b'0010'; run Timer2 at same speed as Fosc (16 MHz)
;    VARIABLE T0_WAITCOUNT = 0; generate unique labels; also remembers init
;    CONSTANT MAX_ACCURACY = 1 << 20; 1 MHz; max accuracy to give caller; use nop for < 1 usec delays
#define T0SRC_FOSC4  b'010'; FOSC / 4; should be in p16f15313.inc
#define T0_prescaler(freq)  prescaler(FOSC_FREQ/4, freq); log2(FOSC_FREQ / 4 / (freq)); (1 MHz)); set pre-scalar for 1 usec ticks
;#define T0_prescfreq(prescaler)  (FOSC_FREQ / 4 / BIT(prescaler)); (1 MHz)); set pre-scalar for 1 usec ticks
;    messg ^^ REINSTATE @__LINE__
;#define T0_postscaler  log2(1); 1-to-1 post-scalar
;#define T0_ROLLOVER  50; 50 ticks @1 usec = 50 usec; WS281X latch time = 50 usec
;    messg [DEBUG] T0 prescaler = #v(T0_prescale), should be 2 (1:4) @__LINE__
;#define MY_T0CON1(tick_freq)  (T0SRC_FOSC4 << T0CS0 | NOBIT(T0ASYNC) | T0_prescaler(tick_freq) << T0CKPS0); FOSC / 4, sync, pre-scalar TBD (1:1 for now)
;#define SETUP_NOWAIT  ORG $-1; idler to use for no-wait, setup only
;#define wait4_t1tick  ifbit PIR5, TMR1GIF, FALSE, goto $-1; wait acq
#define elapsed_fps  PIR0, TMR0IF
    CONSTANT MAX_T0PRESCALER = log2(32768), MAX_T0POSTSC = log2(16);
#ifndef TUNED
 #define TUNED(as_is)  as_is
#endif; @__LINE__
fps_init macro interval_usec;, enable_ints; wait_usec macro delay_usec, idler
;    EXPAND_PUSH FALSE, @__LINE__
CURRENT_FPS_usec = interval_usec; remember last setting; TODO: add to SAVE_CONTEXT
;TODO: don't use TUNED() unless OSCTUNE is adjusted (ws_breakout_setup)
    LOCAL USEC = TUNED(interval_usec); CAUTION: compensate for OSCTUNE (set by ws_breakout_setup)
;    mov8 NCO1CON, LITERAL(NOBIT(N1EN) | NOBIT(N1POL) | NOBIT(N1PFM)); NCO disable during config, active high, fixed duty mode
;    mov8 NCO1CLK, LITERAL(N1CKS_FOSC << N1CKS0); pulse width !used
;    mov24 NCO1INC, LITERAL(1)
;    setbit INTCON, GIE, FALSE; disable interrupts (in case waiting for 50 usec WS latch signal)
;    if usec == 1
;    movlw ~(b'1111' << T0CKPS0) & 0xFF; prescaler bits
;    BANKCHK T0CON1
;    andwf T0CON1, F; strip previous prescaler
;    MESSG fps_init delay_usec @__LINE__;
;    if !WAIT_COUNT; first time init
;        mov8 T0CON0, LITERAL(NOBIT(T0EN) | NOBIT(T016BIT) | T0_postscaler << T0OUTPS0); Timer 0 disabled during config, 8 bit mode, 1:1 post-scalar
;    else
;        setbit T0CON0, T0EN, FALSE;
;    endif; @__LINE__
;    LOCAL ACCURACY = MAX_ACCURACY; 1 MHz; max accuracy to give caller; use nop for < 1 usec delays
    LOCAL PRESCALER = 3, POSTSCALER; not < 1 usec needed (8 MIPS @1:8)
    LOCAL T0tick, LIMIT, ROLLOVER;
;    LOCAL FREQ_FIXUP; = FOSC_FREQ / 4 / BIT(PRESCALER);
;    while ACCURACY >= 1 << 7; 125 Hz
    messg [TODO] change this to use postscaler 1..16 instead of just powers of 2 (for more accuracy) @__LINE__
    while PRESCALER <= MAX_T0PRESCALER + MAX_T0POSTSC; use smallest prescaler for best accuracy
;T0FREQ = FOSC_FREQ / 4 / BIT(PRESCALER); T0_prescfreq(PRESCALER);
T0tick = scale(FOSC_FREQ/4, PRESCALER); BIT(PRESCALER) KHz / (FOSC_FREQ / (4 KHz)); split 1M factor to avoid arith overflow; BIT(PRESCALER - 3); usec
;presc 1<<3, freq 1 MHz, period 1 usec, max delay 256 * usec
;presc 1<<5, freq 250 KHz, period 4 usec, max delay 256 * 4 usec ~= 1 msec
;presc 1<<8, freq 31250 Hz, period 32 usec, max delay 256 * 32 usec ~= 8 msec
;presc 1<<13, freq 976.6 Hz, period 1.024 msec, max delay 256 * 1.024 msec ~= .25 sec
;presc 1<<15, freq 244.1 Hz, period 4.096 msec, max delay 256 * 4.096 msec ~= 1 sec
LIMIT = 256 * T0tick; (1 MHz / T0FREQ); BIT(PRESCALER - 3); 32 MHz / (FOSC_FREQ / 4); MAX_ACCURACY / ACCURACY
;	messg [DEBUG] wait #v(interval_usec) usec: prescaler #v(PRESCALER) => limit #v(LIMIT) @__LINE__
;        messg tick #v(T0tick), presc #v(PRESCALER), max delay #v(LIMIT) usec @__LINE__
	if USEC <= LIMIT; ) || (PRESCALER == MAX_T0PRESCALER); this prescaler allows interval to be reached
POSTSCALER = MAX(PRESCALER - MAX_T0PRESCALER, 0); line too long :(
PRESCALER = MIN(PRESCALER, MAX_T0PRESCALER);
ROLLOVER = rdiv(USEC, T0tick); 1 MHz / T0FREQ); / BIT(PRESCALER - 3)
	    messg [DEBUG] fps_init #v(interval_usec) (#v(USEC) tuned) "usec": "prescaler" #v(PRESCALER)+#v(POSTSCALER), max intv #v(LIMIT), actual #v(ROLLOVER * T0tick), rollover #v(ROLLOVER) @__LINE__
;    messg log 2: #v(FOSC_FREQ / 4) / #v(FOSC_FREQ / 4 / BIT(PRESCALER)) = #v(FOSC_FREQ / 4 / (FOSC_FREQ / 4 / BIT(PRESCALER))) @__LINE__; (1 MHz)); set pre-scalar for 1 usec ticks
;FREQ_FIXUP = MAX(1 MHz / T0tick, 1); T0FREQ;
;	    if T0FREQ * BIT(PRESCALER) != FOSC_FREQ / 4; account for rounding errors
;	    if T0tick * FREQ_FIXUP != 1 MHz; account for rounding errors
;	        messg freq fixup: equate #v(FOSC_FREQ / 4 / MAX(FREQ_FIXUP, 1)) to #v(BIT(PRESCALER)) for t0freq #v(FREQ_FIXUP) fixup @__LINE__
;		CONSTANT log2(FOSC_FREQ/4 / FREQ_FIXUP) = PRESCALER; kludge: apply prescaler to effective freq
;	    endif; @__LINE__
	    setbit PMD0, SYSCMD, ENABLED(SYSCMD); //T0 uses Fosc
	    setbit PMD1, TMR0MD, ENABLED(TMR0MD); //CAUTION: must be done < any reg access
POSTSCALER = BIT(POSTSCALER) - 1; //convert power of 2 => count; postsc ! exponential like prescaler
	    mov8 T0CON0, LITERAL(NOBIT(T0EN) | NOBIT(T016BIT) | POSTSCALER << T0OUTPS0); Timer 0 disabled during config, 8 bit mode, 1:1 post-scalar
	    mov8 T0CON1, LITERAL(T0SRC_FOSC4 << T0CS0 | NOBIT(T0ASYNC) | PRESCALER << T0CKPS0); FOSC / 4, sync, pre-scalar
	    mov8 TMR0L, LITERAL(0); restart count-down with new limit
	    mov8 TMR0H, LITERAL(ROLLOVER - 1); (usec) / (MAX_ACCURACY / ACCURACY) - 1);
	    setbit T0CON0, T0EN, TRUE;
;	    setbit elapsed_fps, FALSE; clear previous interrupt flag
;	    if !WAIT_COUNT ;first time init
;	    if enable_ints
;	        setbit PIE0, TMR0IE, TRUE; no, just polled
;	    endif; @__LINE__
;wait_loop#v(WAIT_COUNT):
;WAIT_COUNT += 1
;	    idler;
;	    if $ < wait_loop#v(WAIT_COUNT - 1); reg setup only; caller doesn't want to wait
;		ORG wait_loop#v(WAIT_COUNT - 1)
;		exitm; @__LINE__
;	    endif; @__LINE__
;assume idler handles BSR + WREG tracking; not needed:
;	    if $ > wait_loop#v(WAIT_COUNT - 1)
;		DROP_CONTEXT; TODO: idler hints; for now assume idler changed BSR or WREG
;	    endif; @__LINE__
;	    ifbit elapsed_fps, FALSE, goto wait_loop#v(WAIT_COUNT - 1); wait for timer roll-over
;	    wait4_t1roll; wait for timer roll-over
;ACCURACY = 1 KHz; break out of loop	    exitwhile
;    if usec >= 256
;	movlw ~(b'1111' << T0CKPS0) & 0xFF; prescaler bits
;	BANKCHK T0CON1
;	andwf T0CON1, F; strip temp prescaler
;	iorwf T0CON1, T0_prescale << T0CKPS0; restore original 8:1 pre-scalar used for WS input timeout
;    endif; @__LINE__
;    mov8 TMR0H, LITERAL(T0_ROLLOVER); restoreint takes 1 extra tick but this accounts for a few instr at start of ISR
	    exitm; @__LINE__ ;@__LINE__
	endif; @__LINE__
PRESCALER += 1
;FREQ_FIXUP = IIF(FREQ_FIXUP == 31250, 16000, FREQ_FIXUP / 2);
    endw; @__LINE__
;    error [ERROR] "fps_init" #v(interval_usec) "usec" (#v(USEC) tuned) unreachable with max "prescaler" #v(MAX_T0PRESCALER), using max interval #v(UNTUNED(LIMIT)) "usec" (#v(LIMIT) tuned) @__LINE__)
    ERRIF(TRUE, [ERROR] "fps_init" #v(interval_usec) "usec" (#v(USEC) tuned) exceeds max reachable interval #v(UNTUNED(LIMIT)) "usec" (#v(LIMIT) tuned) @__LINE__)
;    if usec <= 256
;;	iorwf T0CON1, T0_prescale << T0CKPS0; restore original 8:1 pre-scalar used for WS input timeout
;        mov8 T0CON1, LITERAL(MY_T0CON1(1 MHz));
;        mov8 TMR0H, LITERAL(usec - 1);
;    else
;	if usec <= 1 M; 1 sec
;            mov8 T0CON1, LITERAL(MY_T0CON1(250 Hz));
;	    mov8 TMR0H, LITERAL((usec) / (1 KHz) - 1);
;	else
;	    if usec <= 256 K
;		mov8 T0CON1, LITERAL(MY_T0CON1(1 KHz));
;		mov8 TMR0H, LITERAL((usec) / (1 KHz) - 1);
;	    else
;	    endif; @__LINE__
;	endif; @__LINE__
;    endif; @__LINE__
;    EXPAND_POP @__LINE__
    endm; @__LINE__
;    mov8 T0CON0, LITERAL(NOBIT(T0EN) | NOBIT(T016BIT) | T0_postscale << T0OUTPS0); Timer 0 disabled during config, 8 bit mode, 1:1 post-scalar
;;    mov8 T0CON1, LITERAL(MY_T0CON1(MAX(FREQ_FIXUP, 1))); FREQ_FIXUP)); FOSC_FREQ / 4 / BIT(PRESCALER)));
;    mov8 T0CON1, LITERAL(T0SRC_FOSC4 << T0CS0 | NOBIT(T0ASYNC) | MAX_T0PRESCALER << T0CKPS0); FOSC / 4, sync, pre-scalar TBD (1:1 for now)
;    mov8 TMR0L, LITERAL(0); restart count-down with new limit
;    mov8 TMR0H, LITERAL(ROLLOVER - 1); (usec) / (MAX_ACCURACY / ACCURACY) - 1);
;    setbit T0CON0, T0EN, TRUE;
;    setbit elapsed_fps, FALSE; clear previous overflow
;init app counters:
;    mov8 FPS, LITERAL(0)
;    mov8 numfr, LITERAL(0)
;    endm; @__LINE__


;wait for new frame:
wait4frame macro idler, idler2
;    EXPAND_PUSH FALSE, @__LINE__
; messg wait4frame: idler, idler2, #threads = #v(NUM_THREADS)
;    ifbit elapsed_fps, FALSE, idler; bit !ready yet, let other threads run
    setbit elapsed_fps, FALSE; need to do this < yield_again)
    LOCAL start_idler = $;
    idler; assume not ready yet, let other threads run
    nopif $ == start_idler, 2; give T0IF time to settle?
;    BANKCHK PIR0
;    CONTEXT_SAVE before_idler; #v(uniq)
;    ORG $+1; //placeholder for btfss
;    idler; assume not ready yet, let other threads run
;    LOCAL idler_size = $ - (CONTEXT_ADDR(before_idler) + 1); #v(uniq));
;    CONTEXT_RESTORE before_idler; #v(uniq)
;    if !idler_size; //caller doesn't want to wait for timeout (yet, maybe using interrupts)
;		setbit PIE4, TMR2IF, BOOL2INT(want_interrupt);
;	exitm; @__LINE__
;    endif; @__LINE__
;    whilebit PIR4, TMR2IF, FALSE, ORG$ + idler_size; backfill btfss + goto
 ;TODO: restore context > idler?
;    exitm; @__LINE__
;    ifbit elapsed_fps, FALSE, RESERVE(2); idler2; more efficient than goto $-3 + call
;TODO: why does this need to be right < check instead of after?
    whilebit elapsed_fps, FALSE, idler2; more efficient than goto $-3 + call
;    setbit elapsed_fps, FALSE;
;    EXPAND_POP @__LINE__
    endm; @__LINE__


;; one-shot timer helper ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;use Timer2 in one-shot mode for timeouts:
;used to detect 50 usec WS latch time / end of frame
#define T2SRC_FOSC4  b'001'; FOSC / 4; should be in p16f15313.inc
;#define T2_prescale  log2(1) ;(0 << T1CKPS0); 1-to-1 pre-scalar; make it as accurate as possible
;#define T2_postscale  log2(1) ;(0 << T1CKPS0); 1-to-1 pre-scalar; make it as accurate as possible
#define T2_prescaler(freq)  prescaler(FOSC_FREQ/4, freq); log2(FOSC_FREQ / 4 / (freq)); (1 MHz)); set pre-scalar for 1 usec ticks
#define T2_oneshot  b'01000'; one-shot mode; should be in p16f15313.inc
;    constant T2tick = scale(FOSC_FREQ/4, 1 * 1); BIT(PRESCALER) KHz / (FOSC_FREQ / (4 KHz)); split 1M factor to avoid arith overflow; BIT(PRESCALER - 3); usec
    VARIABLE TIMEOUT_init = 0, TIMEOUT_count = FALSE;
    CONSTANT MAX_T2PRESC = log2(128);, MAX_T2POSTSC = log2(16);
#define is_timeout  T2CON, TMR2ON, !; PIR4, TMR2IF ;setbit/ifbit params
    messg [TODO] change this to use postscaler 1..16 instead of just powers of 2 (for more accuracy) @__LINE__
set_timeout macro delay_usec, idler; want_interrupt
    LOCAL USEC = delay_usec, actual_USEC;
    LOCAL T2tick, LIMIT, ROLLOVER;
    LOCAL T2_prescale = log2(8), T2_postscale; not < 1 usec needed (8 MIPS @1:8)
;preliminary calc to decide if outer loop needed:
T2tick = scale(FOSC_FREQ/4, MAX_T2PRESC)
LIMIT = 256 * T2tick; max limit at highest prescalar
;    messg @ max presc: tick #v(T2tick), limit #v(LIMIT) "usec", orig delay #v(USEC) "usec", need outer? #v(need_outer), outer delay #v(USEC_outer) @__LINE__
    LOCAL delay_loop;
    local outer_count = divup(USEC, LIMIT); //need to round up because inner can't be > limit
    if (outer_count > 1) && (outer_count <= 256); USEC > LIMIT; //use 8-bit outer loop (need 16-bit timer)
;need_loop = TRUE;
        if !TIMEOUT_count
	    nbDCL8 delay_count; //non-banked to reduce bank switching
TIMEOUT_count = TRUE;
	endif; @__LINE__
	mov8 delay_count, LITERAL(outer_count); //rdiv(USEC, USEC_outer));
; EMITL delay_loop:
;    messg here2 @__LINE__
;	set_timeout rdiv(USEC, rdiv(USEC, LIMIT)), idler
USEC = rdiv(USEC, outer_count); //round inner count for more accuracy
;	DECFSZ delay_count, F
;	GOTO delay_loop;
;	exitm; @__LINE__
    endif; @__LINE__
    local before_timer_idler; CAUTION: must be declared outside while/if
;NOTE: PR2 seems to be compared < post-scalar, so can't use post-scalar for one-shot mode
    while T2_prescale <= MAX_T2PRESC; + MAX_T2POSTSC; use smallest prescaler for best accuracy
T2tick = scale(FOSC_FREQ/4, T2_prescale); BIT(PRESCALER) KHz / (FOSC_FREQ / (4 KHz)); split 1M factor to avoid arith overflow; BIT(PRESCALER - 3); usec
LIMIT = 256 * T2tick; (1 MHz / T0FREQ); BIT(PRESCALER - 3); 32 MHz / (FOSC_FREQ / 4); MAX_ACCURACY / ACCURACY
	if USEC <= LIMIT; ) || (PRESCALER == MAX_T0PRESCALER); this prescaler allows interval to be reached
T2_postscale = MAX(T2_prescale - MAX_T2PRESC, 0); line too long :(
;	messg #v(T2_postscale) => #v(BIT(T2_postscale) - 1) @__LINE__
T2_postscale = BIT(T2_postscale) - 1; not log: 1 => 0, 2 => 1, 4 => 3, 8 => 7, 16 => 15
T2_prescale = MIN(T2_prescale, MAX_T2PRESC);
ROLLOVER = rdiv(USEC, T2tick); 1 MHz / T0FREQ); / BIT(PRESCALER - 3)
;    messg #v(TIMEOUT_init), #v(ROLLOVER), #v(delay_usec) @__LINE__
	    if ROLLOVER * T2tick != TIMEOUT_init; need to (re-)init
actual_USEC = ROLLOVER * T2tick * MAX(outer_count, 1); line too long :(	    
    messg [DEBUG] timeout #v(delay_usec) "usec": "prescaler" #v(T2_prescale)+#v(T2_postscale), max intv #v(LIMIT), actual #v(actual_USEC), rollover #v(ROLLOVER), outer #v(outer_count) @__LINE__
;		 mov8 T2INPPS, LITERAL(RA#v(WSDI)); is this needed??
		if !TIMEOUT_init; first time only
		    setbit PMD0, SYSCMD, ENABLED(SYSCMD); //T2 uses Fosc
		    setbit PMD1, TMR2MD, ENABLED(TMR2MD); CAUTION: must be done < any reg access
		endif; @__LINE__
		mov8 T2CON, LITERAL(NOBIT(TMR2ON) | T2_prescale << T2CKPS0 | T2_postscale << T2OUTPS0); Timer 2 disabled during config, 8 bit mode, 1:1 post-scalar
		mov8 T2PR, LITERAL(ROLLOVER);
		if !TIMEOUT_init; first time only
		    mov8 T2CLKCON, LITERAL(T2SRC_FOSC4);
		    mov8 T2HLT, LITERAL(BIT(PSYNC) | XBIT(T2CKPOL) | BIT(T2CKSYNC) | T2_oneshot << T2MODE0); T2 sync to Fosc/4, don't care clock polarity, glitch-free hold 2 count
;	mov8 T2RST, LITERAL(
;        mov8 PR2, LITERAL(
		endif; @__LINE__
		mov8 TMR2, LITERAL(0);
TIMEOUT_init = ROLLOVER * T2tick;
	    endif; @__LINE__
;	    if BOOL2INT(want_interrupt)
;		setbit PIR4, TMR2IF, FALSE;
;		setbit PIE4, TMR2IF, BOOL2INT(want_interrupt);
;	    endif; @__LINE__
;	    setbit T2CON, TMR2ON, TRUE; will reset automatically after T2 matches PR2
 EMITL delay_loop: DROP_CONTEXT
	    setbit T2CON, TMR2ON, TRUE; will reset automatically after T2 matches PR2
	    setbit PIR4, TMR2IF, FALSE; need to reset *inside* delay loop
;	    local before_idler
;	    LOCAL uniq = #v(NUM_CONTEXT)
;	    CONTEXT_SAVE before_timer_idler; #v(uniq)
;	    RESERVE(6); ORG $+3; //placeholder for 2 * (banksel + bcf) + btfss + goto
;	    idler
;	    LOCAL idler_size = $ - (CONTEXT_ADDR(before_timer_idler) + 6); #v(uniq));
;	    CONTEXT_RESTORE before_timer_idler; #v(uniq)
;	    if !idler_size; //caller doesn't want to wait for timeout (yet, maybe using interrupts)
;		WARNIF((outer_count > 1) && (outer_count <= 256), [WARN] outer timer loop meaningless without idler @__LINE__);
;	        setbit PIR4, TMR2IF, FALSE; need to reset *inside* delay loop
;;		setbit PIE4, TMR2IF, BOOL2INT(want_interrupt);
;		exitm; @__LINE__
;	    endif; @__LINE__
;TODO: why does this need to be right < check instead of after?
;TODO: if idler is empty, don't wait for timeout
	    whilebit PIR4, TMR2IF, FALSE, idler; RESERVE(idler_size); backfill btfss + goto
	    if (outer_count > 1) && (outer_count <= 256); need_outer
		DECFSZ delay_count, F
		GOTO delay_loop;
	    endif; @__LINE__
 ;TODO: restore context > idler?
	    exitm; @__LINE__
	endif; @__LINE__
T2_prescale += 1
    endw; @__LINE__
    ERRIF(TRUE, [ERROR] "set_timeout" #v(delay_usec) "usec" exceeds max reachable interval #v(LIMIT) "usec" @__LINE__)
    endm; @__LINE__


;; data helpers ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;    VARIABLE LDI_expanded = FALSE;
    CONSTANT LDI_EOF = 0x2000; //msb prog word
LDI macro dest
;    if !LDI_expanded
;        nbDCL LDI_len,;
;LDI_expanded = TRUE;
;    endif; @__LINE__
;    LOCAL SIZE = size;
;    if size == WREG
;    mov8 LDI_len, size;
;SIZE = LDI_len;
;    endif; @__LINE__
    mov16 FSR0, LITERAL(LINEAR(dest));
;    if !LDI_expanded
;        CALL LDI_prep_first;
;LDI_prep: DROP_CONTEXT
;    mov16 FSR1, TOS; data immediately follows "call"
;    setbit REGHI(FSR1), log2(0x80), TRUE; access prog space
;    PAGECHK LDI_loop; do this before decfsz
;LDI_loop: ;NOTE: each INDF access from prog space uses 1 extra instr cycle
;    mov8 INDF0_postinc, INDF1_postinc; repeat 3x to reduce loop overhead
;    mov8 INDF0_postinc, INDF1_postinc;
;    mov8 INDF0_postinc, INDF1_postinc;
;    DECFSZ LDI_len, F
;    GOTO LDI_#v(size)_loop;
;    mov16 TOS, FSR1; return past immediate data
;    return;
;    else
    CALL lodi24;
;    endif; @__LINE__
;LDI_expanded = TRUE;
    endm; @__LINE__


;helper functions to load packed data from prog space:
;12 bits are loaded from each word in prog space in pairs
;    nbDCL8 i24count;
    BITDCL load_immediate; CAUTION: initial val must be 0
 EMITL lodi24: DROP_CONTEXT;
;TODO? use WREG2 to reduce bank selects here
    setbit PMD0, NVMMD, ENABLED(NVMMD); //CAUTION: must be done < any reg access
    mov16 NVMADR, TOS; data immediately follows "call"
    setbit BITPARENT(load_immediate), TRUE; remember whether to adjust ret addr
 EMITL lodn24: DROP_CONTEXT; caller already set nvmadr
;    mov8 i24count, WREG;
;    INCF i24count, F; kludge: compensate for loop control using decfsz
;    mov16 FSR1, TOS; data immediately follows "call"
    dec16 FSR0; compensate for first INDF0_preinc
;PMD already set (had to be for NVMADR to be set):    setbit PMD0, NVMMD, ENABLED(NVMMD); //CAUTION: must be done < any reg access
    setbit NVMCON1, NVMREGS, FALSE; access prog space, !config space
 EMITL geti24_loop: ;DROP_CONTEXT;
    setbit NVMCON1, RD, TRUE; start read; CAUTION: CPU suspends until read completes => unpredictable timing?
    SWAPF REGHI(NVMDAT), W;
    ANDLW 0xF0; redundant; should be 0
    mov8 INDF0_preinc, WREG;
    SWAPF REGLO(NVMDAT), W;
    ANDLW 0x0F;
    IORWF INDF0, F;
    SWAPF REGLO(NVMDAT), W;
    ANDLW 0xF0;
    mov8 INDF0_preinc, WREG;
    inc16 NVMADR;
    setbit NVMCON1, RD, TRUE; start read; CAUTION: CPU suspends until read completes => unpredictable timing?
    mov8 WREG, REGHI(NVMDAT);
    ANDLW 0x0F; redundant; should be 0
    IORWF INDF0, F;
    mov8 INDF0_preinc, REGLO(NVMDAT);
    inc16 NVMADR;
    PAGECHK geti24_loop; do this before decfsz
;    DECFSZ i24count, F
    ifbit REGHI(NVMDAT), log2(LDI_EOF >> 8), FALSE, GOTO geti24_loop; !eof; CAUTION: only checks second word of pair
    ifbit BITPARENT(load_immediate), FALSE, RETURN; ret addr already correct
;TODO? use WREG2 to reduce bank selects here
    mov16 TOS, NVMADR; return past immediate data
    setbit BITPARENT(load_immediate), FALSE; reset < next call
    RETURN;


;; i2c helpers ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;default pins:
#ifndef SDA1_PIN
 EMITL #define SDA1_PIN  RA2
#endif; @__LINE__
#ifndef SCL1_PIN
 EMITL #define SCL1_PIN  RA1
#endif; @__LINE__

#define I2C_slave7  b'0110'; I2C Slave mode, 7-bit address; should be in p16f15313.inc
#define PPS_SDA1OUT  0x16; should be in p16f15313.inc
#define PPS_SCL1OUT  0x15; should be in p16f15313.inc

i2c_init macro addr
    setbit PMD4, MSSP1MD, ENABLED(TRUE); //CAUTION: must be done < any reg access
;//set I2C I/O pins:
#if SDA1_PIN != RA2
    messg [INFO] SDA1 remapped from RA#v(2) to RA#v(SDA1_PIN) @__LINE__
    mov8 SSP1DATPPS, LITERAL(SDA1_PIN);
    mov8 RA#v(SDA1_PIN)PPS, LITERAL(PPS_SDA1OUT); //use same pin for both directions
;//   setbit ODCONA, SDA1_PIN, TRUE; //not needed; MSSP handles this
#endif; @__LINE__
#if SCL1_PIN != RA1
    messg [INFO] SCL1 remapped from RA#v(2) to RA#v(SCL1_PIN) @__LINE__
    mov8 SSP1CLKPPS, LITERAL(SCL1_PIN)
    mov8 RA#v(SCL1_PIN)PPS, LITERAL(PPS_SCL1OUT); //use same pin for both directions
;//   setbit ODCONA, SCL1_PIN, TRUE; //not needed; MSSP handles this
#endif; @__LINE__
;//turn off output drivers for I2C pins (must be open drain, MSSP overrides TRIS):
;    setbit TRISA, SDA1_PIN, 1;
;    setbit TRISA, SCL1_PIN, 1;
    EMIT2 PinMode SDA1_PIN, InDigital;
    EMIT2 PinMode SCL1_PIN, InDigital;
;//I2C control regs:
;//    SSP1CON1 = 0x26; // SSPEN enabled; CKP disabled; SSPM 7 Bit Polling;
    mov8 SSP1CON1, LITERAL(NOBIT(SSPEN) | NOBIT(CKP) | I2C_slave7 << SSPM0); //I2C disabled during config, clock low, slave mode, 7-bit addr
;//    SSP1STAT = 0x80; // SMP Standard Speed; CKE disabled;
    mov8 SSP1STAT, LITERAL(BIT(SMP) | NOBIT(CKE)); //disable slew rate for standard speed (100 KHz), disable SMBus, 
;//    SSP1CON2 = 0x00; // ACKEN disabled; GCEN disabled; PEN disabled; ACKDT acknowledge; RSEN disabled; RCEN disabled; SEN disabled;
    mov8 SSP1CON2, LITERAL(NOBIT(GCEN) | NOBIT(ACKSTAT) | NOBIT(ACKDT) | NOBIT(SEN)); //disable call addr, ack status, ack data, disable clock stretching
;//    SSP1CON3 = 0x00; // SBCDE disabled; BOEN disabled; SCIE disabled; PCIE disabled; DHEN disabled; SDAHT 100ns; AHEN disabled;
    mov8 SSP1CON3, LITERAL(NOBIT(PCIE) | NOBIT(SCIE) | NOBIT(BOEN) | NOBIT(SDAHT) | NOBIT(SBCDE) | NOBIT(AHEN) | NOBIT(DHEN)); //disable stop + start detect interrupts, don't ack on buf ovfl, 100 ns SDA hold time, disable slave collision detect, disable addr + data hold
;// SSPMSK 127;
    mov8 SSP1MSK, LITERAL(0x7F << 1); //rcv addr bit compare
;// SSPADD 8;
;//    SSP1ADD = (I2C1_SLAVE_ADDRESS << 1);  // adjust UI address for R/nW bit
;    if ISLIT(addr)
;	mov8 WREG, LITERAL(LIT2VAL(addr) << 1);
;    else
;        LSLF addr, W
;    endif; @__LINE__
    EMIT2 mov8 SSP1ADD, addr; WREG; //LITERAL(0x50 << 1); //7-bit rcv addr
    LSLF SSP1ADD, F;
;//    PIR3bits.SSP1IF = 0; // clear the slave interrupt flag
    setbit PIR3, SSP1IF, FALSE; //clear slave interrupt flag
;//    PIE3bits.SSP1IE = 1; // enable the master interrupt
    setbit SSP1CON1, SSPEN, TRUE; //I2C enable
    endm; @__LINE__

    ;wait for new frame:
wait4i2c macro idler, idler2
;    EXPAND_PUSH FALSE, @__LINE__
; messg wait4frame: idler, idler2, #threads = #v(NUM_THREADS)
;    ifbit elapsed_fps, FALSE, idler; bit !ready yet, let other threads run
    idler; assume not ready yet, let other threads run
    ifbit PIR3, SSP1IF, FALSE, idler2; more efficient than goto $-3 + call
    setbit PIR3, SSP1IF, FALSE;
;    EXPAND_POP @__LINE__
    endm; @__LINE__

;    at_init TRUE
;    at_init FALSE

;    EXPAND_POP @__LINE__
    LIST_POP @__LINE__
;    messg end of hoist 3 @__LINE__
;#else; too deep :(
#endif; @__LINE__
#if HOIST == 2
;    messg hoist 2: cooperative multi-tasking ukernel @__LINE__
    LIST_PUSH FALSE, @__LINE__; don't show this section in .LST file
;    EXPAND_PUSH FALSE, @__LINE__
;; cooperative multi-tasking ukernel ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

#define HOST_STKLEN  16-0; total stack space available to threads; none left for host, threaded mode is one-way xition
#define RERUN_THREADS  TRUE; true/false to re-run thread after return (uses 1 extra stack level); comment out ONLY if threads NEVER return!


;NOTE: current (yield) addr uses 1 stack level
#ifndef RERUN_THREADS
 #define MIN_STACK  1; need 1 level for current exec addr within thread
#else
 #define MIN_STACK  2; need another level in case thread returns to wrapper
#endif; @__LINE__


;encapsulate "call" vs "goto" for caller:
;#define YIELD  call yield
;#define YIELD_AGAIN  goto yield_again

;dummy target until threads defined:
;no_treads equ $; kludge: must be const rather than label for "yield" aliasing
;yield_none: sleep
;yield set yield_none
;yield_again set yield_none
;stkptr_#v(0) SET STKPTR; dummy def if no threads defined; threads will redefine
;!worky #define YIELD  yield_generic
;use generic versions outside of thread def:
;YIELD set yield
;YIELD_AGAIN set yield_again


;    nbDCL stkptr_2,
;    messg TODO: ^^^ fix this @__LINE__
;define new thread:
;starts executing when yield is called
    VARIABLE STK_ALLOC = 0; total stack alloc to threads
    VARIABLE NUM_THREADS = 0;
    VARIABLE IN_THREAD = 0;
THREAD_DEF macro thread_body, stacksize
;    EXPAND_PUSH FALSE;, @__LINE__
    ERRIF(IN_THREAD, [ERROR] missing END_THREAD from previous thread #v(NUM_THREADS - 1) @__LINE__);
;    END_THREAD; #undef aliases for prev thread
    ERRIF(stacksize < MIN_STACK, [ERROR] thread_body stack size #v(stacksize)"," needs to be >= #v(MIN_STACK) @__LINE__);
    ERRIF(stacksize > HOST_STKLEN - STK_ALLOC, [ERROR] thread_body stack size #v(stacksize) exceeds available #v(HOST_STKLEN - STK_ALLOC)"," thread cannot be created @__LINE__)
;    ERRIF((NUM_THREADS << 4) & ~0x7F, [ERROR] too many threads already: #v(NUM_THREADS), PCLATH !enough bits @__LINE__); stack is only 15 bits wide
;    LOCAL thread_body;
;statically assign resources to threads:
;gives more efficient code and handles yields to unstarted threads
;threads are assumed to run forever so resources are never deallocated
    nbDCL stkptr_#v(NUM_THREADS),; each thread gets its own section of stack space + saved STKPTR
STK_ALLOC += stacksize
    messg creating thread_body thread# #v(NUM_THREADS) @#v($), stack size #v(stacksize), host stack remaining: #v(HOST_STKLEN - STK_ALLOC) @__LINE__
;stkptr_#v(0) SET stkptr_#v(NUM_THREADS + 1); wrap-around for round robin yield; NOTE: latest thread overwrites this
;cooperative multi-tasking:
;6-instr context switch: 3 now (call + sv STKPTR) + 3 later (rest STKPTR + return)
;    if NUM_THREADS > 0; one back to avoid undefs
;#undefine YIELD
;#define YIELD  call yield_from_#v(NUM_THREADS); alias for caller
;YIELD set yield_from_#v(NUM_THREADS); alias for caller
;#define yield  yield_from_#v(NUM_THREADS); alias for caller
#if 0
yield_from_#v(NUM_THREADS): DROP_CONTEXT; overhead for first yield = 10 instr = 1.25 usec @8 MIPS
    mov8 stkptr_#v(NUM_THREADS), STKPTR; #v(curthread)
;yield_from_#v(NUM_THREADS)_placeholder set $
yield_again_#v(NUM_THREADS): DROP_CONTEXT; overhead for repeating yield = 7 instr < 1 usec @8 MIPS
    CONTEXT_SAVE yield_placeholder_#v(NUM_THREADS)
    ORG $ + 2+1; placeholder for: mov8 STKPTR, stkptr_#v(NUM_THREADS + 1); % MAX_THREADS); #v(curthread + 1); round robin
    RETURN;
;yield set yield_from_#v(NUM_THREADS); alias for caller
;#define YIELD  CALL yield
;yield_again set yield_again_#v(NUM_THREADS); alias for caller
;#define YIELD_AGAIN  GOTO yield_again
#endif; @__LINE__
;yield_from_#v(thread_body) EQU yield_from_#v(NUM_THREADS); allow yield by thread name
;#define YIELD_AGAIN  goto yield_again_#v(NUM_THREADS); alias for caller
;YIELD_AGAIN set yield_again_#v(NUM_THREADS); alias for caller
;#define yield_again  yield_again_#v(NUM_THREADS); alias for caller
;yield_again_#v(NUM_THREADS): DROP_CONTEXT;
;    BANKCHK STKPTR;
;    BANKSAFE dest_arg(W) incf STKPTR;, W; ret addr !change: replaces goto + call, saves 3 instr
;    BANKSAFE dest_arg(F) incf stkptr_#v(NUM_THREADS);, F;
;no! already correct    INCF stkptr_#v(NUM_THREADS), F;
;yield_again_#v(NUM_THREADS)_placeholder set $
;    CONTEXT_SAVE yield_again_placeholder_#v(NUM_THREADS)
;    ORG $ + 2+1; placeholder for: mov8 STKPTR, stkptr_#v(NUM_THREADS + 1); % MAX_THREADS); #v(curthread + 1); round robin
;    EMIT return;
;yield_again set yield_again_#v(NUM_THREADS); alias for caller
;#define YIELD_AGAIN  GOTO yield_again
;yield SET yield_from_#v(NUM_THREADS); alias for caller
;yield_again SET yield_again_#v(NUM_THREADS); alias for caller
;thread_body: DROP_CONTEXT;
;start_thread_#v(0) EQU yield
;define thread entry point:
#define YIELD  CALL yield
#define YIELD_AGAIN  GOTO yield_again
yield set yield_from_#v(NUM_THREADS); alias for caller
yield_again set yield_again_#v(NUM_THREADS); alias for caller
    at_init TRUE;
#ifndef RERUN_THREADS
;    error [TODO] put "CALL stack_alloc" < "thread_body" @__LINE__
;thread_wrapper_#v(NUM_THREADS) EQU thread_body; onthread(NUM_THREADS, thread_body); begin executing thread; doesn't use any stack but thread can never return!
;    goto thread_body; begin executing thread; doesn't use any stack but thread can never return!
    PUSH thread_body; CAUTION: undefined behavior if thread returns
;    GOTO stack_alloc_#v(NUM_THREADS); kludge: put thread_wrapper ret addr onto stack; doesn't return until yield
#else    
;    CALL (NUM_THREADS << (4+8)) | thread_wrapper_#v(NUM_THREADS)); set active thread# + statup addr
    CALL stack_alloc_#v(NUM_THREADS); kludge: put thread_wrapper ret addr onto stack; NOTE: doesn't return until yield-back
;thread_wrapper_#v(NUM_THREADS): DROP_CONTEXT;
#if RERUN_THREADS
    LOCAL rerun_thread
 EMITL rerun_thread:
    CALL thread_body; start executing thread; allows thread to return but uses extra stack level
    GOTO rerun_thread
#else
    CALL thread_body; start executing thread; allows thread to return but uses extra stack level
;    YIELD; call yield_from_#v(NUM_THREADS) ;bypass dead (returned) threads in round robin yields
    YIELD_AGAIN; ret addr already correct, just yield to next thread
;stack_alloc does same thing as yield_from
#endif; @__LINE__
;    GOTO IIF(RERUN_THREADS, rerun_thr, yield_again); $-1; re-run thread or just yield to other threads
#endif; @__LINE__
#if 1
 EMITL yield_from_#v(NUM_THREADS): DROP_CONTEXT; overhead for first yield = 10 instr = 1.25 usec @8 MIPS
    mov8 stkptr_#v(NUM_THREADS), STKPTR; #v(curthread)
;yield_from_#v(NUM_THREADS)_placeholder set $
 EMITL yield_again_#v(NUM_THREADS): DROP_CONTEXT; overhead for repeating yield = 7 instr < 1 usec @8 MIPS
;    CONTEXT_SAVE yield_placeholder_#v(NUM_THREADS)
;    ORG $ + 2+1; placeholder for: mov8 STKPTR, stkptr_#v(NUM_THREADS + 1); % MAX_THREADS); #v(curthread + 1); round robin
    mov8 STKPTR, stkptr_#v(NUM_THREADS + 1); (yield_thread + 1) % NUM_THREADS); round robin wraps around
    RETURN;
;yield set yield_from_#v(NUM_THREADS); alias for caller
;yield_again set yield_again_#v(NUM_THREADS); alias for caller
#endif; @__LINE__
;alloc + stack + set initial addr:
;NOTE: thread doesn't start execeuting until all threads are defined (to allow yield to auto-start threads)
;CAUTION: execution is multi-threaded after this; host stack is taken over by threads; host stack depth !matter because will never return to single-threaded mode
;create_thread_#v(NUM_THREADS): DROP_CONTEXT;
;create thread but allow more init:
;    at_init TRUE;
;    EMIT goto init_#v(INIT_COUNT + 1); daisy chain: create next thread; CAUTION: use goto - change STKPTR here
;    mov8 PCLATH, LITERAL(NUM_THREADS << 4); set active thread#; will be saved/restored by yield
;    movlp NUM_THREADS << 4; set active thread#; will be saved/restored by yield_#v(); used by generic yield() to select active thread
;    movlw 0x0F
;    andwf PCLATH, F; drop current thread#, preserve current code page bits
;    movlw #v(NUM_THREADS) << 4;
;    iorwf PCLATH, F; set new thread#
;    setbit PCLATH, 12-8, NUM_THREADS & BIT(0);
;    mov16 TOS, LITERAL(NUM_THREADS << (4+8) | thread_wrapper_#v(NUM_THREADS)); thread statup addr
;kludge: put thread# in PCH msb; each thread runs on its own code page, but code can be shared between threads with virtual auto-thunks
;    PUSH LITERAL(NUM_THREADS << (4+8) | thread_wrapper_#v(NUM_THREADS)); set active thread# + statup addr
 EMITL stack_alloc_#v(NUM_THREADS): DROP_CONTEXT; CAUTION: this function delays return until yield-back
    mov8 stkptr_#v(NUM_THREADS), STKPTR;
;    REPEAT LITERAL(stacksize), PUSH thread_exec_#v(NUM_THREADS);
;    mov16 TOS, LITERAL(NUM_THREADS << 12 | thread_body); start_#v(NUM_THREADS)); set initial execution point in case another thread yields before this thread starts; thread exec could be delayed by using yield_#v() here
;    BANKCHK STKPTR;
    if (stacksize) <= 3
;	BANKSAFE dest_arg(F) incf STKPTR;, F;
;	INCF STKPTR, F;
        REPEAT LITERAL(stacksize - 1), dest_arg(F) INCF STKPTR; alloc requested space (1 level used by thread wrapper)
    else
        MOVLW stacksize - 1; stack level used for initial addr
;	BANKSAFE dest_arg(F) addwf STKPTR;, F; alloc stack space to thread
	ADDWF STKPTR, F; alloc stack space to thread
    endif; @__LINE__
;    goto create_thread_#v(NUM_THREADS - 1); daisy-chain: create previous thread; CAUTION: use goto - don't want to change STKPTR here!
;  messg [DEBUG] #v(BANK_TRACKER) @__LINE__
    at_init FALSE;
;    messg "YIELD = " YIELD @__LINE__
NUM_THREADS += 1; do this at start so it will remain validate within thread body; use non-0 for easier PCLATH debug; "thread 0" == prior to thread xition
;    messg "YIELD = " YIELD @__LINE__
IN_THREAD = NUM_THREADS;
;    EXPAND_POP @__LINE__
    endm; @__LINE__

THREAD_END macro
;    EXPAND_PUSH FALSE
    ERRIF(!IN_THREAD, [ERROR] no thread"," last used was #v(NUM_THREADS) @__LINE__);
IN_THREAD = FALSE;
;use generic versions outside of thread def:
;YIELD set yield
;YIELD_AGAIN set yield_again
;#undefine yield
;#undefine yield_again
;yield set yield_generic
;yield_again set yield_again_generic
#undefine YIELD
#undefine YIELD_AGAIN
;    EXPAND_POP
    endm; @__LINE__


;in-lined YIELD_AGAIN:
;occupies 2-3 words in prog space but avoids extra "goto" (2 instr cycles) on context changes at run time
;CAUTION: returns to previous YIELD, not code following
YIELD_AGAIN_inlined macro
    mov8 STKPTR, stkptr_#v(NUM_THREADS); round robin
    RETURN; return early if banksel !needed; more efficient than nop
    endm; @__LINE__

;create + execute threads:
;once threads are created, execution jumps to ukernel (via first thread) and never returns
;cre_threads macro
;init_#v(INIT_COUNT): DROP_CONTEXT; macro
;first set up thread stacks + exec addr:
;    LOCAL thr = #v(NUM_THREADS);
;    while thr > 0
;	call create_thread_#v(thr); NOTE: stack alloc + set initial addr; thread doesn't start until yielded to
;thr -= 1
;    endw; @__LINE__
;    call create_thread_#v(NUM_THREADS); create all threads (daisy chained)
;    WARNIF(!NUM_THREADS, [ERROR] no threads to create, going to sleep @__LINE__);
;    sleep
;start executing first thread; other threads will start as yielded to
;CAUTION: never returns
;create_thread_#v(0): DROP_CONTEXT;
;    mov8 STKPTR, stkptr_#v(NUM_THREADS); % MAX_THREADS); #v(curthread + 1); round robin
;    return;
;    ENDM
;INIT_COUNT = -1; += 999; no more init code after multi-threaded ukernel starts
    

;resume_thread macro thrnum
;    mov8 STKPTR, stkptr_#v(thrnum); % MAX_THREADS); #v(curthread + 1); round robin
;    return;
;    endm; @__LINE__
    
;yield_until macro reg, bitnum, bitval
;    ifbit reg, bitnum, bitval, resume_thread
;    mov8 stkptr_#v(NUM_THREADS), STKPTR; #v(curthread)
;    mov8 STKPTR, stkptr_#v(NUM_THREADS + 1); % MAX_THREADS); #v(curthread + 1); round robin
;    endm; @__LINE__

;yield_delay macro usec_delay
;    endm; @__LINE__

; messg EOF_COUNT @__LINE__
eof_#v(EOF_COUNT) macro
;    EXPAND_PUSH FALSE
;    messg [INFO] #threads: #v(NUM_THREADS), stack space needed: #v(STK_ALLOC), unalloc: #v(HOST_STKLEN - STK_ALLOC) @__LINE__
;optimize special cases:
;    if NUM_THREADS == 1
;	messg TODO: bypass yield (only 1 thread) @__LINE__
;    endif; @__LINE__
;    if NUM_THREADS == 2
;	messg TODO: swap stkptr_#v() (only 2 threads) @__LINE__
;    endif; @__LINE__
;start executing first thread; other threads will start as yielded to
;CAUTION: never returns
    if NUM_THREADS
        messg [INFO] #threads: #v(NUM_THREADS), stack alloc: #v(STK_ALLOC)/#v(HOST_STKLEN) (#v(pct(STK_ALLOC, HOST_STKLEN))%) @__LINE__
stkptr_#v(NUM_THREADS) EQU stkptr_#v(0); wrap-around for round robin yield
;stkptr_#v(NUM_THREADS) SET stkptr_#v(0); wrap-around for round robin yield; NOTE: latest thread overwrites this
;	EMITL start_threads:; only used for debug
;	mov8 STKPTR, stkptr_#v(NUM_THREADS); % MAX_THREADS); #v(curthread + 1); round robin
;	EMIT return;
  messg [DEBUG] why is banksel needed here? #v(BANK_TRACKER) @__LINE__
	YIELD_AGAIN_inlined; start first thread
    endif; @__LINE__
;unneeded? generic yield:
;allows code sharing between threads, but adds extra run-time overhead (6 instr cycle per yield)
;caller can also use yield_from_#v() directly if target thread is constant (reduces overhead)
;    nbDCL curthread,; need to track which thread is executing
;kludge: use 4 msb of PCH to track which thread is running; 4 lsb can be involved with addressing
;CAUTION: this requires *all* shared and thread-specific code to run in a separate code page
; this allows code to be shared between threads but only works when code addresses wrap to existing prog space
;    EMITL yield_generic: DROP_CONTEXT;
;    BANKCHK TOSH;
;    BANKSAFE dest_arg(W) swapf TOSH;, W; PCLATH might have changed, TOSH gives true PC
;    EMIT andlw 0x0F; strip off 4 lsb (swapped), leaving thread#; NOTE: PC is 15 bits so only 8 thread pages are possible
;    EMIT brw
#if 1
 EMITL stkptr_#v(NUM_THREADS) EQU stkptr_0; //round robin
#else
    LOCAL yield_thread = 0, here
;    LOCAL save_place = $, save_wreg = WREG_TRACKER, save_bank = BANK_TRACKER
    CONTEXT_SAVE before_yield
    while yield_thread < NUM_THREADS
;	EMIT goto yield_from_#v(yield_thread); NOTE: 4 msb PCLATH will be set within yield_#v()
;go back and fill in placeholders now that we know which thread# will wrap back to 0:
;save_place = $
;BANK_TRACKER = STKPTR; BSR was set < placeholder
;	DROP_WREG;
;	ORG yield_from_#v(yield_thread)_placeholder
        CONTEXT_RESTORE yield_placeholder_#v(yield_thread)
here = $	
	mov8 STKPTR, stkptr_#v(yield_thread + 1); (yield_thread + 1) % NUM_THREADS); round robin wraps around
	if $ < here + 2+1
	    RETURN; return early if banksel !needed; more efficient than nop
	endif; @__LINE__
;	DROP_WREG;
;	ORG yield_again_#v(yield_thread)_placeholder
;        CONTEXT_RESTORE yield_again_placeholder_#v(yield_thread)
;here = $	
;	mov8 STKPTR, stkptr_#v((yield_thread + 1) % NUM_THREADS); round robin wraps around
;	if $ < here + 3
;	    EMIT return; fill space reserve for banksel; return rather than nop
;	endif; @__LINE__
;	ORG save_place
yield_thread += 1
    endw; @__LINE__
;    ORG save_place
;WREG_TRACKER = save_wreg
;BANK_TRACKER = save_bank
    CONTEXT_RESTORE before_yield
#endif
;    while yield_thread < 16
;	EMIT sleep; pad out jump table in case of unknown thread
;yield_thread += 1
;    endw; @__LINE__
;generic yield_again:
;    EMITL yield_again_generic: DROP_CONTEXT;
;    BANKCHK TOSH;
;    BANKSAFE dest_arg(W) swapf TOSH;, W; PCLATH might have changed, TOSH gives true PC
;    EMIT andlw 0x0F; strip off 4 lsb (swapped), leaving thread#; NOTE: PC is 15 bits so only 8 thread pages are possible
;    EMIT brw
;    while yield_thread < 16 + NUM_THREADS
;	EMIT goto yield_again_#v(yield_thread % NUM_THREADS); NOTE: 4 msb PCLATH will be set within yield_#v()
;yield_thread += 1
;    endw; @__LINE__
;    while yield_thread < 16 + 16
;	EMIT sleep; pad out jump table in case of unknown thread
;yield_thread += 1
;    endw; @__LINE__
;    EXPAND_POP
    endm; @__LINE__
EOF_COUNT += 1;


;; config/init ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;peripherals used as follows:
;- Timer 0 generates interrupt for next frame after 50 usec WS idle time or for animation (while interrupts off)
;- Timer 1 gate mode measures WS input pulse width for decoding first WS input pixel or just counting ws bytes thereafter
;- Timer 2 used as elapsed time for FPS tracking
;- EUSART used to generate WS breakout stream
;- CLC1-3 redirects WS input to other pins (segments)


;disable unused peripherals:
;saves a little power, helps prevent accidental interactions
#define ENABLED(n)  NOBIT(n); all peripherals are ON by default
#define DISABLED(n)  BIT(n)
#define ENABLED_ALL  0
#define DISABLED_ALL  0xFF
pmd_init macro
;    exitm; @__LINE__
    EXPAND_PUSH FALSE, @__LINE__
;?    mov8 ODCONA, LITERAL(0); //all push-pull out (default), no open drain
;?    mov8 SLRCONA, LITERAL(~BIT(RA3)); //0x37); //limit slew rate, all output pins 25 ns vs 5 ns
;?    mov8 INLVLA, LITERAL(~BIT(RA3)); //0x3F); //TTL input levels on all input pins
;??    mov8 RA4PPS, LITERAL(0x01);   ;RA4->CLC1:CLC1OUT;    
;??    mov8 RA5PPS, LITERAL(0x01);   ;RA5->CLC1:CLC1OUT;    
;??    mov8 RA1PPS, LITERAL(0x01);   ;RA1->CLC1:CLC1OUT;    
;??    mov8 RA2PPS, LITERAL(0x01);   ;RA2->CLC1:CLC1OUT;    
;??    mov8 RA0PPS, LITERAL(0x16);   ;RA0->MSSP1:SDO1;    
;    setbit PMD0, FVRMD, DISABLED;
;    setbit PMD0, NVMMD, DISABLED;
;    setbit PMD0, CLKRMD, DISABLED;
;    setbit PMD0, IOCMD, DISABLED;
#if 0
;//no- allow peripherals to use clock, allow prog space I/O:
    mov8 PMD0, LITERAL(DISABLED_ALL); //^ DISABLED(SYSCMD) ^ DISABLED(NVMMD)); ENABLED(SYSCMD) | DISABLED(FVRMD) | DISABLED(NVMMD) | DISABLED(CLKRMD) | DISABLED(IOCMD)); keep sys clock, disable FVR, NVM, CLKR, IOC
;    setbit PMD1, NCOMD, DISABLED;
;//no- leave T0-2 enabled, they're typically used:
    mov8 PMD1, LITERAL(DISABLED_ALL); //^ DISABLED(TMR2MD) ^ DISABLED(TMR1MD) ^ DISABLED(TMR0MD)); DISABLED(NCOMD) | ENABLED(TMR2MD) | ENABLED(TMR1MD) | ENABLED(TMR0MD)); disable NCO, enabled Timer 0 - 2
#else
    mov8 PMD0, LITERAL(DISABLED_ALL ^ DISABLED(SYSCMD) ^ DISABLED(NVMMD)); ENABLED(SYSCMD) | DISABLED(FVRMD) | DISABLED(NVMMD) | DISABLED(CLKRMD) | DISABLED(IOCMD)); keep sys clock, disable FVR, NVM, CLKR, IOC
    messg ^^vv disable until needed? @__LINE__
    mov8 PMD1, LITERAL(DISABLED_ALL ^ DISABLED(TMR2MD) ^ DISABLED(TMR1MD) ^ DISABLED(TMR0MD)); DISABLED(NCOMD) | ENABLED(TMR2MD) | ENABLED(TMR1MD) | ENABLED(TMR0MD)); disable NCO, enabled Timer 0 - 2
#endif; @__LINE__
;    setbit PMD2, DAC1MD, DISABLED;
;    setbit PMD2, ADCMD, DISABLED;
;    setbit PMD2, CMP1MD, DISABLED;
;    setbit PMD2, ZCDMD, DISABLED;
    mov8 PMD2, LITERAL(DISABLED_ALL); DISABLED(DAC1MD) | DISABLED(ADCMD) | DISABLED(CMP1MD) | DISABLED(ZCDMD)); disable DAC1, ADC, CMP1, ZCD
;    setbit PMD3, PWM6MD, DISABLED;
;    setbit PMD3, PWM5MD, DISABLED;
;    setbit PMD3, PWM4MD, DISABLED;
;    setbit PMD3, CCP2MD, DISABLED;
;    setbit PMD3, CCP1MD, DISABLED;
    mov8 PMD3, LITERAL(DISABLED_ALL); ^ DISABLED(CCP1MD)); DISABLED(PWM6MD) | DISABLED(PWM5MD) | DISABLED(PWM4MD) | ENABLED(PWM3MD) | DISABLED(CCP2MD) | DISABLED(CCP1MD)); enable PWM 3, disable PWM 4 - 6, CCP 1 - 2
;    setbit PMD4, UART1MD, DISABLED;
;    setbit PMD4, CWG1MD, DISABLED;
    mov8 PMD4, LITERAL(DISABLED_ALL); ^ DISABLED(UART1MD)); ENABLED(UART1MD) | DISABLED(MSSP1MD) | DISABLED(CWG1MD)); disable EUSART1, CWG1, enable MSSP1
;    setbit PMD5, CLC4MD, DISABLED; IIFDEBUG(ENABLED, DISABLED);
;    setbit PMD5, CLC3MD, DISABLED;
;    messg ^v REINSTATE @__LINE__
;    mov8 PMD5, LITERAL(DISABLED(CLC4MD) | DISABLED(CLC3MD) | ENABLED(CLC2MD) | ENABLED(CLC1MD)); disable CLC 3, 4, enable CLC 1, 2
    mov8 PMD5, LITERAL(DISABLED_ALL); ENABLED_ALL); DISABLED_ALL ^ DISABLED(CLC#v(WSPASS)MD) ^ DISABLED(CLC#v(WSDO)MD)); ENABLED(CLC4MD) | ENABLED(CLC3MD) | ENABLED(CLC2MD) | ENABLED(CLC1MD)); disable CLC 3, 4, enable CLC 1, 2
    EXPAND_PUSH FALSE, @__LINE__
    endm; @__LINE__


;NOTE: default is unlocked
pps_lock macro want_lock
;requires next 5 instructions in sequence:
    mov8 PPSLOCK, LITERAL(0x55);
    mov8 PPSLOCK, LITERAL(0xAA);
;    mov8 PPSLOCK, LITERAL(0); allow CLC1 output to be redirected to RA1/2/5/4
    setbit PPSLOCK, PPSLOCKED, want_lock; allow output pins to be reassigned
    endm; @__LINE__


;Arduino/Broadcom-style pin functions:
;NOTE: these are less efficient than setting all pins at once
;TODO: use pin bitmap
    CONSTANT InDigital = 0x100, Pullup = 0x80, InAnalog = 0x200, InFlags = InDigital | Pullup | InAnalog;
    CONSTANT OutHigh = 1, OutLow = 2, OutOpenDrain = 4, OutFlags = OutHigh | OutLow | OutOpenDrain;
PinMode macro pinn, modee
    EXPAND_PUSH FALSE, @__LINE__
;    messg "here1" @__LINE__
    if (modee) & InFlags
	ERRIF((modee) & OutFlags, [ERROR] Input pin #v(pinn) can''t also be output: mode #v(modee) @__LINE__);
        ERRIF((modee) & Pullup && (modee) & InAnalog, [ERROR] Analog pin #v(pinn) can''t use pullup: mode #v(modee) @__LINE__);
        setbit ANSELA, pinn, (modee) & InAnalog; //*must* set digital
	setbit WPUA, pinn, (modee) & Pullup;
    else
	ERRIF(!((modee) & OutFlags), [ERROR] Pin #v(pinn) must be input or output: mode #v(modee) @__LINE);
;??    setbit ODCONA, pin, mode & PushPull;
;??    setbit INLVLA, pin, mode & Shmitt; //shmitt trigger input levels
;??    setbit SLRCONA, pin, mode & Slew; //on = 25 nsec slew, off = 5 nsec slew
	setbit LATA, pinn, (modee) & OutHigh; //start low to prevent junk on line
    endif; @__LINE__
;#ifdef WANT_I2C
    setbit TRISA, pinn, (modee) & InFlags; //1 = Input, 0 = Output
;#endif; @__LINE__
;?    REPEAT LITERAL(RA5 - RA0 + 1), mov8 RA0PPS + repeater, LITERAL(NO_PPS); reset to LATA; is this needed? (datasheet says undefined at startup)
    EXPAND_POP @__LINE__
    endm; @__LINE__

;initialize I/O pins:
;NOTE: RX/TX must be set for Input when EUSART is synchronous, however UESART controls this?
;#define NO_PPS  0
;#define INPUT_PINS  (BIT(WSDI) | BIT(RA#v(BREAKOUT))); //0x00); //all pins are output but datasheet says to set TRIS for peripheral pins; that is just to turn off general-purpose output drivers
;#ifdef SDA1_PIN
; #ifndef WANT_I2C
;  #define WANT_I2C
; #endif; @__LINE__
;#endif; @__LINE__
;#ifdef SCL1_PIN
; #ifndef WANT_I2C
;  #define WANT_I2C
; #endif; @__LINE__
;#endif; @__LINE__
iopin_init macro
    EXPAND_PUSH FALSE, @__LINE__
;    mov8 ANSELA, LITERAL(0); //all digital (most common case); CAUTION: do this before pin I/O
;    mov8 WPUA, LITERAL(0xFF); //set all weak pull-ups in case TRIS left as-is; //LITERAL(BIT(RA3)); INPUT_PINS); //weak pull-up on input pins in case not connected (ignored if MCLRE configured)
;#if 0
;    messg are these needed? @__LINE__
;    mov8 ODCONA, LITERAL(0); push-pull outputs
;    mov8 INLVLA, LITERAL(~0 & 0xff); shmitt trigger input levels;  = 0x3F;
;    mov8 SLRCONA, LITERAL(~BIT(RA#v(RA3)) & 0xff); on = 25 nsec slew, off = 5 nsec slew; = 0x37;
;#endif; @__LINE__
;    mov8 LATA, LITERAL(0); //start low to prevent junk on line
;#ifdef WANT_I2C
;//leave as all input until needed    mov8 TRISA, LITERAL(BIT(RA3)); | BIT(RA#v(BREAKOUT))); INPUT_PINS); //0x00); //all pins are output but datasheet says to set TRIS for peripheral pins; that is just to turn off general-purpose output drivers
;#endif; @__LINE__
;?    REPEAT LITERAL(RA5 - RA0 + 1), mov8 RA0PPS + repeater, LITERAL(NO_PPS); reset to LATA; is this needed? (datasheet says undefined at startup)
    EXPAND_POP @__LINE__
    endm; @__LINE__


;    LIST
;    LIST_PUSH TRUE
;HFFRQ values:
;(these should be in p16f15313.inc)
;    LIST_PUSH TRUE, @__LINE__
    CONSTANT HFFRQ_#v(32 MHz) = b'110'
    CONSTANT HFFRQ_#v(16 MHz) = b'101'
    CONSTANT HFFRQ_#v(12 MHz) = b'100'
    CONSTANT HFFRQ_#v(8 MHz) = b'011'
    CONSTANT HFFRQ_#v(4 MHz) = b'010'
    CONSTANT HFFRQ_#v(2 MHz) = b'001'
    CONSTANT HFFRQ_#v(1 MHz) = b'000'
;    LIST_POP @__LINE__
;    NOLIST

;set int osc freq:
;    CONSTANT CLKDIV = (FOSC_CFG / PWM_FREQ); CLK_FREQ / HFINTOSC_FREQ);
;#define HFINTOSC_NOSC  b'110' ;use OSCFRQ; 0; no change (use cfg); should be in p16f15313.inc
#define USE_HFFRQ  b'110'; should be in p16f15313.inc
;#define PWM_FREQ  (16 MHz); (FOSC_CFG / 2); need PWM freq 16 MHz because max speed is Timer2 / 2 and Timer2 max speed is FOSC/4
;#define FOSC_FREQ  PWM_FREQ; FOSC needs to run at least as fast as needed by PWM
;#define FOSC_FREQ  (32 MHz); (16 MHz); nope-FOSC needs to be a multiple of WS half-bit time; use 4 MIPS to allow bit-banging (DEBUG ONLY)
;    CONSTANT MY_OSCCON = USE_HFFRQ << NOSC0 | 0 << NDIV0; (log2(CLKDIV) << NDIV0 | HFINTOSC_NOSC << NOSC0);
;    messg [INFO] FOSC #v(FOSC_CFG), PWM freq #v(PWM_FREQ) @__LINE__;, CLK DIV #v(CLKDIV) => my OSCCON #v(MY_OSCCON)
;    messg [INFO], Fosc #v(FOSC_FREQ) == 4 MIPS? #v(FOSC_FREQ == 4 MIPS), WS bit freq #v(WSBIT_FREQ), #instr/wsbit #v(FOSC_FREQ/4 / WSBIT_FREQ) @__LINE__
fosc_init macro ;speed, mode
    EXPAND_PUSH FALSE, @__LINE__
;    mov8 OSCCON1, LITERAL(b'110' << NOSC0 | b'0000' << NDIV0
;RSTOSC in CONFIG1 tells HFFRQ to default to 32 MHz, use 2:1 div for 16 MHz:
    setbit OSCCON3, CSWHOLD, FALSE; use new clock as soon as stable (should be immediate if HFFRQ !changed)
    mov8 OSCCON1, LITERAL(USE_HFFRQ << NOSC0 | 0 << NDIV0); MY_OSCCON); 1:1
    mov8 OSCFRQ, LITERAL(HFFRQ_#v(FOSC_FREQ));
;    ERRIF CLK_FREQ != 32 MHz, [ERROR] need to set OSCCON1, clk freq #v(CLK_FREQ) != 32 MHz
;CAUTION: assume osc freq !change, just divider, so new oscillator is ready immediately
;;    ifbit PIR1, CSWIF, FALSE, goto $-1; wait for clock switch to complete
;    ifbit OSCCON3, ORDY, FALSE, goto $-1; wait for clock switch to complete
    EXPAND_POP @__LINE__
    endm; @__LINE__


;general I/O initialization:
    at_init TRUE
;    EXPAND_DEBUG @__LINE__
;    variable xyz = 1;
;    EMIT variable abc = 2;
    EXPAND_PUSH TRUE, @__LINE__
;    EXPAND_DEBUG @__LINE__
    iopin_init;
;    EXPAND_DEBUG @__LINE__
    fosc_init;
;    EXPAND_DEBUG @__LINE__
    pmd_init; turn off unused peripherals
;    EXPAND_DEBUG @__LINE__
    EXPAND_POP @__LINE__
;    EXPAND_DEBUG @__LINE__
;NOPE: PPS assigned during brkout_render    pps_lock TRUE; prevent pin reassignments; default is unlocked
    at_init FALSE


;; config ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Configuration bits: selected in the GUI (MCC)
;#if EXT_CLK_FREQ  ;ext clock might be present
;MY_CONFIG &= _EC_OSC  ;I/O on RA4, CLKIN on RA5; external clock (18.432 MHz); if not present, int osc will be used
;MY_CONFIG &= _FCMEN_ON  ;turn on fail-safe clock monitor in case external clock is not connected or fails (page 33); RA5 will still be configured as input, though
;#else  ;EXT_CLK_FREQ
;MY_CONFIG &= _INTRC_OSC_NOCLKOUT  ;I/O on RA4+5; internal clock (default 4 MHz, later bumped up to 8 MHz)
;MY_CONFIG &= _FCMEN_OFF  ;disable fail-safe clock monitor; NOTE: this bit must explicitly be turned off since MY_CONFIG started with all bits ON
;#endif; @__LINE__  ;EXTCLK_FREQ
;MY_CONFIG &= _IESO_OFF  ;internal/external switchover not needed; turn on to use optional external clock?  disabled when EC mode is on (page 31); TODO: turn on for battery-backup or RTC
;MY_CONFIG &= _BOR_OFF  ;brown-out disabled; TODO: turn this on when battery-backup clock is implemented?
;MY_CONFIG &= _CPD_OFF  ;data memory (EEPROM) NOT protected; TODO: CPD on or off? (EEPROM cleared)
;MY_CONFIG &= _CP_OFF  ;program code memory NOT protected (maybe it should be?)
;MY_CONFIG &= _MCLRE_OFF  ;use MCLR pin as INPUT pin (required for Renard); no external reset needed anyway
;MY_CONFIG &= _PWRTE_ON  ;hold PIC in reset for 64 msec after power up until signals stabilize; seems like a good idea since MCLR is not used
;MY_CONFIG &= _WDT_ON  ;use WDT to restart if software crashes (paranoid); WDT has 8-bit pre- (shared) and 16-bit post-scalars (page 125)
;	__config MY_CONFIG

    LIST_PUSH FALSE, @__LINE__
;#define CFG_BASE  -1; //start with all bits on, then EXPLICITLY turn them off
;#define CFG1A  CFG_BASE
;#define CFG1B  CFG1A & _FCMEN_OFF ; Fail-Safe Clock Monitor Enable bit->FSCM timer disabled
;#define CFG1C  CFG1B & _CSWEN_OFF ;unneeded    ; Clock Switch Enable bit->Writing to NOSC and NDIV is allowed
;#define CFG1D  CFG1C & _CLKOUTEN_OFF ; Clock Out Enable bit->CLKOUT function is disabled; i/o or oscillator function on OSC2
;#define CFG1E  CFG1D & _RSTOSC_HFINT32 ;HFINTOSC with OSCFRQ= 32 MHz and CDIV = 1:1
;#define CFG1_FINAL  CFG1E    
    VARIABLE MY_CONFIG1 = -1  ;start with all Oscillator bits on, then EXPLICITLY turn them off below
MY_CONFIG1 &= _FCMEN_OFF  ; Fail-Safe Clock Monitor Enable bit->FSCM timer disabled
MY_CONFIG1 &= _CSWEN_OFF ;unneeded    ; Clock Switch Enable bit->Writing to NOSC and NDIV is allowed
MY_CONFIG1 &= _CLKOUTEN_OFF  ; Clock Out Enable bit->CLKOUT function is disabled; i/o or oscillator function on OSC2
;#define WANT_PLL  TRUE
;#ifdef WANT_PLL
; MY_CONFIG1 &= _RSTOSC_HFINTPLL  ;Power-up default value for COSC bits->HFINTOSC with 2x PLL, with OSCFRQ = 16 MHz and CDIV = 1:1 (FOSC = 32 MHz)
;#else
;set initial osc freq (will be overridden during startup):
MY_CONFIG1 &= _RSTOSC_HFINT32 ;HFINTOSC with OSCFRQ= 32 MHz and CDIV = 1:1
;#endif; @__LINE__
;MY_CONFIG1 &= _RSTOSC_HFINT1  ;Power-up default value for COSC bits->HFINTOSC (1MHz)
    messg [TODO] use RSTOSC HFINT 1MHz? @__LINE__
;#define OSCFRQ_CFG  (16 MHz)
;#define FOSC_CFG  (32 MHz) ;(16 MHz PLL) ;(OSCFRQ_CFG PLL); HFINTOSC freq 16 MHz with 2x PLL and 1:1 div gives 32 MHz (8 MIPS)
MY_CONFIG1 &= _FEXTOSC_OFF  ;External Oscillator mode selection bits->Oscillator not enabled
    VARIABLE MY_CONFIG2 = -1  ;start with all Supervisor bits on, then EXPLICITLY turn them off below
MY_CONFIG2 &= _STVREN_OFF  ; allow wrap: xition to threaded mode can happen from any stack depth; Stack Overflow/Underflow Reset Enable bit->Stack Overflow or Underflow will cause a reset
MY_CONFIG2 &= _PPS1WAY_ON ; Peripheral Pin Select one-way control->The PPSLOCK bit can be cleared and set only once in software
MY_CONFIG2 &= _ZCD_OFF   ; Zero-cross detect disable->Zero-cross detect circuit is disabled at POR.
MY_CONFIG2 &= _BORV_LO   ; Brown-out Reset Voltage Selection->Brown-out Reset Voltage (VBOR) set to 1.9V on LF, and 2.45V on F Devices
MY_CONFIG2 &= _BOREN_ON  ; Brown-out reset enable bits->Brown-out Reset Enabled, SBOREN bit is ignored
MY_CONFIG2 &= _LPBOREN_OFF   ; Low-Power BOR enable bit->ULPBOR disabled
MY_CONFIG2 &= _PWRTE_OFF  ; Power-up Timer Enable bit->PWRT disabled
MY_CONFIG2 &= _MCLRE_OFF  ; Master Clear Enable bit->MCLR pin function is port defined function
    VARIABLE MY_CONFIG3 = -1  ;start with all WIndowed Watchdog bits on, then EXPLICITLY turn them off below
; config WDTCPS = WDTCPS_31    ; WDT Period Select bits->Divider ratio 1:65536; software control of WDTPS
MY_CONFIG3 &= _WDTE_OFF  ; WDT operating mode->WDT Disabled, SWDTEN is ignored
; config WDTCWS = WDTCWS_7    ; WDT Window Select bits->window always open (100%); software control; keyed access not required
; config WDTCCS = SC    ; WDT input clock selector->Software Control
    VARIABLE MY_CONFIG4 = -1  ;start with all Memory bits on, then EXPLICITLY turn them off below
    MESSG [TODO] boot loader + LVP? @__LINE__
MY_CONFIG4 &= _LVP_OFF ;ON?  ; Low Voltage Programming Enable bit->High Voltage on MCLR/Vpp must be used for programming
MY_CONFIG4 &= _WRTSAF_OFF  ; Storage Area Flash Write Protection bit->SAF not write protected
MY_CONFIG4 &= _WRTC_OFF  ; Configuration Register Write Protection bit->Configuration Register not write protected
MY_CONFIG4 &= _WRTB_OFF  ; Boot Block Write Protection bit->Boot Block not write protected
MY_CONFIG4 &= _WRTAPP_OFF  ; Application Block Write Protection bit->Application Block not write protected
MY_CONFIG4 &= _SAFEN_OFF  ; SAF Enable bit->SAF disabled
MY_CONFIG4 &= _BBEN_OFF  ; Boot Block Enable bit->Boot Block disabled
MY_CONFIG4 &= _BBSIZE_BB512  ; Boot Block Size Selection bits->512 words boot block size
    VARIABLE MY_CONFIG5 = -1  ;start with all Code Protection bits on, then EXPLICITLY turn them off below
MY_CONFIG5 &= _CP_OFF  ; UserNVM Program memory code protection bit->UserNVM code protection disabled
    LIST_PUSH TRUE, @__LINE__
    __config _CONFIG1, #v(MY_CONFIG1); @__LINE__
    __config _CONFIG2, #v(MY_CONFIG2); @__LINE__
    __config _CONFIG3, #v(MY_CONFIG3); @__LINE__
    __config _CONFIG4, #v(MY_CONFIG4); @__LINE__
    __config _CONFIG5, #v(MY_CONFIG5); @__LINE__
    LIST_POP @__LINE__; pop
;config
; config FOSC = HS        ; Oscillator Selection bits (HS oscillator)
; config WDTE = OFF       ; Watchdog Timer Enable bit (WDT disabled)
; config PWRTE = OFF      ; Power-up Timer Enable bit (PWRT disabled)
; config BOREN = OFF      ; Brown-out Reset Enable bit (BOR disabled)
; config LVP = OFF        ; Low-Voltage (Single-Supply) In-Circuit Serial Programming Enable bit (RB3 is digital I/O, HV on MCLR must be used for programming)
; config CPD = OFF        ; Data EEPROM Memory Code Protection bit (Data EEPROM code protection off)
; config WRT = OFF        ; Flash Program Memory Write Enable bits (Write protection off; all program memory may be written to by EECON control)
; config CP = OFF         ; Flash Program Memory Code Protection bit (Code protection off)
    LIST_POP @__LINE__; pop

;    EXPAND_POP @__LINE__
    LIST_POP @__LINE__
;    messg end of hoist 2 @__LINE__
;#else; too deep :(
#endif; @__LINE__
#if HOIST == 1
;    messg hoist 1: custom opc @__LINE__
    LIST_PUSH FALSE, @__LINE__; don't show this section in .LST file
;    LIST_DEBUG @__LINE__
;    EXPAND_PUSH FALSE, @__LINE__
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;    LIST_DEBUG @__LINE__
;    EXPAND_DEBUG @__LINE__
#ifdef WANT_DEBUG
 #define IIFDEBUG(expr_true, ignored)  expr_true
#else
 #define IIFDEBUG(ignored, expr_false)  expr_false
#endif; @__LINE__
;#ifdef WANT_DEBUG
; #define NOLIST  LIST; leave it all on
;    messg [INFO] COMPILED FOR DEV/DEBUG! @__LINE__
;#endif; @__LINE__
    WARNIF(IIFDEBUG(TRUE, FALSE), [INFO] COMPILED FOR DEV/DEBUG! @__LINE__);

    
    LIST n = 60, c = 200, t = on, n = 0  ;line (page) size, column size, truncate, no paging
;	LIST r=hex  ;radix; NOTE: this affects interpretation of literals, as well as output listing; ALWAYS use D'' with literals > 8
    LIST R = DEC
    LIST mm = on  ;memory map
    LIST st = on  ;symbol table
;    PAGEWIDTH   132
;    RADIX       DEC

#ifdef __16F15313
    LIST p = 16F15313
    PROCESSOR 16F15313  ;688 ;16F877A
#define LIST; disable within .inc
#define NOLIST; disable within .inc
;#include "P16F15313.INC"
 #include <p16f15313.inc>
#undefine NOLIST; re-enable
#undefine LIST; re-enable
#define SUPPORTED  TRUE
;#else
#endif; @__LINE__
#ifdef __16F18446
    LIST p = 16F18446
    PROCESSOR 16F18446
#define LIST; disable within .inc
#define NOLIST; disable within .inc
 #define REPEAT  REPEAT_PIC; avoid unfortunate name conflicts
 #define BIT  BIT_PIC; avoid unfortunate name conflicts
 #include <p16f18446.inc>
 #define _PWRTE_OFF  _PWRTS_OFF; make names consistent
 #define T0OUTPS0  OUTPS0
 #undefine REPEAT
 #undefine BIT
#undefine NOLIST; re-enable
#undefine LIST; re-enable
#define SUPPORTED  TRUE
#endif; @__LINE__
#ifndef SUPPORTED
    error [ERROR] Unsupported device @__LINE__; add others as support added
#endif; @__LINE__
;pic-as not mpasm: #include <xc.inc>


;clock macros:
#define mhz(freq)  rdiv(freq, 1000000)
#define khz(freq)  rdiv(freq, 1000)
#define prescaler(base_freq, want_freq)  log2((base_freq) / (want_freq))
;CAUTION: avoid arith overflow:
;#define scale(freq, prescaler)  ((freq) / BIT(prescaler))
#define scale(freq, prescale)  (BIT(prescale) KHz / khz(freq)); split 1M factor to avoid arith overflow; BIT(PRESCALER - 3); usec
;#define prescfreq(prescaler)  (FOSC_FREQ / 4 / BIT(prescaler));
;readabililty macros:
;CAUTION: use with "()"
#define MHz  * 1000000
#define KHz  * 1000
;#define Hz  * 1
#define usec  * 1
#define msec  * 1000
#define sec  * 1000000
#define PLL  * 2; PLL on int osc is 2, ext clk is 4
#define MIPS  * 4 MHz ;4 clock cycles per instr


;* lookup tables (faster than computing as needed) ************************************

;add lookup for non-power of 2:
;find_log2 macro val
;    LOCAL bit = 0;
;    while BIT(bit)
;	if BIT(bit) > 0
;    messg #v(asmpower2), #v(oscpower2), #v(prescpower2), #v(asmbit) @__LINE__
;	    CONSTANT log2(asmpower2) = asmbit
;	endif; @__LINE__
;ASM_MSB set asmpower2  ;remember MSB; assembler uses 32-bit values
;asmpower2 *= 2
;    endm; @__LINE__

;log2 function:
;converts value -> bit mask at compile time; CAUTION: assumes value is exact power of 2
;usage: LOG2_#v(bit#) = power of 2
;NOTE: only works for exact powers of 2
;equivalent to the following definitions:
;#define LOG2_65536  d'16'
; ...
;#define LOG2_4  2
;#define LOG2_2  1
;#define LOG2_1  0
;#define LOG2_0  0
;    EXPAND_PUSH FALSE
#define log2(n)  LOG2_#v(n)
;#define osclog2(freq)  OSCLOG2_#v(freq)
;#define osclog2(freq)  log2((freq) / 250 * 256); kludge: convert clock freq to power of 2
    CONSTANT log2(0) = 0 ;special case
;    CONSTANT osc_log2(0) = 0;
    VARIABLE asmbit = 0, asmpower2 = 1;, oscpower2 = 1, prescpower2 = 1;
    while asmpower2 ;asmbit <= d'16'  ;-1, 0, 1, 2, ..., 16
;	CONSTANT BIT_#v(IIF(bit < 0, 0, 1<<bit)) = IIF(bit < 0, 0, bit)
	if asmpower2 > 0
;    messg #v(asmpower2), #v(oscpower2), #v(prescpower2), #v(asmbit) @__LINE__
	    CONSTANT log2(asmpower2) = asmbit
;	    CONSTANT osclog2(oscpower2) = asmbit
;	    CONSTANT log2(oscpower2) = asmbit
;	    CONSTANT log2(prescpower2) = asmbit
	endif; @__LINE__
	if !(2 * asmpower2)
	    EMITL ASM_MSB EQU #v(asmpower2)  ;remember MSB; assembler uses 32-bit signed values so this should be 32
	endif; @__LINE__
asmpower2 <<= 1
;oscpower2 *= 2
;	if oscpower2 == 128
;oscpower = 125
;	endif; @__LINE__
;oscpower2 = IIF(asmpower2 != 128, IIF(asmpower2 != 32768, 2 * oscpower2, 31250), 125); adjust to powers of 10 for clock freqs
;prescpower2 = IIF(asmpower2 != 128, IIF(asmpower2 != 32768, 2 * prescpower2, 31250), 122); adjust to powers of 10 for prescalars
asmbit += 1
    endw; @__LINE__
;    EXPAND_POP
    ERRIF(log2(1) | log2(0), [ERROR] LOG2_ constants are bad: log2(1) = #v(log2(1)) and log2(0) = #v(log2(0))"," should be 0 @__LINE__); paranoid self-check
    ERRIF(log2(1024) != 10, [ERROR] LOG2_ constants are bad: log2(1024) = #v(log2(1024))"," should be #v(10) @__LINE__); paranoid self-check
;    ERRIF (log2(1 KHz) != 10) | (log2(1 MHz) != 20), [ERROR] OSCLOG2_ constants are bad: log2(1 KHz) = #v(log2(1 KHz)) and log2(1 MHz) = #v(log2(1 MHz)), should be 10 and 20 ;paranoid self-check
;ASM_MSB set 0x80000000  ;assembler uses 32-bit values
    ERRIF((ASM_MSB << 1) || !ASM_MSB, [ERROR] ASM_MSB incorrect value: #v(ASM_MSB << 1)"," #v(ASM_MSB) @__LINE__); paranoid check
    WARNIF((ASM_MSB | 0x800) & 0x800 != 0X800, [ERROR] bit-wise & !worky on ASM_MSB #v(ASM_MSB): #v((ASM_MSB | 0x800) & 0x800) @__LINE__);


;get #bits in a literal value:
;    VARIABLE NUMBITS;
;numbits macro val
;NUMBITS = 
    
;get msb of a literal value:
    VARIABLE FOUND_MSB
find_msb macro value
;    EXPAND_PUSH TRUE
FOUND_MSB = ASM_MSB
    while FOUND_MSB
	if (value) & FOUND_MSB
;	    EXPAND_POP
	    exitm; @__LINE__
	endif; @__LINE__
FOUND_MSB >>= 1
    endw; @__LINE__
;    EXPAND_POP
    endm; @__LINE__


;; memory management helpers ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;PIC memory banks:
;#define COMMON_START  0
#define COMMON_END  0xC
#define GPR_START  0x20
#define GPR_END  0x70
;    CONSTANT GPR_LEN = GPR_END - GPR_START;
#define BANKLEN  0x80
;    CONSTANT NONBANKED_LEN = BANKLEN - GPR_END;
;line too long    CONSTANT BANKLEN = 0X80;
#define BANK_UNKN  -1 ;non-banked or unknown
;line too long    CONSTANT BANK_UNKN = -1; non-banked or unknown
#define BANKOFS(reg)  ((reg) % BANKLEN)
#define ISBANKED(reg)  ((BANKOFS(reg) >= COMMON_END) && (BANKOFS(reg) < GPR_END))
;    MESSG "TODO: check !banked reg also @__LINE__"
#define BANKOF(reg)  IIF(ISBANKED(reg), REG2ADDR(reg) / BANKLEN, BANK_UNKN)
#define NEEDS_BANKSEL(regto, regfrom)  (ISBANKED(regto) && (BANKOF(regto) != BANKOF(regfrom)))

#define LINEAR(reg)  (((reg) - GPR_START) | 0x2000); GPR linear addressing


;optimized bank select:
;only generates bank selects if needed
    VARIABLE BANK_TRACKER = BANK_UNKN; ;currently selected bank
    VARIABLE BANKSEL_KEEP = 0, BANKSEL_DROP = 0; ;perf stats
BANKCHK MACRO reg; ;, fixit, undef_ok
    EXPAND_PUSH FALSE, @__LINE__; reduce clutter in LST file
;    MESSG reg @__LINE__
    LOCAL REG = reg ;kludge; force eval (avoids "missing operand" and "missing argument" errors/MPASM bugs); also helps avoid "line too long" messages (MPASM limit 200)
;    MESSG reg, #v(REG) @__LINE__
;    messg "bankof reg, nobank", #v(BANKOF(REG)), #v(BANK_UNKN)  @__LINE__;debug
    if !ISLIT(REG) && ISBANKED(REG); BANKOF(REG) == BANK_UNKN
        LOCAL REGBANK = BANKOF(REG) ;kludge: expanded line too long for MPASM
;    messg BANKOF(REG) @__LINE__; #v(REGBANK);
	if REGBANK != BANKOF(BANK_TRACKER)  ;don't need to set RP0/RP1
;    messg "banksel bankof reg @__LINE__"
;    movlb BANKOF(REG) ;bank sel
	    EMIT banksel reg;
BANKSEL_KEEP += 1
BANK_TRACKER = reg  ;remember where latest value came from (in case never set)
	else
;PREVBANK = REG  ;update last-used reg anyway (helpful for debug)
BANKSEL_DROP += 1  ;count saved instructions (macro perf)
	endif; @__LINE__
    endif; @__LINE__
    EXPAND_POP @__LINE__
    endm; @__LINE__

; messg EOF_COUNT @__LINE__
eof_#v(EOF_COUNT) macro
    messg [INFO] bank sel: #v(BANKSEL_KEEP) (#v(pct(BANKSEL_KEEP, BANKSEL_KEEP + BANKSEL_DROP))%), dropped: #v(BANKSEL_DROP) (#v(pct(BANKSEL_DROP, BANKSEL_KEEP + BANKSEL_DROP))%) @__LINE__; ;perf stats
    endm; @__LINE__
EOF_COUNT += 1;


DROP_BANK macro
;    EXPAND_PUSH FALSE
BANK_TRACKER = BANK_UNKN  ;forget where latest value came from (used for jump targets)
;    EXPAND_POP
    endm; @__LINE__

;avoid warnings when bank is known to be selected
;#define NOARG  -1; dummy arg (MPASM doesn't like missing/optional args)
BANKSAFE macro stmt
;    EXPAND_PUSH FALSE
;    NOEXPAND
    errorlevel -302  ;this is a useless/annoying message because the assembler doesn't handle it well (always generates warning when accessing registers in bank 1, even if you've set the bank select bits correctly)
;    messg BANKSAFE: stmt @__LINE__
;        EXPAND_RESTORE
;    EXPAND_PUSH TRUE
    stmt
;    EXPAND_POP
;	NOEXPAND
    errorlevel +302 ;kludge: re-Enable bank switch warning
;    EXPAND_RESTORE
;    EXPAND_POP
    endm; @__LINE__
;BANKSAFE1 macro stmt, arg
;    NOEXPAND
;    errorlevel -302  ;this is a useless/annoying message because the assembler doesn't handle it well (always generates warning when accessing registers in bank 1, even if you've set the bank select bits correctly)
;;    if arg == NOARG
;;        EXPAND_RESTORE
;;	stmt
;;	NOEXPAND
;;    else
;    messg stmt @__LINE__
;    messg arg @__LINE__
;        EXPAND_RESTORE
;	stmt, arg
;	NOEXPAND
;;    endif; @__LINE__
;    errorlevel +302 ;kludge: re-Enable bank switch warning
;    EXPAND_RESTORE
;    endm; @__LINE__
;BANKSAFE2 macro stmt, arg1, arsg2
;    NOEXPAND
;    errorlevel -302 ;kludge: Disable bank switch warning
;	EXPAND_RESTORE
;	stmt, arg1, arg2
;	NOEXPAND
;    errorlevel +302 ;kludge: re-Enable bank switch warning
;    EXPAND_RESTORE
;    endm; @__LINE__
 

;jump target:
;set BSR and WREG unknown
DROP_CONTEXT MACRO
    EXPAND_PUSH FALSE, @__LINE__
    DROP_BANK
    DROP_WREG
;TODO: drop PAGE_TRACKER?
    EXPAND_POP @__LINE__
    endm; @__LINE__


;    VARIABLE CTX_DEPTH = 0
;#define CONTEXT_PUSH  CTX_STATE TRUE
;#define CONTEXT_POP  CTX_STATE FALSE
;CTX_STATE macro push_pop
;    if BOOL2INT(push_pop)
;	VARIABLE CTX_ADDR#v(CTX_DEPTH) = $
;	VARIABLE CTX_WREG#v(CTX_DEPTH) = WREG_TRACKER
;	VARIABLE CTX_BANK#v(CTX_DEPTH) = BANK_TRACKER
;	DROP_CONTEXT
;CTX_DEPTH += 1
;    else
;CTX_DEPTH -= 1
;        ORG CTX_ADDR#v(CTX_DEPTH)
;WREG_TRACKER = CTX_WREG#v(CTX_DEPTH)
;BANK_TRACKER = CTX_BANK#v(CTX_DEPTH)
;    endif; @__LINE__
;    endm; @__LINE__

;push context under top of stack:
;CONTEXT_PUSH_UNDER macro
;    VARIABLE CTX_ADDR#v(CTX_DEPTH) = CTX_ADDR#v(CTX_DEPTH - 1);
;    VARIABLE CTX_WREG#v(CTX_DEPTH) = CTX_WREG#v(CTX_DEPTH - 1);
;    VARIABLE CTX_BANK#v(CTX_DEPTH) = CTX_BANK#v(CTX_DEPTH - 1);
;CTX_DEPTH -=1
;    CONTEXT_PUSH
;CTX_DEPTH +=1
;    endm; @__LINE__

;eof_#v(EOF_COUNT) macro
;    WARNIF(CTX_DEPTH, [WARNING] context stack not empty @eof: #v(CTX_DEPTH)"," last addr = #v(CTX_ADDR#v(CTX_DEPTH - 1)) @__LINE__)
;    endm; @__LINE__
;EOF_COUNT += 1;

;save/restore compile-time execution context:
;allows better banksel/pagesel/wreg optimization
;kludge: use #v(0) in lieu of token pasting
;#define bitnum_arg(argg)  withbit_#v(argg)
    VARIABLE NUM_CONTEXT = 0
#define CONTEXT_ADDR(name)  ctx_addr_#v(name)
CONTEXT_SAVE macro name
name SET #v(NUM_CONTEXT); allow context access by caller-supplied name; allow re-def
NUM_CONTEXT += 1
    VARIABLE ctx_addr_#v(name) = $
    VARIABLE ctx_wreg_#v(name) = WREG_TRACKER
    VARIABLE ctx_bank_#v(name) = BANK_TRACKER
    VARIABLE ctx_init_#v(name) = DOING_INIT
    VARIABLE ctx_page_#v(name) = PAGE_TRACKER#v(BOOL2INT(DOING_INIT))
;no, let stmt change it;    DROP_CONTEXT
;    messg save ctx_#v(name)_addr #v(ctx_#v(name)_addr), ctx_#v(name)_page #v(ctx_#v(name)_page) @__LINE__
    endm; @__LINE__

CONTEXT_RESTORE macro name
;    messg restore ctx_#v(name)_addr #v(ctx_#v(name)_addr), ctx_#v(name)_page #v(ctx_#v(name)_page) @__LINE__
    ORG ctx_addr_#v(name);
WREG_TRACKER = ctx_wreg_#v(name)
BANK_TRACKER = ctx_bank_#v(name)
PAGE_TRACKER#v(BOOL2INT(ctx_init_#v(name))) = ctx_page_#v(name)
    endm; @__LINE__


;convenience wrappers for SAFE_ALLOC macro:
;#define b0DCL(name)  ALLOC_GPR name, TRUE; banked alloc
;#define nbDCL(name)  ALLOC_GPR name, FALSE; non-banked alloc
#define b0DCL  ALLOC_GPR 0, ; bank 0 alloc
#define b1DCL  ALLOC_GPR 1, ; bank 1 alloc
#define nbDCL  ALLOC_GPR NOBANK, ; non-banked alloc
;allocate a banked/non-banked/reallocated variable:
;checks for address overflow on allocated variables
;also saves banked or non-banked RAM address for continuation in a later CBLOCK
    CONSTANT NOBANK = 9999; can't use -1 due to #v()
;    CONSTANT RAM_START#v(TRUE) = GPR_START, RAM_START#v(FALSE) = GPR_END;
;    CONSTANT MAX_RAM#v(TRUE) = GPR_END, MAX_RAM#v(FALSE) = BANKLEN;
;    CONSTANT RAM_LEN#v(TRUE) = MAX_RAM#v(TRUE) - RAM_START#v(TRUE), RAM_LEN#v(FALSE) = MAX_RAM#v(FALSE) - RAM_START#v(FALSE)
    CONSTANT RAM_START#v(0) = GPR_START, MAX_RAM#v(0) = GPR_END, RAM_LEN#v(0) = MAX_RAM#v(0) - RAM_START#v(0)
    CONSTANT RAM_START#v(1) = BANKLEN + GPR_START, MAX_RAM#v(1) = BANKLEN + GPR_END, RAM_LEN#v(1) = MAX_RAM#v(1) - RAM_START#v(1)
    CONSTANT RAM_START#v(NOBANK) = GPR_END, MAX_RAM#v(NOBANK) = BANKLEN, RAM_LEN#v(NOBANK) = MAX_RAM#v(NOBANK) - RAM_START#v(NOBANK)
;    VARIABLE NEXT_RAM#v(TRUE) = RAM_START#v(TRUE), NEXT_RAM#v(FALSE) = RAM_START#v(FALSE);
;    VARIABLE RAM_USED#v(TRUE) = 0, RAM_USED#v(FALSE) = 0;
    VARIABLE NEXT_RAM#v(0) = RAM_START#v(0), RAM_USED#v(0) = 0;
    VARIABLE NEXT_RAM#v(1) = RAM_START#v(1), RAM_USED#v(1) = 0;
    VARIABLE NEXT_RAM#v(NOBANK) = RAM_START#v(NOBANK), RAM_USED#v(NOBANK) = 0;
#define SIZEOF(name)  name#v(0)size; use #v(0) in lieu of token pasting
#define ENDOF(name)  (name + SIZEOF(name))
;params:
; name = variable name to allocate
; banked = flag controlling where it is allocated; TRUE/FALSE == yes/no, MAYBE == reallocate from caller-specified pool of reusable space
    VARIABLE RAM_BLOCK = 0; unique name for each block
ALLOC_GPR MACRO bank, name, numbytes
;    EXPAND_PUSH FALSE
;    NOEXPAND  ;reduce clutter
;    EXPAND_PUSH TRUE  ;show RAM allocations in LST
;    EXPAND ;show RAM allocations in LST
    EXPAND_PUSH TRUE, @__LINE__; CAUTION: macro expand must be set outside of cblock
    CBLOCK NEXT_RAM#v(bank); BOOL2INT(banked))  ;continue where we left off last time @__LINE__
	name numbytes; @__LINE__
    ENDC  ;can't span macros
    EXPAND_POP @__LINE__
;    EXPAND_PUSH FALSE
RAM_BLOCK += 1  ;need a unique symbol name so assembler doesn't complain; LOCAL won't work inside CBLOCK
;    EXPAND_RESTORE; NOEXPAND
    CBLOCK
	LATEST_RAM#v(RAM_BLOCK):0  ;get address of last alloc; need additional CBLOCK because macros cannot span CBLOCKS
    ENDC
;    NOEXPAND
NEXT_RAM#v(bank) = LATEST_RAM#v(RAM_BLOCK)  ;update pointer to next available RAM location
RAM_USED#v(bank) = NEXT_RAM#v(bank) - RAM_START#v(bank); BOOL2INT(banked))
    EMIT CONSTANT SIZEOF(name) = LATEST_RAM#v(RAM_BLOCK) - name;
    ERRIF(NEXT_RAM#v(bank) > MAX_RAM#v(bank), [ERROR] ALLOC_GPR: RAM overflow #v(LATEST_RAM#v(RAM_BLOCK)) > max #v(MAX_RAM#v(bank)) @__LINE__); BOOL2INT(banked))),
;    ERRIF LAST_RAM_ADDRESS_#v(RAM_BLOCK) > RAM_END#v(BOOL2INT(banked)), [ERROR] SAFE_ALLOC: RAM overflow #v(LAST_RAM_ADDRESS_#v(RAM_BLOCK)) > end #v(RAM_END#v(BOOL2INT(banked)))
;    ERRIF LAST_RAM_ADDRESS_#v(RAM_BLOCK) <= RAM_START#v(BOOL2INT(banked)), [ERROR] SAFE_ALLOC: RAM overflow #v(LAST_RAM_ADDRESS_#v(RAM_BLOCK)) <= start #v(RAM_START#v(BOOL2INT(banked)))
;    EXPAND_POP
;    EXPAND_POP
;    EXPAND_POP
    ENDM

; messg EOF_COUNT @__LINE__
eof_#v(EOF_COUNT) macro
    if RAM_USED#v(0)
        messg [INFO] bank0 used: #v(RAM_USED#v(0))/#v(RAM_LEN#v(0)) (#v(pct(RAM_USED#v(0), RAM_LEN#v(0)))%) @__LINE__
    endif; @__LINE__
    if RAM_USED#v(1)
	MESSG [INFO] bank1 used: #v(RAM_USED#v(1))/#v(RAM_LEN#v(1)) (#v(pct(RAM_USED#v(1), RAM_LEN#v(1)))%) @__LINE__
    endif; @__LINE__
    if RAM_USED#v(NOBANK)
        MESSG [INFO] non-banked used: #v(RAM_USED#v(NOBANK))/#v(RAM_LEN#v(NOBANK)) (#v(pct(RAM_USED#v(NOBANK), RAM_LEN#v(NOBANK)))%) @__LINE__
    endif; @__LINE__
    endm; @__LINE__
EOF_COUNT += 1;


;; custom 8-bit opcodes ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;#define PROGDCL  EMIT da; put value into prog space; use for opcodes or packed read-only data

;operand types:
;allows pseudo-opcodes to accept either literal or register values
;NOTE: assembler uses 32-bit constants internally; use msb to distinguish literal values from register addresses since it is not usually needed for code generation (which is only 8 or 14 bits)
;literal value operands:
#define LITERAL(n)  (ASM_MSB | (n))  ;prepend this to any 8-, 16- or 24-bit literal values used as pseudo-opcode parameters, to distinguish them from register addresses (which are only 1 byte)
#define ISLIT(val)  ((val) & ASM_MSB) ;((addr) & ASM_MSB) ;&& !ISPSEUDO(thing))  ;check for a literal
#define LIT2VAL(n)  ((n) & ~ASM_MSB)  ;convert from literal to number (strips _LITERAL tag)
;register operands:
#define REGISTER(a)  (a) ;address as-is
#define REG2ADDR(a)  (a)


;pseudo-reg:
;these have special meaning for mov8/MOVV/MOVWF
    CONSTANT INDF1_special = 0x10000;
    CONSTANT INDF1_preinc = (INDF1_special + 0); moviw ++INDF1
    CONSTANT INDF1_predec = (INDF1_special + 1); moviw --INDF1
    CONSTANT INDF1_postinc = (INDF1_special + 2); moviw INDF1++
    CONSTANT INDF1_postdec = (INDF1_special + 3); moviw INDF1--
    CONSTANT INDF0_special = 0x20000;
    CONSTANT INDF0_preinc = (INDF0_special + 0); moviw ++INDF0
    CONSTANT INDF0_predec = (INDF0_special + 1); moviw --INDF0
    CONSTANT INDF0_postinc = (INDF0_special + 2); moviw INDF0++
    CONSTANT INDF0_postdec = (INDF0_special + 3); moviw INDF0--
;#define MOVIW_opc(fsr, mode)  PROGDCL 0x10 | ((fsr) == FSR1) << 2 | ((mode) & 3)
#define MOVIW_opc(fsr, mode)  MOVIW_fsr#v((fsr) == FSR1)_#v((mode) & 3)
#define MOVIW_fsr1_0  MOVIW ++FSR1
#define MOVIW_fsr1_1  MOVIW --FSR1
#define MOVIW_fsr1_2  MOVIW FSR1++
#define MOVIW_fsr1_3  MOVIW FSR1--
#define MOVIW_fsr0_0  MOVIW ++FSR0
#define MOVIW_fsr0_1  MOVIW --FSR0
#define MOVIW_fsr0_2  MOVIW FSR0++
#define MOVIW_fsr0_3  MOVIW FSR0--
;#define MOVWI_opc(fsr, mode)  PROGDCL 0x18 | ((fsr) == FSR1) << 2 | ((mode) & 3)
#define MOVWI_opc(fsr, mode)  MOVWI_fsr#v((fsr) == FSR1)_#v((mode) & 3)
#define MOVWI_fsr1_0  MOVWI ++FSR1
#define MOVWI_fsr1_1  MOVWI --FSR1
#define MOVWI_fsr1_2  MOVWI FSR1++
#define MOVWI_fsr1_3  MOVWI FSR1--
#define MOVWI_fsr0_0  MOVWI ++FSR0
#define MOVWI_fsr0_1  MOVWI --FSR0
#define MOVWI_fsr0_2  MOVWI FSR0++
#define MOVWI_fsr0_3  MOVWI FSR0--


;move (copy) reg or value to reg:
;optimized to reduce banksel and redundant WREG loads
;    messg "TODO: optimize mov8 to avoid redundant loads @__LINE__"
;#define UNKNOWN  -1 ;non-banked or unknown
    CONSTANT WREG_UNKN = ASM_MSB >> 1; -1; ISLIT == FALSE
    VARIABLE WREG_TRACKER = WREG_UNKN ;unknown at start
mov8 macro dest, src
    EXPAND_PUSH FALSE, @__LINE__
;    NOEXPAND  ;reduce clutter
;    if (SRC == DEST) && ((srcbytes) == (destbytes)) && !(reverse)  ;nothing to do
    LOCAL SRC = src ;kludge; force eval (avoids "missing operand" and "missing argument" errors/MPASM bugs); also helps avoid "line too long" messages (MPASM limit 200)
    LOCAL DEST = dest ;kludge; force eval (avoids "missing operand" and "missing argument" errors/MPASM bugs); also helps avoid "line too long" messages (MPASM limit 200)
    WARNIF(DEST == SRC, [WARNING] useless mov8 from dest to src @__LINE__);
;    messg "mov8", #v(DEST), #v(SRC), #v(ISLIT(SRC)), #v(LIT2VAL(SRC)) @__LINE__
;    messg src, dest @__LINE__;
    if ISLIT(SRC)  ;unpack SRC bytes
; messg dest, #v(!LIT2VAL(SRC)), #v(DEST != WREG), #v(!(DEST & INDF0_special)), #v(!(DEST & INDF1_special)) @__LINE__
	if !LIT2VAL(SRC) && (DEST != WREG) && !(DEST & INDF0_special) && !(DEST & INDF1_special)
;	    BANKCHK dest;
;	    BANKSAFE clrf dest; special case
;	    EMIT CLRF dest;
	    CLRF dest;
	    EXPAND_POP @__LINE__
	    exitm; @__LINE__
	endif; @__LINE__
	if WREG_TRACKER != src
;	    EXPAND_RESTORE ;show generated opcodes
;	    EMIT movlw LIT2VAL(src); #v(LIT2VAL(SRC))
	    MOVLW LIT2VAL(src);
;	    NOEXPAND
;WREG_TRACKER = src
	endif; @__LINE__
    else ;register
	if (SRC != WREG) && (SRC != WREG_TRACKER)
	    MOVF src, W;
	endif; @__LINE__
;special pseudo-reg:
;	if src & INDF0_special
;;	    EXPAND_RESTORE; NOEXPAND
;	    EMIT MOVIW_opc(FSR0, SRC);
;;	    NOEXPAND  ;reduce clutter
;	else
;	    if src & INDF1_special
;;	        EXPAND_RESTORE; NOEXPAND
;		EMIT MOVIW_opc(FSR1, SRC);
;;		NOEXPAND  ;reduce clutter
;	    else
;		if (SRC != WREG) && (SRC != WREG_TRACKER)
;;		    BANKCHK src;
;;		    BANKSAFE dest_arg(W) movf src;, W;
;;WREG_TRACKER = src
;		    MOVF src, W;
;;		else
;;		    if (SRC == WREG) && (WREG_TRACKER == WREG_UNKN)
;;			messg [WARNING] WREG contents unknown here @__LINE__
;;		    endif; @__LINE__
;		endif; @__LINE__
;	    endif; @__LINE__
;	endif; @__LINE__
    endif; @__LINE__
;    if dest & INDF0_special
;;        EXPAND_RESTORE; NOEXPAND
;	EMIT MOVWI_opc(FSR0, dest);
;;	NOEXPAND  ;reduce clutter
;    else
;	if dest & INDF1_special
;;	    EXPAND_RESTORE; NOEXPAND
;	    EMIT MOVWI_opc(FSR1, dest);
;;	    NOEXPAND  ;reduce clutter
;	else
    if dest != WREG
;;		BANKCHK dest;
;;		BANKSAFE movwf dest; NOARG
	MOVWF dest;
;	    endif; @__LINE__
;        endif; @__LINE__
    endif; @__LINE__
    EXPAND_POP @__LINE__
    endm; @__LINE__

DROP_WREG macro
;    EXPAND_PUSH FALSE
WREG_TRACKER = WREG_UNKN  ;forget latest value
;    EXPAND_POP
    endm; @__LINE__


;invert Carry
;CAUTION: destroys WREG, Z
;INVC macro
;    MOVLW BIT(Carry)
;    XORWF STATUS, F; invert Carry
;    endm; @__LINE__

;WREG = lhs - rhs
;sets Borrow and Equals
    VARIABLE has_WREG2 = FALSE;
cmp8 macro lhs, rhs
    if lhs == WREG; special cases; need to swap operands
	if ISLIT(rhs)
	    ADDLW -LIT2VAL(rhs) & 0xFF
	    exitm; @__LINE__
	else; use temp for lhs
	    if !has_WREG2
		nbDCL8 WREG2;
has_WREG2 = TRUE
	    endif; @__LINE__
	    mov8 WREG2, lhs;
lhs = WREG2
	endif; @__LINE__
    endif; @__LINE__
    mov8 WREG, rhs
    if ISLIT(lhs)
	SUBLW LIT2VAL(lhs)
    else
	BANKCHK lhs
	SUBWF lhs, W
    endif; @__LINE__
    endm; @__LINE__


cmp16 macro lhs, rhs
    LOCAL not_eq;
;    LOCAL LHS = #v(lhs)
;    LOCAL RHS = #v(rhs)
;CAUTION: line too long; use #v()
    cmp8 BYTEOF(#v(lhs), 1), BYTEOF(#v(rhs), 1)
    ifbit EQUALS0 FALSE, GOTO not_eq
    cmp8 BYTEOF(#v(lhs), 0), BYTEOF(#v(rhs), 0)
 EMITL not_eq:
    endm; @__LINE__

;add 8-bit value to 16-bit value:
add16_8 macro dest, src
    mov8 WREG, src;
    BANKCHK dest;
    ADDWF REGLO(dest), F;
    ifbit CARRY TRUE, dest_arg(F) INCF REGHI(dest);
    endm; @__LINE__

;2's complement:
comf2s macro reg, dest
;    EXPAND_PUSH FALSE
    BANKCHK reg;
;    BANKSAFE dest_arg(dest) comf reg;, dest;
    EMIT dest_arg(dest) comf reg;, dest;
;    messg here @__LINE__
;    BANKSAFE dest_arg(F) incf IIF(dest == W, WREG, reg);, F;
    INCF IIF(dest == W, WREG, reg), F;
;    if (reg == WREG) && ISLIT(WREG_TRACKER)
    if (reg == WREG) || !BOOL2INT(dest)
;WREG_TRACKER = LITERAL((0 - LITVAL(WREG_TRACKER)) & 0xFF)
WREG_TRACKER = IIF(ISLIT(WREG_TRACKER), LITERAL((0 - WREG_TRACKER) & 0xFF), WREG_UNKN)
;    else
;	if (dest == W) 
;	    DROP_WREG; unknown reg contents
;	endif; @__LINE__
    endif; @__LINE__
;    EXPAND_POP
    endm; @__LINE__


;swap 2 reg:
;uses no temps
swapreg macro reg1, reg2
;    EXPAND_PUSH FALSE
    if (reg2) == WREG
	XORWF reg1, W; reg ^ WREG
	XORWF reg1, F; reg ^ (reg ^ WREG) == WREG
	XORWF reg1, W; WREG ^ (reg ^ WREG) == reg
    else
	if (reg1) != WREG
	    MOVF reg1, W;
	endif; @__LINE__
	XORWF reg2, W; reg ^ WREG
	XORWF reg2, F; reg ^ (reg ^ WREG) == WREG
	XORWF reg1, F; WREG ^ (reg ^ WREG) == reg
    endif; @__LINE__
;    EXPAND_POP
    endm; @__LINE__


;bank-safe, tracker versions of opcodes:

#define CLRF  clrf_tracker; override default opcode for WREG tracking
;WREG tracking:
CLRF macro reg
;    EXPAND_PUSH FALSE
    BANKCHK reg
;too deep :(    mov8 reg, LITERAL(0);
    BANKSAFE EMIT clrf reg; PROGDCL 0x180 | ((reg) % (BANKLEN));
    if reg == WREG
WREG_TRACKER = LITERAL(0);
    endif; @__LINE__
;    EXPAND_POP
    endm; @__LINE__

LODW macro reg
    MOVF reg, W
    endm; @__LINE__

#define MOVWF  movwf_banksafe
MOVWF macro reg
;    EXPAND_PUSH FALSE
    if (reg) & INDF0_special
;        EXPAND_RESTORE; NOEXPAND
	EMIT MOVWI_opc(FSR0, reg);
;	NOEXPAND  ;reduce clutter
    else
	if (reg) & INDF1_special
;	    EXPAND_RESTORE; NOEXPAND
	    EMIT MOVWI_opc(FSR1, reg);
;	    NOEXPAND  ;reduce clutter
	else
;	    if reg != WREG
	    BANKCHK reg;
;		BANKSAFE movwf dest; NOARG
	    BANKSAFE EMIT movwf reg;
	endif; @__LINE__
    endif; @__LINE__
;    EXPAND_POP
    endm; @__LINE__


#define MOVF  movf_banksafe
MOVF macro reg, dest
;    EXPAND_PUSH FALSE
    if ((reg) & INDF0_special) && !BOOL2INT(dest)
;	    EXPAND_RESTORE; NOEXPAND
	EMIT MOVIW_opc(FSR0, reg);
;	    NOEXPAND  ;reduce clutter
WREG_TRACKER = WREG_UNKN;
    else
	if ((reg) & INDF1_special) && !BOOL2INT(dest)
;	        EXPAND_RESTORE; NOEXPAND
	    EMIT MOVIW_opc(FSR1, reg);
;		NOEXPAND  ;reduce clutter
WREG_TRACKER = WREG_UNKN;
	else
;	    if (SRC != WREG) && (SRC != WREG_TRACKER)
	    BANKCHK reg;
	    BANKSAFE EMIT dest_arg(dest) movf reg;, dest;
;WREG_TRACKER = src
	    if !BOOL2INT(dest); || (reg == WREG)
WREG_TRACKER = reg; IIF(ISLIT(WREG_TRACKER), WREG_TRACKER + 1, WREG_UNKN)
	    endif; @__LINE__
	endif; @__LINE__
    endif; @__LINE__
;    EXPAND_POP
    endm; @__LINE__


#define INCF  incf_banksafe
INCF macro reg, dest
;    EXPAND_PUSH FALSE
    BANKCHK reg
    BANKSAFE EMIT dest_arg(dest) incf reg;, dest;
    if (reg == WREG) || !BOOL2INT(dest)
WREG_TRACKER = IIF(ISLIT(WREG_TRACKER), WREG_TRACKER + 1, WREG_UNKN)
    endif; @__LINE__
;    EXPAND_POP
    endm; @__LINE__


#define DECF  decf_banksafe
DECF macro reg, dest
;    EXPAND_PUSH FALSE
    BANKCHK reg
    BANKSAFE EMIT dest_arg(dest) decf reg;, dest;
    if (reg == WREG) || !BOOL2INT(dest)
WREG_TRACKER = IIF(ISLIT(WREG_TRACKER), WREG_TRACKER + 1, WREG_UNKN)
    endif; @__LINE__
;    EXPAND_POP
    endm; @__LINE__

#define SWAPF  swapf_banksafe
SWAPF macro reg, dest
;    EXPAND_PUSH FALSE
    BANKCHK reg
    BANKSAFE EMIT dest_arg(dest) swapf reg;, dest;
    if (reg == WREG) || !BOOL2INT(dest)
WREG_TRACKER = IIF(ISLIT(WREG_TRACKER), LITERAL(((WREG_TRACKER >> 4) & 0xF) | ((WREG_TRACKER << 4) & 0xF0)), WREG_UNKN)
    endif; @__LINE__
;    EXPAND_POP
    endm; @__LINE__


#define ADDWF  addwf_banksafe
ADDWF macro reg, dest
;    EXPAND_PUSH FALSE
    BANKCHK reg
    BANKSAFE EMIT dest_arg(dest) addwf reg;, dest;
    if (reg == WREG) || !BOOL2INT(dest)
WREG_TRACKER = WREG_UNKN; IIF(ISLIT(WREG_TRACKER), WREG_TRACKER + 1, WREG_UNKN)
    endif; @__LINE__
;    EXPAND_POP
    endm; @__LINE__


#define LSLF  lslf_banksafe
LSLF macro reg, dest
    BANKCHK reg
    BANKSAFE EMIT dest_arg(dest) lslf reg;, dest
    endm; @__LINE__

#define XORWF  xorwf_banksafe
XORWF macro reg, dest
    BANKCHK reg
    BANKSAFE EMIT dest_arg(dest) xorwf reg;, dest
    endm; @__LINE__


#define SET8W  IORLW 0xFF; set all WREG bits
#define clrw  clrf WREG; clrw_tracker; override default opcode for WREG tracking
#define CLRW  CLRF WREG; clrw_tracker; override default opcode for WREG tracking
#define incw  addlw 1
#define INCW  ADDLW 1
;WREG tracking:
;clrw macro
;    mov8 WREG, LITERAL(0);
;    clrf WREG;
;    endm; @__LINE__

;#define moviw  moviw_tracker; override default opcode for WREG tracking
;moviw macro arg
;    moviw arg
;    DROP_WREG
;    endm; @__LINE__

#define MOVLW  movlw_tracker; override default opcode for WREG tracking
MOVLW macro value
;    EXPAND_PUSH FALSE
;    andlw arg
    ERRIF((value) & ~0xFF, [ERROR] extra MOV bits ignored: #v((value) & ~0xFF) @__LINE__)
    if WREG_TRACKER != LITERAL(value)
;    EXPAND_RESTORE; NOEXPAND
;    messg movlw_tracker: "value" #v(value) value @__LINE__
        EMIT movlw value; #v(value); PROGDCL 0x3000 | (value)
;    NOEXPAND; reduce clutter
WREG_TRACKER = LITERAL(value)
    endif; @__LINE__
;    EXPAND_POP
    endm; @__LINE__

    messg [TODO]: need to UNLIT WREG_TRACKER when used in arith (else upper bits might be affected) @__LINE__

#define ANDLW  andlw_tracker; override default opcode for WREG tracking
ANDLW macro value
;    EXPAND_PUSH FALSE
;    andlw arg
    ERRIF((value) & ~0xFF, [ERROR] extra AND bits ignored: #v((value) & ~0xFF) @__LINE__)
;    EXPAND_RESTORE; NOEXPAND
    EMIT andlw value; PROGDCL 0x3900 | value
;    NOEXPAND; reduce clutter
;don't do this: (doesn't handle STATUS)
    if WREG_TRACKER != WREG_UNKN
WREG_TRACKER = IIF(ISLIT(WREG_TRACKER), LITERAL(WREG_TRACKER & (value)), WREG_UNKN)
    endif; @__LINE__
;    DROP_WREG
;    EXPAND_POP
    endm; @__LINE__

#define IORLW  iorlw_tracker; override default opcode for WREG tracking
IORLW macro value
;    EXPAND_PUSH FALSE
;    andlw arg
    ERRIF((value) & ~0xFF, [ERROR] extra IOR bits ignored: #v((value) & ~0xFF) @__LINE__)
;    EXPAND_RESTORE; NOEXPAND
    EMIT iorlw value; PROGDCL 0x3800 | value
;    NOEXPAND; reduce clutter
;don't do this: (doesn't handle STATUS)
    if WREG_TRACKER != WREG_UNKN
WREG_TRACKER = IIF(ISLIT(WREG_TRACKER), LITERAL(WREG_TRACKER | (value)), WREG_UNKN)
    endif; @__LINE__
;    DROP_WREG
;    EXPAND_POP
    endm; @__LINE__

#define XORLW  xorlw_tracker; override default opcode for WREG tracking
XORLW macro value
;    EXPAND_PUSH FALSE
;    andlw arg
    ERRIF((value) & ~0xFF, [ERROR] extra XOR bits ignored: #v((value) & ~0xFF) @__LINE__)
;    EXPAND_RESTORE; NOEXPAND
    EMIT xorlw value; PROGDCL 0x3A00 | (value)
;    NOEXPAND; reduce clutter
;don't do this: (doesn't handle STATUS)
    if WREG_TRACKER != WREG_UNKN
WREG_TRACKER = IIF(ISLIT(WREG_TRACKER), LITERAL(WREG_TRACKER ^ (value)), WREG_UNKN)
    endif; @__LINE__
;    DROP_WREG
;    EXPAND_POP
    endm; @__LINE__

#define ADDLW  addlw_tracker; override default opcode for WREG tracking
ADDLW macro value
;    EXPAND_PUSH FALSE
;    addlw arg
    ERRIF((value) & ~0xFF, [ERROR] extra ADD bits ignored: #v((value) & ~0xFF) @__LINE__)
;    EXPAND_RESTORE; NOEXPAND
    EMIT addlw value; PROGDCL 0x3E00 | (value)
;    NOEXPAND; reduce clutter
;don't do this: (doesn't handle STATUS)
    if WREG_TRACKER != WREG_UNKN
WREG_TRACKER = IIF(ISLIT(WREG_TRACKER), LITERAL(WREG_TRACKER + (value)), WREG_UNKN)
    endif; @__LINE__
;    DROP_WREG
;    EXPAND_POP
    endm; @__LINE__

#define SUBLW  sublw_tracker; override default opcode for WREG tracking
SUBLW macro value
;    EXPAND_PUSH FALSE
;    addlw arg
    ERRIF((value) & ~0xFF, [ERROR] extra SUB bits ignored: #v((value) & ~0xFF) @__LINE__)
;    EXPAND_RESTORE; NOEXPAND
    EMIT sublw value; PROGDCL 0x3E00 | (value)
;    NOEXPAND; reduce clutter
;don't do this: (doesn't handle STATUS)
    if WREG_TRACKER != WREG_UNKN
;CAUTION: operands are reversed: W subtract *from* lit
WREG_TRACKER = IIF(ISLIT(WREG_TRACKER), LITERAL((value) - WREG_TRACKER), WREG_UNKN)
    endif; @__LINE__
;    DROP_WREG
;    EXPAND_POP
    endm; @__LINE__

;k - W - !B(C) => W
SUBLWB macro value
    ifbit BORROW TRUE, incw; apply Borrow first (sub will overwrite it)
    SUBLW value;
    endm; @__LINE__


#define DECFSZ  decfsz_tracker; override default opcode for WREG tracking
DECFSZ macro reg, dest; TODO: add goto arg for PAGECHK
;    EXPAND_PUSH FALSE
;    addlw arg
;    NOEXPAND; reduce clutter
    BANKCHK reg;
    BANKSAFE EMIT dest_arg(dest) decfsz reg;
;don't do this: (doesn't handle STATUS)
;    if WREG_TRACKER != WREG_UNKN
    if reg == WREG
WREG_TRACKER = IIF(ISLIT(WREG_TRACKER), LITERAL(WREG_TRACKER - 1), WREG_UNKN)
    else
	if dest == W
WREG_TRACKER = WREG_UNKN
	endif; @__LINE__
    endif; @__LINE__
;    DROP_WREG
;    EXPAND_POP
    endm; @__LINE__


#define INCFSZ  incfsz_tracker; override default opcode for WREG tracking
INCFSZ macro reg, dest; TODO: add goto arg for PAGECHK
;    EXPAND_PUSH FALSE
;    addlw arg
;    NOEXPAND; reduce clutter
    BANKCHK reg;
    BANKSAFE EMIT dest_arg(dest) incfsz reg;
;don't do this: (doesn't handle STATUS)
;    if WREG_TRACKER != WREG_UNKN
    if reg == WREG
WREG_TRACKER = IIF(ISLIT(WREG_TRACKER), LITERAL(WREG_TRACKER - 1), WREG_UNKN)
    else
	if dest == W
WREG_TRACKER = WREG_UNKN
	endif; @__LINE__
    endif; @__LINE__
;    DROP_WREG
;    EXPAND_POP
    endm; @__LINE__


#define BSF  bsf_tracker
BSF macro reg, bitnum
;    EXPAND_PUSH FALSE
    ERRIF((bitnum) & ~7, [ERROR] invalid bitnum ignored: #v(bitnum) @__LINE__)
    BANKCHK reg
    BANKSAFE EMIT bitnum_arg(bitnum) bsf reg
    if reg == WREG
WREG_TRACKER = IIF(ISLIT(WREG_TRACKER), LITERAL(WREG_TRACKER | BIT(bitnum)), WREG_UNKN)
    endif; @__LINE__
;    EXPAND_POP
    endm; @__LINE__


#define BCF  bcf_tracker
BCF macro reg, bitnum
;    EXPAND_PUSH FALSE
    ERRIF((bitnum) & ~7, [ERROR] invalid bitnum ignored: #v(bitnum) @__LINE__)
    BANKCHK reg
    BANKSAFE EMIT bitnum_arg(bitnum) bcf reg
    if reg == WREG
WREG_TRACKER = IIF(ISLIT(WREG_TRACKER), LITERAL(WREG_TRACKER & ~BIT(bitnum)), WREG_UNKN)
    endif; @__LINE__
;    EXPAND_POP
    endm; @__LINE__


#define ADDFSR  addfsr_wrap
ADDFSR macro reg, amt
    EMIT2 addfsr reg, amt;
    endm; @__LINE__


;; custom multi-byte opcodes (little endian): ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;broken (line too long)
#define LOBYTE(val)  BYTEOF(val, 0); IIF(ISLIT(val), LITERAL((val) & 0xFF), REGLO(val))
#define MIDBYTE(val)  BYTEOF(val, 1); IIF(ISLIT(val), LITERAL((val) >> 8 & 0xFF), REGMID(val))
#define HIBYTE24(val)  BYTEOF(val, 2); IIF(ISLIT(val), LITERAL((val) >> 16 & 0xFF), REGHI(val))
#define HIBYTE16(val)  BYTEOF(val, 1); IIF(ISLIT(val), LITERAL((val) >> 16 & 0xFF), REGHI(val))
;#define BYTEOF(val, byte)  BYTEOF_#v(ISLIT(val)) (val, byte)
;#define BYTEOF_0(val, byte)  ((val) + (byte)); register
;#define BYTEOF_1(val, byte)  ((val) & 0xFF << (8 * (byte))); literal
;little endian: byte 0 = LSB
#define BYTEOF(val, which)  IIF(ISLIT(val), BYTEOF_LIT(val, which), BYTEOF_REG(val, which))
#define BYTEOF_LIT(val, which)  LITERAL(((val) >> (8 * (which))) & 0xFF); literal
#define BYTEOF_REG(val, which)  REGISTER((val) + (which)); register, little endian


;    messg #v(PWM3DC), #v(PWM3DCL), #v(PWM3DCH) @__LINE__
#define mov16  mov_mb 16,
#define mov24  mov_mb 24,
;TODO?: mov32  mov_mb 32,
mov_mb macro numbits, dest, src
;    EXPAND_PUSH FALSE
;    NOEXPAND  ;reduce clutter
;    if (SRC == DEST) && ((srcbytes) == (destbytes)) && !(reverse)  ;nothing to do
;    LOCAL SRC = src ;kludge; force eval (avoids "missing operand" and "missing argument" errors/MPASM bugs); also helps avoid "line too long" messages (MPASM limit 200)
;    LOCAL DEST = dest ;kludge; force eval (avoids "missing operand" and "missing argument" errors/MPASM bugs); also helps avoid "line too long" messages (MPASM limit 200)
    LOCAL LODEST = REGLO(dest);
;    messg "check HI " dest @__LINE__
    LOCAL HIDEST = REGHI(dest);
    if numbits > 16
;        messg "check MID " dest @__LINE__
	LOCAL MIDDEST = REGMID(dest);
        ERRIF((HIDEST != MIDDEST+1) || (MIDDEST != LODEST+1), [ERROR] dest is not 24-bit little endian"," lo@#v(LODEST) mid@#v(MIDDEST) hi@#v(HIDEST) @__LINE__)
    else
;	messg #v(len), #v(LODEST), #v(LO(dest)), #v(HIDEST), #v(HI(dest)) @__LINE__
	ERRIF(HIDEST != LODEST+1, [ERROR] dest is not 16-bit little endian: lo@#v(LODEST)"," hi@#v(HIDEST) @__LINE__)
    endif; @__LINE__
    LOCAL SRC = src ;kludge; force eval (avoids "missing operand" and "missing argument" errors/MPASM bugs); also helps avoid "line too long" messages (MPASM limit 200)
    if ISLIT(SRC)  ;unpack SRC bytes
	mov8 REGLO(dest), LITERAL(SRC & 0xFF)
	if numbits > 16
	    mov8 REGMID(dest), LITERAL(SRC >> 8 & 0xFF)
	    mov8 REGHI(dest), LITERAL(SRC >> 16 & 0xFF)
	else
	    mov8 REGHI(dest), LITERAL(SRC >> 8 & 0xFF)
	endif; @__LINE__
    else ;register
	LOCAL LOSRC = REGLO(src);
;        messg "get HI " src @__LINE__
	LOCAL HISRC = REGHI(src);
	mov8 REGLO(dest), REGLO(src)
	if numbits > 16
	    LOCAL MIDSRC = REGMID(src);
	    ERRIF((HISRC != MIDSRC+1) || (MIDSRC != LOSRC+1), [ERROR] src is not 24-bit little endian"," lo@#v(LOSRC) mid@#v(MIDSRC) hi@#v(HISRC) @__LINE__)
;	    messg "get MID " src @__LINE__
	    mov8 REGMID(dest), REGMID(src)
	else
;	    messg #v(len), #v(LOSRC), #v(LO(src)), #v(HISRC), #v(HI(src)) @__LINE__
	    ERRIF(HISRC != LOSRC+1, [ERROR] src is not 16-bit little endian: lo@#v(LOSRC)"," hi@#v(HISRC) @__LINE__)
	endif; @__LINE__
	mov8 REGHI(dest), REGHI(src)
    endif; @__LINE__
;    EXPAND_RESTORE
;    EXPAND_POP
    endm; @__LINE__


inc16 macro reg
    if (reg == FSR0) || (reg == FSR1)
    	ADDFSR reg, +1; //next 8 px (1 bpp)
	exitm; @__LINE__
    endif; @__LINE__
    INCFSZ REGLO(reg), F
    DECF REGHI(reg), F; kludge: cancels incf below if !zero
    INCF REGHI(reg), F
    endm; @__LINE__


dec16 macro reg
    if (reg == FSR0) || (reg == FSR1)
    	ADDFSR reg, -1;
	exitm; @__LINE__
    endif; @__LINE__
    DECFSZ REGLO(reg), F
    INCF REGHI(reg), F; kludge: cancels decf below if !zero
    DECF REGHI(reg), F
    endm; @__LINE__


#if 0
;load immediate:
;uses FSR1 (not restored_
;customize as needed for varying lengths
;kludge: wrapped as macro to avoid code gen unless needed (and to avoid reset org)
    VARIABLE LDI_expanded = FALSE;
    messg [TODO] unpack 12 bits per addr instead of 8, reuse LDI_len temp @__LINE__
LDI macro size
    if !LDI_expanded
        nbDCL LDI_len,;
LDI_expanded = TRUE;
    endif; @__LINE__
LDI_#v(size): DROP_CONTEXT
    mov16 FSR1, TOS; data immediately follows "call"
    setbit REGHI(FSR1), log2(0x80), TRUE; access prog space
    mov8 LDI_len, LITERAL(8);
    PAGECHK LDI_#v(size)_loop; do this before decfsz
LDI_#v(size)_loop: ;NOTE: each INDF access from prog space uses 1 extra instr cycle
    mov8 INDF0_postinc, INDF1_postinc; repeat 3x to reduce loop overhead
    mov8 INDF0_postinc, INDF1_postinc;
    mov8 INDF0_postinc, INDF1_postinc;
    DECFSZ LDI_len, F
    GOTO LDI_#v(size)_loop;
    mov16 TOS, FSR1; return past immediate data
    RETURN;
    endm; @__LINE__
#endif; @__LINE__


#if 0
	PAGECHK memcpy_loop; do this before decfsz
memcpy_loop: DROP_CONTEXT;
    mov8 INDF0_postinc, INDF1_postinc;
    DECFSZ WREG, F
    GOTO memcpy_loop;
    RETURN;
memcpy macro dest, src, len
    mov16 FSR0, LITERAL(dest);
    mov16 FSR1, LITERAL(src);
    mov8 WREG, len;
    endm; @__LINE__
#endif; @__LINE__


;24-bit rotate left:
;C bit comes into lsb
;rlf24 macro reg
;    rlf REGLO(reg), F
;    rlf REGMID(reg), F
;    rlf REGHI(reg), F
;    endm; @__LINE__


;kludge: need inner macro level to force arg expansion:
;#define CONCAT(lhs, rhs)  lhs#v(0)rhs

b0DCL8 macro name
    b0DCL name,; 1 byte
    endm; @__LINE__
nbDCL8 macro name
    nbDCL name,;1 byte
    endm; @__LINE__


;kludge: MPASM token-pasting only occurs around #v():
#define REGHI(name)  name#v(0)hi ;CONCAT(name, H)
#define REGLO(name)  name ;leave LSB as-is to use as generic name ref ;CONCAT(name, L)
;    CONSTANT REGHI(PWM3DC) = PWM3DCH; shim
b0DCL16 macro name
;    EXPAND_PUSH FALSE
    b0DCL REGLO(name),:2
;    b0DCL REGHI(name),
    EMIT CONSTANT REGHI(name) = REGLO(name) + 1;
;    CONSTANT name = REGLO(name); kludge: allow generic reference to both bytes
;    EXPAND_POP
    endm; @__LINE__

nbDCL16 macro name
;    EXPAND_PUSH FALSE
    nbDCL REGLO(name),:2
;    nbDCL REGHI(name),
    EMIT CONSTANT REGHI(name) = REGLO(name) + 1;
;    CONSTANT name = REGLO(name); kludge: allow generic reference to both bytes
;    EXPAND_POP
    endm; @__LINE__

#define REGMID(name)  name#v(0)mid ;CONCAT(name, M)
b0DCL24 macro name
;    EXPAND_PUSH FALSE
    b0DCL REGLO(name),:3
;    b0DCL REGMID(name),
;    b0DCL REGHI(name),
    EMIT CONSTANT REGMID(name) = REGLO(name) + 1;
    EMIT CONSTANT REGHI(name) = REGLO(name) + 2;
;    CONSTANT name = REGLO(name); kludge: allow generic reference to all 3 bytes
;    EXPAND_POP
    endm; @__LINE__

nbDCL24 macro name
;    EXPAND_PUSH FALSE
    nbDCL REGLO(name),:3
;    nbDCL REGMID(name),
;    nbDCL REGHI(name),
    EMIT CONSTANT REGMID(name) = REGLO(name) + 1;
    EMIT CONSTANT REGHI(name) = REGLO(name) + 2;
;    CONSTANT name = REGLO(name); kludge: allow generic reference to all 3 bytes
;    EXPAND_POP
    endm; @__LINE__


;    constant REGLO(PALETTE_#v(0)) = palents + 0*3, REGMID(
;    EMIT CONSTANT REGMID(name) = REGLO(name) + 1;
;    EMIT CONSTANT REGHI(name) = REGLO(name) + 2;
ALIAS_DCL24 macro alias, addr
    constant REGLO(alias) = (addr)+0;
    constant REGMID(alias) = (addr)+1;
    constant REGHI(alias) = (addr)+2;
    endm; @__LINE__


;    LIST_PUSH TRUE
    CONSTANT REGHI(FSR0) = FSR0H; mov16 shim
    CONSTANT REGHI(FSR1) = FSR1H; mov16 shim
TOS EQU TOSL; make naming more consistent
    CONSTANT REGHI(TOS) = TOSH; mov16 shim
    CONSTANT REGHI(SP1BRG) = SP1BRGH; mov16 shim
    CONSTANT REGHI(NVMADR) = NVMADRH; mov16 shim
    CONSTANT REGHI(NVMDAT) = NVMDATH; mov16 shim
;    LIST_POP

;; custom 1-bit opcodes: ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;bit operands:
#define BIT(n)  (1 << (n)); YNBIT(1, n); //(1 << (n))
#define REVBIT(n)  (0x80 >> (n))
#define NOBIT(n)  0; //YNBIT(0, n); (0 << (n))
;#define YNBIT(yesno, n)  ((yesno) << (n))
#define XBIT(n)  NOBIT(n); don't care (safer to turn off?)
#define LITBIT(n)  LITERAL(BIT(n))

;allow reg + bit# to be passed as 1 arg:
#define BITWRAP(reg, bitnum)  (((reg) << 4) | ((bitnum) & 0x0F))
#define REGOF(bitwrap)  (((bitwrap) >> 4) & 0xFFFF)
#define BITOF(bitwrap)  ((bitwrap) & 0x0F)


;allocate a 1-bit variable (cuts down on memory usage):
;currently bit variables are allocated in non-banked RAM to cut down on bank selects
;all bit vars are initialized to 0
    VARIABLE BITDCL_COUNT = 0;
#define BITPARENT(name)  BITVARS#v(name / 8), 7 - name % 8; for ifbit/setbit
BITDCL MACRO name  ;, banked
    EXPAND_PUSH FALSE, @__LINE__; hide clutter in LST file
;    LOCAL banked = FALSE  ;don't need this param; hard-code to OFF
    if !(BITDCL_COUNT % 8); allocate more storage space
;	if banked
;	    BDCL BITDCL#v(BITDCL_COUNT_#v(banked) / 8)
;	else
;	NBDCL BITDCL#v(BITDCL_COUNT_#v(banked) / 8)
        nbDCL BITVARS#v(BITDCL_COUNT / 8),; //general-use bit vars
        at_init TRUE;
	mov8 BITVARS#v(BITDCL_COUNT / 8), LITERAL(0); init all bit vars to 0
	at_init FALSE;
;	endif; @__LINE__
    endif; @__LINE__
    EMIT CONSTANT name = BITDCL_COUNT; _#v(banked); remember where the bit is
BITDCL_COUNT += 1; _#v(banked) += 1
    EXPAND_POP @__LINE__
    ENDM

eof_#v(EOF_COUNT) macro
    if BITDCL_COUNT
	exitm; @__LINE__
    endif; @__LINE__
    messg [INFO] (non-banked) Bit vars: allocated #v(8 * divup(BITDCL_COUNT, 8)), used #v(BITDCL_COUNT) @__LINE__
    endm; @__LINE__
EOF_COUNT += 1;


;single-arg wrappers (avoids ","):
biton macro regbit
    setbit REGOF(regbit), BITOF(regbit), TRUE
    endm
bitoff macro regbit
    setbit REGOF(regbit), BITOF(regbit), FALSE
    endm
 
;setbit_only macro dest, bit, bitval
;    mov8 dest, LITERAL(IIF(BOOL2INT(bitval), BIT(bit), 0)
;    endm; @__LINE__
;set/clear bit:
setbit macro dest, bit, bitval
    EXPAND_PUSH FALSE, @__LINE__
;    NOEXPAND  ;reduce clutter
;    if (SRC == DEST) && ((srcbytes) == (destbytes)) && !(reverse)  ;nothing to do
;    LOCAL BIT = bit ;kludge; force eval (avoids "missing operand" and "missing argument" errors/MPASM bugs); also helps avoid "line too long" messages (MPASM limit 200)
    LOCAL DEST = dest ;kludge; force eval (avoids "missing operand" and "missing argument" errors/MPASM bugs); also helps avoid "line too long" messages (MPASM limit 200)
;    messg "mov8", #v(DEST), #v(SRC), #v(ISLIT(SRC)), #v(LIT2VAL(SRC)) @__LINE__
;    messg src, dest @__LINE__;
;    BANKCHK dest;
    LOCAL BITNUM = #v(bit)
    if BOOL2INT(bitval)
;        BANKSAFE bitnum_arg(BITNUM) bsf dest;, bit;
;        EMIT bitnum_arg(BITNUM) BSF dest;, bit;
        BSF dest, bit;
    else
;	BANKSAFE bitnum_arg(BITNUM) bcf dest;, bit;
;	EMIT bitnum_arg(BITNUM) BCF dest;, bit;
	BCF dest, bit;
    endif; @__LINE__
    if dest == WREG
;	if ISLIT(WREG_TRACKER)
;	    if BOOL2INT(bitval)
;WREG_TRACKER |= BIT(bit)
;	    else
;WREG_TRACKER &= ~BIT(bit)
;	    endif; @__LINE__
;	else
;WREG_TRACKER = WREG_UNK
;	endif; @__LINE__
	if BOOL2INT(bitval)
WREG_TRACKER = IIF(ISLIT(WREG_TRACKER), WREG_TRACKER | BIT(bit), WREG_UNKN);
	else
WREG_TRACKER = IIF(ISLIT(WREG_TRACKER), WREG_TRACKER & ~BIT(bit), WREG_UNKN);
	endif; @__LINE__
    endif; @__LINE__
;    EXPAND_RESTORE
    EXPAND_POP @__LINE__
    endm; @__LINE__


;single-arg variants:
;BROKEN
;    VARIABLE bitnum = 0;
;    while bitnum < 8
;biton_#v(bitnum) macro reg
;	setbit reg, bitnum, TRUE;
;	endm; @__LINE__
;bitoff_#v(bitnum) macro reg
;	setbit reg, bitnum, FALSE;
;	endm; @__LINE__
;bitnum += 1
;    endw; @__LINE__
biton_#v(0) macro reg
	setbit reg, 0, TRUE;
	endm; @__LINE__
bitoff_#v(0) macro reg
	setbit reg, 0, FALSE;
	endm; @__LINE__
biton_#v(1) macro reg
	setbit reg, 1, TRUE;
	endm; @__LINE__
bitoff_#v(1) macro reg
	setbit reg, 1, FALSE;
	endm; @__LINE__
biton_#v(2) macro reg
	setbit reg, 2, TRUE;
	endm; @__LINE__
bitoff_#v(2) macro reg
	setbit reg, 2, FALSE;
	endm; @__LINE__
biton_#v(3) macro reg
	setbit reg, 3, TRUE;
	endm; @__LINE__
bitoff_#v(3) macro reg
	setbit reg, 3, FALSE;
	endm; @__LINE__
biton_#v(4) macro reg
	setbit reg, 4, TRUE;
	endm; @__LINE__
bitoff_#v(4) macro reg
	setbit reg, 4, FALSE;
	endm; @__LINE__
biton_#v(5) macro reg
	setbit reg, 5, TRUE;
	endm; @__LINE__
bitoff_#v(5) macro reg
	setbit reg, 5, FALSE;
	endm; @__LINE__
biton_#v(6) macro reg
	setbit reg, 6, TRUE;
	endm; @__LINE__
bitoff_#v(6) macro reg
	setbit reg, 6, FALSE;
	endm; @__LINE__
biton_#v(7) macro reg
	setbit reg, 7, TRUE;
	endm; @__LINE__
bitoff_#v(7) macro reg
	setbit reg, 7, FALSE;
	endm; @__LINE__


;more verbose for text search:
Carry EQU C
Equals0 EQU Z

;alias for ifbit tests:
#define EQUALS0  STATUS, Equals0,
#define BORROW  STATUS, Carry, ! ;Borrow == !Carry; CAUTION: ifbit arg3 inverted
#define CARRY  STATUS, Carry, 


;use same #instr if result known @compile time:
ifbit_const macro reg, bitnum, bitval, stmt
    if ISLIT(reg)
	if BOOL2INT(LIT2VAL(reg) & BIT(bitnum)) == BOOL2INT(bitval)
;	    EXPAND_PUSH TRUE
	    NOP 1; //replace bit test instr
	    EMIT stmt
;	    EXPAND_POP
	else
	    NOP 2; //replace both instr
	endif; @__LINE__
	exitm; @__LINE__
    endif; @__LINE__
    ifbit reg, bitnum, bitval, stmt
    endm; @__LINE__

;check reg bit:
;stmt must be 1 opcode (due to btfxx instr)
;doesn't emit btfxx if stmt is null, but might emit extraneous banksel
;    VARIABLE STMT_COUNTER = 0
ifbit macro reg, bitnum, bitval, stmt
;    EXPAND_PUSH FALSE
;    NOEXPAND  ;reduce clutter
;    if (SRC == DEST) && ((srcbytes) == (destbytes)) && !(reverse)  ;nothing to do
;    LOCAL BIT = bit ;kludge; force eval (avoids "missing operand" and "missing argument" errors/MPASM bugs); also helps avoid "line too long" messages (MPASM limit 200)
    LOCAL REG = reg ;kludge; force eval (avoids "missing operand" and "missing argument" errors/MPASM bugs); also helps avoid "line too long" messages (MPASM limit 200)
;    messg "mov8", #v(DEST), #v(SRC), #v(ISLIT(SRC)), #v(LIT2VAL(SRC)) @__LINE__
;    messg src, dest @__LINE__;
    if ISLIT(reg); compile-time check
	if BOOL2INT(LIT2VAL(reg) & BIT(bitnum)) == BOOL2INT(bitval)
;	    EXPAND_PUSH TRUE
	    EMIT stmt
;	    EXPAND_POP
	endif; @__LINE__
;        EXPAND_POP
	exitm; @__LINE__
    endif; @__LINE__
;    BANKCHK reg;
;    if BOOL2INT(bitval)
;	BANKSAFE bitnum_arg(bitnum) btfsc reg;, bitnum;
;    else
;	BANKSAFE bitnum_arg(bitnum) btfss reg;, bitnum;
;    endif; @__LINE__
;;    LOCAL BEFORE_STMT = $
;;STMT_ADDR#v(STMT_COUNTER) = 0-$
;    LOCAL STMT_ADDR
;STMT_INSTR = 0 - $
;    LOCAL SVWREG = WREG_TRACKER
;    EXPAND_RESTORE
;    stmt
;    NOEXPAND  ;reduce clutter
;    if WREG_TRACKER != SVWREG
;	DROP_WREG
;;	messg WREG unknown here, conditional stmt might have changed it @__LINE__
;    endif; @__LINE__
;;STMT_ADDR#v(STMT_COUNTER) += $
;STMT_INSTR += $
;;    LOCAL STMT_INSTR = STMT_ADDR; #v(STMT_COUNTER)
;;STMT_COUNTER += 1
;;    LOCAL AFTER_STMT = 0; $ - (BEFORE_STMT + 1)
;    WARNIF((STMT_INSTR != 1) && !ISLIT(reg), [ERROR] if-ed stmt !1 opcode: #v(STMT_INSTR), @__LINE__); use warn to allow compile to continue
    LOCAL NUM_IFBIT = NUM_CONTEXT; kludge: need unique symbols
    LOCAL has_banksel = $
    BANKCHK reg; do this before allocating fized-sized placeholder
has_banksel -= $
    LOCAL before_addr = $, before_bank = BANK_TRACKER;, before_wreg = WREG_TRACKER
    CONTEXT_SAVE before_#v(NUM_IFBIT)
    ORG before_addr + 1; leave placeholder for btf; backfill after checking for idler
;    EXPAND_PUSH TRUE
    EMIT stmt;
;    EXPAND_POP
    LOCAL after_addr = $, after_bank = BANK_TRACKER;, after_wreg = WREG_TRACKER
    CONTEXT_SAVE after_#v(NUM_IFBIT)
    LOCAL bank_changed = BANKOF(after_bank);
bank_changed -= BANKOF(before_bank); line too long :(
;    ORG before_addr
;BANK_TRACKER = before_bank
;WREG_TRACKER = before_wreg
    CONTEXT_RESTORE before_#v(NUM_IFBIT)
    if after_addr == before_addr + 1; no stmt
	WARNIF(has_banksel, [INFO] emitted extraneous banksel (no stmt for ifbit) @__LINE__);
    else; back-fill btf instr
	if BOOL2INT(bitval)
;	    messg emit btfsc @__LINE__
	    BANKSAFE EMIT bitnum_arg(bitnum) btfsc reg;, bitnum;
	else
;	    messg emit btfss @__LINE__
	    BANKSAFE EMIT bitnum_arg(bitnum) btfss reg;, bitnum;
	endif; @__LINE__
;	ORG after_addr
;BANK_TRACKER = after_bank
;WREG_TRACKER = after_wreg
	CONTEXT_RESTORE after_#v(NUM_IFBIT)
    endif; @__LINE__
;    EXPAND_POP
NUM_IFBIT += 1; kludge: need unique labels
    endm; @__LINE__


;wait for bit:
;optimized for shortest loop
whilebit macro reg, bitnum, bitval, idler
    EXPAND_PUSH FALSE, @__LINE__
    LOCAL whilebit_loop, whilebit_around
    EMITL whilebit_loop:
    if ISLIT(reg); bit won't change; do idler forever or never
;	ifbit reg, bitnum, bitval, idler
	if BOOL2INT(LITVAL(reg) & BIT(bitnum)) == BOOL2INT(bitval)
;	    EXPAND_PUSH TRUE
	    EMIT idler
	    GOTO whilebit_loop;
;	    EXPAND_POP
	endif; @__LINE__
        EXPAND_POP @__LINE__
	exitm; @__LINE__
    endif; @__LINE__
    LOCAL NUM_WHILEBIT = NUM_CONTEXT; kludge: need unique symbols
    BANKCHK reg; allow this to be skipped in loop
    LOCAL before_idler = $, before_bank = BANK_TRACKER;, before_wreg = WREG_TRACKER
    CONTEXT_SAVE before_#v(NUM_WHILEBIT)
    ORG before_idler + 2; leave placeholder for btf + goto; backfill after checking for idler
;    EXPAND_POP
    CONTEXT_SAVE before_whilebit
    EMIT idler; allows cooperative multi-tasking (optional)
;    EXPAND_PUSH FALSE
    LOCAL after_idler = $, after_bank = BANK_TRACKER;, after_wreg = WREG_TRACKER
    LOCAL bank_changed = BANKOF(after_bank);
bank_changed -= BANKOF(before_bank); line too long :(
;     messg bank changed #v(bank_changed) @__LINE__
    if bank_changed
	BANKCHK reg; //kludge: restore BSR < "goto whilebit_loop" since ifbit doesn't know about idler
    endif
    CONTEXT_SAVE after_#v(NUM_WHILEBIT)
;    EMIT ORG before_addr
;BANK_TRACKER = before_bank
;WREG_TRACKER = before_wreg
    CONTEXT_RESTORE before_#v(NUM_WHILEBIT)
    if after_idler == before_idler + 2; no idler, use tight busy-wait (3 instr)
    	ifbit reg, bitnum, bitval, GOTO before_idler; don't need to repeat banksel
	ERRIF($ != before_idler + 2, [ERROR] tight-while bit test size wrong: #v($ - (before_idler + 2)) @__LINE__);
    else; jump around idler
	ifbit reg, bitnum, !BOOL2INT(bitval), GOTO whilebit_around; check for *opposite* bit val
	ERRIF($ != before_idler + 2, [ERROR] bulky-while bit test size wrong: #v($ - (before_idler + 2)) @__LINE__);
;	ORG after_addr
;BANK_TRACKER = after_bank
;WREG_TRACKER = after_wreg
	CONTEXT_RESTORE after_#v(NUM_WHILEBIT)
	GOTO IIF(bank_changed, whilebit_loop, before_idler);
    endif; @__LINE__
    CONTEXT_SAVE after_whilebit
    EMITL whilebit_around:
    EXPAND_POP @__LINE__
    endm; @__LINE__


;; custom flow control opcodes ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

#define RESERVE(n)  ORG$+n

;    LIST
;busy-wait functions:
;CAUTION: use only for small delays
;use Timer-based functions for longer delays (those allow cooperative multi-tasking)
;nop7_func: nop;
;nop6_func: nop;
;nop5_func: nop;
;CAUTION: each level falls thru to next and uses another stack level
;nop_functions macro
;next_init macro
;    init_chain; nop functions only need to be defined, not called; put other init first
;    previous_init;
;    goto around_nop
;around_nop:
;    endm; @__LINE__
;INIT_COUNT += 1
;#undefine init_chain
;#define init_chain  nop_functions //initialization wedge for compilers that don't support static init
;    NOLIST

;use non-0 value for nop opcode:
;(allows code gap detection using real nop)
;    messg TODO: vvv fix this @__LINE__
;NOPNZ macro count
;BROKEN
;    if (count) & 1
;	addlw 0; benign non-0 opcode
;        NOP (count)-1
;	exitm; @__LINE__
;    endif; @__LINE__
;    NOP count
;    endm; @__LINE__

    VARIABLE NOP_expanded = FALSE;
#define NOP  nop_multi; override default opcode for PCH checking and BSR, WREG tracking
NOP macro count;, dummy; dummy arg for usage with REPEAT
    EXPAND_PUSH FALSE, @__LINE__
;    NOEXPAND; hide clutter
    LOCAL COUNT = count
    WARNIF(!COUNT, [WARNING] no nop? @__LINE__)
;    if COUNT == 7
;	EMIT call nop#v(COUNT); special case for WS bit-banging
;	exitm; @__LINE__
;    endif; @__LINE__
    if COUNT & 1
;        EXPAND_RESTORE; NOEXPAND
;	PROGDCL 0; nop
	EMIT nop;
;	NOEXPAND
COUNT -= 1
    endif; @__LINE__
    if COUNT && !NOP_expanded; avoid code unless needed; kludge: also avoids reset org conflict
;	at_init TRUE
;	LOCAL around
;broken 	goto around
    CONTEXT_SAVE around_nop;
    RESERVE(1); ORG$+1
    LIST_PUSH TRUE, @__LINE__
nop#v(32): call nop#v(16)
nop#v(16): call nop#v(8)
;nop#v(8): nop ;call nop#v(4); 1 usec @8 MIPS
;nop#v(7): nop
;	  goto $+1
nop#v(8): call nop#v(4); 1 usec @8 MIPS
nop#v(4): return; 1 usec @4 MIPS
;    nop 1;,; 1 extra to preserve PCH
around_nop_:
    LIST_POP @__LINE__
    CONTEXT_RESTORE around_nop;
    EMIT goto around_nop_;
    ORG around_nop_;
;	at_init FALSE
NOP_expanded = TRUE
COUNT -= 2; apply go-around towards delay period
    endif; @__LINE__
    if COUNT & 2
;        EXPAND_RESTORE; NOEXPAND
        EMIT goto $+1; 1 instr, 2 cycles (saves space)
;	NOEXPAND
COUNT -= 2
    endif; @__LINE__
;(small) multiples of 4:
;    if count >= 4
    if COUNT
;        EXPAND_RESTORE; NOEXPAND
	EMIT call nop#v(COUNT);
;	NOEXPAND
    endif; @__LINE__
    EXPAND_POP @__LINE__
    endm; @__LINE__


;conditional nop:
nopif macro want_nop, count
    if !BOOL2INT(want_nop)
	exitm; @__LINE__
    endif; @__LINE__
    NOP count
    endm; @__LINE__

;nop2if macro want_nop
;    if want_nop
;	nop2
;    endif; @__LINE__
;    endm; @__LINE__

;nop4if macro want_nop
;    EXPAND_PUSH FALSE
;    if want_nop
;	EMIT NOP 4;,
;    endif; @__LINE__
;    EXPAND_POP
;    endm; @__LINE__


;simulate "call" opcode:
PUSH macro addr
;    EXPAND_PUSH FALSE
;    BANKCHK STKPTR;
;    BANKSAFE dest_arg(F) incf STKPTR;, F;
    INCF STKPTR, F
    mov16 TOS, addr; LITERAL(addr); NOTE: only h/w stack is only 15 bits wide
;    EXPAND_POP
    endm; @__LINE__

;simulate "return" opcode:
POP macro
;    EXPAND_PUSH FALSE
;    BANKCHK STKPTR;
;    BANKSAFE dest_arg(F) decf STKPTR;, F;
    DECF STKPTR, F;
;    EXPAND_POP
    endm; @__LINE__


;PUSHPOP macro addr
;    PUSH addr;
;    POP;
;    endm; @__LINE__


;PIC code pages:
;#define PAGELEN  0x400
#define REG_PAGELEN  0x100  ;code at this address or above is paged and needs page select bits (8 bit address)
#define LIT_PAGELEN  0x800  ;code at this address or above is paged and needs page select bits (11 bit address)
;line too long    CONSTANT PAGELEN = 0X400;
;#define BANKOFS(reg)  ((reg) % BANKLEN)
;get page# of a code address:
;NOTE: there are 2 formats: literal (compile-time) and register-based (run-time)
#define LITPAGEOF(addr)  ((addr) / LIT_PAGELEN)  ;used for direct addressing (thru opcode)
#define REGPAGEOF(addr)  ((addr) / REG_PAGELEN)  ;used for indirect addressing (thru register)
;#define PROGDCL  EMIT da; put value into prog space; use for opcodes or packed read-only data
;
;back-fill code page:
;allows code to be generated < reset + isr
;    VARIABLE CODE_COUNT = 0;
;    VARIABLE CODE_HIGHEST = LIT_PAGELEN; start @eo page 0 and fill downwards
;CODE_HOIST macro len
;    if len == -1
;        EMITO ORG CODE_ADDR#v(CODE_COUNT)
;	exitm; @__LINE__
;    endif; @__LINE__
;    ERRIF(!len, [ERROR] code length len must be > 0, @__LINE__);
;CODE_COUNT += 1
;    CONSTANT CODE_ADDR#v(CODE_COUNT) = $
;CODE_HIGHEST -= len
;    EMITO ORG CODE_HIGHEST
;;    messg code push: was #v(CODE_ADDR#v(CODE_COUNT)), is now #v(CODE_NEXT) @__LINE__
;    endm; @__LINE__

;CODE_POP macro
;    ORG CODE_ADDR#v(CODE_COUNT)
;    endm; @__LINE__
 

;ensure PCLATH is correct before call or goto:
    VARIABLE PAGE_TRACKER#v(1) = ASM_MSB -1; //paranoid: already 0 after power-up or reset but assume not
    VARIABLE PAGE_TRACKER#v(0) = 0; //assume pclath already set after init
    VARIABLE PAGESEL_KEEP = 0, PAGESEL_DROP = 0; ;perf stats
#define need_pagesel(dest)  (LITPAGEOF(dest) != LITPAGEOF(PAGE_TRACKER#v(BOOL2INT(DOING_INIT)))); track init + !init separately
PAGECHK MACRO dest; ;, fixit, undef_ok
    EXPAND_PUSH FALSE, @__LINE__; reduce clutter in LST file
;    messg pg trkr? #v(LITPAGEOF(dest)) vs #v(LITPAGEOF(PAGE_TRACKER)) @__LINE__
;    if LITPAGEOF(dest) != LITPAGEOF(PAGE_TRACKER); only check upper bits of PCLATH for call/goto
    LOCAL updctx = 0;
    if need_pagesel(dest); only check upper bits of PCLATH for call/goto
;??    if REGPAGEOF(dest) != REGPAGEOF(PAGE_TRACKER)
;	EMIT CLRF PCLATH; PAGESEL dest; kludge: mpasm doesn't want to pagesel
	EMIT movlp REGPAGEOF(dest); LITPAGEOF(dest); NOTE: set all bits in case BRW/BRA used later
;    messg pg trkr #v(PAGE_TRACKER#v(BOOL2INT(DOING_INIT))) => #v(dest), doing init #v(DOING_INIT) @__LINE__
PAGE_TRACKER#v(BOOL2INT(DOING_INIT)) = dest;
;kludge: go back and update saved contexts:
	while updctx < NUM_CONTEXT
	    if BOOL2INT(ctx_init_#v(updctx)) == BOOL2INT(DOING_INIT)
;    messg upd pg trkr[#v(updctx)/#v(NUM_CONTEXT)] #v(ctx_page_#v(updctx)) => #v(PAGE_TRACKER#v(BOOL2INT(DOING_INIT))) @__LINE__
ctx_page_#v(updctx) = PAGE_TRACKER#v(1); //BOOL2INT(DOING_INIT))
	    endif
updctx += 1
	endw; @__LINE__
PAGESEL_KEEP += 1
    else
PAGESEL_DROP += 1
    endif; @__LINE__
    EXPAND_POP @__LINE__
    endm; @__LINE__
    

;conditional call (to reduce caller verbosity):
CALLIF macro want_call, dest
    if want_call
        CALL dest;
    endif; @__LINE__
    endm; @__LINE__

#define CALL  call_pagesafe; override default opcode for PCH checking and BSR, WREG tracking
CALL macro dest
    EXPAND_PUSH FALSE, @__LINE__
;    NOEXPAND; hide clutter
    WARNIF(LITPAGEOF(dest), [ERROR] dest !on page 0: #v(LITPAGEOF(dest)) @__LINE__)
;PAGESEL_DROP += 1
;    LOCAL WREG_SAVE = WREG_TRACKER
;    EXPAND_RESTORE; NOEXPAND
;    messg call dest, page tracker #v(PAGE_TRACKER), need page sel? #v(LITPAGEOF(dest)) != #v(LITPAGEOF(PAGE_TRACKER))? #v(LITPAGEOF(dest) != LITPAGEOF(PAGE_TRACKER))
;    if LITPAGEOF(dest) != LITPAGEOF(PAGE_TRACKER)
;	EMIT CLRF PCLATH; PAGESEL dest; kludge: mpasm doesn't want to pagesel
;PAGESEL_KEEP += 1
;    else
;PAGESEL_DROP += 1
;    endif; @__LINE__
    PAGECHK dest
    EMIT call dest; PROGDCL 0x2000 | (dest); call dest
;PAGE_TRACKER = dest;
;    NOEXPAND
    if NOP_expanded
	if (dest == nop#v(4)) || (dest == nop#v(8)); these don't alter BSR or WREG; TODO: choose a mechanism to indicate this
            EXPAND_POP
	    exitm; @__LINE__
	endif; @__LINE__
    endif; @__LINE__
    DROP_CONTEXT; BSR and WREG unknown here
;    if dest == choose_next_color
;WREG_TRACKER = color; kludge: avoid unknown contents warning
;    endif; @__LINE__
;#ifdef BITBANG
;    if dest == bitbang_wreg
;BANK_TRACKER = LATA; preserve caller context to improve timing
;    endif; @__LINE__
;#endif; @__LINE__
    EXPAND_POP @__LINE__
    endm; @__LINE__
;    messg ^^^ REINSTATE, @__LINE__


#define GOTO  goto_pagesafe; override default opcode for PCH checking
GOTO macro dest
    EXPAND_PUSH FALSE, @__LINE__
; messg here1 @__LINE__
    WARNIF(LITPAGEOF(dest), [ERROR] "dest" dest #v(dest) !on page 0: #v(LITPAGEOF(dest)) @__LINE__)
    WARNIF(#v(eof) && !#v(dest), [WARNING] jump to 0 @__LINE__);
; messg here2 @__LINE__
;PAGESEL_DROP += 1
;    messg goto dest, page tracker #v(PAGE_TRACKER), need page sel? #v(LITPAGEOF(dest)) != #v(LITPAGEOF(PAGE_TRACKER))? #v(LITPAGEOF(dest) != LITPAGEOF(PAGE_TRACKER))
;    if LITPAGEOF(dest) != LITPAGEOF(PAGE_TRACKER)
;	EMIT CLRF PCLATH; PAGESEL dest; kludge: mpasm doesn't want to pagesel
;PAGESEL_KEEP += 1
;    else
;PAGESEL_DROP += 1
;    endif; @__LINE__
    PAGECHK dest
;    EXPAND_RESTORE; NOEXPAND
; messg here3 @__LINE__
    EMIT goto dest; PROGDCL 0x2000 | (dest); call dest
;PAGE_TRACKER = dest;
; messg here4 @__LINE__
;    NOEXPAND
;not needed: fall-thru would be handled by earlier code    DROP_CONTEXT; BSR and WREG unknown here if dest falls through
    EXPAND_POP @__LINE__
    endm; @__LINE__

#define RETURN  EMIT return

eof_#v(EOF_COUNT) macro
    if PAGESEL_KEEP + PAGESEL_DROP
        messg [INFO] page sel: #v(PAGESEL_KEEP) (#v(pct(PAGESEL_KEEP, PAGESEL_KEEP + PAGESEL_DROP))%), dropped: #v(PAGESEL_DROP) (#v(pct(PAGESEL_DROP, PAGESEL_KEEP + PAGESEL_DROP))%) @__LINE__; ;perf stats
    endif; @__LINE__
    messg [INFO] page0 used: #v(EOF_ADDR)/#v(LIT_PAGELEN) (#v(pct(EOF_ADDR, LIT_PAGELEN))%) @__LINE__
    endm; @__LINE__
EOF_COUNT += 1;


;; startup code ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;special code addresses:
#ifndef RESET_VECTOR
 #define RESET_VECTOR  0; must be 0 for real code; shift for compile/dev debug ONLY
#endif; @__LINE__
;#ifdef ISR_VECTOR
; messg isr vec ISR_VECTOR #v(ISR_VECTOR) already defined? @__LINE__
; #undefine ISR_VECTOR
;#endif
#ifndef ISR_VECTOR
 #define ISR_VECTOR  (RESET_VECTOR + 4); must be 4 for real code; shift for compile/dev debug ONLY
;#define ISR_RESERVED  2; space to reserve for (jump from) ISR
#endif; @__LINE__

;init_#v(INIT_COUNT): DROP_CONTEXT; macro
    at_init TRUE
;    EXPAND_PUSH FALSE
;NOTE: this code must be @address 0 in absolute mode
;pic-as, not mpasm: PSECT   code
    DROP_CONTEXT ;DROP_BANK
    ORG RESET_VECTOR; startup
;    messg RESET_VECTOR #v(RESET_VECTOR), ISR_VECTOR #v(ISR_VECTOR) @__LINE__
;#ifdef RESET_VECTOR; CAUTION: pass 2 seems to leave #defs intact
;; #if isPASS2
;  #undefine RESET_VECTOR
;; #endif
;#endif; @__LINE__
    CONSTANT RESET_VECTOR_ = $; redef as const for .LST
    EMIT ORG RESET_VECTOR_; startup
    WARNIF($, [ERROR] reset code !@0: #v($) @__LINE__);
    NOP 1; nop; reserve space for ICE debugger?
;    PAGECHK 0; redundant
;    EMIT clrf PCLATH; EMIT pagesel $; paranoid
;    EMIT goto init_#v(INIT_COUNT + 1); init_code ;main
;    at_init FALSE
;    messg reset pad #v(ISR_VECTOR - $) @__LINE__
    at_init FALSE;
#ifdef WANT_ISR
    REPEAT LITERAL(ISR_VECTOR - $), NOP 1; nop; fill in empty space (avoids additional programming data block?); CAUTION: use repeat nop 1 to fill
    ORG ISR_VECTOR
;#ifdef ISR_VECTOR; CAUTION: pass 2 seems to leave #defs intact
;; #if isPASS2
;  #undefine ISR_VECTOR
;; #endif
;#endif; @__LINE__
    CONSTANT ISR_VECTOR_ = $; redef as const for .LST
    EMIT ORG ISR_VECTOR_ + WANT_ISR; ISR_RESERVED; reserve space for isr in case other opcodes are generated first
;    CONSTANT ISR_PLACEHOLDER = $;
#endif; @__LINE__
;    EXPAND_POP
;    endm; @__LINE__
;INIT_COUNT += 1
;    at_init FALSE


;VERY ugly kludge to help MPASM get back on track:
;this macro is needed because of page/bank optimization and the assembler's inability to handle it
;use this macro ahead of a label that gets an error 116 "Address label duplicated or different in second pass"
;there appear to be 2 main causes for this: pass 1 vs. pass 2 addresses out of sync, and LOCAL identifier name clashes
;the NEXT_UNIQID variable addresses the second of those causes, while this macro addresses the first one
;this macro can be used to pad out the address during pass 1, skipping it during pass 2 (or vice versa), so that the address is consistent between pass 1 + 2
;it's best to use it within dead code chunks (ie, AFTER a goto), where the extra instructions will NEVER be executed; this avoids any run-time overhead
;I'm not sure why symbolic addresses occassionally get out of alignment between pass 1 and pass 2; it's inconsistent - sometimes the assembler recovers correctly and sometimes not
;usage of this macro is trial and error; only add it in one place at a time, and adjust it until the error 116 goes away (use the .LST file to check the addresses in pass 1 vs. 2)
;if pass 1 address (LST) is higher than pass 2 address (symtab), use a +ve offset; this will put nop's in the final executable code
;if pass 1 address (LST) is less than pass 2 (symtab), use a -ve offset; this will only generate nop's in pass 1, and won't actually take up any code space in pass 2
;params:
; pass2ofs = amount to adjust; if pass 2 address > pass 1 address, use pass2ofs > 0; else use pass2ofs < 0; there can be errors in either direction
    VARIABLE PASS1_FIXUPS = 0, PASS2_FIXUPS = 0  ;used to track macro perf stats
#define isPASS2  eof; only true during pass 2 (address resolved); eof label MUST be at end
UGLY_PASS12FIX MACRO pass2ofs
;    EXPAND_PUSH FALSE
;    NOEXPAND; reduce clutter
;    EXPAND_PUSH FALSE
    if (pass2ofs) < 0; slide pass 2 addresses down (pad pass 1 address up, actually)
	if !isPASS2; only true during pass 1 (assembler hasn't resolved the address yet); eof label MUST be at end
	    REPEAT -(pass2ofs), EMIT nop; insert dummy instructions to move address during pass 1; these won't be present during pass 2
	endif; @__LINE__
;		WARNIF eof, "[WARNING] Unneeded pass 1 fixup", pass2ofs, eof  ;won't ever see this message (output discarded during pass 1)
PASS1_FIXUPS += 0x10000-(pass2ofs)  ;lower word = #prog words; upper word = #times called
    endif; @__LINE__
    if (pass2ofs) > 0; slide pass 2 addresses up
	if isPASS2; only true during pass 2 (address resolved); eof label MUST be at end
	    REPEAT pass2ofs, EMIT nop;
	endif; @__LINE__
	WARNIF(!eof, [WARNING] Unneeded #v(pass2ofs) pass 2 fixup @__LINE__)
PASS2_FIXUPS += 0x10000+(pass2ofs)  ;lower word = #prog words; upper word = #times called
    endif; @__LINE__
;    EXPAND_POP
;    EXPAND_POP
    ENDM

eof_#v(EOF_COUNT) macro
    if PASS1_FIXUPS + PASS2_FIXUPS
	messg [INFO] Ugly fixups pass1: #v(PASS1_FIXUPS/0x10000):#v(PASS1_FIXUPS%0x10000), pass2: #v(PASS2_FIXUPS/0x10000):#v(PASS2_FIXUPS%0x10000) @__LINE__
    endif; @__LINE__
    endm; @__LINE__
EOF_COUNT += 1;

;    EXPAND_POP @__LINE__
    LIST_POP @__LINE__
;    messg end of hoist 1 @__LINE__
;#else; too deep :(
#endif; @__LINE__
#if HOIST == 0; //bottom level, mpasm must see this first
;    messg hoist 0: generic pic/asm helpers @__LINE__
;#define LIST  NOLIST; too much .LST clutter, turn off for this section; also works for nested .inc file
;#define NOLIST  LIST; show everything in .LST clutter
    NOLIST; don't show this section in .LST file
    NOEXPAND
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; generic PIC/ASM helpers ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;bool macros:
#define TRUE  1
#define FALSE  0
#define BOOL2INT(val)  ((val) != 0); MPASM evaluates this to 0 or 1
;#define XOR(lrs, rhs)  ((lhs) && (rhs) || !(lhs) && !(rhs))
;for text messages:
#define YESNO(val)  YESNO_#v(BOOL2INT(val))
;broken:#define YESNO_#v(TRUE)  true
#define YESNO_1  true
;broken:#define YESNO_#v(FALSE)  false
#define YESNO_0  false
;ternary operator (like C/C++ "?:" operator):
;helps with compile-time optimizations
;line too long: #define IIF(TF, tval, fval)  (BOOL2INT(TF) * (tval) + (!BOOL2INT(TF)) * (fval))
;only eval TF once, but requires shorter fval (with no side effects):
;#define IIF(TF, tval, fval)  (BOOL2INT(TF) * ((tval) - (fval)) + (fval))
#define IIF(TF, tval, fval)  IIF_#v(BOOL2INT(TF))(tval, fval)
#define IIF_1(tval, fval)  (tval); IIF_#v(TRUE)
#define IIF_0(tval, fval)  (fval); IIF_#v(FALSE)


;misc arithmetic helpers:
#define rdiv(num, den)  (((num)+(den)/2)/MAX(den, 1))  ;rounded divide (at compile-time)
#define divup(num, den)  (((num)+(den)-1)/(den))  ;round-up divide
#define pct(num, den)  rdiv(100 * (num), den)
;#define err_rate(ideal, actual)  ((d'100'*(ideal)-d'100'*(actual))/(ideal))  ;%error
;#define mhz(freq)  #v((freq)/ONE_SECOND)MHz  ;used for text messages
;#define kbaud(freq)  #v((freq)/1000)kb  ;used for text messages
;#define sgn(x)  IIF((x) < 0, -1, (x) != 0)  ;-1/0/+1
#define ABS(x)  IIF((x) < 0, -(x), x)  ;absolute value
#define MIN(x, y)  IIF((x) < (y), x, y)  ;use upper case so it won't match text within ERRIF/WARNIF messages
#define MAX(x, y)  IIF((x) > (y), x, y)  ;use upper case so it won't match text within ERRIF/WARNIF messages

#define NULL_STMT  ORG $; dummy stmt for macros that need a parameter


;error/debug assertion message macros:
;******************************************************************************
;show error message if condition is true:
;params:
; assert = condition that must (not) be true
; message = message to display if condition is true (values can be embedded using #v)
;    messg [TODO] change to #def to preserve line# @__LINE__
;ERRIF MACRO assert, message, args
;    NOEXPAND  ;hide clutter
;    if assert
;	error message, args
;    endif; @__LINE__
;    EXPAND_RESTORE
;    ENDM
;use #def to preserve line#:
;#define ERRIF(assert, msg, args)  \
;    if assert \
;	error msg, args  \
;    endif; @__LINE__
;mpasm doesn't allow #def to span lines :(
;#define ERRIF(assert, msg, args)  ERRIF_#v(BOOL2INT(assert)) msg, args
#define ERRIF(assert, msg)  ERRIF_#v(BOOL2INT(assert)) msg
#define ERRIF_0  IGNORE_EOL; msg_ignore, args_ignore  ;IGNORE_EOL; no ouput
#define ERRIF_1  error; (msg, args)  error msg, args
;show warning message if condition is true:
;params:
; assert = condition that must (not) be true
; message = message to display if condition is true (values can be embedded using #v)
;    messg [TODO] change to #def to preserve line# @__LINE__
;WARNIF MACRO assert, message, args
;    NOEXPAND  ;hide clutter
;    if assert
;	messg message, args
;    endif; @__LINE__
;    EXPAND_RESTORE
;    ENDM
;use #def to preserve line#:
;#define WARNIF(assert, msg, args)  \
;    if assert \
;	messg msg, args \
;    endif; @__LINE__
;mpasm doesn't allow #def to span lines :(
;#define WARNIF(assert, msg, args)  WARNIF_#v(BOOL2INT(assert)) msg, args
#define WARNIF(assert, msg)  WARNIF_#v(BOOL2INT(assert)) msg
#define WARNIF_0  IGNORE_EOL; (msg_ignore, args_ignore)  ;IGNORE_EOL; no output
#define WARNIF_1  messg; (msg, args)  messg msg, args


;#define COMMENT(thing) ; kludge: MPASM doesn't have in-line comments, so use macro instead

;ignore remainder of line (2 args):
;    messg TODO: replace? IGNEOL @__LINE__
;IGNORE_EOL2 macro arg1, arg2
;    endm; @__LINE__
IGNORE_EOL macro arg
    endm; @__LINE__


;#define WARNIF_1x(lineno, assert, msg, args)  WARNIF_1x_#v(BOOL2INT(assert)) lineno, msg, args
;kludge: MPASM doesn't provide 4008 so use current addr ($) instead:
;#define WARNIF_1x(assert, msg, args)  WARNIF_1x_#v(BOOL2INT(assert)) $, msg, args
;#define WARNIF_1x_0  IGNORE_EOL2; (msg_ignore, args_ignore)  ;IGNORE_EOL; no output
;#define WARNIF_1x_1  messg1x; (msg, args)  messg msg, args

;show msg 1x only per location:
;kludge: use addr since there's no way to get caller's line#
;TODO: figure out a better way to get lineno
;    VARIABLE NUM_MESSG1X = 0
;messg1x macro lineno, msg, args
;    EXPAND_PUSH FALSE
;    LOCAL already = 0
;    while already < NUM_MESSG1X
;	if WARNED_#v(already) == lineno
;	    EXPAND_POP
;	    exitm; @__LINE__
;	endif; @__LINE__
;already += 1
;    endw; @__LINE__
;    messg msg, args @#v(lineno)
;    CONSTANT WARNED_#v(NUM_MESSG1X) = lineno
;NUM_MESSG1X += 1
;    EXPAND_POP
;    endm; @__LINE__


;add to init code chain:
    VARIABLE INIT_COUNT = 0;
    VARIABLE LAST_INIT = -1;
    VARIABLE DOING_INIT = 0; //nesting level + flag
at_init macro onoff
;    EXPAND_PUSH FALSE, @__LINE__
;    messg [DEBUG] at_init: onoff, count #v(INIT_COUNT), $ #v($), last #v(LAST_INIT), gap? #v($ != LAST_INIT) @__LINE__; 
    LOCAL jump_placeholder, reserve_space
    if BOOL2INT(onoff); && INIT_COUNT; (LAST_INIT != -1); add to previous init code
;	LOCAL next_init = $
;	CONTEXT_SAVE before_init
;	ORG LAST_INIT; reclaim or backfill placeholder space
;	CONTEXT_RESTORE after_init
DOING_INIT += 1
	if $ == LAST_INIT; continue from previous code block
	    CONTEXT_RESTORE last_init_#v(INIT_COUNT - 1)
	else; jump from previous code block
	    if INIT_COUNT; && ($ != LAST_INIT); IIF(LITPAGEOF(PAGE_TRACKER), $ + 2, $ + 1); LAST_INIT + 1; jump to next block
;PAGE_TRACKER = LAST_INIT; kludge: PCLATH had to be correct in order to get there
		CONTEXT_SAVE next_init_#v(INIT_COUNT)
		CONTEXT_RESTORE last_init_#v(INIT_COUNT - 1)
;    messg pg trkr #v(PAGE_TRACKER#v(BOOL2INT(DOING_INIT))) => #v(init_#v(INIT_COUNT)), doing init #v(DOING_INIT) @__LINE__
		EMIT GOTO init_#v(INIT_COUNT); next_init
;	    ORG next_init
		CONTEXT_RESTORE next_init_#v(INIT_COUNT)
	    endif; @__LINE__
	endif; @__LINE__
	EMITL init_#v(INIT_COUNT):
;init_#v(INIT_COUNT): DROP_CONTEXT; macro
    else; end of init code (for now)
reserve_space = IIF(need_pagesel($), $ + 2, $ + 1); leave placeholder for jump to next init section in case needed
DOING_INIT -= 1
	CONTEXT_SAVE last_init_#v(INIT_COUNT)
;	ORG IIF(LITPAGEOF(PAGE_TRACKER), $ + 2, $ + 1); leave placeholder for jump to next init section in case needed
;NOTE: movlp will be set after first jump
;jump_placeholder = IIF(LITPAGEOF(PAGE_TRACKER) != LITPAGEOF($), $ + 2, $ + 1); leave placeholder for jump to next init section in case needed
;    messg init[#v(INIT_COUNT)] jump placeholder $ #v($), ph #v(jump_placeholder) @__LINE__
 EMITL jump_placeholder:
	ORG reserve_space; //in case next init section is not contiguous
;    messg pg trkr #v(PAGE_TRACKER#v(BOOL2INT(DOING_INIT + 1))) @#v($), doing init #v(DOING_INIT + 1) @__LINE__
LAST_INIT = $
;    EMIT goto init_#v(INIT_COUNT + 1); daisy chain: create next thread; CAUTION: use goto - change STKPTR here
INIT_COUNT += 1; 
    endif; @__LINE__
;    EXPAND_POP @__LINE__
    endm; @__LINE__


;add to eof code chain:
    VARIABLE EOF_COUNT = 0;
;#define at_eof  REPEAT LITERAL(EOF_COUNT), EMITL at_eof_#v(REPEATER): eof_#v(REPEATER)
at_eof macro
;    EXPAND_PUSH FALSE, @__LINE__
;;broken:    REPEAT EOF_COUNT, eof_#v(repeater)
;broken:    REPEAT LITERAL(EOF_COUNT), EMITL at_eof_#v(REPEATER): eof_#v(REPEATER)
    WARNIF(DOING_INIT != 1, [WARNING] doing init @eof: #v(DOING_INIT) @__LINE__); mismatched directives can cause incorrect code gen
    LOCAL count = 0;
    while count < EOF_COUNT
        EMITL at_eof_#v(count):; only used for debug
	eof_#v(count)
count += 1;
    endw; @__LINE__
;    EXPAND_POP @__LINE__
    endm; @__LINE__


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;macro expansion control:
;push/pop current directive, then set new value (max 31 nested levels)
;allows clutter to be removed from the .LST file
    VARIABLE MEXPAND_STACK = FALSE; top starts off; //TRUE; default is ON (for caller, set at eof in this file)
;use this if more than 32 levels needed:
;    VARIABLE MEXPAND_STACKHI = 0, MEXPAND_STACKLO = 1; default is ON (for caller, set at eof in this file)
    VARIABLE MEXPAND_DEPTH = 0, MEXPAND_DEEPEST = 0
#define EXPAND_PUSH  EXPAND_CTL
#define EXPAND_POP  EXPAND_CTL -1,
#define EXPAND_RESTORE  EXPAND_CTL 0xf00d,
#define EXPAND_DEBUG  messg [DEBUG] MEXPAND current #v(MEXPAND_STACK & 1), stack #v(MEXPAND_STACK), depth #v(MEXPAND_DEPTH) @__LINE__
EXPAND_CTL MACRO onoffpop, where
    NOEXPAND; hide clutter in LST file @__LINE__
;    LIST_DEBUG enter expand @__LINE__
;    if (onoffpop) == 0xf00d; restore current setting
    if ((onoffpop) >= 0) && ((onoffpop) != 0xf00d); push on/off
	LOCAL pushpop = (MEXPAND_STACK + MEXPAND_STACK) / 2;
;	    if pushpop != MEXPAND_STACK; & ASM_MSB
;		messg [ERROR] macro expand stack too deep: #v(MEXPAND_DEPTH) @__LINE__; allow continuation (!error)
;	    endif; @__LINE__
	WARNIF(pushpop != MEXPAND_STACK, [ERROR] macro expand stack too deep where: #v(MEXPAND_DEPTH) @__LINE__); allow continuation (!error)
MEXPAND_STACK += MEXPAND_STACK + BOOL2INT(onoffpop); push: shift + add new value
MEXPAND_DEPTH += 1; keep track of current nesting level
MEXPAND_DEEPEST = MAX(MEXPAND_DEEPEST, MEXPAND_DEPTH); keep track of high-water mark
;use this if more than 32 levels needed:
;MEXPAND_STACKHI *= 2
;	if MEXPAND_STACKLO & ASM_MSB
;MEXPAND_STACKHI += 1
;MEXPAND_STACKLO &= ~ASM_MSB
;	endif; @__LINE__
;    if !(onoff) ;leave it off
;	if onoffpop
;	    LIST; _PUSH pushpop; NOTE: must be on in order to see macro expansion
;	endif; @__LINE__
    else; pop or restore
        if (onoffpop) == -1; pop
;    LOCAL EXP_NEST = nesting -1  ;optional param; defaults to -1 if not passed
MEXPAND_STACK >>= 1; pop previous value (shift right)
MEXPAND_DEPTH -= 1; keep track of current nesting level
;only needed if reach 16 levels:
;	if MEXPAND_STACKLO & ASM_MSB  ;< 0
;MEXPAND_STACKLO &= ~ASM_MSB  ;1-MEXPAND_STACKLO  ;make correction for assembler sign-extend
;	endif; @__LINE__
;use this if more than 32 levels needed:
;	if MEXPAND_STACKHI & 1
;MEXPAND_STACKLO += ASM_MSB
;	endif; @__LINE__
;MEXPAND_STACKHI /= 2
;errif does this:
;	if !(MEXPAND_STACKLO & 1)  ;pop, leave off
;		EXITM
;	endif; @__LINE__
;	    if MEXPAND_DEPTH < 0
;		messg [ERROR] macro expand stack underflow @__LINE__; allow continuation (!error)
;	    endif; @__LINE__
	    WARNIF(MEXPAND_DEPTH < 0, [ERROR] macro expand stack underflow where @__LINE__); allow continuation (!error)
;	    LIST_POP
;	    if !(LSTCTL_STACK & 1)
;		messg "list off" @__LINE__
;		NOLIST
;	    endif; @__LINE__
	endif; @__LINE__
    endif; @__LINE__
;    LIST_DEBUG <exit expand @__LINE__
    if !(MEXPAND_STACK & 1); leave it off
;        messg leave expand OFF after onoffpop where, depth #v(MEXPAND_DEPTH) @__LINE__
;djdebug = 1
	LIST_RESTORE where
;        LIST_DEBUG on exit expand off @__LINE__
	exitm; @__LINE__; @__LINE__
    endif; @__LINE__
;    messg leave expand ON after onoffpop where, depth #v(MEXPAND_DEPTH) @__LINE__
;    LIST_DEBUG on exit expand on @__LINE__
    LIST; _PUSH pushpop @__LINE__; NOTE: must be on in order to see macro expansion
    EXPAND; turn expand back on @__LINE__
    ENDM

eof_#v(EOF_COUNT) macro
;    LOCAL nested = 0; 1; kludge: account for at_eof wrapper
    LOCAL sv_depth = #v(MEXPAND_DEPTH);
    WARNIF(sv_depth, [WARNING] macro expand stack not empty @eof: #v(sv_depth) @__LINE__); mismatched directives can cause incorrect code gen; stack = #v(sv_depth); MEXPAND_DEPTH != nested
    endm; @__LINE__
EOF_COUNT += 1;


;listing control:
;push/pop current directive, then set new value (max 31 nested levels)
;allows clutter to be removed from the .LST file
    VARIABLE LSTCTL_STACK = FALSE; //top starts off; //default is OFF (for caller, set at eof in this file)
    VARIABLE LSTCTL_DEPTH = 0, LSTCTL_DEEPEST = 0
#define LIST_PUSH  LISTCTL
#define LIST_POP  LISTCTL -1,
#define LIST_RESTORE  LISTCTL 0xfeed,
#define LIST_DEBUG  messg [DEBUG] LSTCTL current #v(LSTCTL_STACK & 1), stack #v(LSTCTL_STACK), depth #v(LSTCTL_DEPTH) @__LINE__
;   variable djdebug = 0
LISTCTL MACRO onoffpop, where
;    EXPAND_PUSH FALSE, where; hide clutter in LST file
    NOEXPAND; hide clutter in LST file @__LINE__
;      if djdebug
;       messg onoffpop #v((onoffpop) >= 0) #v((onoffpop) == -1) @__LINE__
;djdebug = 0
;      endif; @__LINE__
;    if (onoffpop) == 0xfeed; restore current setting
    if ((onoffpop) >= 0) && ((onoffpop) != 0xfeed); push on/off
;	    messg list push @__LINE__
	LOCAL pushpop = (LSTCTL_STACK + LSTCTL_STACK) / 2;
	WARNIF(pushpop != LSTCTL_STACK, [ERROR] list control stack too deep where: #v(LSTCTL_DEPTH)"," @__LINE__); allow continuation (!error)
LSTCTL_STACK += LSTCTL_STACK + BOOL2INT(onoffpop); push new value
LSTCTL_DEPTH += 1; keep track of current nesting level
LSTCTL_DEEPEST = MAX(LSTCTL_DEEPEST, LSTCTL_DEPTH); keep track of high-water mark
    else; pop or restore
        if (onoffpop) == -1; pop
;	    messg list pop @__LINE__
LSTCTL_STACK >>= 1; pop previous value (shift right)
LSTCTL_DEPTH -= 1; keep track of current nesting level
	    WARNIF(LSTCTL_DEPTH < 0, [ERROR] list control stack underflow where @__LINE__); allow continuation (!error)
        endif; @__LINE__
    endif; @__LINE__
    if LSTCTL_STACK & 1; turn it on
;	messg turn list on after onoffpop, depth #v(LSTCTL_DEPTH) @__LINE__
	LIST ;turn list on @__LINE__
    else; turn it off
	NOLIST ;turn list off @__LINE__
;	messg turn list off after onoffpop, depth #v(LSTCTL_DEPTH) @__LINE__
    endif; @__LINE__
;    EXPAND_POP where
;    EXPAND_RESTORE where
    if MEXPAND_STACK & 1; turn it back on; aavoid recursion
	EXPAND; @__LINE__
    endif; @__LINE__
    ENDM

eof_#v(EOF_COUNT) macro
    LOCAL sv_depth = #v(LSTCTL_DEPTH);
    WARNIF(sv_depth, [WARNING] list expand stack not empty @eof: #v(sv_depth) @__LINE__); mismatched directives can cause incorrect code gen; "," stack = #v(LSTCTL_STACK)
    endm; @__LINE__
EOF_COUNT += 1;


;show stmt in LST file even if LIST/EXPAND are off:
;used mainly for opcodes
;#define EMITD  LSTLINE_#v(0); initial state
;#define EMITO  LSTLINE_#v(0); initial state
;#define LSTLINE_0; leave as-is (off/on as handled by LST_CONTROL)
;#define MEXPAND_#v(mALL); leave as-is (all off/on handled by MEXPAND)
;LSTLINE_#v(TRUE) macro expr; turn expand on+off to show item in .LST
; messg here1 @__LINE__
EMIT macro stmt
;    EXPAND_PUSH TRUE; show expanded opc/data
    EXPAND
    LIST
    stmt
    EXPAND_RESTORE @__LINE__
    LIST_RESTORE @__LINE__
;    EXPAND_POP
    endm; @__LINE__
;kludge: allow "," in emitted stmt:
EMIT2 macro stmt, arg2
;    EXPAND_PUSH TRUE; show expanded opc/data
    EXPAND
    LIST
    stmt, arg2
    EXPAND_RESTORE @__LINE__
    LIST_RESTORE @__LINE__
;    EXPAND_POP
    endm; @__LINE__

;left-justified version of above (for stmt with label):
EMITL macro stmt
;    EXPAND_PUSH TRUE, @__LINE__; show expanded opc/data
    EXPAND
    LIST
stmt
    EXPAND_RESTORE @__LINE__
    LIST_RESTORE @__LINE__
;    EXPAND_POP @__LINE__
    endm; @__LINE__


#if 0; LST control tests
    LIST_PUSH TRUE
    messg hello 1 @__LINE__
    LIST_PUSH FALSE
    messg hello 0 @__LINE__
    LIST_POP
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
test_expand macro aa, bb
;    EXPAND_PUSH FALSE
    LOCAL cc;broken = aa + bb
    EMITL cc = aa + bb
;  messg "cc" = cc @__LINE__
    LOCAL dd = 1
    test_nested aa, bb, cc
    if cc < 0 
	EMIT movlw 0-cc & 0xff
    else
        EMIT movlw cc & 0xff
    endif; @__LINE__
    movlw b'10101'
;    EXPAND_POP
    endm; @__LINE__
test_nested macro arg1, arg2, arg3
    EXPAND_PUSH TRUE
;  messg "arg1" = arg1, "arg2" = arg2, "arg3" = arg3 @__LINE__
    EMIT LOCAL ARG1 = arg1
    LOCAL ARG2 = arg2
    EXPAND_POP
    EMIT addlw arg1
    sublw arg2
    endm; @__LINE__
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
#define RESET_VECTOR  60; kludge:allow compile
    test_expand 1, 2; 7cc
    LIST_PUSH FALSE
    test_expand 3, 4; 7cc
    LIST_POP
    LIST_POP
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
#endif; @__LINE__; text


;vararg kludge:
;MPASM doesn't handle var args, so use wrappers :(
;#define _ARG(argg)  witharg_#v(argg)
#define bitnum_arg(argg)  withbit_#v(argg)
#define dest_arg(argg)  withdest_#v(argg)
#define val_arg(argg) showarg_#v(argg)
#define with_arg(argg)  witharg_#v(argg) ;//for arbitrary values
;yet-another-kludge: add instances as needed:
;add variants specifically for dest F/W:
;helps to recognize purpose in assembly/debug
dest_arg(W) macro stmt
    stmt, W;
    endm; @__LINE__
; messg here @__LINE__
;broken dest_arg(F) macro stmt
     messg TODO: fix this ^^^ vvv @__LINE__
withdest_1 macro stmt
    stmt, F;
    endm; @__LINE__
;kludge-kludge: pre-generate wrappers for small values (bit# args):
#if 0; broken :(
    VARIABLE bitnum = 0;
    while bitnum < 8
bitnum_arg(bitnum) macro stmt
	stmt, bitnum;
	endm; @__LINE__
bitnum += 1;
    endw; @__LINE__
#else
bitnum_arg(0) macro stmt
    stmt, 0;
    endm; @__LINE__
bitnum_arg(1) macro stmt
    stmt, 1;
    endm; @__LINE__
bitnum_arg(2) macro stmt
    stmt, 2
    endm; @__LINE__
bitnum_arg(3) macro stmt
    stmt, 3
    endm; @__LINE__
bitnum_arg(4) macro stmt
    stmt, 4
    endm; @__LINE__
bitnum_arg(5) macro stmt
    stmt, 5
    endm; @__LINE__
bitnum_arg(6) macro stmt
    stmt, 6
    endm; @__LINE__
bitnum_arg(7) macro stmt
    stmt, 7
    endm; @__LINE__
#endif; @__LINE__
;expand arg value then throw away (mainly for debug):
val_arg(0) macro stmt
    stmt
    endm; @__LINE__

with_arg(0) macro stmt
    stmt, 0
    endm; @__LINE__

;BROKEN:
;    EXPAND
;    VARIABLE small_arg = 0
;    while small_arg < 8
;;bitnum_arg(small_arg) macro stmt
;    messg #v(small_arg), witharg#v(small_arg) @__LINE__
;witharg#v(small_arg) macro stmt
;    messg witharg#v(small_arg) stmt, #v(small_arg) @__LINE__
;        stmt, #v(small_arg); CAUTION: force eval of small_arg here
;	endm; @__LINE__
;small_arg += 1
;    endw; @__LINE__
;    NOEXPAND


;repeat a statement the specified number of times:
;stmt can refer to "repeater" for iteration-specific behavior
;stmt cannot use more than 1 parameter (MPASM gets confused by commas; doesn't know which macro gets the params); use bitnum_arg() or other wrapper
;params:
; count = #times to repeat stmt
; stmt = statement to be repeated
;#define NOARG  0; dummy arg for stmts that don't want any
    VARIABLE REPEATER; move outside macro so caller can use it
REPEAT MACRO count, stmt; _arg1, arg2
;    EXPAND_PUSH FALSE
;    NOEXPAND  ;hide clutter
;?    EXPAND_PUSH FALSE
    LOCAL loop; must be outside if?
    if !ISLIT(count)
;        if $ < 10
;	    messg REPEAT: var count #v(count) @__LINE__
;	endif; @__LINE__
;        LOCAL loop
;        EXPAND_POP
	EMITL loop:	
	EMIT stmt;
;        EXPAND_PUSH FALSE
        BANKCHK count;
	PAGECHK loop; do this before decfsz
	EMIT BANKSAFE dest_arg(F) decfsz count;, F; CAUTION: 0 means 256
;	EXPAND_POP
	GOTO loop;
	exitm; @__LINE__
    endif; @__LINE__
    LOCAL COUNT;broken = LIT2VAL(count)
    EMITL COUNT = LIT2VAL(count)
    WARNIF(COUNT < 1, [WARNING] no repeat?"," count #v(COUNT) @__LINE__)
    ERRIF(COUNT > 1000, [ERROR] repeat loop too big: count #v(COUNT) @__LINE__)
;	if repeater > 1000  ;paranoid; prevent run-away code expansion
;repeater = count
;	    EXITM
;	endif; @__LINE__
;    LOCAL repeater;broken = 0 ;count UP to allow stmt to use repeater value
;    EMITL repeater = 0 ;count UP to allow stmt to use repeater value
;    if $ < 10
;	messg REPEAT: const "count" #v(COUNT) @__LINE__
;    endif; @__LINE__
;    messg REPEAT: count, stmt;_arg1, arg2 @__LINE__
REPEATER = 0;
    while REPEATER < COUNT  ;0, 1, ..., count-1
;	if arg == NOARG
;	    EXPAND_RESTORE  ;show generated code
;	    NOEXPAND  ;hide clutter
;	else
;	EXPAND_RESTORE  ;show generated code
;        EXPAND_PUSH TRUE
        EMIT stmt; _arg1, arg2
;        EXPAND_POP
;	NOEXPAND  ;hide clutter
;	endif; @__LINE__
;	EMITL repeater += 1
REPEATER += 1
    endw; @__LINE__
;    EXPAND_POP
    ENDM
;REPEAT macro count, stmt
;    NOEXPAND  ;hide clutter
;    REPEAT2 count, stmt,
;    endm; @__LINE__


;init injection:
;not needed; just define a linked list of executable code (perf doesn't matter @startup)
;init macro
;    EXPAND_PUSH FALSE
;;broken    REPEAT INIT_COUNT, init_#v(repeater)
;init_code: DROP_CONTEXT
;    LOCAL count = 0;
;    while count < INIT_COUNT
;	init_#v(count)
;count += 1;
;    endw; @__LINE__
;    EXPAND_POP
;    endm; @__LINE__

eof_#v(EOF_COUNT) macro
    CONSTANT EOF_ADDR = $
 EMITL eof:; only used for compile; this must go AFTER all executable code (MUST be a forward reference for pass 1); used to detect pass 1 vs. 2 for annoying error[116] fixups
    messg [INFO] optimization stats: @__LINE__
    ERRIF(LITPAGEOF(EOF_ADDR), [ERROR] code page 0 overflow: eof @#v(EOF_ADDR) is past #v(LIT_PAGELEN)"," need page selects @__LINE__); need to add page selects
;    EMIT sleep;
    endm; @__LINE__
EOF_COUNT += 1;

    NOEXPAND
    NOLIST; reduce .LST clutter
;    messg end of hoist 0 @__LINE__
;#else; too deep :(
#endif; @__LINE__
#if HOIST == 6
;    messg epilog @__LINE__
;    NOLIST; don't show this section in .LST file
    LIST_PUSH FALSE, @__LINE__; don't show this section in .LST file
;; epilog ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;    init
;    cre_threads
;init_#v(INIT_COUNT): DROP_CONTEXT; macro
    at_init TRUE;
    WARNIF(LITPAGEOF($), [ERROR] pclath != 0 after init"," need to change PAGE_TRACKER[1] @__LINE__)
    EMIT at_eof; include trailing code
    EMIT sleep; goto $; all code has run, now just wait for something to happen
;INIT_COUNT = -1; += 999; terminate init code chain
    at_init FALSE;

;    variable @here = 3;
    
;    CONSTANT EOF_ADDR = $
;stkptr_#v(0) EQU stkptr_#v(NUM_THREADS); wrap-around for round robin yield
;start_thread_#v(0) EQU yield; 
;//sanity checks, perf stats:
;eof:  ;this must go AFTER all executable code (MUST be a forward reference); used to detect pass 1 vs. 2 for annoying error[116] fixups
;    messg [INFO] optimization stats: @__LINE__
;    ERRIF(MEXPAND_DEPTH, [ERROR] missing #v(MEXPAND_DEPTH) MEXPAND_POP(s), @__LINE__)
;    WARNIF(LSTCTL_DEPTH, [WARNING] list expand stack not empty @eof: #v(LSTCTL_DEPTH), top = #v(LSTCTL_STKTOP) @__LINE__); can only detect ON entries, but good enough since outer level is off
;    messg [INFO] bank sel: #v(BANKSEL_KEEP) (#v(pct(BANKSEL_KEEP, BANKSEL_KEEP + BANKSEL_DROP))%), dropped: #v(BANKSEL_DROP) (#v(pct(BANKSEL_DROP, BANKSEL_KEEP + BANKSEL_DROP))%) @__LINE__; ;perf stats
;    messg [INFO] bank0 used: #v(RAM_USED#v(0))/#v(RAM_LEN#v(0)) (#v(pct(RAM_USED#v(0), RAM_LEN#v(0)))%) @__LINE__
;    MESSG [INFO] bank1 used: #v(RAM_USED#v(1))/#v(RAM_LEN#v(1)) (#v(pct(RAM_USED#v(1), RAM_LEN#v(1)))%) @__LINE__
;    MESSG [INFO] non-banked used: #v(RAM_USED#v(NOBANK))/#v(RAM_LEN#v(NOBANK)) (#v(pct(RAM_USED#v(NOBANK), RAM_LEN#v(NOBANK)))%) @__LINE__
;    messg [INFO] page sel: #v(PAGESEL_KEEP) (#v(pct(PAGESEL_KEEP, PAGESEL_KEEP + PAGESEL_DROP))%), dropped: #v(PAGESEL_DROP) (#v(pct(PAGESEL_DROP, PAGESEL_KEEP + PAGESEL_DROP))%) @__LINE__; ;perf stats
;    messg [INFO] page0 used: #v(EOF_ADDR)/#v(LIT_PAGELEN) (#v(pct(EOF_ADDR, LIT_PAGELEN))%) @__LINE__
;    MESSG "TODO: fix eof page check @__LINE__"
;    messg [INFO] #threads: #v(NUM_THREADS), stack space needed: #v(STK_ALLOC), unalloc: #v(HOST_STKLEN - STK_ALLOC) @__LINE__
;    messg [INFO] Ugly fixups pass1: #v(PASS1_FIXUPS/0x10000):#v(PASS1_FIXUPS%0x10000), pass2: #v(PASS2_FIXUPS/0x10000):#v(PASS2_FIXUPS%0x10000) @__LINE__
;    ERRIF(LITPAGEOF(EOF_ADDR), [ERROR] code page 0 overflow: eof @#v(EOF_ADDR) is past #v(LIT_PAGELEN), need page selects @__LINE__); need to add page selects
;    END

;    NOLIST; reduce .LST clutter
    LIST_POP @__LINE__
;    messg end of epilog @__LINE__
#endif; @__LINE__; HOIST 6
;#endif; @__LINE__; HOIST 0
;#endif; @__LINE__; HOIST 1
;#endif; @__LINE__; HOIST 2
;#endif; @__LINE__; HOIST 3
;#endif; @__LINE__; HOIST 4
;#endif; @__LINE__; HOIST 5
;#endif; @__LINE__; HOIST 6
#endif; @__LINE__; ndef HOIST    

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;hoist plumbing:
;generates bottom-up assembly code from the above top-down src code
;kludge: MPASM loses track of line#s if file is #included > 1x, so append # to make each unique
#ifndef HOIST
;#define END; "hide" except at outer layer
#define HOIST 1
#include __FILE__ 1; self
#undefine HOIST
#define HOIST 2
#include __FILE__ 2; self
#undefine HOIST
#define HOIST 3
#include __FILE__ 3; self
#undefine HOIST
#define HOIST 4
#include __FILE__ 4; self
#undefine HOIST
#define HOIST 5
#include __FILE__ 5; self
#undefine HOIST
#define HOIST 6
#include __FILE__ 6; self
#undefine HOIST
#define HOIST 7
#include __FILE__ 7; self
#undefine HOIST
;#undefine END; unhide for real eof
#endif; @__LINE__; ndef HOIST
;eof control:
#ifdef HOIST
 #ifndef END
  #define END; prevent hoisted files from ending input
 #endif; @__LINE__
#else
 #undefine END; allow outer file to end input
#endif; @__LINE__; ndef HOIST
    END; eof, maybe
