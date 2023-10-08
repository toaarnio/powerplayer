TITLE SB.ASM - EMF PM Sound System - SB Series Soundcard Driver v0.2 18.12.94
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ

        Uses_Timer = 1
        Uses_RasterMeter = 1
	INCLUDE stdrouts.hdr

Code32		Segment Para Public Use32
	ASSUME	CS:Code32,DS:Code32

	INCLUDE pmode.inc

;ÕÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÑ¸
;³³				    D A T A				      ³³
;ÔÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÏ¾

        INCLUDE callspec.hdr
        INCLUDE gmd.hdr
        INCLUDE dma.hdr
        INCLUDE debug.inc

SB_FunctionPtr	DD	0
TESTI           DW      0

;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ

SB_DMAInfo      DB      DMAInfoLen DUP (0)

OldDosSBIrq	DD	0
OldPmSBIrq	DD	0
SBIRQStub	DB	21 DUP (0)

;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ

SB_Inited	DB	'Sound Blaster (DSP version '
SIDSPHi 	DB	'00.'
SIDSPLo 	DB	'00) initialized at '
SIBase		DB	'0000h, IRQ '
SIIRQ		DB	'00h and DMA '
SIDMA		DB	'00h.',13,10,'$'

;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ

SBDriverInfo    Label   Dword           ; The public driver info block.
SB_PlayModes    DB      00000010b       ; Playing modes: callplay only.
SB_OutputModes  DB      00000001b       ; Output modes: 8bit mono only.
SB_LoadModes    DB      00000001b       ; Loading modes: memload only.
                DB      0               ; Reserved byte.
SB_BaseAddr     DD      0               ; SB base port address.
SB_DMA          DD      0               ; SB DMA channel number.
SB_IRQ          DD      0               ; SB IRQ number.
SB_OutputFreq   DD      0               ; SB output frequency.
SB_PollFreq     DD      0               ; SB mixer polling rate.
SB_DSPVersion   DD      0               ; SB DSP version number.

;ÕÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÑ¸
;³³				    C O D E				      ³³
;ÔÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÏ¾

Public	SBDriver

SBDriver	Proc	Near

	pushad
	mov	SB_FunctionPtr, ebx
;        call    DetectBase
;        jc      SB_InitError
        xor     edx, edx
        mov     dx, [esi+4]
        mov     SB_BaseAddr, edx
        xor     eax, eax
        mov     al, [esi+12]
        mov     SB_DMA, eax
        mov     al, [esi+8]
        mov     SB_IRQ, eax
        mov     eax, [esi+16]
        mov     SB_OutputFreq, eax
        mov     SB_PollFreq, 70
        call    GetDSPVersion
        movzx   ebx, bx
        mov     SB_DSPVersion, ebx
        cmp     ebx, 300h
        jb      IsOk
        cmp     DPtr [esi], 2
        jne     IsOk
        mov     SB_DSPVersion, 201h
