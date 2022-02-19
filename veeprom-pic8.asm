    title  "PIC8-EEPROM - serial EEPROM emulator for 8-pin/8-bit Microchip PIC"
;add support for other devices @line ~4200
;in general, adding support just involves renaming items to have consistent names or changing mem size
;custom build step:
;pre: cat *.asm  |  awk '{gsub(/__LINE__/, NR)}1' |  tee  "__FILE__ 1.ASM"  "__FILE__ 2.ASM"  "__FILE__ 3.ASM"  "__FILE__ 4.ASM"  "__FILE__ 5.ASM"  "__FILE__ 6.ASM"  "__FILE__ 7.ASM"  >  __FILE__.ASM
;post: rm -f nope__FILE__* &amp;&amp; cp ${ImagePath} ~/Documents/ESOL-fog/ESOL21/tools/PIC/firmware &amp;&amp;  awk 'BEGIN{IGNORECASE=1} NR==FNR { if ($$2 == "EQU") EQU[$$1] = $$3; next; } !/^ +((M|[0-9]+) +)?(EXPAND|EXITM|LIST)([ ;_]|$$)/  { if ((NF != 2) || !match($$2, /^[0-9A-Fa-f]+$$/) || (!EQU[$$1] &amp;&amp; !match($$1, /_[0-9]+$$/))) print; }'  /opt/microchip/mplabx/v5.35/mpasmx/p16f15313.inc  ./build/${ConfName}/${IMAGE_TYPE}/*.o.lst  >  *.LST
;================================================================================
; File:     pic8-eeprom.asm
; Date:     2/19/2022
; Version:  0.22.02
; Author:   djulien@thejuliens.net, (c)2022 djulien@thejuliens.net
; Device:   PIC16F15313 (midrange Microchip 8-pin PIC) or equivalent running @8 MIPS

; Peripherals used: Timer0, Timer1 (gated), Timer2, no-MSSP, EUSART, no-PWM, CLC
; Compiler: mpasmx(v5.35), NOT pic-as; NOTE: custom build line is used for source code fixups
; IDE:      MPLABX v5.35 (last one to include mpasm)
; Description:
;   WS281X-Splitter can be used for the following purposes:
;   1. split a single WS281X data stream into <= 4 separate segments; 
;     creates a virtual daisy chain of LED strings instead of using null pixels between
;   2. debugger or signal integrity checker; show 24-bit WS pixel data at end of string
;   3. timing checker; display frame rate (FPS received); alternating color is used as heartbeat
; Build instructions:
;no   ?Add this line in the project properties box, pic-as Global Options -> Additional options:
;no   -Wa,-a -Wl,-pPor_Vec=0h,-pIsr_Vec=4h
;   - use PICKit2 or 3 or equivalent programmer (PICKit2 requires PICKitPlus for newer PICs)
; Wiring:
;  RA0 = debug output (32 px WS281X):
;        - first 24 px shows segment 1/2/3 quad px length (0 = 1K)
;        - next 8 px = FPS (255 max), msb first
;  RA1 = output segment 1
;  RA2 = output segment 2
;  RA3 = WS281X input stream
;        - first/second/third byte = segment 1/2/3 quad pixel length
;	 - first segment data follows immediately
;  RA4 = output segment 4; receives anything after segment 1/2/3
;  RA5 = output segment 3
; TODO:
;  - use PPS to set RA3 as segment 3 out and RA5 as WS input?
;  - uart bootloader; ground segment 0 out to enable? auto-baud detect; verify
;  - custom pixel dup/skip, enforce max brightness limit?
;================================================================================
    NOLIST; reduce clutter in .LST file
;NOTE: ./Makefile += AWK, GREP
;test controller: SP108E_3E6F0D
;check nested #if/#else/#endif: grep -vn ";#" this-file | grep -e "#if" -e "#else" -e "#endif"
;or:    sed 's/;.*//' < ~/MP*/ws*/wssplitter.asm | grep -n -e " if " -e " else" -e " end" -e " macro" -e " while "
;grep -viE '^ +((M|[0-9]+) +)?(EXPAND|EXITM|LIST)([ ;_]|$$)'  ./build/${ConfName}/${IMAGE_TYPE}/wssplitter.o.lst > wssplitter.LST
    EXPAND; show macro expansions
#ifndef HOIST
#define HOIST  0
#include __FILE__; self
    messg no hoist, app config/defs @48
    LIST_PUSH TRUE
    EXPAND_PUSH FALSE
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;//compile-time options:
;#define BITBANG; //dev/test only
;;#define SPI_TEST
#define WANT_DEBUG; //DEV/TEST ONLY!
;#define WANT_ISR; //ISR not used; uncomment to reserve space for ISR (or jump to)
;#define MAX_THREADS  2; //anim xmit or frame rcv, breakout xmit
#define FOSC_FREQ  (32 MHz); //max speed; NOTE: SPI 3x requires max speed, otherwise lower speed might work

;//pin assignments:
;#define WSDI  RA3; //RA3 = WS input stream (from controller or previous WS281X pixels)
;#define BREAKOUT  RA0; //RA0 = WS breakout pixels, or simple LED for dev/debug
;#define LEDOUT  IIFDEBUG(SEG4OUT, -1); //RA5 = simple LED output; ONLY FOR DEV/DEBUG
;#define WSCLK  4-2; //RA4 = WS input clock (recovered from WS input data signal); EUSART sync rcv clock needs a real I/O pin?
;#define SEG1OUT  RA1; //RA1 = WS output segment 1
;#define SEG2OUT  RA2; //RA2 = WS output segment 2
;#define SEG3OUT  RA#v(3+2); //RA5 = WS output segment 3; RA3 is input-only, use alternate pin for segment 3
;#define SEG4OUT  RA4; //RA4 = WS output segment 4
;;#define RGSWAP  0x321; //3 = R, 2 = G, 1 = B; default = 0x321 = RGB
;;#define RGSWAP  0x231; //3 = R, 2 = G, 1 = B; default = 0x321 = RGB
;#define RGB_ORDER  0x123; //R = byte[1-1], G = byte[2-1], B = byte[3-1]; default = 0x123 = RGB
;//             default    test strip
;//order 0x123: RGBYMCW => BRGMCYW
;//order 0x132: RGBYMCW => RBGMYCW
;//order 0x213: RGBYMCW => BGRCMYW
;//order 0x231: RGBYMCW => RGBYMCW ==
;//order 0x312: RGBYMCW => GBRCYMW
;//order 0x321: RGBYMCW => GRBYCMW
; messg [TODO] R is sending blue(3rd byte), G is sending red(first byte), B is sending green(second byte)
;test strip is GRB order
#define WANT_ISR  10; reserve space for small ISR

    EXPAND_POP
    LIST_POP
    messg end of !hoist @88
#undefine HOIST; //preserve state for plumbing @eof
#else
#if HOIST == 5
    messg hoist 5: custom main @__LINE__
    LIST_PUSH TRUE
    EXPAND_PUSH FALSE
;; custom main ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    THREAD_DEF main, 6; 6 levels: wrapper->ws_player->drip->anim->ws_send->nop

;placeholder:
;real logic goes here
main: DROP_CONTEXT;
    setbit LATA, RA0, TRUE;
    setbit LATA, RA0, FALSE;
    GOTO main;

    THREAD_END;

    EXPAND_POP
    LIST_POP
    messg end of hoist 5 @__LINE__
;#else; too deep :(
#endif
#if HOIST == 2
    messg hoist 2: cooperative multi-tasking ukernel @__LINE__
    LIST_PUSH FALSE; don't show this section in .LST file
    EXPAND_PUSH FALSE
;; cooperative multi-tasking ukernel ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

#define HOST_STKLEN  16-0; total stack space available to threads; none left for host, threaded mode is one-way xition
#define RERUN_THREADS  TRUE; true/false to re-run thread after return (uses 1 extra stack level); comment out ONLY if threads NEVER return!


;NOTE: current (yield) addr uses 1 stack level
#ifndef RERUN_THREADS
 #define MIN_STACK  1; need 1 level for current exec addr within thread
#else
 #define MIN_STACK  2; need another level in case thread returns to wrapper
#endif


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
;    EXPAND_PUSH FALSE;
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
    EMIT return;
;yield set yield_from_#v(NUM_THREADS); alias for caller
;#define YIELD  CALL yield
;yield_again set yield_again_#v(NUM_THREADS); alias for caller
;#define YIELD_AGAIN  GOTO yield_again
#endif
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
    doing_init TRUE;
#ifdef RERUN_THREADS
;    CALL (NUM_THREADS << (4+8)) | thread_wrapper_#v(NUM_THREADS)); set active thread# + statup addr
    CALL stack_alloc_#v(NUM_THREADS); kludge: put thread_wrapper ret addr onto stack; NOTE: doesn't return until yield-back
;thread_wrapper_#v(NUM_THREADS): DROP_CONTEXT;
;    LOCAL rerun_thr;
;rerun_thr:
    CALL thread_body; start executing thread; allows thread to return but uses extra stack level
#if !RERUN_THREADS
    YIELD; call yield_from_#v(NUM_THREADS) ;bypass dead (returned) threads in round robin yields
#endif
;    GOTO IIF(RERUN_THREADS, rerun_thr, yield_again); $-1; re-run thread or just yield to other threads
    YIELD_AGAIN; stack_alloc does same thing as yield_from
#else
;    error [TODO] put "CALL stack_alloc" < "thread_body" @__LINE__
;thread_wrapper_#v(NUM_THREADS) EQU thread_body; onthread(NUM_THREADS, thread_body); begin executing thread; doesn't use any stack but thread can never return!
;    goto thread_body; begin executing thread; doesn't use any stack but thread can never return!
    PUSH thread_body;
