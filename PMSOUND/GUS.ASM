TITLE GUS.ASM - EMF PM Sound System - GUS Soundcard Driver v0.15 by Saint
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

;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
OutGUS		MACRO	Index, Data

	push	eax
	mov	edx, GUS_BaseAddr
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
	mov	edx, GUS_BaseAddr
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

	mov	edx, GUS_BaseAddr
	add	edx, CommandPort
	mov	al, Index
	out	dx, al
	add	edx, 2
	in	al, dx

		ENDM
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
VSelect 	MACRO	Voice

	mov	edx, GUS_BaseAddr
	add	edx, VoiceSelectPort
	mov	al, Voice
	out	dx, al

		ENDM
;ÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ
GusDriver	Proc	Near

	pushad
        mov     GUS_FunctionPtr, ebx
        call    GetGUSAddresses
        mov     ebx, GUS_FunctionPtr
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

        push    ebx                     ; Mask & hook the GUS IRQ.
        mov     ebx, GUS_IRQ
	call	_GetIrqVect
	mov	OldPmGUSIrq, edx
        mov     ebx, GUS_IRQ
        lea     edx, GusTimerIRQ
	call	_SetIrqVect
	lea	edi, GusIrqStub
	call	_RmPmIrqSet
	mov	OldDosGUSIrq, eax
        mov     ebx, GUS_IRQ
	mov	al, 0
        call    _SetIrqMask
        pop     ebx

        mov     ChansAllocated, 1
	mov	ChansUsed, 14
	or	DPtr [ebx+DrvInited], 01h

        mov     ebx, GUS_BaseAddr
        lea     edi, GIBase
	call	PrintW
        mov     eax, GUS_Irq
	call	BToH
	mov	WPtr GIIrq, ax
	mov	eax, GUS_Dma
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
GetGUSAddresses Proc    Near

        mov     eax, [esi+4]
        mov     GUS_BaseAddr, eax
        mov     eax, [esi+8]
        mov     GUS_IRQ, eax
        mov     eax, [esi+12]
        mov     GUS_DMA, eax
	ret

GetGUSAddresses EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
ScanNum         Proc    Near

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
GUS_Reset	Proc	Near

	pushad
	OutGUSb ResetReg, 0
	mov	edx, GUS_BaseAddr
	REPT	6
	in	al, dx
	ENDM
	OutGUSb ResetReg, 1
	mov	edx, GUS_BaseAddr
	REPT	6
	in	al, dx
	ENDM
	OutGUSb DramDMACtrlReg, 0
	OutGUSb TimerCtrlReg, 0
	OutGUSb SamplingCtrlReg, 0

	mov	edx, GUS_BaseAddr
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

	InGUSb	DramDMACtrlReg
	InGUSb	SamplingCtrlReg
	InGUSb	IRQSourceReg_R
	OutGUSb ResetReg, 3

	mov	edx, GUS_BaseAddr
	mov	al, 08h
	out	dx, al

	mov	MasterVol, 255
	mov	ChansUsed, 14
	mov	ChansAllocated, 0
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
	cmp	eax, 14
	jae	ChUsedOk
	mov	eax, 14
ChUsedOk:
	mov	ChansUsed, eax
	mov	ebx, eax
	dec	al
	or	al, 0C0h
	OutGUSb ActiveVoicesReg, al
	mov	eax, GUS_Rates[ebx*4-14*4]
	mov	GUS_SampleRate, eax
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
	mov	[edi+SmplOfs], eax
	mov	ebx, [edi+SmplLen]
	push	edi
	mov	edi, SampleBase
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
	mov	edx, GUS_BaseAddr
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

SampleLoaded:
        mov     ecx, 4
ClrLoop:
        mov     eax, edi
	OutGUS	DramIOAddrLoReg, ax
	shr	eax, 16
	OutGUSb DramIOAddrHiReg, al
	mov	edx, GUS_BaseAddr
	add	edx, DramIOPort
        mov     al, 0
        out     dx, al
        inc     edi
        loop    ClrLoop

        pop     edi
	mov	eax, [edi+SmplLen]
        add     eax, 4
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

	mov	ebx, edx
	VSelect al
	imul	ebx, MasterVol
	shr	ebx, 8
	mov	ax, GUS_Volumes[ebx*4]
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
        mov     ebx, GUS_SampleRate
        div     ebx
        and     eax, 0FFFFFFFEh
        OutGUS  FrequencyReg, ax
	popad
	clc
	ret

GUS_SetFreq     EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
GUS_SetMastVol        Proc    Near

	push	eax
	and	eax, 0FFh
	mov	MasterVol, eax
	pop	eax
        clc
	ret

