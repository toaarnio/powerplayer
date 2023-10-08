TITLE GUS.ASM - EMF PM Sound System - GUS Soundcard Driver v0.15 by Saint
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ

        .386P

        Uses_Timer = 1                  ; Include timer stuff.
	Uses_Kbd   = 1			; Include keyboard stuff.
	Uses_ExcHandling = 1		; Include the exception handler.
        Uses_DataFileRead = 1
        Uses_Debug=1

        Uses_RasterMeter=1

;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ

        INCLUDE callspec.hdr
        INCLUDE stdrouts.hdr
        INCLUDE debug.inc

Code32  Segment Para Public Use32
	ASSUME	CS:Code32,DS:Code32

	INCLUDE pmode.inc

;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º				    C O D E				       º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
Public  GusDriver

MidiIRQ         EQU     12
RecDMA          EQU     5

;ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
;³GUS's GF1 register definitions

VoiceCtrlReg	EQU	00h		; Voice specific registers
FrequencyReg	EQU	01h
StartAddrHiReg	EQU	02h
StartAddrLoReg	EQU	03h
EndAddrHiReg	EQU	04h
EndAddrLoReg	EQU	05h
VolRampRateReg	EQU	06h
VolRampStartReg EQU	07h
VolRampEndReg	EQU	08h
CurVolReg	EQU	09h
CurLocHiReg	EQU	0Ah
CurLocLoReg	EQU	0Bh
PanPosReg	EQU	0Ch
VolRampCtrlReg	EQU	0Dh
ActiveVoicesReg EQU	0Eh
IRQSourceReg_R	EQU	8Fh
RegRead 	EQU	80h

DramDMACtrlReg	EQU	41h		; Global registers
DMAStartAddrReg EQU	42h
DramIOAddrLoReg EQU	43h
DramIOAddrHiReg EQU	44h
TimerCtrlReg	EQU	45h
SamplingCtrlReg EQU	49h
ResetReg	EQU	4Ch

;ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
;³GUS's port address definitions (base + )

VoiceSelectPort EQU	102h
CommandPort	EQU	103h
DataPort	EQU	104h
DataHiPort	EQU	105h
DramIOPort	EQU	107h
MixCrtlPort	EQU	000h
IRQStatusPort	EQU	006h
IRQControlPort  EQU     00Bh

;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
OutGUS		MACRO	Index, Data

	push	eax
        mov     edx, BaseAddr
	add	edx, CommandPort
	mov	al, Index
	out	dx, al
	inc	edx
	pop	eax
	mov	ax, Data
	out	dx, ax

		ENDM
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
OutGUSb 	MACRO	Index, Data

	push	eax
        mov     edx, BaseAddr
	add	edx, CommandPort
	mov	al, Index
	out	dx, al
	add	edx, 2
	pop	eax
	mov	al, Data
	out	dx, al

		ENDM
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
InGUSb		MACRO	Index

        mov     edx, BaseAddr
	add	edx, CommandPort
	mov	al, Index
	out	dx, al
	add	edx, 2
	in	al, dx

		ENDM
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
VSelect 	MACRO	Voice

        mov     edx, BaseAddr
	add	edx, VoiceSelectPort
	mov	al, Voice
	out	dx, al

		ENDM
;ÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ
GusDriver	Proc	Near

	pushad
	mov	GUS_FunctionPtr, ebx
	call	GetGUSAddresses
	mov	ebx, GUS_FunctionPtr
	mov	DPtr [ebx+Sd_Reset], Offset GUS_Reset
	mov	DPtr [ebx+Sd_GetInfo], Offset GUS_GetInfo
	mov	DPtr [ebx+Sd_AllocChan], Offset GUS_AllocChan
	mov	DPtr [ebx+Sd_RegMemSmpl], Offset GUS_RegMemSmpl
        mov     DPtr [ebx+Sd_ChunkLoad], Offset GUS_ChunkLoad
	mov	DPtr [ebx+Sd_SetSample], Offset GUS_SetSample
	mov	DPtr [ebx+Sd_SetVolume], Offset GUS_SetVolume
	mov	DPtr [ebx+Sd_SetBalance], Offset GUS_SetBalance
        mov     DPtr [ebx+Sd_SetFreq], Offset GUS_SetFreq
        mov     DPtr [ebx+Sd_SetMastVol], Offset GUS_SetMastVol
        mov     DPtr [ebx+Sd_StopSample], Offset GUS_StopSample

	mov	DPtr [ebx+Sd_DeInit], Offset GUS_Reset
        mov     DPtr [ebx+Sd_TmrReset], Offset GUS_TmrReset
        mov     DPtr [ebx+Sd_TmrReqCall], Offset GUS_TmrReqCall
        mov     DPtr [ebx+Sd_TmrDeInit], Offset GUS_TmrDeInit

        push    ebx

        mov     bl, BPtr GF1Irq
	call	_GetIrqVect
	mov	OldPmGUSIrq, edx

        mov     bl, BPtr GF1Irq
        lea     edx, GusTimerIRQ
	call	_SetIrqVect
	lea	edi, GusIrqStub
	call	_RmPmIrqSet
	mov	OldDosGUSIrq, eax

        mov     bl, BPtr GF1Irq
	mov	al, 0
        call    _SetIrqMask

        pop     ebx

        mov     ChansAllocated, 1
	mov	ChansUsed, 14
	or	DPtr [ebx+DrvInited], 01h

        mov     ebx, BaseAddr
	lea	edi, GIBase
	call	PrintW
        mov     eax, GF1Irq
	call	BToH
	mov	WPtr GIIrq, ax
        mov     eax, DMAOut
	call	BToH
	mov	WPtr GIDma, ax
	Print	GUS_Inited
	clc
	popad
	ret

GUS_InitError:
	stc
	popad
	ret

GusDriver	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
GetGUSAddresses Proc	Near

        mov     eax, [esi+4]
        mov     BaseAddr, eax
        mov     eax, [esi+8]
        mov     GF1Irq, eax
        mov     eax, [esi+12]
        mov     DMAOut, eax
	ret

GetGUSAddresses EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
ScanNum 	Proc	Near

NoNumLoop:
	mov	al, [edi]
	cmp	al, 30h
	jb	NoNumFound
	cmp	al, 39h
	ja	NoNumFound
	inc	edi
	loop	NoNumLoop

NoNumFound:
	mov	al, [edi]
	cmp	al, 30h
	jb	NoNumFound2
	cmp	al, 39h
	ja	NoNumFound2
	ret
NoNumFound2:
	inc	edi
	loop	NoNumFound
	ret

ScanNum 	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
GUS_Reset       Proc    Near

        pushad
        mov     edx, BaseAddr
        mov     al, 00001011b
        out     dx, al
        out     dx, al

        xor     ebx, ebx
        mov     bl, MidiIRQ
        mov     cl, GUSChangeIRQ[ebx]
        shl     cl, 3
        mov     ebx, GF1Irq
        or      cl, GusChangeIRQ[ebx]
        cmp     bl, MidiIRQ
        jne     IrqDone
        and     cl, 7
        or      cl, 40h

IrqDone:
        push    ecx
        mov     ebx, DMAOut
        mov     cl, GUSChangeDMA[ebx]
        or      cl, 40h
        mov     bl, cl
        pop     ecx

        mov     edx, BaseAddr
        mov     al, 00001011b
        out     dx, al
        add     edx, IrqControlPort
        mov     al, bl
        or      al, 80h
        out     dx, al
        sub     edx, IrqControlPort
        mov     al, 01001011b
        out     dx, al
        add     edx, IrqControlPort
        mov     al, cl
        out     dx, al

        mov     edx, BaseAddr
        mov     al, 00001011b
        out     dx, al
        add     edx, IrqControlPort
        mov     al, bl
        out     dx, al
        sub     edx, IrqControlPort
        mov     al, 01001011b
        out     dx, al
        add     edx, IrqControlPort
        mov     al, cl
        out     dx, al

        VSelect 0
        mov     edx, BaseAddr
        mov     al, 00001000b
        out     dx, al
        VSelect 0

        OutGUSb ResetReg, 0
        mov     edx, BaseAddr
        REPT    16
	in	al, dx
	ENDM
	OutGUSb ResetReg, 1
        mov     edx, BaseAddr
        REPT    16
	in	al, dx
	ENDM
	OutGUSb DramDMACtrlReg, 0
	OutGUSb TimerCtrlReg, 0
	OutGUSb SamplingCtrlReg, 0

        mov     edx, BaseAddr
	add	edx, IRQStatusPort
	in	al, dx
	InGUSb	DramDMACtrlReg
	InGUSb	SamplingCtrlReg
	InGUSb	IRQSourceReg_R

	mov	ecx, 32