IsOk:   mov     ebx, SB_FunctionPtr
        mov     DPtr [ebx+Sd_Reset], Offset Gmd_Reset
	mov	DPtr [ebx+Sd_GetInfo], Offset SB_GetInfo
	mov	DPtr [ebx+Sd_AllocChan], Offset Gmd_AllocChan
	mov	DPtr [ebx+Sd_RegMemSmpl], Offset Gmd_RegMemSmpl
	mov	DPtr [ebx+Sd_ChunkLoad], Offset Gmd_ChunkLoad
	mov	DPtr [ebx+Sd_SetSample], Offset Gmd_SetSample
	mov	DPtr [ebx+Sd_StopSample], Offset Gmd_StopSample
	mov	DPtr [ebx+Sd_SetVolume], Offset Gmd_SetVolume
	mov	DPtr [ebx+Sd_SetBalance], Offset Gmd_SetBalance
	mov	DPtr [ebx+Sd_SetFreq], Offset Gmd_SetFreq
        mov     DPtr [ebx+Sd_SetMastVol], Offset Gmd_SetMastVol
	mov	DPtr [ebx+Sd_DeInit], Offset SB_DeInit
	mov	DPtr [ebx+Sd_TmrReset], Offset Gmd_TmrReset
	mov	DPtr [ebx+Sd_TmrReqCall], Offset Gmd_TmrReqCall
	mov	DPtr [ebx+Sd_TmrDeInit], Offset Gmd_TmrDeInit
	or	DPtr [ebx+DrvInited], 01h

        call    SBInit

        mov     eax, SB_DSPVersion
	call	BToH
	mov	WPtr SIDSPLo, ax
        mov     eax, SB_DSPVersion
	shr	eax, 8
	call	BToH
	mov	WPtr SIDSPHi, ax

        mov     ebx, SB_BaseAddr
	lea	edi, SIBase
	call	PrintW
        mov     eax, SB_IRQ
	call	BToH
	mov	WPtr SIIRQ, ax
        mov     eax, SB_DMA
	call	BToH
	mov	WPtr SIDMA, ax
        Print   SB_Inited
	popad
	clc
	ret

SB_InitError:
	popad
	stc
	ret

SBDriver	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
CheckCmdStatus	MACRO			; This one checks the 'SB ready' bit.
		Local	bwd

bwd:	in	al, dx			; Fetch the cmd port's contents.
	add	al, al			; Is the highest bit on?
	jc	bwd			; Wait until it's off.

		ENDM
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
SBInit          Proc    Near

        ; Reset the SoundBlaster DSP

        call    SBDSPReset

        ; Compute & output the TIME_CONSTANT to the DSP

        call    SetXferSpeed

        ; Allocate & clear the DMA buffer

	mov	eax, SB_OutputFreq
	xor	edx, edx
	mov	ecx, SB_PollFreq
        idiv    ecx                     ; EAX = number of bytes to mix/frame.
        imul    eax, 4                  ; Create a buffer for 4 frames.
        cmp     SB_DSPVersion, 0300h    ; Stereo available?
        jb      MonoBuf
        add     eax, eax                ; If stereo, then buflen=buflen*2.
MonoBuf:lea     esi, SB_DMAInfo
	mov	[esi+DBufLength], eax
	call	DMA_AllocBuf
	lea	esi, SB_DMAInfo
	mov	edi, [esi+DBufAddress]
	mov	ecx, [esi+DBufLength]
	mov	al, 128
        rep     stosb                   ; Fill the buffer with 80h.

        ; Initialize the General Mixer Device

	mov	eax, SB_OutputFreq
	lea	esi, SB_DMAInfo
	mov	edi, [esi+DBufAddress]
	mov	ecx, [esi+DBufLength]
        xor     bl, bl
        cmp     SB_DSPVersion, 0300h    ; Is stereo available?
        jna     NoSBP                   ; Skip if no SB Pro.
        mov     bl, 1                   ; Set stereo mode on.
        shr     ecx, 1                  ; Buffer length = number of words.
NoSBP:  call    Gmd_Init                ; Initialize the mixer device.

	; Set the SB IRQ handler

        call    GetIrq                  ; Hook & unmask the SoundBlaster IRQ.

	; Start playing the DMA buffer

	lea	esi, SB_DMAInfo
        mov     eax, SB_DMA
	mov	[esi+DBufChannel], al
        mov     BPtr [esi+DBufDirection], 0
        mov     BPtr [esi+DBufAutoLoop], 1
        call    DMA_Play

        ; Program the SB to start playing

        mov     ecx, [esi+DBufLength]
        dec     ecx
        cmp     SB_DSPVersion, 0200h
        jae     AutoI
        call    SBStartMonoS8
        jmp     fwd3
AutoI:  cmp     SB_DSPVersion, 0201h
        jae     HiSpeed
        call    SBStartMonoL8
        jmp     fwd3