GUS_SetMastVol        EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
GUS_TmrReset    Proc    Near

        pushad
        OutGusb ResetReg, 7
        mov     edx, GUS_BaseAddr
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
        mov     ebx, GUS_SampleRate
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
        mov     ebx, GUS_IRQ
        mov     al, 1
        call    _SetIrqMask
        mov     ebx, GUS_IRQ
        mov     edx, OldPmGUSIrq
        call    _SetIrqVect
        mov     ebx, GUS_IRQ
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
        mov     ax, cs:_SelData
        mov     ds, ax
        mov     es, ax
        mov     gs, _SelZero

        mov     al, 20h
        out     20h, al
        cmp     GUS_IRQ, 08h
        jb      NotSlaveIRQ
        out     0A0h, al
NotSlaveIRQ:

        mov     edx, GUS_BaseAddr
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
GUS_FunctionPtr DD      0
GUS_GetChunkPtr DD      0
GUS_EnvName	DB	'ULTRASND='
GUS_EnvNameLen	EQU	$-GUS_EnvName
GUS_EnvMsg	DB	'GUS Driver: ULTRASND environment variable not found!',10,13,'$'
GUS_Error	DB	'GUS Driver: Fatal error.',13,10,0,'$'

GUS_Inited	DB	'Gravis Ultrasound initialized at '
GIBase          DB      '0000h, IRQ '
GIIrq           DB      '00h and DMA '
GIDma           DB      '00h.',13,10,'$'

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