VoiceClearLoop:
	dec	ecx
	VSelect cl
	OutGUSb VoiceCtrlReg, 3
	OutGUSb VolRampCtrlReg, 3
	OutGUSb VolRampRateReg, 3Fh
	OutGUS	CurVolReg, 0h
	or	ecx, ecx
	jnz	VoiceClearLoop

        InGUSb  DramDMACtrlReg
	InGUSb	SamplingCtrlReg
	InGUSb	IRQSourceReg_R
        OutGUSb ResetReg, 7

        mov     edx, BaseAddr
        mov     al, 09h
	out	dx, al

	mov	MasterVol, 255
	mov	ChansUsed, 14
        mov     ChansAllocated, 1
	mov	SamplesUsed, 0
	mov	SampleBase, 20h

	popad
	clc
	ret

GUS_Reset	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
GUS_AllocChan	Proc	Near

	inc	ChansAllocated
	mov	eax, ChansAllocated
	pushad
        cmp     eax, 14
	jae	ChUsedOk
        mov     eax, 14
ChUsedOk:
	mov	ChansUsed, eax
	mov	ebx, eax
        dec     al
	or	al, 0C0h
	OutGUSb ActiveVoicesReg, al
	mov	eax, GUS_Rates[ebx*4-14*4]
        mov     SampleRate, eax
	popad
	clc
	ret

GUS_AllocChan	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
GUS_RegMemSmpl	Proc	Near

	Print	GUS_Error
	stc
	ret

GUS_RegMemSmpl	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
GUS_ChunkLoad	Proc	Near

	pushad
	mov	GUS_GetChunkPtr, edx
	mov	ebx, eax
	mov	eax, SamplesUsed
	imul	edi, eax, SIBLen
	lea	edi, SampleData[edi]
	mov	eax, [ebx+SmplLen]
	mov	[edi+SmplLen], eax
	mov	eax, [ebx+SmplRepeatFrom]
	mov	[edi+SmplRepeatFrom], eax
	mov	eax, [ebx+SmplRepeatTo]
	mov	[edi+SmplRepeatTo], eax
	mov	eax, [ebx+SmplFlags]
	mov	[edi+SmplFlags], eax
	mov	eax, SampleBase

        push    ecx
        mov     ecx, 4
BegClearLoop:
        push    eax
        OutGUS  DramIOAddrLoReg, ax
        shr     eax, 16
        OutGUSb DramIOAddrHiReg, al
        mov     edx, BaseAddr
        add     edx, DramIOPort
        xor     al, al
        out     dx, al
        pop     eax
        inc     eax
        dec     ecx
        jnz     BegClearLoop
        pop     ecx
        mov     [edi+SmplOfs], eax
                            
	mov	ebx, [edi+SmplLen]
	push	edi
        mov     edi, [edi+SmplOfs]
WhileSomeToUpload:
	or	ebx, ebx
	jz	SampleLoaded
	cmp	ebx, ecx
	jnb	LenOk
	mov	ecx, ebx
LenOk:  call    [GUS_GetChunkPtr]

	push	ecx
	push	esi
UploadLoop:
	mov	eax, edi
	OutGUS	DramIOAddrLoReg, ax
	shr	eax, 16
	OutGUSb DramIOAddrHiReg, al
        mov     edx, BaseAddr
	add	edx, DramIOPort
	mov	al, [esi]
	out	dx, al
	inc	esi
	inc	edi
	loop	UploadLoop
	pop	esi
	pop	ecx
	sub	ebx, ecx
	jmp	WhileSomeToUpload

        mov     ecx, 4
EndClearLoop:
        mov     eax, edi
        OutGUS  DramIOAddrLoReg, ax
        shr     eax, 16
        OutGUSb DramIOAddrHiReg, al
        mov     edx, BaseAddr
        add     edx, DramIOPort
        mov     al, 0
        out     dx, al
        inc     edi
        dec     ecx
        jnz     EndClearLoop