HiSpeed:cmp     SB_DSPVersion, 0300h
        ja      Stereo
        cmp     SB_OutputFreq, 22000
        ja      HiSp
        call    SBStartMonoL8
        jmp     fwd3
Hisp:   call    SBStartMonoHL8
        jmp     fwd3
Stereo: call    SBStartStereoL8

fwd3:
	lea	eax, SBMixer
        mov     MixerFunc, eax
	ret

SBInit          EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
SBDSPReset      Proc    Near

        mov     edx, SB_BaseAddr
	mov	al, 1			; Set AL = The first init code.
        add     dx, 6                   ; Point the DSP reset port.
	out	dx, al			; Send the first reset code.
        mov     ecx, 10000              ; Set the delay count to 5000.
	loop	$			; Give some time for the DSP.
	dec	al			; Clear the AL.
	out	dx, al			; Send the second reset code.
        mov     ecx, 10000              ; Set the delay count to 5000.
	loop	$			; Give some time for the DSP.

	add	dx, 8			; Point the SB status port.
        mov     ecx, 10000
wd1:    in      al, dx
	add	al, al			; Is the highest bit on?
        jc      ok1                     ; Ready to go if it is.
        loop    wd1                     ; Otherwise loop and wait.
ok1:
        mov     ecx, 10000
        sub     dx, 4                   ; Point the SB read data port.
wd2:    in      al, dx                  ; Fetch a byte from it.
        cmp     al, 0AAh
        je      ok2
        loop    wd2
ok2:
	add	dx, 2			; Point the SB command port.
	CheckCmdStatus			; Wait until the DSP is ready.
	ret

SBDSPReset      EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
SetXferSpeed    Proc    Near

        mov     edx, SB_BaseAddr        ; Prepare to send the TIME_CONSTANT,
        add     dx, 0Ch                 ; ie. the transfer speed to the DSP.
        CheckCmdStatus
        mov     al, 40h
        out     dx, al

WhichBlaster:
        xor     ebp, ebp                ; Default = no stereo output.
        mov     ebx, SB_OutputFreq      ; Get the user-specified output freq.
        mov     cl, 210                 ; Maximum time constant for DSP ó 2.00.
        cmp     SB_DSPVersion, 0201h    ; Is high speed output available?
        jb      OldBlaster              ; Skip if we have a really old SB.
        mov     cl, 233                 ; Maximum time constant for DSP > 2.00.
        cmp     SB_DSPVersion, 0300h    ; Is stereo output available?
        jb      OldBlaster              ; Skip if we only have a plain SB.
        add     ebx, ebx                ; Stereo output; double frequency.
        mov     ebp, 1                  ; Indicate stereo output.

OldBlaster:
        mov     eax, 1000000            ; TIME_CONSTANT = 256-(10^6/PlayFreq)
        xor     edx, edx
        div     ebx
        neg     ax
        cmp     al, cl
        jbe     fwd1
        mov     al, cl
fwd1:   mov     ebx, eax
        mov     edx, SB_BaseAddr
        add     dx, 0Ch
        CheckCmdStatus
        mov     al, bl
	out	dx, al			; Send the output speed byte.
        neg     bx
        mov     eax, 1000000
	xor	edx, edx
        div     ebx
        mov     ecx, ebp                ; Now CL=1 if stereo, CL=0 if mono.
        shr     eax, cl                 ; Divide by two if stereo output.
        mov     SB_OutputFreq, eax      ; Store the actual playing frequency.
        ret

SetXferSpeed    EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
GetIrq          Proc    Near

        mov     ebx, SB_IRQ             ; Mask the EODMA IRQ.
	call	_GetIrqVect
	mov	OldPmSBIrq, edx

        lea     edx, SBSingleModeIRQ    ; Single mode available on all
        cmp     SB_DSPVersion, 0200h    ; DSP versions.
        jb      SetIRQ                  ; Autoinit only on version 2.00
        lea     edx, SBAutoInitIRQ      ; and above.