;    GOTO stack_alloc_#v(NUM_THREADS); kludge: put thread_wrapper ret addr onto stack; doesn't return until yield
#endif
#if 1
yield_from_#v(NUM_THREADS): DROP_CONTEXT; overhead for first yield = 10 instr = 1.25 usec @8 MIPS
    mov8 stkptr_#v(NUM_THREADS), STKPTR; #v(curthread)
;yield_from_#v(NUM_THREADS)_placeholder set $
yield_again_#v(NUM_THREADS): DROP_CONTEXT; overhead for repeating yield = 7 instr < 1 usec @8 MIPS
    CONTEXT_SAVE yield_placeholder_#v(NUM_THREADS)
    ORG $ + 2+1; placeholder for: mov8 STKPTR, stkptr_#v(NUM_THREADS + 1); % MAX_THREADS); #v(curthread + 1); round robin
    EMIT return;
;yield set yield_from_#v(NUM_THREADS); alias for caller
;yield_again set yield_again_#v(NUM_THREADS); alias for caller
#endif
;alloc + stack + set initial addr:
;NOTE: thread doesn't start execeuting until all threads are defined (to allow yield to auto-start threads)
;CAUTION: execution is multi-threaded after this; host stack is taken over by threads; host stack depth !matter because will never return to single-threaded mode
;create_thread_#v(NUM_THREADS): DROP_CONTEXT;
;create thread but allow more init:
;    doing_init TRUE;
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
stack_alloc_#v(NUM_THREADS): DROP_CONTEXT; CAUTION: this function delays return until yield-back
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
    endif
;    goto create_thread_#v(NUM_THREADS - 1); daisy-chain: create previous thread; CAUTION: use goto - don't want to change STKPTR here!
;  messg [DEBUG] #v(BANK_TRACKER) @__LINE__
    doing_init FALSE;
;    messg "YIELD = " YIELD @__LINE__
NUM_THREADS += 1; do this at start so it will remain validate within thread body; use non-0 for easier PCLATH debug; "thread 0" == prior to thread xition
;    messg "YIELD = " YIELD @__LINE__
IN_THREAD = NUM_THREADS;
;    EXPAND_POP
    endm

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
    endm


;in-lined YIELD_AGAIN:
;occupies 2-3 words in prog space but avoids extra "goto" (2 instr cycles) on context changes at run time
;CAUTION: returns to previous YIELD, not code following
YIELD_AGAIN_inlined macro
    mov8 STKPTR, stkptr_#v(NUM_THREADS); round robin
    EMIT return; return early if banksel !needed; more efficient than nop
    endm

;create + execute threads:
;once threads are created, execution jumps to ukernel (via first thread) and never returns
;cre_threads macro
;init_#v(INIT_COUNT): DROP_CONTEXT; macro
;first set up thread stacks + exec addr:
;    LOCAL thr = #v(NUM_THREADS);
;    while thr > 0
;	call create_thread_#v(thr); NOTE: stack alloc + set initial addr; thread doesn't start until yielded to
;thr -= 1
;    endw
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
;    endm
    
;yield_until macro reg, bitnum, bitval
;    ifbit reg, bitnum, bitval, resume_thread
;    mov8 stkptr_#v(NUM_THREADS), STKPTR; #v(curthread)
;    mov8 STKPTR, stkptr_#v(NUM_THREADS + 1); % MAX_THREADS); #v(curthread + 1); round robin
;    endm

;yield_delay macro usec_delay
;    endm

; messg EOF_COUNT @__LINE__
eof_#v(EOF_COUNT) macro
;    EXPAND_PUSH FALSE
;    messg [INFO] #threads: #v(NUM_THREADS), stack space needed: #v(STK_ALLOC), unalloc: #v(HOST_STKLEN - STK_ALLOC) @__LINE__
;optimize special cases:
;    if NUM_THREADS == 1
;	messg TODO: bypass yield (only 1 thread) @__LINE__
;    endif
;    if NUM_THREADS == 2
;	messg TODO: swap stkptr_#v() (only 2 threads) @__LINE__
;    endif
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
    endif
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
	    EMIT return; return early if banksel !needed; more efficient than nop
	endif
;	DROP_WREG;
;	ORG yield_again_#v(yield_thread)_placeholder
;        CONTEXT_RESTORE yield_again_placeholder_#v(yield_thread)
;here = $	
;	mov8 STKPTR, stkptr_#v((yield_thread + 1) % NUM_THREADS); round robin wraps around
;	if $ < here + 3
;	    EMIT return; fill space reserve for banksel; return rather than nop
;	endif
;	ORG save_place
yield_thread += 1
    endw
;    ORG save_place
;WREG_TRACKER = save_wreg
;BANK_TRACKER = save_bank
    CONTEXT_RESTORE before_yield
;    while yield_thread < 16
;	EMIT sleep; pad out jump table in case of unknown thread
;yield_thread += 1
;    endw
;generic yield_again:
;    EMITL yield_again_generic: DROP_CONTEXT;
;    BANKCHK TOSH;
;    BANKSAFE dest_arg(W) swapf TOSH;, W; PCLATH might have changed, TOSH gives true PC
;    EMIT andlw 0x0F; strip off 4 lsb (swapped), leaving thread#; NOTE: PC is 15 bits so only 8 thread pages are possible
;    EMIT brw
;    while yield_thread < 16 + NUM_THREADS
;	EMIT goto yield_again_#v(yield_thread % NUM_THREADS); NOTE: 4 msb PCLATH will be set within yield_#v()
;yield_thread += 1
;    endw
;    while yield_thread < 16 + 16
;	EMIT sleep; pad out jump table in case of unknown thread
;yield_thread += 1
;    endw
;    EXPAND_POP
    endm
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
    mov8 PMD0, LITERAL(DISABLED_ALL ^ DISABLED(SYSCMD) ^ DISABLED(NVMMD)); ENABLED(SYSCMD) | DISABLED(FVRMD) | DISABLED(NVMMD) | DISABLED(CLKRMD) | DISABLED(IOCMD)); keep sys clock, disable FVR, NVM, CLKR, IOC
;    setbit PMD1, NCOMD, DISABLED;
    mov8 PMD1, LITERAL(DISABLED_ALL ^ DISABLED(TMR2MD) ^ DISABLED(TMR1MD) ^ DISABLED(TMR0MD)); DISABLED(NCOMD) | ENABLED(TMR2MD) | ENABLED(TMR1MD) | ENABLED(TMR0MD)); disable NCO, enabled Timer 0 - 2
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
    messg ^v REINSTATE
;    mov8 PMD5, LITERAL(DISABLED(CLC4MD) | DISABLED(CLC3MD) | ENABLED(CLC2MD) | ENABLED(CLC1MD)); disable CLC 3, 4, enable CLC 1, 2
    mov8 PMD5, LITERAL(DISABLED_ALL); ENABLED_ALL); DISABLED_ALL ^ DISABLED(CLC#v(WSPASS)MD) ^ DISABLED(CLC#v(WSDO)MD)); ENABLED(CLC4MD) | ENABLED(CLC3MD) | ENABLED(CLC2MD) | ENABLED(CLC1MD)); disable CLC 3, 4, enable CLC 1, 2
    endm


;NOTE: default is unlocked
pps_lock macro want_lock
;requires next 5 instructions in sequence:
    mov8 PPSLOCK, LITERAL(0x55);
    mov8 PPSLOCK, LITERAL(0xAA);
;    mov8 PPSLOCK, LITERAL(0); allow CLC1 output to be redirected to RA1/2/5/4
    setbit PPSLOCK, PPSLOCKED, want_lock; allow output pins to be reassigned
    endm


;initialize I/O pins:
;NOTE: RX/TX must be set for Input when EUSART is synchronous, however UESART controls this?
;#define NO_PPS  0
;#define INPUT_PINS  (BIT(WSDI) | BIT(RA#v(BREAKOUT))); //0x00); //all pins are output but datasheet says to set TRIS for peripheral pins; that is just to turn off general-purpose output drivers
iopin_init macro
    mov8 ANSELA, LITERAL(0); //all digital; CAUTION: do this before pin I/O
    mov8 WPUA, LITERAL(BIT(RA3)); INPUT_PINS); //weak pull-up on input pins in case not connected (ignored if MCLRE configured)