GUS_Volumes	Label	Word
	DW	00000h,07000h,07FF0h,08800h,08FF0h,09400h,09800h,09C00h
	DW	09FF0h,0A200h,0A400h,0A600h,0A800h,0AA00h,0AC00h,0AE00h
	DW	0AFF0h,0B100h,0B200h,0B300h,0B400h,0B500h,0B600h,0B700h
	DW	0B800h,0B900h,0BA00h,0BB00h,0BC00h,0BD00h,0BE00h,0BF00h
	DW	0BFF0h,0C080h,0C100h,0C180h,0C200h,0C280h,0C300h,0C380h
	DW	0C400h,0C480h,0C500h,0C580h,0C600h,0C680h,0C700h,0C780h
	DW	0C800h,0C880h,0C900h,0C980h,0CA00h,0CA80h,0CB00h,0CB80h
	DW	0CC00h,0CC80h,0CD00h,0CD80h,0CE00h,0CE80h,0CF00h,0CF80h
	DW	0CFF0h,0D040h,0D080h,0D0C0h,0D100h,0D140h,0D180h,0D1C0h
	DW	0D200h,0D240h,0D280h,0D2C0h,0D300h,0D340h,0D380h,0D3C0h
	DW	0D400h,0D440h,0D480h,0D4C0h,0D500h,0D540h,0D580h,0D5C0h
	DW	0D600h,0D640h,0D680h,0D6C0h,0D700h,0D740h,0D780h,0D7C0h
	DW	0D800h,0D840h,0D880h,0D8C0h,0D900h,0D940h,0D980h,0D9C0h
	DW	0DA00h,0DA40h,0DA80h,0DAC0h,0DB00h,0DB40h,0DB80h,0DBC0h
	DW	0DC00h,0DC40h,0DC80h,0DCC0h,0DD00h,0DD40h,0DD80h,0DDC0h
	DW	0DE00h,0DE40h,0DE80h,0DEC0h,0DF00h,0DF40h,0DF80h,0DFC0h
	DW	0DFF0h,0E020h,0E040h,0E060h,0E080h,0E0A0h,0E0C0h,0E0E0h
	DW	0E100h,0E120h,0E140h,0E160h,0E180h,0E1A0h,0E1C0h,0E1E0h
	DW	0E200h,0E220h,0E240h,0E260h,0E280h,0E2A0h,0E2C0h,0E2E0h
	DW	0E300h,0E320h,0E340h,0E360h,0E380h,0E3A0h,0E3C0h,0E3E0h
	DW	0E400h,0E420h,0E440h,0E460h,0E480h,0E4A0h,0E4C0h,0E4E0h
	DW	0E500h,0E520h,0E540h,0E560h,0E580h,0E5A0h,0E5C0h,0E5E0h
	DW	0E600h,0E620h,0E640h,0E660h,0E680h,0E6A0h,0E6C0h,0E6E0h
	DW	0E700h,0E720h,0E740h,0E760h,0E780h,0E7A0h,0E7C0h,0E7E0h
	DW	0E800h,0E820h,0E840h,0E860h,0E880h,0E8A0h,0E8C0h,0E8E0h
	DW	0E900h,0E920h,0E940h,0E960h,0E980h,0E9A0h,0E9C0h,0E9E0h
	DW	0EA00h,0EA20h,0EA40h,0EA60h,0EA80h,0EAA0h,0EAC0h,0EAE0h
	DW	0EB00h,0EB20h,0EB40h,0EB60h,0EB80h,0EBA0h,0EBC0h,0EBE0h
	DW	0EC00h,0EC20h,0EC40h,0EC60h,0EC80h,0ECA0h,0ECC0h,0ECE0h
	DW	0ED00h,0ED20h,0ED40h,0ED60h,0ED80h,0EDA0h,0EDC0h,0EDE0h
	DW	0EE00h,0EE20h,0EE40h,0EE60h,0EE80h,0EEA0h,0EEC0h,0EEE0h
	DW	0EF00h,0EF20h,0EF40h,0EF60h,0EF80h,0EFA0h,0EFC0h,0EFE0h
	DW	0EFF0h,0F010h,0F020h,0F030h,0F040h,0F050h,0F060h,0F070h
	DW	0F080h,0F090h,0F0A0h,0F0B0h,0F0C0h,0F0D0h,0F0E0h,0F0F0h
	DW	0F100h,0F110h,0F120h,0F130h,0F140h,0F150h,0F160h,0F170h
	DW	0F180h,0F190h,0F1A0h,0F1B0h,0F1C0h,0F1D0h,0F1E0h,0F1F0h
	DW	0F200h,0F210h,0F220h,0F230h,0F240h,0F250h,0F260h,0F270h
	DW	0F280h,0F290h,0F2A0h,0F2B0h,0F2C0h,0F2D0h,0F2E0h,0F2F0h
	DW	0F300h,0F310h,0F320h,0F330h,0F340h,0F350h,0F360h,0F370h
	DW	0F380h,0F390h,0F3A0h,0F3B0h,0F3C0h,0F3D0h,0F3E0h,0F3F0h
	DW	0F400h,0F410h,0F420h,0F430h,0F440h,0F450h,0F460h,0F470h
	DW	0F480h,0F490h,0F4A0h,0F4B0h,0F4C0h,0F4D0h,0F4E0h,0F4F0h
	DW	0F500h,0F510h,0F520h,0F530h,0F540h,0F550h,0F560h,0F570h
	DW	0F580h,0F590h,0F5A0h,0F5B0h,0F5C0h,0F5D0h,0F5E0h,0F5F0h
	DW	0F600h,0F610h,0F620h,0F630h,0F640h,0F650h,0F660h,0F670h
	DW	0F680h,0F690h,0F6A0h,0F6B0h,0F6C0h,0F6D0h,0F6E0h,0F6F0h
	DW	0F700h,0F710h,0F720h,0F730h,0F740h,0F750h,0F760h,0F770h
	DW	0F780h,0F790h,0F7A0h,0F7B0h,0F7C0h,0F7D0h,0F7E0h,0F7F0h
	DW	0F800h,0F810h,0F820h,0F830h,0F840h,0F850h,0F860h,0F870h
	DW	0F880h,0F890h,0F8A0h,0F8B0h,0F8C0h,0F8D0h,0F8E0h,0F8F0h
	DW	0F900h,0F910h,0F920h,0F930h,0F940h,0F950h,0F960h,0F970h
	DW	0F980h,0F990h,0F9A0h,0F9B0h,0F9C0h,0F9D0h,0F9E0h,0F9F0h
	DW	0FA00h,0FA10h,0FA20h,0FA30h,0FA40h,0FA50h,0FA60h,0FA70h
	DW	0FA80h,0FA90h,0FAA0h,0FAB0h,0FAC0h,0FAD0h,0FAE0h,0FAF0h
	DW	0FB00h,0FB10h,0FB20h,0FB30h,0FB40h,0FB50h,0FB60h,0FB70h
	DW	0FB80h,0FB90h,0FBA0h,0FBB0h,0FBC0h,0FBD0h,0FBE0h,0FBF0h
	DW	0FC00h,0FC10h,0FC20h,0FC30h,0FC40h,0FC50h,0FC60h,0FC70h
	DW	0FC80h,0FC90h,0FCA0h,0FCB0h,0FCC0h,0FCD0h,0FCE0h,0FCF0h
	DW	0FD00h,0FD10h,0FD20h,0FD30h,0FD40h,0FD50h,0FD60h,0FD70h
	DW	0FD80h,0FD90h,0FDA0h,0FDB0h,0FDC0h,0FDD0h,0FDE0h,0FDF0h
	DW	0FE00h,0FE10h,0FE20h,0FE30h,0FE40h,0FE50h,0FE60h,0FE70h
	DW	0FE80h,0FE90h,0FEA0h,0FEB0h,0FEC0h,0FED0h,0FEE0h,0FEF0h
	DW	0FF00h,0FF10h,0FF20h,0FF30h,0FF40h,0FF50h,0FF60h,0FF70h
	DW	0FF80h,0FF90h,0FFA0h,0FFB0h,0FFC0h,0FFD0h,0FFE0h,0FFF0h

GusDriverInfo   Label   Dword           ; The public driver info block.
GUS_PlayMode    DB      00000001b       ; Playing modes: HW mixing only.
GUS_OutputMode  DB      00001111b       ; Output modes: 8/16bit mono/stereo.
GUS_LoadMode    DB      00000010b       ; Loading modes: chunkload only.
                DB      0               ; Reserved byte.
GUS_BaseAddr    DD      0               ; GUS base port address.
GUS_DMA         DD      0               ; GUS DMA channel number.
GUS_IRQ         DD      0               ; GUS IRQ number.
GUS_SampleRate  DD      0               ; Usually 44100 Hz.
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
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