SetIRQ: mov     ebx, SB_IRQ
        call    _SetIrqVect
        lea     edi, SBIrqStub
        call    _RmPmIrqSet
	mov	OldDosSBIrq, eax

        mov     ebx, SB_IRQ             ; Unmask the IRQ.
	mov	al, 0
        call    _SetIrqMask
        ret

GetIrq          EndP
;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º Soundsys Function ID: Sd_GetInfo					       º
;º									       º
;º FUNCTION:	Returns a pointer to the soundcard info block.		       º
;º PARAMETERS:	None.							       º
;º RETURNS:	EAX --> The requested info block.			       º
;º		CF set on error, EAX --> Error message. 		       º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
SB_GetInfo	Proc	Near

	lea	eax, SBDriverInfo
	clc
	ret

SB_GetInfo	EndP
;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º Soundsys Function ID: Sd_DeInit					       º
;º									       º
;º FUNCTION:	Deinitializes the sound card.				       º
;º PARAMETERS:	None.							       º
;º RETURNS:	CF set on error, EAX --> Error message. 		       º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
SB_DeInit	Proc	Near

	pushad

        call    SBDSPReset              ; Reset the SB DSP.

        lea     esi, SB_DMAInfo
	call	DMA_Stop

        mov     edx, SB_BaseAddr        ; Fetch the card's base address.
	add	dx, 0Ch 		; Point the card's command port.
	mov	al, 0D3h		; Turn the speaker off.
	out	dx, al

        mov     ebx, SB_IRQ
	mov	al, 1
	call	_SetIrqMask
        mov     ebx, SB_IRQ
	mov	edx, OldPmSBIrq
	call	_SetIrqVect
        mov     ebx, SB_IRQ
	mov	eax, OldDosSBIrq
	call	_RmPmIrqFree

	call	Gmd_DeInit

        lea     esi, SB_DMAInfo
        call    DMA_FreeBuf

	popad
	clc
	ret

SB_DeInit	EndP
;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º RETURNS:	DX = port address (CF set if not found).		       º
;º FUNCTION:	Detects the SoundBlaster base IO-port address.		       º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
DetectBase	Proc   Near

	mov	bx, 210h		; BX = The first base addr.
TestNextAddr:
	mov	dx, bx			; DX = The current SB base addr.
	add	dl, 0Ch 		; Point the write status port.
	mov	ah, 0D3h		; AH = Speaker off code.
	mov	ecx, 200h		; Wait 200 times.
Wait1:	in	al, dx			; Get a byte from the status port.
	or	al, al			; Set flags.
	jns	Ready1			; Jump if buffer ready (bit 7 = 0).
	loop	Wait1			; Try again.
	jmp	SBNext			; No response - try the next address.
Ready1: mov	al, ah			; AL = Turn speaker off code.
	out	dx, al			; Send the code.
	mov	ecx, 0FFFFh		; Wait a moment (DSP is s-l-o-w).
	loop	$
	sub	dl, 0Ch-06h		; Point the DSP reset port.
	mov	al, 01h 		; AL = The first reset code.
	out	dx, al			; Send the code.
	mov	ecx, 0FFFFh		; Wait a moment (DSP is s-l-o-w).
	loop	$
	xor	al, al			; Clear the AL.
	out	dx, al			; Send the second reset code.
	mov	ecx, 10h		; Test 10 times.
	add	dl, 0Eh-06h		; Point the data waiting status port.
TestLp: push	ecx			; Save the CX register.
	mov	ecx, 200h		; Test 200 times.
Wait2:	in	al, dx			; Get the status byte.
	or	al, al			; Set flags.
	js	Ready2			; Jump if data waiting (bit 7 = 1).
	loop	Wait2			; Try again.
	jmp	SBNext			; No response - try the next address.