SampleLoaded:
	pop	edi
	mov	eax, [edi+SmplLen]
        add     eax, 8
	test	eax, 01Fh
	jz	NoFix
	add	eax, 32
	and	eax, 0FFFFFFE0h
NoFix:	add	SampleBase, eax
	popad
	mov	eax, SamplesUsed
	inc	SamplesUsed
	clc
	ret

GUS_ChunkLoad	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
IFDEF DebugGUS
SetSmplMsg	DB	'GUS_SetSample: Channel '
SSchan		DB	'00000000  Sample '
SSsmpl		DB	'00000000  Sample Offset '
SSofs		DB	'00000000.',13,10,'$'
ENDIF
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
GUS_SetSample	Proc	Near

	pushad

IFDEF DebugGUS
	pushad
	mov	ebx, eax
	lea	edi, SSchan
	call	PrintD
	mov	ebx, edx
	lea	edi, SSsmpl
	call	PrintD
	mov	ebx, esi
	lea	edi, SSofs
	call	PrintD
	Print	SetSmplMsg
	popad
ENDIF

	imul	edi, edx, SIBLen
	lea	edi, SampleData[edi]

	VSelect al
	OutGUSb VoiceCtrlReg, 03h
	mov	eax, [edi+SmplOfs]
	add	eax, esi
	shl	eax, 9
	OutGUS	CurLocLoReg, ax
	rol	eax, 16
	OutGUS	CurLocHiReg, ax
	test	BPtr [edi+SmplFlags], 01h
	jnz	IsRepeating

	rol	eax, 16
	OutGUS	StartAddrLoReg, ax
	rol	eax, 16
	OutGUS	StartAddrHiReg, ax
	mov	eax, [edi+SmplOfs]
	add	eax, [edi+SmplLen]
;        dec     eax
	shl	eax, 9
	OutGUS	EndAddrLoReg, ax
	shr	eax, 16
	OutGUS	EndAddrHiReg, ax
	OutGUSb VoiceCtrlReg, 00h
	popad
	clc
	ret

IsRepeating:
	mov	eax, [edi+SmplOfs]
	add	eax, [edi+SmplRepeatFrom]
	shl	eax, 9
	OutGUS	StartAddrLoReg, ax
	shr	eax, 16
	OutGUS	StartAddrHiReg, ax
	mov	eax, [edi+SmplOfs]
	add	eax, [edi+SmplRepeatTo]
;        dec     eax
	shl	eax, 9
	OutGUS	EndAddrLoReg, ax
	shr	eax, 16
	OutGUS	EndAddrHiReg, ax
	OutGUSb VoiceCtrlReg, 08h
	popad
	clc
	ret

GUS_SetSample	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
GUS_StopSample  Proc    Near

        pushad
        VSelect al
        OutGusB VoiceCtrlReg, 03h
        OutGus  CurVolReg, 0
        popad
        clc
        ret

GUS_StopSample  EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
IFDEF DebugGUS
SetVolMsg	DB	'GUS_SetVolume: Channel '
SVchan		DB	'00000000  Vol '
SVvol		DB	'00000000.',13,10,'$'
ENDIF
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
GUS_SetVolume	Proc	Near

	pushad

IFDEF DebugGUS
	pushad
	mov	ebx, eax
	lea	edi, SVchan
	call	PrintD
	mov	ebx, edx
	lea	edi, SVvol
	call	PrintD
	Print	SetVolMsg
	popad
ENDIF

        cmp     edx, 256
        jb      VolOk
        int     01h
VolOk:

	mov	ebx, edx
	VSelect al
        mov     ax, GUS_Volumes[ebx*2]
	OutGUS	CurVolReg, ax
	popad
	clc
	ret

GUS_SetVolume	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
IFDEF DebugGUS
SetBalMsg	DB	'GUS_SetBalance: Channel '
SBchan		DB	'00000000  Balance '
SBbal		DB	'00000000.',13,10,'$'
ENDIF
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
GUS_SetBalance	Proc	Near

	pushad

IFDEF DebugGUS
	pushad
	mov	ebx, eax
	lea	edi, SBchan
	call	PrintD
	mov	ebx, edx
	lea	edi, SBBal
	call	PrintD
	Print	SetBalMsg
	popad
ENDIF

	mov	ebx, edx
	VSelect al
	shr	bl, 4
	OutGUSb PanPosReg, bl
	popad
	clc
	ret