#if 0
    messg are these needed? @__LINE__
    mov8 ODCONA, LITERAL(0); push-pull outputs
    mov8 INLVLA, LITERAL(~0 & 0xff); shmitt trigger input levels;  = 0x3F;
    mov8 SLRCONA, LITERAL(~BIT(RA#v(RA3)) & 0xff); on = 25 nsec slew, off = 5 nsec slew; = 0x37;
#endif
    mov8 LATA, LITERAL(0); //start low to prevent junk on line
    mov8 TRISA, LITERAL(BIT(RA3)); | BIT(RA#v(BREAKOUT))); INPUT_PINS); //0x00); //all pins are output but datasheet says to set TRIS for peripheral pins; that is just to turn off general-purpose output drivers
;?    REPEAT LITERAL(RA5 - RA0 + 1), mov8 RA0PPS + repeater, LITERAL(NO_PPS); reset to LATA; is this needed? (datasheet says undefined at startup)
    endm


;    LIST
;    LIST_PUSH TRUE
;HFFRQ values:
;(these should be in p16f15313.inc)
    CONSTANT HFFRQ_#v(32 MHz) = b'110'
    CONSTANT HFFRQ_#v(16 MHz) = b'101'
    CONSTANT HFFRQ_#v(12 MHz) = b'100'
    CONSTANT HFFRQ_#v(8 MHz) = b'011'
    CONSTANT HFFRQ_#v(4 MHz) = b'010'
    CONSTANT HFFRQ_#v(2 MHz) = b'001'
    CONSTANT HFFRQ_#v(1 MHz) = b'000'
;    LIST_POP; pop
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
fosc_init macro
;    mov8 OSCCON1, LITERAL(b'110' << NOSC0 | b'0000' << NDIV0
;RSTOSC in CONFIG1 tells HFFRQ to default to 32 MHz, use 2:1 div for 16 MHz:
    setbit OSCCON3, CSWHOLD, FALSE; use new clock as soon as stable (should be immediate if HFFRQ !changed)
    mov8 OSCCON1, LITERAL(USE_HFFRQ << NOSC0 | 0 << NDIV0); MY_OSCCON); 1:1
    mov8 OSCFRQ, LITERAL(HFFRQ_#v(FOSC_FREQ));
;    ERRIF CLK_FREQ != 32 MHz, [ERROR] need to set OSCCON1, clk freq #v(CLK_FREQ) != 32 MHz
;CAUTION: assume osc freq !change, just divider, so new oscillator is ready immediately
;;    ifbit PIR1, CSWIF, FALSE, goto $-1; wait for clock switch to complete
;    ifbit OSCCON3, ORDY, FALSE, goto $-1; wait for clock switch to complete
    endm


;general I/O initialization:
    doing_init TRUE
    EXPAND_PUSH TRUE
    iopin_init;
    fosc_init;
    pmd_init; turn off unused peripherals
    EXPAND_POP
;NOPE: PPS assigned during brkout_render    pps_lock TRUE; prevent pin reassignments; default is unlocked
    doing_init FALSE


;; config ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Configuration bits: selected in the GUI (MCC)
;#if EXT_CLK_FREQ  ;ext clock might be present
;MY_CONFIG &= _EC_OSC  ;I/O on RA4, CLKIN on RA5; external clock (18.432 MHz); if not present, int osc will be used
;MY_CONFIG &= _FCMEN_ON  ;turn on fail-safe clock monitor in case external clock is not connected or fails (page 33); RA5 will still be configured as input, though
;#else  ;EXT_CLK_FREQ
;MY_CONFIG &= _INTRC_OSC_NOCLKOUT  ;I/O on RA4+5; internal clock (default 4 MHz, later bumped up to 8 MHz)
;MY_CONFIG &= _FCMEN_OFF  ;disable fail-safe clock monitor; NOTE: this bit must explicitly be turned off since MY_CONFIG started with all bits ON
;#endif  ;EXTCLK_FREQ
;MY_CONFIG &= _IESO_OFF  ;internal/external switchover not needed; turn on to use optional external clock?  disabled when EC mode is on (page 31); TODO: turn on for battery-backup or RTC
;MY_CONFIG &= _BOR_OFF  ;brown-out disabled; TODO: turn this on when battery-backup clock is implemented?
;MY_CONFIG &= _CPD_OFF  ;data memory (EEPROM) NOT protected; TODO: CPD on or off? (EEPROM cleared)
;MY_CONFIG &= _CP_OFF  ;program code memory NOT protected (maybe it should be?)
;MY_CONFIG &= _MCLRE_OFF  ;use MCLR pin as INPUT pin (required for Renard); no external reset needed anyway
;MY_CONFIG &= _PWRTE_ON  ;hold PIC in reset for 64 msec after power up until signals stabilize; seems like a good idea since MCLR is not used
;MY_CONFIG &= _WDT_ON  ;use WDT to restart if software crashes (paranoid); WDT has 8-bit pre- (shared) and 16-bit post-scalars (page 125)
;	__config MY_CONFIG

    LIST_PUSH FALSE
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
;#endif
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
    LIST_PUSH TRUE
    __config _CONFIG1, MY_CONFIG1
    __config _CONFIG2, MY_CONFIG2
    __config _CONFIG3, MY_CONFIG3
    __config _CONFIG4, MY_CONFIG4
    __config _CONFIG5, MY_CONFIG5
    LIST_POP; pop
;config
; config FOSC = HS        ; Oscillator Selection bits (HS oscillator)
; config WDTE = OFF       ; Watchdog Timer Enable bit (WDT disabled)
; config PWRTE = OFF      ; Power-up Timer Enable bit (PWRT disabled)
; config BOREN = OFF      ; Brown-out Reset Enable bit (BOR disabled)
; config LVP = OFF        ; Low-Voltage (Single-Supply) In-Circuit Serial Programming Enable bit (RB3 is digital I/O, HV on MCLR must be used for programming)
; config CPD = OFF        ; Data EEPROM Memory Code Protection bit (Data EEPROM code protection off)
; config WRT = OFF        ; Flash Program Memory Write Enable bits (Write protection off; all program memory may be written to by EECON control)
; config CP = OFF         ; Flash Program Memory Code Protection bit (Code protection off)
    LIST_POP; pop

    EXPAND_POP
    LIST_POP
    messg end of hoist 2 @__LINE__
;#else; too deep :(
#endif
#if HOIST == 1
    messg hoist 1: custom opc @__LINE__
    LIST_PUSH FALSE; don't show this section in .LST file
    EXPAND_PUSH FALSE
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

#ifdef WANT_DEBUG
 #define IIFDEBUG(expr_true, ignored)  expr_true
#else
 #define IIFDEBUG(ignored, expr_false)  expr_false
#endif
;#ifdef WANT_DEBUG
; #define NOLIST  LIST; leave it all on
;    messg [INFO] COMPILED FOR DEV/DEBUG! @__LINE__
;#endif
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
#endif
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
#endif
#ifndef SUPPORTED
    error [ERROR] Unsupported device @__LINE__; add others as support added
#endif
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
;	endif
;ASM_MSB set asmpower2  ;remember MSB; assembler uses 32-bit values
;asmpower2 *= 2
;    endm

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
	endif
	if !(2 * asmpower2)
	    EMITL ASM_MSB EQU #v(asmpower2)  ;remember MSB; assembler uses 32-bit signed values so this should be 32
	endif
asmpower2 <<= 1
;oscpower2 *= 2
;	if oscpower2 == 128
;oscpower = 125
;	endif
;oscpower2 = IIF(asmpower2 != 128, IIF(asmpower2 != 32768, 2 * oscpower2, 31250), 125); adjust to powers of 10 for clock freqs
;prescpower2 = IIF(asmpower2 != 128, IIF(asmpower2 != 32768, 2 * prescpower2, 31250), 122); adjust to powers of 10 for prescalars
asmbit += 1
    endw
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
	    exitm
	endif
FOUND_MSB >>= 1
    endw
;    EXPAND_POP
    endm


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
    EXPAND_PUSH FALSE; reduce clutter in LST file
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
	endif
    endif
    EXPAND_POP
    endm

; messg EOF_COUNT @__LINE__
eof_#v(EOF_COUNT) macro
    messg [INFO] bank sel: #v(BANKSEL_KEEP) (#v(pct(BANKSEL_KEEP, BANKSEL_KEEP + BANKSEL_DROP))%), dropped: #v(BANKSEL_DROP) (#v(pct(BANKSEL_DROP, BANKSEL_KEEP + BANKSEL_DROP))%) @__LINE__; ;perf stats
    endm
EOF_COUNT += 1;


DROP_BANK macro
;    EXPAND_PUSH FALSE
BANK_TRACKER = BANK_UNKN  ;forget where latest value came from (used for jump targets)
;    EXPAND_POP
    endm

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
    endm
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
;;    endif
;    errorlevel +302 ;kludge: re-Enable bank switch warning
;    EXPAND_RESTORE
;    endm
;BANKSAFE2 macro stmt, arg1, arsg2
;    NOEXPAND
;    errorlevel -302 ;kludge: Disable bank switch warning
;	EXPAND_RESTORE
;	stmt, arg1, arg2
;	NOEXPAND
;    errorlevel +302 ;kludge: re-Enable bank switch warning
;    EXPAND_RESTORE
;    endm
 

;jump target:
;set BSR and WREG unknown
DROP_CONTEXT MACRO
    DROP_BANK
    DROP_WREG
    endm


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
;    endif
;    endm

;push context under top of stack:
;CONTEXT_PUSH_UNDER macro
;    VARIABLE CTX_ADDR#v(CTX_DEPTH) = CTX_ADDR#v(CTX_DEPTH - 1);
;    VARIABLE CTX_WREG#v(CTX_DEPTH) = CTX_WREG#v(CTX_DEPTH - 1);
;    VARIABLE CTX_BANK#v(CTX_DEPTH) = CTX_BANK#v(CTX_DEPTH - 1);
;CTX_DEPTH -=1
;    CONTEXT_PUSH
;CTX_DEPTH +=1
;    endm

;eof_#v(EOF_COUNT) macro
;    WARNIF(CTX_DEPTH, [WARNING] context stack not empty @eof: #v(CTX_DEPTH)"," last addr = #v(CTX_ADDR#v(CTX_DEPTH - 1)) @__LINE__)
;    endm
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
    VARIABLE ctx_page_#v(name) = PAGE_TRACKER
;no, let stmt change it;    DROP_CONTEXT
;    messg save ctx_#v(name)_addr #v(ctx_#v(name)_addr), ctx_#v(name)_page #v(ctx_#v(name)_page) @__LINE__
    endm

CONTEXT_RESTORE macro name
;    messg restore ctx_#v(name)_addr #v(ctx_#v(name)_addr), ctx_#v(name)_page #v(ctx_#v(name)_page) @__LINE__
    EMIT ORG ctx_addr_#v(name);
WREG_TRACKER = ctx_wreg_#v(name)
BANK_TRACKER = ctx_bank_#v(name)
PAGE_TRACKER = ctx_page_#v(name)
    endm


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
    EXPAND_PUSH TRUE; CAUTION: macro expand must be set outside of cblock
    CBLOCK NEXT_RAM#v(bank); BOOL2INT(banked))  ;continue where we left off last time
	name numbytes
    ENDC  ;can't span macros
    EXPAND_POP
;    EXPAND_PUSH FALSE
RAM_BLOCK += 1  ;need a unique symbol name so assembler doesn't complain; LOCAL won't work inside CBLOCK
;    EXPAND_RESTORE; NOEXPAND
    CBLOCK
	LATEST_RAM#v(RAM_BLOCK):0  ;get address of last alloc; need additional CBLOCK because macros cannot span CBLOCKS
    ENDC
;    NOEXPAND
NEXT_RAM#v(bank) = LATEST_RAM#v(RAM_BLOCK)  ;update pointer to next available RAM location
RAM_USED#v(bank) = NEXT_RAM#v(bank) - RAM_START#v(bank); BOOL2INT(banked))
    CONSTANT SIZEOF(name) = LATEST_RAM#v(RAM_BLOCK) - name;
    ERRIF(NEXT_RAM#v(bank) > MAX_RAM#v(bank), [ERROR] ALLOC_GPR: RAM overflow #v(LATEST_RAM#v(RAM_BLOCK)) > max #v(MAX_RAM#v(bank)) @__LINE__); BOOL2INT(banked))),
;    ERRIF LAST_RAM_ADDRESS_#v(RAM_BLOCK) > RAM_END#v(BOOL2INT(banked)), [ERROR] SAFE_ALLOC: RAM overflow #v(LAST_RAM_ADDRESS_#v(RAM_BLOCK)) > end #v(RAM_END#v(BOOL2INT(banked)))
;    ERRIF LAST_RAM_ADDRESS_#v(RAM_BLOCK) <= RAM_START#v(BOOL2INT(banked)), [ERROR] SAFE_ALLOC: RAM overflow #v(LAST_RAM_ADDRESS_#v(RAM_BLOCK)) <= start #v(RAM_START#v(BOOL2INT(banked)))
;    EXPAND_POP,
;    EXPAND_POP,
;    EXPAND_POP
    ENDM

; messg EOF_COUNT @__LINE__
eof_#v(EOF_COUNT) macro
    if RAM_USED#v(0)
        messg [INFO] bank0 used: #v(RAM_USED#v(0))/#v(RAM_LEN#v(0)) (#v(pct(RAM_USED#v(0), RAM_LEN#v(0)))%) @__LINE__
    endif
    if RAM_USED#v(1)
	MESSG [INFO] bank1 used: #v(RAM_USED#v(1))/#v(RAM_LEN#v(1)) (#v(pct(RAM_USED#v(1), RAM_LEN#v(1)))%) @__LINE__
    endif
    if RAM_USED#v(NOBANK)
        MESSG [INFO] non-banked used: #v(RAM_USED#v(NOBANK))/#v(RAM_LEN#v(NOBANK)) (#v(pct(RAM_USED#v(NOBANK), RAM_LEN#v(NOBANK)))%) @__LINE__
    endif
    endm
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
#define MOVIW_opc(fsr, mode)  MOVIW_#v((fsr) == FSR1)_#v((mode) & 3)
#define MOVIW_1_0  MOVIW ++FSR1
#define MOVIW_1_1  MOVIW --FSR1
#define MOVIW_1_2  MOVIW FSR1++
#define MOVIW_1_3  MOVIW FSR1--
#define MOVIW_0_0  MOVIW ++FSR0
#define MOVIW_0_1  MOVIW --FSR0
#define MOVIW_0_2  MOVIW FSR0++
#define MOVIW_0_3  MOVIW FSR0--
;#define MOVWI_opc(fsr, mode)  PROGDCL 0x18 | ((fsr) == FSR1) << 2 | ((mode) & 3)
#define MOVWI_opc(fsr, mode)  MOVWI_#v((fsr) == FSR1)_#v((mode) & 3)
#define MOVWI_1_0  MOVWI ++FSR1
#define MOVWI_1_1  MOVWI --FSR1
#define MOVWI_1_2  MOVWI FSR1++
#define MOVWI_1_3  MOVWI FSR1--
#define MOVWI_0_0  MOVWI ++FSR0
#define MOVWI_0_1  MOVWI --FSR0
#define MOVWI_0_2  MOVWI FSR0++
#define MOVWI_0_3  MOVWI FSR0--


;move (copy) reg or value to reg:
;optimized to reduce banksel and redundant WREG loads
;    messg "TODO: optimize mov8 to avoid redundant loads @__LINE__"
;#define UNKNOWN  -1 ;non-banked or unknown
    CONSTANT WREG_UNKN = ASM_MSB >> 1; -1; ISLIT == FALSE
    VARIABLE WREG_TRACKER = WREG_UNKN ;unknown at start
mov8 macro dest, src
;    EXPAND_PUSH FALSE
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
;	    EXPAND_POP
	    exitm
	endif
	if WREG_TRACKER != src
;	    EXPAND_RESTORE ;show generated opcodes
;	    EMIT movlw LIT2VAL(src); #v(LIT2VAL(SRC))
	    MOVLW LIT2VAL(src);
;	    NOEXPAND
;WREG_TRACKER = src
	endif
    else ;register
	if (SRC != WREG) && (SRC != WREG_TRACKER)
	    MOVF src, W;
	endif
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
;;		    endif
;		endif
;	    endif
;	endif
    endif
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
;	    endif
;        endif
    endif
;    EXPAND_POP
    endm

DROP_WREG macro
;    EXPAND_PUSH FALSE
WREG_TRACKER = WREG_UNKN  ;forget latest value
;    EXPAND_POP
    endm


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
;	endif
    endif
;    EXPAND_POP
    endm


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
	endif
	XORWF reg2, W; reg ^ WREG
	XORWF reg2, F; reg ^ (reg ^ WREG) == WREG
	XORWF reg1, F; WREG ^ (reg ^ WREG) == reg
    endif
;    EXPAND_POP
    endm


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
    endif
;    EXPAND_POP
    endm

LODW macro reg
    MOVF reg, W
    endm

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
	endif
    endif
;    EXPAND_POP
    endm


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
	    endif
	endif
    endif
;    EXPAND_POP
    endm


#define INCF  incf_banksafe
INCF macro reg, dest
;    EXPAND_PUSH FALSE
    BANKCHK reg
    BANKSAFE EMIT dest_arg(dest) incf reg;, dest;
    if (reg == WREG) || !BOOL2INT(dest)
WREG_TRACKER = IIF(ISLIT(WREG_TRACKER), WREG_TRACKER + 1, WREG_UNKN)
    endif
;    EXPAND_POP
    endm


#define DECF  decf_banksafe
DECF macro reg, dest
;    EXPAND_PUSH FALSE
    BANKCHK reg
    BANKSAFE EMIT dest_arg(dest) decf reg;, dest;
    if (reg == WREG) || !BOOL2INT(dest)
WREG_TRACKER = IIF(ISLIT(WREG_TRACKER), WREG_TRACKER + 1, WREG_UNKN)
    endif
;    EXPAND_POP
    endm

#define SWAPF  swapf_banksafe
SWAPF macro reg, dest
;    EXPAND_PUSH FALSE
    BANKCHK reg
    BANKSAFE EMIT dest_arg(dest) swapf reg;, dest;
    if (reg == WREG) || !BOOL2INT(dest)
WREG_TRACKER = IIF(ISLIT(WREG_TRACKER), LITERAL(((WREG_TRACKER >> 4) & 0xF) | ((WREG_TRACKER << 4) & 0xF0)), WREG_UNKN)
    endif
;    EXPAND_POP
    endm


#define ADDWF  addwf_banksafe
ADDWF macro reg, dest
;    EXPAND_PUSH FALSE
    BANKCHK reg
    BANKSAFE EMIT dest_arg(dest) addwf reg;, dest;
    if (reg == WREG) || !BOOL2INT(dest)
WREG_TRACKER = WREG_UNKN; IIF(ISLIT(WREG_TRACKER), WREG_TRACKER + 1, WREG_UNKN)
    endif
;    EXPAND_POP
    endm


#define SET8W  IORLW 0xFF; set all WREG bits
#define clrw  clrf WREG; clrw_tracker; override default opcode for WREG tracking
#define CLRW  CLRF WREG; clrw_tracker; override default opcode for WREG tracking
#define incw  addlw 1
#define INCW  ADDLW 1
;WREG tracking:
;clrw macro
;    mov8 WREG, LITERAL(0);
;    clrf WREG;
;    endm

;#define moviw  moviw_tracker; override default opcode for WREG tracking
;moviw macro arg
;    moviw arg
;    DROP_WREG
;    endm

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
    endif
;    EXPAND_POP
    endm

    messg [TODO]: need to UNLIT WREG_TRACKER when used in arith (else upper bits might be affected)

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
    endif
;    DROP_WREG
;    EXPAND_POP
    endm

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
    endif
;    DROP_WREG
;    EXPAND_POP
    endm

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
    endif
;    DROP_WREG
;    EXPAND_POP
    endm

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
    endif
;    DROP_WREG
;    EXPAND_POP
    endm

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
    endif
;    DROP_WREG
;    EXPAND_POP
    endm

;k - W - !B(C) => W
SUBLWB macro value
    ifbit BORROW TRUE, incw; apply Borrow first (sub will overwrite it)
    SUBLW value;
    endm


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
	endif
    endif
;    DROP_WREG
;    EXPAND_POP
    endm


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
	endif
    endif
;    DROP_WREG
;    EXPAND_POP
    endm


#define BSF  bsf_tracker
BSF macro reg, bitnum
;    EXPAND_PUSH FALSE
    ERRIF((bitnum) & ~7, [ERROR] invalid bitnum ignored: #v(bitnum) @__LINE__)
    BANKCHK reg
    BANKSAFE EMIT bitnum_arg(bitnum) bsf reg
    if reg == WREG
WREG_TRACKER = IIF(ISLIT(WREG_TRACKER), LITERAL(WREG_TRACKER | BIT(bitnum)), WREG_UNKN)
    endif
;    EXPAND_POP
    endm


#define BCF  bcf_tracker
BCF macro reg, bitnum
;    EXPAND_PUSH FALSE
    ERRIF((bitnum) & ~7, [ERROR] invalid bitnum ignored: #v(bitnum) @__LINE__)
    BANKCHK reg
    BANKSAFE EMIT bitnum_arg(bitnum) bcf reg
    if reg == WREG
WREG_TRACKER = IIF(ISLIT(WREG_TRACKER), LITERAL(WREG_TRACKER & ~BIT(bitnum)), WREG_UNKN)
    endif
;    EXPAND_POP
    endm


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
    endif
    LOCAL SRC = src ;kludge; force eval (avoids "missing operand" and "missing argument" errors/MPASM bugs); also helps avoid "line too long" messages (MPASM limit 200)
    if ISLIT(SRC)  ;unpack SRC bytes
	mov8 REGLO(dest), LITERAL(SRC & 0xFF)
	if numbits > 16
	    mov8 REGMID(dest), LITERAL(SRC >> 8 & 0xFF)
	    mov8 REGHI(dest), LITERAL(SRC >> 16 & 0xFF)
	else
	    mov8 REGHI(dest), LITERAL(SRC >> 8 & 0xFF)
	endif
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
	endif
	mov8 REGHI(dest), REGHI(src)
    endif
;    EXPAND_RESTORE
;    EXPAND_POP
    endm


inc16 macro reg
    if (reg == FSR0) || (reg == FSR1)
    	addfsr reg, +1; //next 8 px (1 bpp)
	exitm
    endif
    INCFSZ REGLO(reg), F
    DECF REGHI(reg), F; kludge: cancels incf below if !zero
    INCF REGHI(reg), F
    endm


dec16 macro reg
    if (reg == FSR0) || (reg == FSR1)
    	addfsr reg, -1;
	exitm
    endif
    DECFSZ REGLO(reg), F
    INCF REGHI(reg), F; kludge: cancels decf below if !zero
    DECF REGHI(reg), F
    endm


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
    endif
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
    return;
    endm
#endif


#if 0
	PAGECHK memcpy_loop; do this before decfsz
memcpy_loop: DROP_CONTEXT;
    mov8 INDF0_postinc, INDF1_postinc;
    DECFSZ WREG, F
    GOTO memcpy_loop;
    return;
memcpy macro dest, src, len
    mov16 FSR0, LITERAL(dest);
    mov16 FSR1, LITERAL(src);
    mov8 WREG, len;
    endm
#endif


;24-bit rotate left:
;C bit comes into lsb
;rlf24 macro reg
;    rlf REGLO(reg), F
;    rlf REGMID(reg), F
;    rlf REGHI(reg), F
;    endm


;kludge: need inner macro level to force arg expansion:
;#define CONCAT(lhs, rhs)  lhs#v(0)rhs

b0DCL8 macro name
    b0DCL name,; 1 byte
    endm
nbDCL8 macro name
    nbDCL name,;1 byte
    endm


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
    endm

nbDCL16 macro name
;    EXPAND_PUSH FALSE
    nbDCL REGLO(name),:2
;    nbDCL REGHI(name),
    EMIT CONSTANT REGHI(name) = REGLO(name) + 1;
;    CONSTANT name = REGLO(name); kludge: allow generic reference to both bytes
;    EXPAND_POP
    endm

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
    endm

nbDCL24 macro name
;    EXPAND_PUSH FALSE
    nbDCL REGLO(name),:3
;    nbDCL REGMID(name),
;    nbDCL REGHI(name),
    EMIT CONSTANT REGMID(name) = REGLO(name) + 1;
    EMIT CONSTANT REGHI(name) = REGLO(name) + 2;
;    CONSTANT name = REGLO(name); kludge: allow generic reference to all 3 bytes
;    EXPAND_POP
    endm


;    constant REGLO(PALETTE_#v(0)) = palents + 0*3, REGMID(
;    EMIT CONSTANT REGMID(name) = REGLO(name) + 1;
;    EMIT CONSTANT REGHI(name) = REGLO(name) + 2;
ALIAS_DCL24 macro alias, addr
    constant REGLO(alias) = (addr)+0;
    constant REGMID(alias) = (addr)+1;
    constant REGHI(alias) = (addr)+2;
    endm


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
    EXPAND_PUSH FALSE; hide clutter in LST file
;    LOCAL banked = FALSE  ;don't need this param; hard-code to OFF
    if !(BITDCL_COUNT % 8); allocate more storage space
;	if banked
;	    BDCL BITDCL#v(BITDCL_COUNT_#v(banked) / 8)
;	else
;	NBDCL BITDCL#v(BITDCL_COUNT_#v(banked) / 8)
        nbDCL BITVARS#v(BITDCL_COUNT / 8),; //general-use bit vars
        doing_init TRUE;
	mov8 BITVARS#v(BITDCL_COUNT / 8), LITERAL(0); init all bit vars to 0
	doing_init FALSE;
;	endif
    endif
    EMIT CONSTANT name = BITDCL_COUNT; _#v(banked); remember where the bit is
BITDCL_COUNT += 1; _#v(banked) += 1
    EXPAND_POP
    ENDM

eof_#v(EOF_COUNT) macro
    messg [INFO] (non-banked) Bit vars: allocated #v(8 * divup(BITDCL_COUNT, 8)), used #v(BITDCL_COUNT) @__LINE__
    endm
EOF_COUNT += 1;


;setbit_only macro dest, bit, bitval
;    mov8 dest, LITERAL(IIF(BOOL2INT(bitval), BIT(bit), 0)
;    endm
;set/clear bit:
setbit macro dest, bit, bitval
;    EXPAND_PUSH FALSE
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
    endif
    if dest == WREG
;	if ISLIT(WREG_TRACKER)
;	    if BOOL2INT(bitval)
;WREG_TRACKER |= BIT(bit)
;	    else
;WREG_TRACKER &= ~BIT(bit)
;	    endif
;	else
;WREG_TRACKER = WREG_UNK
;	endif
	if BOOL2INT(bitval)
WREG_TRACKER = IIF(ISLIT(WREG_TRACKER), WREG_TRACKER | BIT(bit), WREG_UNKN);
	else
WREG_TRACKER = IIF(ISLIT(WREG_TRACKER), WREG_TRACKER & ~BIT(bit), WREG_UNKN);
	endif
    endif
;    EXPAND_RESTORE
;    EXPAND_POP
    endm


;single-arg variants:
;BROKEN
;    VARIABLE bitnum = 0;
;    while bitnum < 8
;biton_#v(bitnum) macro reg
;	setbit reg, bitnum, TRUE;
;	endm
;bitoff_#v(bitnum) macro reg
;	setbit reg, bitnum, FALSE;
;	endm
;bitnum += 1
;    endw
biton_#v(0) macro reg
	setbit reg, 0, TRUE;
	endm
bitoff_#v(0) macro reg
	setbit reg, 0, FALSE;
	endm
biton_#v(1) macro reg
	setbit reg, 1, TRUE;
	endm
bitoff_#v(1) macro reg
	setbit reg, 1, FALSE;
	endm
biton_#v(2) macro reg
	setbit reg, 2, TRUE;
	endm
bitoff_#v(2) macro reg
	setbit reg, 2, FALSE;
	endm
biton_#v(3) macro reg
	setbit reg, 3, TRUE;
	endm
bitoff_#v(3) macro reg
	setbit reg, 3, FALSE;
	endm
biton_#v(4) macro reg
	setbit reg, 4, TRUE;
	endm
bitoff_#v(4) macro reg
	setbit reg, 4, FALSE;
	endm
biton_#v(5) macro reg
	setbit reg, 5, TRUE;
	endm
bitoff_#v(5) macro reg
	setbit reg, 5, FALSE;
	endm
biton_#v(6) macro reg
	setbit reg, 6, TRUE;
	endm
bitoff_#v(6) macro reg
	setbit reg, 6, FALSE;
	endm
biton_#v(7) macro reg
	setbit reg, 7, TRUE;
	endm
bitoff_#v(7) macro reg
	setbit reg, 7, FALSE;
	endm


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
	endif
	exitm
    endif
    ifbit reg, bitnum, bitval, stmt
    endm

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
	endif
;        EXPAND_POP
	exitm
    endif
;    BANKCHK reg;
;    if BOOL2INT(bitval)
;	BANKSAFE bitnum_arg(bitnum) btfsc reg;, bitnum;
;    else
;	BANKSAFE bitnum_arg(bitnum) btfss reg;, bitnum;
;    endif
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
;    endif
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
	    BANKSAFE bitnum_arg(bitnum) btfsc reg;, bitnum;
	else
	    BANKSAFE bitnum_arg(bitnum) btfss reg;, bitnum;
	endif
;	ORG after_addr
;BANK_TRACKER = after_bank
;WREG_TRACKER = after_wreg
	CONTEXT_RESTORE after_#v(NUM_IFBIT)
    endif
;    EXPAND_POP
NUM_IFBIT += 1; kludge: need unique labels
    endm


;wait for bit:
;optimized for shortest loop
whilebit macro reg, bitnum, bitval, idler
    EXPAND_PUSH FALSE
    LOCAL loop, around
    EMITL loop:
    if ISLIT(reg); bit won't change; do idler forever or never
;	ifbit reg, bitnum, bitval, idler
	if BOOL2INT(LITVAL(reg) & BIT(bitnum)) == BOOL2INT(bitval)
;	    EXPAND_PUSH TRUE
	    EMIT idler
	    GOTO loop;
;	    EXPAND_POP
	endif
        EXPAND_POP
	exitm
    endif
    LOCAL NUM_WHILEBIT = NUM_CONTEXT; kludge: need unique symbols
    BANKCHK reg; allow this to be skipped in loop
    LOCAL before_idler = $, before_bank = BANK_TRACKER;, before_wreg = WREG_TRACKER
    CONTEXT_SAVE before_#v(NUM_WHILEBIT)
    ORG before_idler + 2; leave placeholder for btf + goto; backfill after checking for idler
;    EXPAND_POP
    EMIT idler; allows cooperative multi-tasking (optional)
;    EXPAND_PUSH FALSE
    LOCAL after_idler = $, after_bank = BANK_TRACKER;, after_wreg = WREG_TRACKER
    CONTEXT_SAVE after_#v(NUM_WHILEBIT)
    LOCAL bank_changed = BANKOF(after_bank);
bank_changed -= BANKOF(before_bank); line too long :(
;    EMIT ORG before_addr
;BANK_TRACKER = before_bank
;WREG_TRACKER = before_wreg
    CONTEXT_RESTORE before_#v(NUM_WHILEBIT)
    if after_idler == before_idler + 2; no idler, use tight busy-wait (3 instr)
    	ifbit reg, bitnum, bitval, GOTO before_idler; don't need to repeat banksel
	ERRIF($ != before_idler + 2, [ERROR] tight-while bit test size wrong: #v($ - (before_idler + 2)) @__LINE__);
    else; jump around idler
	ifbit reg, bitnum, !BOOL2INT(bitval), GOTO around; check for *opposite* bit val
	ERRIF($ != before_idler + 2, [ERROR] bulky-while bit test size wrong: #v($ - (before_idler + 2)) @__LINE__);
;	ORG after_addr
;BANK_TRACKER = after_bank
;WREG_TRACKER = after_wreg
	CONTEXT_RESTORE after_#v(NUM_WHILEBIT)
	GOTO IIF(bank_changed, loop, before_idler);
    endif
    EMITL around:
    EXPAND_POP
    endm


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
;    endm
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
;	exitm
;    endif
;    NOP count
;    endm

    VARIABLE NOP_expanded = FALSE;
#define NOP  nop_multi; override default opcode for PCH checking and BSR, WREG tracking
NOP macro count;, dummy; dummy arg for usage with REPEAT
    EXPAND_PUSH FALSE
;    NOEXPAND; hide clutter
    LOCAL COUNT = count
    WARNIF(!COUNT, [WARNING] no nop? @__LINE__)
;    if COUNT == 7
;	EMIT call nop#v(COUNT); special case for WS bit-banging
;	exitm
;    endif
    if COUNT & 1
;        EXPAND_RESTORE; NOEXPAND
;	PROGDCL 0; nop
	EMIT nop;
;	NOEXPAND
COUNT -= 1
    endif
    if COUNT && !NOP_expanded; avoid code unless needed; kludge: also avoids reset org conflict
;	doing_init TRUE
;	LOCAL around
;broken 	goto around
    CONTEXT_SAVE around_nop;
    ORG$+1
nop#v(32): call nop#v(16)
nop#v(16): call nop#v(8)
;nop#v(8): nop ;call nop#v(4); 1 usec @8 MIPS
;nop#v(7): nop
;	  goto $+1
nop#v(8): call nop#v(4); 1 usec @8 MIPS
nop#v(4): return; 1 usec @4 MIPS
;    nop 1;,; 1 extra to preserve PCH
around:
    CONTEXT_RESTORE around_nop;
    goto around;
    ORG around;
;	doing_init FALSE
NOP_expanded = TRUE
COUNT -= 2; apply go-around towards delay period
    endif
    if COUNT & 2
;        EXPAND_RESTORE; NOEXPAND
        EMIT goto $+1; 1 instr, 2 cycles (saves space)
;	NOEXPAND
COUNT -= 2
    endif
;(small) multiples of 4:
;    if count >= 4
    if COUNT
;        EXPAND_RESTORE; NOEXPAND
	EMIT call nop#v(COUNT);
;	NOEXPAND
    endif
    EXPAND_POP
    endm


;conditional nop:
nopif macro want_nop, count
    if !BOOL2INT(want_nop)
	exitm
    endif
    NOP count
    endm

;nop2if macro want_nop
;    if want_nop
;	nop2
;    endif
;    endm

;nop4if macro want_nop
;    EXPAND_PUSH FALSE
;    if want_nop
;	EMIT NOP 4;,
;    endif
;    EXPAND_POP
;    endm


;simulate "call" opcode:
PUSH macro addr
;    EXPAND_PUSH FALSE
;    BANKCHK STKPTR;
;    BANKSAFE dest_arg(F) incf STKPTR;, F;
    INCF STKPTR, F
    mov16 TOS, addr; LITERAL(addr); NOTE: only h/w stack is only 15 bits wide
;    EXPAND_POP
    endm

;simulate "return" opcode:
POP macro
;    EXPAND_PUSH FALSE
;    BANKCHK STKPTR;
;    BANKSAFE dest_arg(F) decf STKPTR;, F;
    DECF STKPTR, F;
;    EXPAND_POP
    endm


;PUSHPOP macro addr
;    PUSH addr;
;    POP;
;    endm


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
;	exitm
;    endif
;    ERRIF(!len, [ERROR] code length len must be > 0, @__LINE__);
;CODE_COUNT += 1
;    CONSTANT CODE_ADDR#v(CODE_COUNT) = $
;CODE_HIGHEST -= len
;    EMITO ORG CODE_HIGHEST
;;    messg code push: was #v(CODE_ADDR#v(CODE_COUNT)), is now #v(CODE_NEXT) @__LINE__
;    endm

;CODE_POP macro
;    ORG CODE_ADDR#v(CODE_COUNT)
;    endm
 

;ensure PCLATH is correct:
PAGECHK MACRO dest; ;, fixit, undef_ok
    EXPAND_PUSH FALSE; reduce clutter in LST file
    if LITPAGEOF(dest) != LITPAGEOF(PAGE_TRACKER)
;??    if REGPAGEOF(dest) != REGPAGEOF(PAGE_TRACKER)
;	EMIT CLRF PCLATH; PAGESEL dest; kludge: mpasm doesn't want to pagesel
	EMIT MOVLP REGPAGEOF(dest); LITPAGEOF(dest); set all bits in case BRW/BRA used later
PAGE_TRACKER = dest;
PAGESEL_KEEP += 1
    else
PAGESEL_DROP += 1
    endif
    EXPAND_POP
    endm
    

;conditional call (to reduce caller verbosity):
CALLIF macro want_call, dest
    if want_call
        CALL dest;
    endif
    endm

    VARIABLE PAGE_TRACKER = ASM_MSB -1;
    VARIABLE PAGESEL_KEEP = 0, PAGESEL_DROP = 0; ;perf stats
#define CALL  call_pagesafe; override default opcode for PCH checking and BSR, WREG tracking
CALL macro dest
;    EXPAND_PUSH FALSE
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
;    endif
    PAGECHK dest
    EMIT call dest; PROGDCL 0x2000 | (dest); call dest
PAGE_TRACKER = dest;
;    NOEXPAND
    if NOP_expanded
	if (dest == nop#v(4)) || (dest == nop#v(8)); these don't alter BSR or WREG; TODO: choose a mechanism to indicate this
;        EXPAND_POP
	    exitm
	endif
    endif
    DROP_CONTEXT; BSR and WREG unknown here
;    if dest == choose_next_color
;WREG_TRACKER = color; kludge: avoid unknown contents warning
;    endif
;#ifdef BITBANG
;    if dest == bitbang_wreg
;BANK_TRACKER = LATA; preserve caller context to improve timing
;    endif
;#endif
;    EXPAND_POP
    endm
;    messg ^^^ REINSTATE, @__LINE__


#define GOTO  goto_pagesafe; override default opcode for PCH checking
GOTO macro dest
;    EXPAND_PUSH FALSE
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
;    endif
    PAGECHK dest
;    EXPAND_RESTORE; NOEXPAND
; messg here3 @__LINE__
    EMIT goto dest; PROGDCL 0x2000 | (dest); call dest
PAGE_TRACKER = dest;
; messg here4 @__LINE__
;    NOEXPAND
;not needed: fall-thru would be handled by earlier code    DROP_CONTEXT; BSR and WREG unknown here if dest falls through
;    EXPAND_POP
    endm


eof_#v(EOF_COUNT) macro
    if PAGESEL_KEEP + PAGESEL_DROP
        messg [INFO] page sel: #v(PAGESEL_KEEP) (#v(pct(PAGESEL_KEEP, PAGESEL_KEEP + PAGESEL_DROP))%), dropped: #v(PAGESEL_DROP) (#v(pct(PAGESEL_DROP, PAGESEL_KEEP + PAGESEL_DROP))%) @__LINE__; ;perf stats
    endif
    messg [INFO] page0 used: #v(EOF_ADDR)/#v(LIT_PAGELEN) (#v(pct(EOF_ADDR, LIT_PAGELEN))%) @__LINE__
    endm
EOF_COUNT += 1;


;; startup code ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;special code addresses:
#ifndef RESET_VECTOR
 #define RESET_VECTOR  0; must be 0 for real code; shift for compile/dev debug ONLY
#endif
#define ISR_VECTOR  (RESET_VECTOR + 4); must be 4 for real code; shift for compile/dev debug ONLY
;#define ISR_RESERVED  2; space to reserve for (jump from) ISR

;init_#v(INIT_COUNT): DROP_CONTEXT; macro
    doing_init TRUE
;    EXPAND_PUSH FALSE
;NOTE: this code must be @address 0 in absolute mode
;pic-as, not mpasm: PSECT   code
    DROP_CONTEXT ;DROP_BANK
    EMIT ORG RESET_VECTOR; startup
    WARNIF($, [ERROR] reset code !@0: #v($) @__LINE__);
    EMIT NOP 1; nop; reserve space for ICE debugger?
;    EMIT clrf PCLATH; EMIT pagesel $; paranoid
;    EMIT goto init_#v(INIT_COUNT + 1); init_code ;main
;    doing_init FALSE
;    messg reset pad #v(ISR_VECTOR - $) @__LINE__
#ifdef WANT_ISR
    REPEAT LITERAL(ISR_VECTOR - $), NOP 1; nop; fill in empty space (avoids additional programming data block?); CAUTION: use repeat nop 1 to fill
    EMIT ORG ISR_VECTOR + WANT_ISR; ISR_RESERVED; reserve space for isr in case other opcodes are generated first
;    CONSTANT ISR_PLACEHOLDER = $;
#endif
;    EXPAND_POP
;    endm
;INIT_COUNT += 1
    doing_init FALSE


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
UGLY_PASS12FIX MACRO pass2ofs
;    EXPAND_PUSH FALSE
;    NOEXPAND; reduce clutter
;    EXPAND_PUSH FALSE
    if (pass2ofs) < 0; slide pass 2 addresses down (pad pass 1 address up, actually)
	if !eof; only true during pass 1 (assembler hasn't resolved the address yet); eof label MUST be at end
	    REPEAT -(pass2ofs), nop; insert dummy instructions to move address during pass 1; these won't be present during pass 2
	endif
;		WARNIF eof, "[WARNING] Unneeded pass 1 fixup", pass2ofs, eof  ;won't ever see this message (output discarded during pass 1)
PASS1_FIXUPS += 0x10000-(pass2ofs)  ;lower word = #prog words; upper word = #times called
    endif
    if (pass2ofs) > 0; slide pass 2 addresses up
	if eof; only true during pass 2 (address resolved); eof label MUST be at end
	    REPEAT pass2ofs, nop;
	endif
	WARNIF(!eof, [WARNING] Unneeded #v(pass2ofs) pass 2 fixup @__LINE__)
PASS2_FIXUPS += 0x10000+(pass2ofs)  ;lower word = #prog words; upper word = #times called
    endif
;    EXPAND_POP
;    EXPAND_POP
    ENDM

eof_#v(EOF_COUNT) macro
    if PASS1_FIXUPS + PASS2_FIXUPS
	messg [INFO] Ugly fixups pass1: #v(PASS1_FIXUPS/0x10000):#v(PASS1_FIXUPS%0x10000), pass2: #v(PASS2_FIXUPS/0x10000):#v(PASS2_FIXUPS%0x10000) @__LINE__
    endif
    endm
EOF_COUNT += 1;

    EXPAND_POP
    LIST_POP
    messg end of hoist 1 @__LINE__
;#else; too deep :(
#endif
#if HOIST == 0
    messg hoist 0: generic pic/asm helpers @__LINE__
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
;    endif
;    EXPAND_RESTORE
;    ENDM
;use #def to preserve line#:
;#define ERRIF(assert, msg, args)  \
;    if assert \
;	error msg, args  \
;    endif
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
;    endif
;    EXPAND_RESTORE
;    ENDM
;use #def to preserve line#:
;#define WARNIF(assert, msg, args)  \
;    if assert \
;	messg msg, args \
;    endif
;mpasm doesn't allow #def to span lines :(
;#define WARNIF(assert, msg, args)  WARNIF_#v(BOOL2INT(assert)) msg, args
#define WARNIF(assert, msg)  WARNIF_#v(BOOL2INT(assert)) msg
#define WARNIF_0  IGNORE_EOL; (msg_ignore, args_ignore)  ;IGNORE_EOL; no output
#define WARNIF_1  messg; (msg, args)  messg msg, args


;#define COMMENT(thing) ; kludge: MPASM doesn't have in-line comments, so use macro instead

;ignore remainder of line (2 args):
;    messg TODO: replace? IGNEOL @__LINE__
;IGNORE_EOL2 macro arg1, arg2
;    endm
IGNORE_EOL macro arg
    endm


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
;	    exitm
;	endif
;already += 1
;    endw
;    messg msg, args @#v(lineno)
;    CONSTANT WARNED_#v(NUM_MESSG1X) = lineno
;NUM_MESSG1X += 1
;    EXPAND_POP
;    endm


;add to init code chain:
    VARIABLE INIT_COUNT = 0;
    VARIABLE LAST_INIT = -1;
doing_init macro onoff
    EXPAND_PUSH FALSE
;    messg [DEBUG] doing_init: onoff, count #v(INIT_COUNT), $ #v($), last #v(LAST_INIT), gap? #v($ != LAST_INIT) @__LINE__; 
    if BOOL2INT(onoff); && INIT_COUNT; (LAST_INIT != -1); add to previous init code
;	LOCAL next_init = $
;	CONTEXT_SAVE before_init
;	ORG LAST_INIT; reclaim or backfill placeholder space
;	CONTEXT_RESTORE after_init
	if $ == LAST_INIT; continue from previous code block
	    CONTEXT_RESTORE last_init_#v(INIT_COUNT - 1)
	else; jump from previous code block
	    if INIT_COUNT; && ($ != LAST_INIT); IIF(LITPAGEOF(PAGE_TRACKER), $ + 2, $ + 1); LAST_INIT + 1; jump to next block
PAGE_TRACKER = LAST_INIT; kludge: PCLATH had to be correct in order to get there
		CONTEXT_SAVE next_init_#v(INIT_COUNT)
		CONTEXT_RESTORE last_init_#v(INIT_COUNT - 1)
		GOTO init_#v(INIT_COUNT); next_init
;	    ORG next_init
		CONTEXT_RESTORE next_init_#v(INIT_COUNT)
	    endif
	endif
	EMITL init_#v(INIT_COUNT):
;init_#v(INIT_COUNT): DROP_CONTEXT; macro
    else; end of init code (for now)
	CONTEXT_SAVE last_init_#v(INIT_COUNT)
	ORG IIF(LITPAGEOF(PAGE_TRACKER), $ + 2, $ + 1); leave placeholder for jump to next init section in case needed
LAST_INIT = $
;    EMIT goto init_#v(INIT_COUNT + 1); daisy chain: create next thread; CAUTION: use goto - change STKPTR here
INIT_COUNT += 1; 
    endif
    EXPAND_POP
    endm


;add to eof code chain:
    VARIABLE EOF_COUNT = 0;
;#define at_eof  REPEAT LITERAL(EOF_COUNT), EMITL at_eof_#v(REPEATER): eof_#v(REPEATER)
at_eof macro
;    EXPAND_PUSH FALSE
;;broken:    REPEAT EOF_COUNT, eof_#v(repeater)
;broken:    REPEAT LITERAL(EOF_COUNT), EMITL at_eof_#v(REPEATER): eof_#v(REPEATER)
    LOCAL count = 0;
    while count < EOF_COUNT
        EMITL at_eof_#v(count):; only used for debug
	eof_#v(count)
count += 1;
    endw
;    EXPAND_POP
    endm


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;macro expansion control:
;push/pop current directive, then set new value (max 31 nested levels)
;allows clutter to be removed from the .LST file
    VARIABLE MEXPAND_STACK = TRUE; default is ON (for caller, set at eof in this file)
;use this if more than 32 levels needed:
;    VARIABLE MEXPAND_STACKHI = 0, MEXPAND_STACKLO = 1; default is ON (for caller, set at eof in this file)
    VARIABLE MEXPAND_DEPTH = 0, MEXPAND_DEEPEST = 0
#define EXPAND_PUSH  EXPAND_CTL
#define EXPAND_POP  EXPAND_CTL -1
#define EXPAND_RESTORE  EXPAND_CTL 0xf00d
EXPAND_CTL MACRO onoffpop
    NOEXPAND; hide clutter in LST file
;    if (onoffpop) == 0xf00d; restore current setting
    if (onoffpop) >= 0; push on/off
	LOCAL pushpop = (MEXPAND_STACK + MEXPAND_STACK) / 2;
;	    if pushpop != MEXPAND_STACK; & ASM_MSB
;		messg [ERROR] macro expand stack too deep: #v(MEXPAND_DEPTH) @__LINE__; allow continuation (!error)
;	    endif
	WARNIF(pushpop != MEXPAND_STACK, [ERROR] macro expand stack too deep: #v(MEXPAND_DEPTH) @__LINE__); allow continuation (!error)
MEXPAND_STACK += MEXPAND_STACK + BOOL2INT(onoffpop); push: shift + add new value
MEXPAND_DEPTH += 1; keep track of current nesting level
MEXPAND_DEEPEST = MAX(MEXPAND_DEEPEST, MEXPAND_DEPTH); keep track of high-water mark
;use this if more than 32 levels needed:
;MEXPAND_STACKHI *= 2
;	if MEXPAND_STACKLO & ASM_MSB
;MEXPAND_STACKHI += 1
;MEXPAND_STACKLO &= ~ASM_MSB
;	endif
;    if !(onoff) ;leave it off
	if onoffpop
	    LIST; _PUSH pushpop; NOTE: must be on in order to see macro expansion
	endif
    else; pop or restore
        if (onoffpop) == -1; pop
;    LOCAL EXP_NEST = nesting -1  ;optional param; defaults to -1 if not passed
MEXPAND_STACK >>= 1; pop previous value (shift right)
MEXPAND_DEPTH -= 1; keep track of current nesting level
;only needed if reach 16 levels:
;	if MEXPAND_STACKLO & ASM_MSB  ;< 0
;MEXPAND_STACKLO &= ~ASM_MSB  ;1-MEXPAND_STACKLO  ;make correction for assembler sign-extend
;	endif
;use this if more than 32 levels needed:
;	if MEXPAND_STACKHI & 1
;MEXPAND_STACKLO += ASM_MSB
;	endif
;MEXPAND_STACKHI /= 2
;errif does this:
;	if !(MEXPAND_STACKLO & 1)  ;pop, leave off
;		EXITM
;	endif
;	    if MEXPAND_DEPTH < 0
;		messg [ERROR] macro expand stack underflow @__LINE__; allow continuation (!error)
;	    endif
	    WARNIF(MEXPAND_DEPTH < 0, [ERROR] macro expand stack underflow @__LINE__); allow continuation (!error)
;	    LIST_POP
	    if !(LSTCTL_STACK & 1)
		NOLIST
	    endif
	endif
    endif
    if !(MEXPAND_STACK & 1); leave it off
	exitm
    endif
    EXPAND; turn expand back on
    ENDM

eof_#v(EOF_COUNT) macro
    LOCAL nested = 0; 1; kludge: account for at_eof wrapper
    WARNIF(MEXPAND_DEPTH != nested, [WARNING] macro expand stack not empty @eof: #v(MEXPAND_DEPTH - nested)"," stack = #v(MEXPAND_STACK) @__LINE__); mismatched directives can cause incorrect code gen
    endm
EOF_COUNT += 1;


;listing control:
;push/pop current directive, then set new value (max 31 nested levels)
;allows clutter to be removed from the .LST file
    VARIABLE LSTCTL_STACK = FALSE; default is OFF (for caller, set at eof in this file)
    VARIABLE LSTCTL_DEPTH = 0, LSTCTL_DEEPEST = 0
#define LIST_PUSH  LISTCTL
#define LIST_POP  LISTCTL -1
#define LIST_RESTORE  LISTCTL 0xfeed
LISTCTL MACRO onoffpop
    EXPAND_PUSH FALSE; hide clutter in LST file
;    if (onoffpop) == 0xfeed; restore current setting
    if (onoffpop) >= 0; push on/off
;	    messg list push @__LINE__
	LOCAL pushpop = (LSTCTL_STACK + LSTCTL_STACK) / 2;
	WARNIF(pushpop != LSTCTL_STACK, [ERROR] list control stack too deep: #v(LSTCTL_DEPTH)"," @__LINE__); allow continuation (!error)
LSTCTL_STACK += LSTCTL_STACK + BOOL2INT(onoffpop); push new value
LSTCTL_DEPTH += 1; keep track of current nesting level
LSTCTL_DEEPEST = MAX(LSTCTL_DEEPEST, LSTCTL_DEPTH); keep track of high-water mark
    else; pop or restore
        if (onoffpop) == -1; pop
;	    messg list pop @__LINE__
LSTCTL_STACK >>= 1; pop previous value (shift right)
LSTCTL_DEPTH -= 1; keep track of current nesting level
	    WARNIF(LSTCTL_DEPTH < 0, [ERROR] list control stack underflow @__LINE__); allow continuation (!error)
        endif
    endif
    if LSTCTL_STACK & 1; turn it on
	LIST
    else; turn it off
	NOLIST
    endif
    EXPAND_POP
    ENDM

eof_#v(EOF_COUNT) macro
    WARNIF(LSTCTL_DEPTH, [WARNING] list expand stack not empty @eof: #v(LSTCTL_DEPTH)"," stack = #v(LSTCTL_STACK) @__LINE__); mismatched directives can cause incorrect code gen
    endm
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
    EXPAND_PUSH TRUE; show expanded opc/data
    stmt
    EXPAND_POP
    endm

;left-justified version of above (for stmt with label):
EMITL macro stmt
    EXPAND_PUSH TRUE; show expanded opc/data
stmt
    EXPAND_POP
    endm


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
    endif
    movlw b'10101'
;    EXPAND_POP
    endm
test_nested macro arg1, arg2, arg3
    EXPAND_PUSH TRUE
;  messg "arg1" = arg1, "arg2" = arg2, "arg3" = arg3 @__LINE__
    EMIT LOCAL ARG1 = arg1
    LOCAL ARG2 = arg2
    EXPAND_POP
    EMIT addlw arg1
    sublw arg2
    endm
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
#define RESET_VECTOR  60; kludge:allow compile
    test_expand 1, 2; 7cc
    LIST_PUSH FALSE
    test_expand 3, 4; 7cc
    LIST_POP
    LIST_POP
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
#endif; text


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
    endm
; messg here @__LINE__
;broken dest_arg(F) macro stmt
     messg TODO: fix this ^^^ vvv
withdest_1 macro stmt
    stmt, F;
    endm
;kludge-kludge: pre-generate wrappers for small values (bit# args):
#if 0; broken :(
    VARIABLE bitnum = 0;
    while bitnum < 8
bitnum_arg(bitnum) macro stmt
	stmt, bitnum;
	endm
bitnum += 1;
    endw
#else
bitnum_arg(0) macro stmt
    stmt, 0;
    endm
bitnum_arg(1) macro stmt
    stmt, 1;
    endm
bitnum_arg(2) macro stmt
    stmt, 2
    endm
bitnum_arg(3) macro stmt
    stmt, 3
    endm
bitnum_arg(4) macro stmt
    stmt, 4
    endm
bitnum_arg(5) macro stmt
    stmt, 5
    endm
bitnum_arg(6) macro stmt
    stmt, 6
    endm
bitnum_arg(7) macro stmt
    stmt, 7
    endm
#endif
;expand arg value then throw away (mainly for debug):
val_arg(0) macro stmt
    stmt
    endm

with_arg(0) macro stmt
    stmt, 0
    endm

;BROKEN:
;    EXPAND
;    VARIABLE small_arg = 0
;    while small_arg < 8
;;bitnum_arg(small_arg) macro stmt
;    messg #v(small_arg), witharg#v(small_arg) @__LINE__
;witharg#v(small_arg) macro stmt
;    messg witharg#v(small_arg) stmt, #v(small_arg) @__LINE__
;        stmt, #v(small_arg); CAUTION: force eval of small_arg here
;	endm
;small_arg += 1
;    endw
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
;	endif
;        LOCAL loop
;        EXPAND_POP
	EMITL loop:	
	EMIT stmt;
;        EXPAND_PUSH FALSE
        BANKCHK count;
	PAGECHK loop; do this before decfsz
	BANKSAFE dest_arg(F) decfsz count;, F; CAUTION: 0 means 256
;	EXPAND_POP
	GOTO loop;
	exitm
    endif
    LOCAL COUNT;broken = LIT2VAL(count)
    EMITL COUNT = LIT2VAL(count)
    WARNIF(COUNT < 1, [WARNING] no repeat?"," count #v(COUNT) @__LINE__)
    ERRIF(COUNT > 1000, [ERROR] repeat loop too big: count #v(COUNT) @__LINE__)
;	if repeater > 1000  ;paranoid; prevent run-away code expansion
;repeater = count
;	    EXITM
;	endif
;    LOCAL repeater;broken = 0 ;count UP to allow stmt to use repeater value
;    EMITL repeater = 0 ;count UP to allow stmt to use repeater value
;    if $ < 10
;	messg REPEAT: const "count" #v(COUNT) @__LINE__
;    endif
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
;	endif
;	EMITL repeater += 1
REPEATER += 1
    endw
;    EXPAND_POP
    ENDM
;REPEAT macro count, stmt
;    NOEXPAND  ;hide clutter
;    REPEAT2 count, stmt,
;    endm


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
;    endw
;    EXPAND_POP
;    endm

eof_#v(EOF_COUNT) macro
    CONSTANT EOF_ADDR = $
eof:; only used for compile; this must go AFTER all executable code (MUST be a forward reference for pass 1); used to detect pass 1 vs. 2 for annoying error[116] fixups
    messg [INFO] optimization stats: @__LINE__
    ERRIF(LITPAGEOF(EOF_ADDR), [ERROR] code page 0 overflow: eof @#v(EOF_ADDR) is past #v(LIT_PAGELEN)"," need page selects @__LINE__); need to add page selects
;    EMIT sleep;
    endm
EOF_COUNT += 1;

    NOEXPAND
    NOLIST; reduce .LST clutter
    messg end of hoist 0 @__LINE__
;#else; too deep :(
#endif
#if HOIST == 6
    messg epilog @__LINE__
    NOLIST; don't show this section in .LST file
;; epilog ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;    init
;    cre_threads
;init_#v(INIT_COUNT): DROP_CONTEXT; macro
    doing_init TRUE;
    at_eof; include trailing code
    sleep; goto $; all code has run, now just wait for something to happen
;INIT_COUNT = -1; += 999; terminate init code chain
    doing_init FALSE;

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

    NOLIST; reduce .LST clutter
    messg end of epilog @__LINE__
#endif; HOIST 6
;#endif; HOIST 0
;#endif; HOIST 1
;#endif; HOIST 2
;#endif; HOIST 3
;#endif; HOIST 4
;#endif; HOIST 5
;#endif; HOIST 6
#endif; ndef HOIST    

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
#endif; ndef HOIST
;eof control:
#ifdef HOIST
 #ifndef END
  #define END; prevent hoisted files from ending input
 #endif
#else
 #undefine END; allow outer file to end input
#endif; ndef HOIST
    END; eof, maybe
