TITLE DMA.ASM - EMF Protected Mode Sound System - DMA Manager v1.0 31.08.1994
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ

        INCLUDE stdrouts.hdr

Code32          Segment Para Public Use32
	ASSUME	CS:Code32,DS:Code32

	INCLUDE pmode.inc

;ÕÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÑ¸
;³³				    D A T A				      ³³
;ÔÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÏ¾

        INCLUDE dma.hdr

DMAPageRegs     DW      87h, 83h, 81h, 82h

;ÕÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÑ¸
;³³				    C O D E				      ³³
;ÔÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÏ¾

;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º Function:    Allocates a DMA buffer.                                        º
;º Parameters:  ESI --> A DMA buffer structure with DBufLength set.            º
;º Returns:     CF set on error.                                               º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
DMA_AllocBuf    Proc    Near

        mov     ecx, [esi+DBufLength]   ; Fetch the requested buffer length.
        add     ecx, ecx                ; Allocate two buffers to avoid the
        AllocLo [esi+DBufBlockAddr], ecx; DMA page boundary.
        jc      ABErr                   ; Abort if allocation not succesful.
        mov     eax, [esi+DBufBlockAddr]; Store the base address of the block.
        mov     ebx, eax                ; Store a copy of the address.
        add     ebx, _Code32A           ; Convert to physical address.
        mov     edx, ebx                ; Store another copy of the address,
        add     ebx, [esi+DBufLength]   ; Calculate the address of the last byte
        dec     ebx                     ; of the first buffer.
        shr     edx, 16                 ; Get the DMA page # of the 1st byte.
        shr     ebx, 16                 ; Get the DMA page # of the last byte.
        cmp     ebx, edx                ; Are they on the same page?
        je      OnPage                  ; Use the first buffer if yes.
        add     eax, [esi+DBufLength]   ; Use the another buffer instead if not.
OnPage: mov     [esi+DBufAddress], eax  ; Store the address of the buffer.
        clc
        ret

ABErr:  stc
        ret

DMA_AllocBuf    EndP
;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º Function:    Frees a DMA buffer.                                            º
;º Parameters:  ESI --> A DMA buffer structure.                                º
;º Returns:     Nothing.                                                       º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
DMA_FreeBuf     Proc    Near

        mov     eax, [esi+DBufBlockAddr]; Fetch the address of the emory block.
        mov     ecx, [esi+DBufLength]   ; Fetch the length of the buffer.
        add     ecx, ecx                ; Two buffers were allocated.
        Free    eax, ecx                ; Free the allocated memory.
        ret