GUS_SetBalance	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
IFDEF DebugGUS
SetAccMsg	DB	'GUS_SetAcc: Channel '
SAchan		DB	'00000000 Accumulator: '
SAacc		DB	'00000000.',13,10,'$'
ENDIF
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
GUS_SetFreq     Proc    Near

	pushad

IFDEF DebugGUS
	pushad
	mov	ebx, eax
	lea	edi, SAchan
	call	PrintD
	mov	ebx, edx
	lea	edi, SAacc
	call	PrintD
	Print	SetAccMsg
	popad
ENDIF

        push    edx
        VSelect al
        pop     eax
        xor     edx, edx
        shl     eax, 10
        mov     ebx, SampleRate
        div     ebx
        and     eax, 0FFFFFFFEh
        OutGUS  FrequencyReg, ax
	popad
	clc
	ret

GUS_SetFreq     EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
GUS_SetMastVol        Proc    Near

        pushad
        xor     ebx, ebx
        mov     ebp, eax
        xor     edx, edx
        lea     edi, GUS_Volumes
        mov     esi, 256
VolumeLoop:
        cmp     edx, 0
        jne     vnz
        push    edx
        xor     ebx, ebx
        jmp     stovol
vnz:    bsr     ecx, edx
        mov     bh, cl
        push    edx
        mov     eax, 1
        shl     eax, cl
        sub     edx, eax
        sub     cl, 8
        ror     edx, cl
        mov     bl, dl
        shl     ebx, 4
stovol: mov     [edi], bx
        add     edi, 2
        pop     edx
        add     edx, ebp
        dec     esi
        jnz     VolumeLoop
        popad
        clc
        ret

GUS_SetMastVol        EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
GUS_TmrReset    Proc    Near

        pushad
        OutGusb ResetReg, 7
        mov     edx, BaseAddr
        add     edx, IRQStatusPort
        in      al, dx
        InGUSb  DramDMACtrlReg
        InGUSb  SamplingCtrlReg
        InGUSb  IRQSourceReg_R
        VSelect 0
        OutGUSb VoiceCtrlReg, 3
        OutGUSb VolRampCtrlReg, 3
        OutGUS  CurVolReg, 0
        OutGUS  FrequencyReg, 1024
        InGUSb  DramDMACtrlReg
        InGUSb  SamplingCtrlReg
        InGUSb  IRQSourceReg_R
        xor     eax, eax
        mov     TmrFreq, eax
        mov     NextCallAddr, eax
        mov     InGThandler, eax
        popad
        clc
        ret

GUS_TmrReset    EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
GUS_TmrReqCall  Proc    Near

	pushad
        mov     TmrFreq, eax
	mov	NextCallAddr, edi
	or	eax, eax
	jnz	DoProgramTimer
        int     03h
        call    CallFunction
	popad
	clc
	ret

DoProgramTimer:
	VSelect 0
	OutGUSb VoiceCtrlReg, 3
	OutGUS	FrequencyReg, 1024
	OutGUS	StartAddrLoReg, 0
	OutGUS	StartAddrHiReg, 0
	OutGUS	CurLocLoReg, 0
	OutGUS	CurLocHiReg, 0
        xor     eax, eax
        mov     edx, 1
        div     TmrFreq
        mov     ebx, SampleRate
        mul     ebx
        mov     ebx, 65536
        div     ebx
	shl	eax, 9
	OutGUS	EndAddrLoReg, ax
	shr	eax, 16
	OutGUS	EndAddrHiReg, ax
        OutGUSb VoiceCtrlReg, 28h       ; Let's go!
        OutGUSb VoiceCtrlReg, 28h
	popad
	clc
	ret

GUS_TmrReqCall  EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
GUS_TmrStop     Proc    Near

        pushad
        VSelect 0
        OutGUSb VoiceCtrlReg, 3
        mov     NextCallAddr, 0
        popad
        clc
        ret

GUS_TmrStop     EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
GUS_TmrDeInit   Proc    Near

        pushad
        call    GUS_TmrStop
        mov     bl, BPtr GF1Irq
        mov     al, 1
        call    _SetIrqMask
        mov     bl, BPtr GF1Irq
        mov     edx, OldPmGUSIrq
        call    _SetIrqVect
        mov     bl, BPtr GF1Irq
        mov     eax, OldDosGUSIRQ
        call    _RmPmIrqFree
        popad
        clc
        ret

