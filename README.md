# Mega CD Mode 1 Library

A small library of functions for working with the Sega Mega CD's boot mode 1 (boot from cartridge).

## What is "Mode 1"?

Simply put, it's when the console boots from cartridge while the Mega CD is attached to the Mega Drive.
There is a pin on the cartridge port that dictates how to arrange memory for the cartridge and expansion.
Cartridge games will have cartridge memory be the first thing visible to the 68000, with expansion memory
placed after. If a cartridge game is not present, then the memory is arranged the other way around. This
also means that expansion memory is still visible, and we can make use of it.

## How do I use this?

If you want a quick way to get the BIOS and your Sub CPU program loaded and running, then all you need
to do is call **InitSubCpu** with register a0 containing the pointer to your Sub CPU program and
register d0 containing the length of that program in bytes. It will return a code in register d0 that
indicates if it was successful, or if an error has occurred.

            lea     SubCpuProgram,a0              ; Initialize the Sub CPU
            move.l  #SubCpuProgramLength,d0
            jsr     InitSubCpu
            beq.s   SubCpuInitSuccess             ; If it was successful, branch
        
    SubCpuInitError:
            ; Error occurred, handle it
                
    SubCpuInitSuccess:
            ; Success

Because the Sub CPU BIOS is compressed in [Kosinski](https://segaretro.org/Kosinski_compression), a
decompression routine is provided. If you already have a Kosinski decompression function, then you can
just use that instead and replace the call to **SubCpuKosDec** to call your function instead. You can
also choose to change how your Sub CPU program gets loaded by changing the call to **CopyPrgRamData**.

Once that is called and you start checking if your program has started running, you will
need to make sure the Sub CPU's IRQ2 gets triggered. You can go about this in 2 ways:

* Call **SubCpuInitIrq2** inside the wait loop, which approximates the timing of the IRQ2 triggers
to avoid messing with the VDP.

      WaitSubCpuStart:
              jsr     SubCpuInitIrq2            ; Trigger IRQ2 and wait
              ; Check if the Sub CPU program has started running
              bra.s   WaitSubCpuStart           ; Loop until it has started
* Call **TriggerSubCpuIrq2** manually to fit your specific needs (i.e. using your V-BLANK interrupt handler).

      WaitSubCpuStart:
              ; Check if the Sub CPU program has started running
              bra.s   WaitSubCpuStart           ; Loop until it has started

              ...

      VBlankInterrupt:
              jsr     TriggerSubCpuIrq2         ; Trigger the Sub CPU's IRQ2
              ...

If this isn't suitable for your needs, then you can run separate functions that handle Sub CPU
resets, bus requests, BIOS detection, and copying to Program RAM.