Ready2: sub	dl, 0Eh-0Ah		; Point the ADC data port.
	in	al, dx			; Get the data byte.
	pop	ecx			; Restore the CX register.
	add	dl, 0Eh-0Ah		; Point to data waiting status port.
	cmp	al, 0AAh		; Is the byte 0AAh?
	je	SBFound 		; Yes, this is the right address!
	loop	TestLp			; No, try again.
SBNext: add	bx, 10h 		; BX = The next base addr.
	cmp	bx, 260h		; Have all addresses been tested?
	jbe	TestNextAddr		; No, go and test the next one.
	stc
	ret				; ...just in case...
SBFound:
	mov	dx, bx			; Return the port addr. in DX.
	clc
	ret

DetectBase	EndP
;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º FUNCTION:	This routine sets the SB Pro into Stereo mode.		       º
;º PARAMETERS:  BL = Filter mode: 0 - no change, 1 - on, 2 - off.              º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
SetStereo	Proc	Near

        mov     edx, SB_BaseAddr        ; Fetch the SBPro's base I/O addr.
	add	dx, 04h 		; Point to SBPro mixer command reg.
	mov	al, 0Eh 		; Request stereo/filter enable.
	out	dx, al			; Send the request.
	inc	dx			; Point to SBPro mixer data reg.
	in	al, dx			; Read the current value.
	or	al, 02h 		; Put to stereo mode.
        cmp     bl, 1                   ; Should we set the filter on?
	je	FilterOn		; If yes, go send the command byte.
        cmp     bl, 2                   ; Let's see if we should put it off.
	je	FilterOff		; If yes, then go put the filter off.
        out     dx, al
	ret				; No filter status change; return.
FilterOn:
	and	al, not 20h		; Assume option 1, put filter on.
	out	dx, al			; Send the new mode byte.
	ret				; Return.
FilterOff:
	or	al, 20h 		; Put filter off.
	out	dx, al			; Send the new mode byte.
	ret				; Return.

SetStereo	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
GetDSPVersion   Proc    Near

        mov     edx, SB_BaseAddr        ; Fetch the card's base address.
	add	dx, 0Ch 		; Point the card's command port.
	mov	al, 0E1h		; Get DSP version number.
	out	dx, al

        mov     edx, SB_BaseAddr        ; Fetch the card's base address.
	add	dx, 0Eh 		; Point the Data Available port.
	mov	ecx, 0FFFFh		; Wait until bit 7 is set.
bw1:    in      al, dx
	test	al, al
        js      fwd4
        loop    bw1
fwd4:   sub     dx, 04h                 ; Point the DSP Data port.
	in	al, dx
	mov	bh, al
        mov     edx, SB_BaseAddr        ; Fetch the card's base address.
	add	dx, 0Eh 		; Point the Data Available port.
	mov	ecx, 0FFFFh		; Wait until bit 7 is set.
bw2:    in      al, dx
	test	al, al
        js      fwd5
        loop    bw2
fwd5:   sub     dx, 04h                 ; Point the DSP Data port.
	in	al, dx
	mov	bl, al
	ret

GetDSPVersion	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
SBStartMonoS8   Proc    Near            ; Mono, 8-bit, low-speed, non-autoinit.

        mov     edx, SB_BaseAddr        ; Turn the speaker on.
        add     dx, 0Ch
        CheckCmdStatus
        mov     al, 0D1h
        out     dx, al

        CheckCmdStatus
        mov     al, 14h                 ; Send the byte count to the DSP.
        out     dx, al                  ; (14h = non-autoinit mode, DSPó2.00)
        CheckCmdStatus
        mov     al, cl
        out     dx, al
        CheckCmdStatus
        mov     al, ch
        out     dx, al
        ret