GUS_TmrDeInit   EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
GusTimerIRQ     Proc    Near

        pushad
        push    es ds fs gs
        RASTER  63,63,0
        mov     ax, cs:_SelData
        mov     ds, ax
        mov     es, ax
        mov     gs, _SelZero

        mov     al, 20h
        out     20h, al
        cmp     GF1Irq, 08h
        jb      NotSlaveIRQ
        out     0A0h, al
NotSlaveIRQ:

        mov     edx, BaseAddr
        add     edx, IRQStatusPort
        in      al, dx

        InGUSb  IrqSourceReg_R
        cmp     InGTHandler, 0
        jnz     GetOut
        mov     InGTHandler, 1
        sti
        call    CallFunction
        mov     InGTHandler, 0

GetOut:
        RASTER  0,0,0
        pop     gs fs ds es
        popad
        iretd

GusTimerIRQ     EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
CallFunction    Proc    Near

        mov     eax, NextCallAddr
        or      eax, eax
        jz      DoNotCall
        call    eax
DoNotCall:
        clc
        ret

CallFunction    EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
GUS_GetInfo     Proc    Near

	lea	eax, GusDriverInfo
	ret

GUS_GetInfo	EndP
;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º                                  D A T A                                    º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
GUS_FunctionPtr DD	0
GUS_GetChunkPtr DD      0
GUS_EnvName	DB	'ULTRASND='
GUS_EnvNameLen	EQU	$-GUS_EnvName
GUS_EnvMsg	DB	'GUS Driver: ULTRASND environment variable not found!',10,13,'$'
GUS_Error	DB	'GUS Driver: Fatal error.',13,10,0,'$'

GUS_Inited	DB	'Gravis Ultrasound initialized at '
GIBase		DB	'0000h, IRQ '
GIIrq		DB	'00h and DMA '
GIDma		DB	'00h.',13,10,'$'

ReqMsg          DB      13,10,'GUS_TmrReqCall: '
ReqBytes        DB      '00000000 ',13,10,'$'

GUS_Rates	DD	44100		; 14 voices
		DD	41160		; 15 voices
		DD	38587		; 16 voices
		DD	36317		; 17 voices
		DD	34300		; 18 voices
		DD	32494		; 19 voices
		DD	30870		; 20 voices
		DD	29400		; 21 voices
		DD	28063		; 22 voices
		DD	26843		; 23 voices
		DD	25725		; 24 voices
		DD	24696		; 25 voices
		DD	23746		; 26 voices
		DD	22866		; 27 voices
		DD	22050		; 28 voices
		DD	21289		; 29 voices
		DD	20580		; 30 voices
		DD	19916		; 31 voices
		DD	19293		; 32 voices

GUSChangeIRQ    DB      0,0,1,3,0,2,0,4,0,0,0,5,6,0,0,7
GUSChangeDMA    DB      0,1,0,2,0,3,4,5


GUS_Volumes     DW      256 DUP (0)

GusDriverInfo	Label	Dword

                DB      01h             ; Playing mode = HW mixing
                DB      0Fh             ; Kaikki kelpaa... ?
                DB      02h             ; Chunk load preferred
                DB      00h             ; Dummy

BaseAddr        DD      0
DMAOut          DD      0
GF1Irq          DD      0
SampleRate      DD      0

MasterVol	DD	0
ChansAllocated	DD	0
ChansUsed	DD	0
SamplesUsed	DD	0
SampleBase	DD	0

SampleData	DB	SIBCount*SIBLen dup (0)

SmplLen 	EQU	0			; DD
SmplRepeatFrom	EQU	SmplLen+4		; DD
SmplRepeatTo	EQU	SmplRepeatFrom+4	; DD
SmplFlags	EQU	SmplRepeatTo+4		; DD
SmplOfs 	EQU	SmplFlags+4		; DD
SIBLen		EQU	SmplOfs+4
SIBCount	EQU	48
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
TmrFreq         DD      0
NextCallAddr	DD	0
InGThandler	DD	0
OldDosGUSIrq	DD	0
OldPmGUSIrq	DD	0

GusIRQStub	DB	21 dup (0)
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Code32		EndS

                End