DMA_FreeBuf     EndP
;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º Function:    Starts playing a DMA buffer.                                   º
;º Parameters:  ESI -> A DMA buffer structure with all fields set.             º
;º Returns:     Nothing.                                                       º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
DMA_Play        Proc    Near

        cli
        cmp     BPtr [esi+DBufChannel],3; Is the DMA channel 16bit?
        ja      Play16bit               ; Skip the 8bit channel code if yes.

        mov     al, [esi+DBufChannel]   ; Fetch the number of the DMA channel.
        out     09h, al                 ; Reset DMA request.
        or      al, 04h                 ; Set the DMA channel mask.
        out     0Ah, al                 ; Mask the channel.
        mov     al, [esi+DBufChannel]   ; Fetch the number of the DMA channel.
        or      al, 48h                 ; Set the playing parameters.
        mov     ah, [esi+DBufAutoLoop]  ; Fetch the auto-initialization flag.
        shl     ah, 4                   ; Multiply the mode flag by 10h.
        or      al, ah                  ; Set the corresponsing DMA parameter.
        mov     ah, [esi+DBufDirection] ; Fetch direction flag.
        shl     ah, 5                   ; Multiply the mode flag by 20h.
        or      al, ah                  ; Set the corresponsing DMA parameter.
        out     0Bh, al                 ; Send the playing parameters.

        movzx   eax, BPtr [esi+DBufChannel]; Fetch the number of the DMA chnl.
        mov     dx, DMAPageRegs[2*eax]  ; Fetch the addr. of the page register.
        mov     eax, [esi+DBufAddress]  ; Fetch the address of the buffer.
        add     eax, _Code32A           ; Convert to physical address.
        shr     eax, 16                 ; Calculate the DMA page number.
        out     dx, al                  ; Send the DMA page.

        xor     al, al                  ; Clear AL.
        out     0Ch, al                 ; Clear the byte pointer flip-flop.
        movzx   dx, BPtr [esi+DBufChannel]; Fetch the number of the DMA channel.
        add     dx, dx                  ; Point the base address register.
        mov     eax, [esi+DBufAddress]  ; Fetch the address of the buffer.
        add     eax, _Code32A           ; Convert to physical address.
        out     dx, al                  ; Send the DMA address low byte.
        shr     eax, 8                  ; Get the high byte.
        out     dx, al                  ; Send the DMA address high byte.

        inc     dx                      ; Point the DMA count register.
        mov     eax, [esi+DBufLength]   ; Fetch the length of the DMA buffer.
        dec     eax                     ; Calculate the DMA count.
        out     dx, al                  ; Send the DMA count low byte.
        shr     eax, 8                  ; Get the high byte.
        out     dx, al                  ; Send the DMA count high byte.

        mov     al, [esi+DBufChannel]   ; Fetch the number of the DMA channel.
        out     0Ah, al                 ; Enable the DMA channel.
        sti
        ret

Play16bit:
        mov     al, [esi+DBufChannel]   ; Fetch the number of the DMA channel.
        and     al, 03h                 ; Get the physical number.
        out     0D2h, al                ; Reset DMA request.
        or      al, 04h                 ; Set the DMA channel mask.
        out     0D4h, al                ; Mask the channel.
        mov     al, [esi+DBufChannel]   ; Fetch the number of the DMA channel.
        or      al, 48h                 ; Set the playing parameters.
        mov     ah, [esi+DBufAutoLoop]  ; Fetch the auto-initialization flag.
        shl     ah, 4                   ; Multiply the mode flag by 10h.
        or      al, ah                  ; Set the corresponsing DMA parameter.
        mov     ah, [esi+DBufDirection] ; Fetch direction flag.
        shl     ah, 5                   ; Multiply the mode flag by 20h.
        or      al, ah                  ; Set the corresponsing DMA parameter.
        out     0D6h, al                ; Send the playing parameters.

        movzx   eax, BPtr [esi+DBufChannel]; Fetch the number of the DMA chnl.
        and     al, 03h                 ; Get the physical number.
        mov     dx, DMAPageRegs[2*eax]  ; Fetch the addr. of the page register.
        add     dx, 08h                 ; Use the second DMA controller.
        mov     eax, [esi+DBufAddress]  ; Fetch the address of the buffer.
        shr     eax, 16                 ; Calculate the DMA page number.
        out     dx, al                  ; Send the DMA page.

        xor     al, al                  ; Clear AL.
        out     0D8h, al                ; Clear the byte pointer flip-flop.

        movzx   dx, BPtr [esi+DBufChannel]; Fetch the number of the DMA channel.
        and     al, 03h                 ; Get the physical number.
        add     dx, dx                  ; Point the base address register.
        add     dx, 0C0h                ; Use the second DMA controller.
        mov     eax, [esi+DBufAddress]  ; Fetch the address of the buffer.
        shr     eax, 1                  ; Get the number of words.
        out     dx, al                  ; Send the DMA address low byte.
        shr     eax, 8                  ; Get the high byte.
        out     dx, al                  ; Send the DMA address high byte.

        add     dx, 2                   ; Point the DMA count register.
        mov     eax, [esi+DBufLength]   ; Fetch the length of the DMA buffer.
        shr     ebx, 1                  ; Get the number of words.
        dec     eax                     ; Calculate the DMA count.
        out     dx, al                  ; Send the DMA count low byte.
        shr     eax, 8                  ; Get the high byte.
        out     dx, al                  ; Send the DMA count high byte.

        mov     al, [esi+DBufChannel]   ; Fetch the number of the DMA channel.
        and     al, 03h                 ; Get the physical number.
        out     0D4h, al                ; Enable the DMA channel.
        sti
        ret