SBStartMonoS8   EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
SBStartMonoL8   Proc    Near            ; Mono, 8-bit, low-speed, autoinit.

        mov     edx, SB_BaseAddr        ; Turn the speaker on.
        add     dx, 0Ch
        CheckCmdStatus
        mov     al, 0D1h
	out	dx, al

        CheckCmdStatus
        mov     al, 48h                 ; Send the byte count to the DSP.
        out     dx, al                  ; (48h = autoinit mode, DSP>2.00)
        CheckCmdStatus
        mov     al, cl
        out     dx, al
        CheckCmdStatus
        mov     al, ch
        out     dx, al

        CheckCmdStatus
        mov     al, 1Ch                 ; Normal speed DMA request.
	out	dx, al
	ret

SBStartMonoL8   EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
SBStartMonoHL8  Proc    Near            ; Mono, 8-bit, high-speed, autoinit.

        mov     edx, SB_BaseAddr        ; Turn the speaker on.
        add     dx, 0Ch
        CheckCmdStatus
        mov     al, 0D1h
	out	dx, al

        CheckCmdStatus
        mov     al, 48h                 ; Send the byte count to the DSP.
        out     dx, al                  ; (48h = autoinit mode)
        CheckCmdStatus
        mov     al, cl
        out     dx, al
        CheckCmdStatus
        mov     al, ch
        out     dx, al

        CheckCmdStatus
        mov     al, 90h                 ; High-speed DMA request.
	out	dx, al
	ret

SBStartMonoHL8  EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
SBStartStereoL8 Proc    Near            ; Stereo, 8-bit, low-speed, autoinit.

        xor     bl, bl                  ; Enable stereo output.
        call    SetStereo

        mov     edx, SB_BaseAddr        ; Turn the speaker on.
        add     dx, 0Ch
        CheckCmdStatus
        mov     al, 0D1h
	out	dx, al

        CheckCmdStatus
        mov     al, 48h                 ; Send the byte count to the DSP.
        out     dx, al                  ; (48h = autoinit mode)
        CheckCmdStatus
        mov     al, cl
        out     dx, al
        CheckCmdStatus
        mov     al, ch
        out     dx, al

        CheckCmdStatus
        mov     al, 90h                 ; Request to begin High-speed DMA.
        out     dx, al
	ret

SBStartStereoL8 EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
SBAutoInitIRQ	Proc	Near

	sti
        push    ds
	push	eax
        push    edx
	mov	ds, cs:_SelData
        mov     edx, SB_BaseAddr
        add     edx, 0Eh
	in	al, dx			; Acknowledge the card's IRQ.
        cmp     SB_IRQ, 7
        ja      PIC2
	mov	al, 20h
	out	20h, al
	jmp	EOI
PIC2:   mov     al, 20h
	out	0A0h, al
EOI:    pop     edx
	pop	eax
        pop     ds
	iretd

SBAutoInitIRQ	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
SBSingleModeIRQ Proc    Near

        sti
        push    ds
        push    eax
        push    ebx
        push    edx
        mov     ds, cs:_SelData
        mov     edx, SB_BaseAddr
        add     edx, 0Eh
	in	al, dx			; Acknowledge the card's IRQ.

        lea     ebx, SB_DMAInfo         ; Send the byte count to the DSP.
        mov     ebx, [ebx+DBufLength]
        dec     ebx
        mov     edx, SB_BaseAddr
        add     edx, 0Ch
        CheckCmdStatus
        mov     al, 14h
        out     dx, al
        CheckCmdStatus
        mov     al, bl
        out     dx, al
        CheckCmdStatus
        mov     al, bh
        out     dx, al

        mov     al, 20h
        out     20h, al
        pop     edx
        pop     ebx
        pop     eax
        pop     ds
        iretd

SBSingleModeIRQ EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
SBMixer 	Proc	Near

        push    es
        mov     es, cs:_SelData
        lea     esi, SB_DMAInfo
        call    DMA_GetPosition
        mov     edi, eax
        call    Gmd_Mixer               ; EDI = DMA playing position
        pop     es
        ret

SBMixer 	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Code32		EndS

		End