DMA_Play        EndP
;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º Function:    Stops playing a DMA buffer.                                    º
;º Parameters:  ESI -> A DMA buffer structure with all fields set.             º
;º Returns:     Nothing.                                                       º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
DMA_Stop        Proc    Near

        cli                             ; Interrupts off while handling DMA.
        cmp     BPtr [esi+DBufChannel],3; Is the DMA channel 16bit?
        ja      Stop16bit               ; Skip the 8bit channel code if yes.
        mov     al, [esi+DBufChannel]   ; Fetch the number of the DMA channel.
        or      al, 04h                 ; Set the DMA channel mask.
        out     0Ah, al                 ; Mask the channel.
        xor     al, al                  ; Clear AL.
        out     0Ch, al                 ; Clear the byte pointer flip-flop.
        sti
        ret

Stop16bit:
        mov     al, [esi+DBufChannel]   ; Fetch the number of the DMA channel.
        and     al, 03h                 ; Get the physical number.
        or      al, 04h                 ; Set the DMA channel mask.
        out     0D4h, al                ; Mask the channel.
        xor     al, al                  ; Clear AL.
        out     0D8h, al                ; Clear the byte pointer flip-flop.
        sti
        ret

DMA_Stop        EndP
;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º Parameters:  ESI -> A DMA buffer structure with all fields set.             º
;º Returns:     EAX = Playing position, relative to the buffer start address.  º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
DMA_GetPosition Proc    Near

        cli
        mov     dx, 0Ch
        cmp     BPtr [esi+DBufChannel],4; Is the DMA channel 16bit?
        jb      fwd16a                  ; Skip 16bit channel code if not.
        mov     dx, 0D8h                ; Use the second DMA controller.
fwd16a: xor     al, al                  ; Clear the byte ptr flip-flop.
        out     dx, al

        movzx   dx, BPtr [esi+DBufChannel];Fetch the number of the DMA channel.
        add     dx, dx                  ; Calculate the address of the word
        inc     dx                      ; count port.
        cmp     BPtr [esi+DBufChannel],4; Is the DMA channel 16bit?
        jb      ReadCnt                 ; Skip 16bit channel code if not.
        add     dx, 0C1h                ; Use the second DMA controller.
ReadCnt:xor     eax, eax                ; Clear EAX.
        xor     ebx, ebx                ; Clear EBX.
        in      al, dx                  ; Get the first DMA count.
        mov     bl, al                  ; Store the low byte.
        in      al, dx                  ; Get the high byte.
        mov     bh, al                  ; Store the low byte.
        in      al, dx                  ; Get the second DMA count.
        mov     ah, al                  ; Store the low byte.
        in      al, dx                  ; Get the high byte.
        rol     ax, 8                   ; Swap the bytes.

        sub     ebx, eax                ; Calculate the difference between the
        cmp     ebx, 4                  ; two values; discard the values
        jg      ReadCnt                 ; if the difference is greater than 4.
        cmp     ebx, -4
        jl      ReadCnt

        cmp     BPtr [esi+DBufChannel], 04h; Is the DMA channel 16bit?
        jb      fwd16c                  ; Skip 16bit channel code if not.
        add     eax, eax                ; Calculate the byte count.
fwd16c: neg     eax                     ; Subtract DMA count from the buffer
        add     eax, [esi+DBufLength]   ; length.
        sti
        ret

DMA_GetPosition EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Code32          EndS

		End
