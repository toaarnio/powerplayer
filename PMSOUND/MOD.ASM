TITLE MOD Player Driver for EMF Protected Mode Music System
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ

        .386P

        Uses_Timer = 1                  ; Include timer stuff.
	Uses_Kbd   = 1			; Include keyboard stuff.
	Uses_ExcHandling = 1		; Include the exception handler.
        Uses_DataFileRead = 1

;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ

        INCLUDE callspec.hdr
        INCLUDE stdrouts.hdr
        INCLUDE filelib.hdr
        INCLUDE debug.inc

Code32  Segment Para Public Use32
	ASSUME	CS:Code32,DS:Code32

	INCLUDE pmode.inc

;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º				    C O D E				       º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½

Public  MODPlayerDriver

;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
MODPlayerDriver Proc    Near

	pushad
        mov     MOD_FunctionPtr, ebx
        mov     DPtr [ebx+Mus_Reset], Offset MOD_Reset
        mov     DPtr [ebx+Mus_GetInfo], Offset MOD_GetInfo
        mov     DPtr [ebx+Mus_Start], Offset MOD_Start
        mov     DPtr [ebx+Mus_Stop], Offset MOD_Stop
        mov     DPtr [ebx+Mus_Resume], Offset MOD_Resume
        mov     DPtr [ebx+Mus_SetPos], Offset MOD_SetPos
        mov     DPtr [ebx+Mus_GetPos], Offset MOD_GetPos
        mov     DPtr [ebx+Mus_Load], Offset MOD_Load
        mov     DPtr [ebx+Mus_Unload], Offset MOD_UnLoad
	or	DPtr [ebx+DrvInited], 08h
	popad
	clc
	ret

MODPlayerDriver EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
MOD_Reset       Proc    Near

	pushad
        mov     ebx, MOD_FunctionPtr
	lea	edi, ChannelHandle
	mov	ecx, NumChannels
AllocLoop:
	call	[ebx+Sd_AllocChan]
	stosd
        dec     ecx
        jnz     AllocLoop

	mov	ecx, 1
BalanceLoop:
	mov	edx, PanPosLeft
	test	cl, 2
	jz	NotR
	mov	edx, PanPosRight
NotR:	mov	eax, ChannelHandle[ecx*4-4]
	call	[ebx+Sd_SetBalance]
	inc	ecx
	cmp	ecx, NumChannels
	jna	BalanceLoop

	mov	edi, ModDataPtr
	add	edi, ChannelInfo
	mov	ecx, 8*CIBLen
	mov	al, 0
	rep	stosb

	call	[ebx+Sd_GetInfo]	; Always get it, it might change!
	mov	eax, [eax+SdOutputFreq] ; Get the output rate into ebx.
	imul	eax, 60
	xor	edx, edx
	mov	ebx, 125*6*4
	div	ebx
	mov	TickBytes, eax
	mov	TickCounter, 0
	mov	MasterVolume, 63
	popad
	clc
	ret

MOD_Reset       EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
MOD_Start       Proc    Near

	mov	PatternRow, 1
	mov	PattDelayCnt, 1
	mov	NextOrder, 0
	mov	TickCounter, 0F0h
        call    MOD_Resume
	clc
	ret

MOD_Start       EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
MOD_Resume      Proc    Near

	push	eax ebx edi
        mov     ebx, MOD_FunctionPtr
        lea     edi, MOD_Update
        xor     eax, eax
        mov     al, SongTempo
        imul    eax, 26214
        call    [ebx+Sd_TmrReqCall]
	pop	edi ebx eax
	clc
	ret

MOD_Resume      EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
MOD_Stop        Proc    Near

        push    ebx
        mov     ebx, MOD_FunctionPtr
        call    [ebx+Sd_TmrStop]
        pop     ebx
	clc
	ret

MOD_Stop        EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
MOD_SetPos      Proc    Near

	shr	eax, 6
	mov	NextOrder, eax
	mov	PatternRow, 1
	clc
	ret

MOD_SetPos      EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
MOD_GetPos      Proc    Near

	push	ebx
	mov	eax, 64
	sub	eax, PatternRow
	mov	ebx, NextOrder
	dec	ebx
	shl	ebx, 6
	add	eax, ebx
;
;        mov     bl, SongSpeed
;        mov     bh, SongTempo
        mov     ebx, NumChannels
        shl     ebx, 16
        or      eax, ebx
;
	pop	ebx
        movzx   edx, WrapCount
        clc
	ret

MOD_GetPos      EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
MOD_GetInfo     Proc    Near

	lea	eax, ModPlayerInfo
	clc
	ret

MOD_GetInfo     EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
MOD_Update      Proc    Near

	call	HandleModule
	clc
	ret

MOD_Update      EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
HandleModule	Proc	Near

	mov	ebp, ModDataPtr
	inc	TickCounter
	mov	eax, TickCounter
	cmp	al, SongSpeed
	jb	NoNewNotes
	mov	TickCounter, 0
	dec	PattDelayCnt
	jnz	NoNewNotes
	mov	PattDelayCnt, 1
	call	ParsePattern
	ret

NoNewNotes:
	mov	edi, RowPtr
	lea	esi, [ebp+ChannelInfo]
	mov	ChannelNum, 0
	mov	ecx, NumChannels
HandleNext:
	push	ecx
	inc	ChannelNum
	movzx	ebx, BPtr [esi.CmdNumber]
	call	ModCmdHandlers[ebx*4]
	add	esi, CIBLen
	pop	ecx
	loop	HandleNext
	ret

HandleModule	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
ParsePattern	Proc	Near

	dec	PatternRow
	jnz	GotOrder
	call	OrderFetch
GotOrder:
	mov	edi, RowPtr
	mov	OrigRowPtr, edi
	mov	eax, NumChannels
	shl	eax, 2
	add	RowPtr, eax
	lea	esi, [ebp+ChannelInfo]
	mov	ChannelNum, 0
	mov	ecx, NumChannels
ParseNext:
	push	ecx
	inc	ChannelNum
	call	ParseChannel
	add	edi, 4
	add	esi, CIBLen
	pop	ecx
	loop	ParseNext
	ret
	   
ParsePattern	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
; Input: esi -> current CIB, edi -> current row&channel (both preserved)
ParseChannel	Proc	Near

	mov	SampleOffset, 0FFFFFFFFh
	call	GetInstrument
	js	NoNote
	jc	NoInstrument
	mov	[esi.TrueVol], dl
	mov	[esi.FineTune], dh
	mov	[esi.InstrNum], al
	mov	SampleOffset, 0
NoInstrument:
	call	ParseCommands
	call	GetAccumulator
	jc	NoNote
	mov	[esi.CurPeriod], ebx
	cmp	BPtr [esi.CmdNumber], 10h
	je	NoNote
	mov	[esi.CurAcc], eax
	call	InstrumentAcc
	call	PlayInstrument
	cmp	ReParseCommand, 1
	jne	NoNote
	call	ParseCommands
NoNote:
	mov	al, [esi.TrueVol]
	call	SetCurVol
	ret

ParseChannel	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
GetAccumulator	Proc	Near

	xor	eax, eax
	mov	al, [edi+2]
	and	al, 0Fh
	cmp	al, 3
	je	NoNoteFound			; Skip if TonePorta.

	mov	ah, [edi]
	and	ah, 0Fh
	mov	al, [edi+1]
	or	eax, eax
	jz	NoNoteFound

	cmp	eax, MinPeriod
	jb	NoChange
	cmp	eax, MaxPeriod
	ja	NoChange

	lea	ebx, PeriodTable
	mov	ecx, NoteNum
	call	PeriodScan
	movzx	ecx, BPtr [esi.FineTune]
	imul	ecx, NoteNum
	movzx	eax, WPtr [ebx+ecx*2]
	or	eax, eax
	jz	NoNoteFound

NoChange:
	mov	ebx, eax
	push	ebx
	call	PeriodToAcc
	pop	ebx
	clc
	ret

NoNoteFound:
	stc
	ret

GetAccumulator	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
GetDestPeriod	Proc	Near

	xor	eax, eax
	mov	ah, [edi]
	and	ah, 0Fh
	mov	al, [edi+1]
	or	eax, eax
	jz	NoDestFound

	cmp	eax, MinPeriod
	jb	DestNoChange
	cmp	eax, MaxPeriod
	ja	DestNoChange

	movzx	ebx, BPtr [esi.FineTune]
	imul	ebx, NoteNum
	lea	ebx, PeriodTable[ebx*2]
	mov	ecx, NoteNum
	call	PeriodScan

	mov	al, [esi.FineTune]
	test	al, 8
	jz	StpGossD
	cmp	ecx, NoteNum
	je	StpGossD
	sub	ebx, 2
StpGossD:
	movzx	eax, WPtr [ebx]
	or	eax, eax
	jz	NoDestFound

DestNoChange:
	mov	ebx, eax
	push	ebx
	call	PeriodToAcc
	pop	ebx
	clc
	ret

NoDestFound:
	stc
	ret

GetDestPeriod	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
GetInstrument	Proc	Near

	xor	eax, eax
	mov	al, [edi]
	and	al, 0F0h
	mov	bl, [edi+2]
	shr	bl, 4
	or	al, bl
	or	al, al
	jz	InstrNotFound
	cmp	al, 32
	ja	InvalidInstr
InstrFound:
	dec	al
	mov	dl, [ebp+DefVolumes+eax]
	mov	dh, [ebp+FineTunes+eax]
	xor	bl, bl
	clc
	ret

InstrNotFound:
	xor	bl, bl
	stc
	ret

InvalidInstr:
	xor	bl, bl
	dec	bl
	stc
	ret

GetInstrument	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
PlayInstrument	Proc	Near

	cmp	SampleOffset, 0FFFFFFFFh
	jne	DoPlay
	ret
DoPlay: mov     ebx, MOD_FunctionPtr
	mov	ecx, ChannelNum
	mov	eax, ChannelHandle[ecx*4-4]
	movzx	edx, BPtr [esi.InstrNum]
        mov     edx, [ebp+SampleHandles+edx*4]
	push	esi
	mov	esi, SampleOffset
	call	[ebx+Sd_SetSample]
	pop	esi
	ret

PlayInstrument	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
InstrumentAcc	Proc	Near

        mov     ebx, MOD_FunctionPtr
	mov	ecx, ChannelNum
	mov	eax, ChannelHandle[ecx*4-4]
	mov	edx, [esi.CurAcc]
        call    [ebx+Sd_SetFreq]
	ret

InstrumentAcc	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
OrderFetch	Proc	Near

	mov	PatternRow, 64
	mov	al, 65
	lea	esi, [ebp+ChannelInfo+LoopPatRow]
	mov	[esi+CIBLen*0], al
	mov	[esi+CIBLen*1], al
	mov	[esi+CIBLen*2], al
	mov	[esi+CIBLen*3], al
	mov	[esi+CIBLen*4], al
	mov	[esi+CIBLen*5], al
	mov	[esi+CIBLen*6], al
	mov	[esi+CIBLen*7], al
	mov	ebx, NextOrder
	cmp	ebx, SongLength
	jb	NoLoopInSong
	xor	ebx, ebx
	inc	WrapCount
NoLoopInSong:
	xor	eax, eax
	mov	al, [ebp+Orders+ebx]
	inc	ebx
	mov	NextOrder, ebx
	mul	PatternSize
	lea	eax, [ebp+ModDataSize+eax]
	mov	RowPtr, eax
	lea	esi, [ebp+ChannelInfo+LoopRowPtr]
	mov	[esi+CIBLen*0], eax
	mov	[esi+CIBLen*1], eax
	mov	[esi+CIBLen*2], eax
	mov	[esi+CIBLen*3], eax
	mov	[esi+CIBLen*4], eax
	mov	[esi+CIBLen*5], eax
	mov	[esi+CIBLen*6], eax
	mov	[esi+CIBLen*7], eax
	ret

OrderFetch	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
PeriodScan	Proc	Near

	cmp	ax, [ebx]
	jae	NoteFound
	add	ebx, 2
	loop	PeriodScan
	sub	ebx, 2
NoteFound:
	ret

PeriodScan	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
; in: esi -> current CIB, eax - current period
; out: eax-accumulator
PeriodToAcc	Proc	Near

	mov	ebx, eax
	movzx	ecx, BPtr [esi.InstrNum]
	mov	eax, [ebp+MidCFreqs+ecx*4]
	imul	eax, 428
	xor	edx, edx
	div	ebx
	ret

PeriodToAcc	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
; al - New current volume
SetCurVol	Proc	Near

	and	eax, 0FFh
	mov	edx, 255
	imul	edx, eax
	shr	edx, 6
	mov	ecx, ChannelNum
	mov	eax, ChannelHandle[ecx*4-4]
        mov     ebx, MOD_FunctionPtr
	call	[ebx+Sd_SetVolume]
	ret

SetCurVol	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
ParseCommands	Proc	Near

	xor	ebx, ebx
	mov	ReParseCommand, bl
	mov	bl, [edi+2]
	and	bl, 0Fh
	mov	BPtr [esi.CmdNumber], 08h
	call	ModCmdParsers[ebx*4]
	ret

ParseCommands	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
ParsePTCommands Proc	Near

	xor	ebx, ebx
	mov	bl, [edi+3]
	and	bl, 0F0h
	shr	ebx, 4
	call	PT_Parsers[ebx*4]
	ret

ParsePTCommands EndP
;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º									       º
;º		O N E - P A S S   C O M M A N D   H A N D L E R S	       º
;º									       º
;ÇÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¶
;º Information about all one-pass command handlers in general:		       º
;º									       º
;º INPUT:	EDI = Pointer to row & channel to parse.		       º
;º		ESI = Pointer to current channel's Command Info Block.	       º
;º FUNCTION:	Init the possible multiple-pass commands for each channel.     º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
SetTempo	Proc	Near

        xor     eax, eax
	mov	al, [edi+3]
	or	al, al
	jz	Dummy
	cmp	al, 20h
	ja	AbnormalTempo
	mov	SongSpeed, al
	mov	TickCounter, 0
	ret
AbnormalTempo:
        mov     SongTempo, al
	cmp	TempoMode, 1
	je	Dummy
        push    edi
        imul    eax, 26214
        lea     edi, MOD_Update
        mov     ebx, MOD_FunctionPtr
        call    [ebx+Sd_TmrReqCall]
        pop     edi
	ret

SetTempo	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
SetVolume	Proc	Near

	mov	al, [edi+3]
	cmp	al, 40h
	jbe	VolOk
	mov	al, 40h
VolOk:	mov	[esi.TrueVol], al
	ret

SetVolume	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
PositionJump	Proc	Near

	cmp	JumpsDisabled, 1
	je	Dummy
	xor	ebx, ebx
	mov	bl, [edi+3]
	mov	NextOrder, ebx
	mov	PatternRow, 1
	ret

PositionJump	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
BreakPattern	Proc	Near

	mov	PatternRow, 1
	ret

BreakPattern	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
SetSampleOffs	Proc	Near

	xor	eax, eax
	mov	al, [edi+3]
	shl	eax, 8
	mov	SampleOffset, eax
	ret

SetSampleOffs	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
FineSlideUp	Proc	Near

	mov	al, [edi+3]
	and	al, 0Fh
	mov	[esi.CmdInfo], al
	call	PortamentoUp
	mov	ReParseCommand, 1
	ret

FineSlideUp	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
FineSlideDown	Proc	Near

	mov	al, [edi+3]
	and	al, 0Fh
	mov	[esi.CmdInfo], al
	call	PortamentoDown
	mov	ReParseCommand, 1
	ret

FineSlideDown	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
PatternLoop	Proc	Near

	mov	al, [edi+3]
	and	eax, 0Fh
	jz	SetLoop
	cmp	BPtr [esi.LoopCount], 0
	je	SetCount
	dec	BPtr [esi.LoopCount]
	jnz	JmpLoop
	ret

SetCount:
	mov	[esi.LoopCount], al

JmpLoop:
	xor	eax, eax
	mov	al, [esi.LoopPatRow]
	mov	PatternRow, eax
	mov	eax, [esi.LoopRowPtr]
	mov	RowPtr, eax
	ret

SetLoop:
	mov	eax, PatternRow
	inc	eax
	mov	[esi.LoopPatRow], al
	mov	eax, OrigRowPtr
	mov	[esi.LoopRowPtr], eax
	ret

PatternLoop	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
SetGlissControl Proc	Near

	mov	al, [edi+3]
	and	al, 0Fh
	and	BPtr [esi.GlisFunk], 0F0h
	or	[esi.GlisFunk], al
	ret

SetGlissControl EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
SetVibControl	Proc	Near

	mov	al, [edi+3]
	and	al, 0Fh
	and	BPtr [esi.WaveCtrl], 0F0h
	or	[esi.WaveCtrl], al
	ret

SetVibControl	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
SetFineTune	Proc	Near

	mov	al, [edi+3]
	and	al, 0Fh
	mov	[esi.FineTune], al
	ret

SetFineTune	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
SetTreControl	Proc	Near

	mov	al, [edi+3]
	shl	al, 4
	and	BPtr [esi.WaveCtrl], 0Fh
	or	[esi.WaveCtrl], al
	ret

SetTreControl	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
FineVolSldUp	Proc	Near

	mov	al, [edi+3]
	and	al, 0Fh
	mov	bl, al
	mov	al, [esi.TrueVol]
	add	al, bl
	cmp	al, 40h
	jbe	$+4
	mov	al, 40h
	mov	[esi.TrueVol], al
	ret

FineVolSldUp	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
FineVolSldDown	Proc	Near

	mov	al, [edi+3]
	and	al, 0Fh
	mov	bl, al
	mov	al, [esi.TrueVol]
	sub	al, bl
	jnb	$+4
	xor	al, al
	mov	[esi.TrueVol], al
	ret

FineVolSldDown	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
PatternDelay	Proc	Near

	mov	al, [edi+3]
	and	al, 0Fh
	inc	al
	add	PattDelayCnt, al
	ret

PatternDelay	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Dummy		Proc	Near

	ret

Dummy		EndP
;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º									       º
;º     M U L T I P L E - P A S S   C O M M A N D   I N I T I A L I Z E R S     º
;º									       º
;ÇÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¶
;º Information about all command initializers in general:		       º
;º									       º
;º INPUT:	EBX = Command number					       º
;º		EDI = Pointer to row & channel to parse.		       º
;º		ESI = Pointer to current channel's Command Info Block.	       º
;º FUNCTION:	Init the possible multiple-pass commands for each channel.     º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
SlideCommands	Proc	Near

	xor	eax, eax
	mov	al, [edi+3]
	mov	[esi.CmdInfo], al
	mov	[esi.CmdNumber], bl
	ret

SlideCommands	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
InitTonePort	Proc	Near

	xor	eax, eax
	or	al, [edi+3]
	jz	InitTone&VSlide
	mov	[esi.PortInfo], al
InitTone&VSlide:
	xor	eax, eax
	mov	al, [edi+3]
	mov	[esi.CmdInfo], al
	mov	[esi.CmdNumber], bl
	call	GetDestPeriod
	jc	NoNewDestPeriod
	mov	[esi.DestPeriod], ebx
	mov	eax, [esi.CurPeriod]
	cmp	eax, ebx
	seta	[esi.TPortaDirec]
NoNewDestPeriod:
	ret

InitTonePort	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
InitVibrato	Proc	Near

	mov	[esi.CmdNumber], bl
	xor	edx, edx
	or	dh, [edi+3]
	jz	Dummy
	mov	al, [esi.VibratoInfo]
	mov	dl, dh
	and	dl, 0Fh
	jz	VibSkip
	and	al, 0F0h
	or	al, dl
VibSkip:
	mov	dl, dh
	and	dl, 0F0h
	jz	VibSkip2
	and	al, 0Fh
	or	al, dl
VibSkip2:
	mov	[esi.VibratoInfo], al
	ret

InitVibrato	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
InitTremolo	Proc	Near

	mov	[esi.CmdNumber], bl
	xor	edx, edx
	or	dh, [edi+3]
	jz	Dummy
	mov	al, [esi.TremoloInfo]
	mov	dl, dh
	and	dl, 0Fh
	jz	TreSkip
	and	al, 0F0h
	or	al, dl
TreSkip:
	mov	dl, dh
	and	dl, 0F0h
	jz	TreSkip2
	and	al, 0Fh
	or	al, dl
TreSkip2:
	mov	[esi.TremoloInfo], al
	ret

InitTremolo	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
InitRetrigNote	Proc	Near

	mov	al, [edi+3]
	mov	[esi.CmdInfo], al
	mov	BPtr [esi.CmdNumber], 0Eh
	ret

InitRetrigNote	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
InitNoteCut	Proc	Near

	mov	al, [edi+3]
	mov	[esi.CmdInfo], al
	mov	BPtr [esi+CmdNumber], 0Fh
	ret

InitNoteCut	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
InitNoteDelay	Proc	Near

	mov	al, [edi+3]
	test	al, 0Fh
	jz	Dummy
	mov	[esi.CmdInfo], al
	mov	BPtr [esi.CmdNumber], 10h
	ret

InitNoteDelay	EndP
;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º									       º
;º	    M U L T I P L E - P A S S	C O M M A N D	H A N D L E R S        º
;º									       º
;ÇÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¶
;º Information about all command handlers in general:			       º
;º									       º
;º INPUT:	ESI = Pointer to current channel's Command Info Block.	       º
;º FUNCTION:	Handle the possible multiple-pass commands for each channel.   º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
VolumeSlide	Proc	Near

	mov	bl, [esi.CmdInfo]
	mov	al, [esi.TrueVol]
	test	bl, 0F0h
	jnz	SlideVolUp
	and	bl, 0Fh
	sub	al, bl
	jnb	SaveNewVolume
	xor	al, al

SaveNewVolume:
	mov	[esi.TrueVol], al
	call	SetCurVol
	ret

SlideVolUp:
	shr	bl, 4
	add	al, bl
	cmp	al, 40h
	jbe	SaveNewVolume
	mov	al, 40h
	jmp	SaveNewVolume

VolumeSlide	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
PortamentoDown	Proc	Near

	xor	ebx, ebx
	mov	eax, [esi.CurPeriod]
	mov	bl, [esi.CmdInfo]
	add	eax, ebx
	cmp	eax, MaxPeriod
	jb	SkipPD
	mov	eax, MaxPeriod
SkipPD:
;
	or	eax, eax
	jnz	NoZ1
	mov	ecx, 29h
	int	01h
NoZ1:
;

	mov	[esi.CurPeriod], eax
	call	PeriodToAcc
	mov	[esi.CurAcc], eax
	call	InstrumentAcc
	ret

PortamentoDown	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
PortamentoUp	Proc	Near
        xor     ebx, ebx
	mov	eax, [esi.CurPeriod]
	mov	bl, [esi.CmdInfo]
	sub	eax, ebx
	cmp	eax, MinPeriod
	jge	SkipPU
	mov	eax, MinPeriod
SkipPU:
;
	or	eax, eax
	jnz	NoZ2
	mov	ecx, 11h
	int	01h
NoZ2:
;

	mov	[esi.CurPeriod], eax
	call	PeriodToAcc
	mov	[esi.CurAcc], eax
	call	InstrumentAcc
	ret

PortamentoUp	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
TonePortamento	Proc	Near

	xor	eax, eax
	mov	al, [esi.PortInfo]
	mov	ecx, [esi.CurPeriod]
	mov	edx, [esi.DestPeriod]
	or	edx, edx
	jz	NoPortamento
	cmp	ecx, edx
	je	NoPortamento
	cmp	BPtr [esi.TPortaDirec], 1
	je	PortaUp
PortaDown:
	add	ecx, eax
	cmp	ecx, edx
	jle	NoPortamento
	mov	ecx, edx
	mov	DPtr [esi.DestPeriod], 0
	jmp	NoPortamento
PortaUp:
	sub	ecx, eax
	cmp	ecx, edx
	jg	NoPortamento
	mov	ecx, edx
	mov	DPtr [esi.DestPeriod], 0

NoPortamento:
	mov	[esi.CurPeriod], ecx
	mov	al, [esi+GlisFunk]
	and	al, 0Fh
	jz	NoGlissando

	xor	ebx, ebx
	mov	eax, [esi.CurPeriod]
	mov	bl, [esi.FineTune]
	imul	ebx, NoteNum
	lea	ebx, [PeriodTable+ebx*2]
	mov	ecx, NoteNum
	call	PeriodScan
	movzx	ecx, WPtr [ebx]

NoGlissando:
	mov	eax, ecx

;
	or	eax, eax
	jnz	NoZ3
	mov	ecx, 76h
	int	01h
NoZ3:
;

	call	PeriodToAcc
	mov	[esi.CurAcc], eax
	call	InstrumentAcc
	ret

TonePortamento	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Vibrato 	Proc	Near

	push	edi
	xor	eax, eax
	mov	al, [esi.VibratoInfo]
	mov	edi, [esi.VibratoPos]
	mov	ecx, eax
	shr	ecx, 4
	add	[esi.VibratoPos], ecx
	mov	ecx, edi
	and	edi, 001Fh

	mov	dl, [esi.WaveCtrl]
	and	dl, 0Fh
	jz	VibSine
	shl	edi, 3
	cmp	dl, 1
	je	VibRampDown
	mov	ebx, 255
	jmp	VibSet

VibRampDown:
	mov	ebx, edi
	test	cl, 20h
	jz	VibSet
	mov	ebx, 255
	sub	ebx, edi
	jmp	VibSet

VibSine:
	movzx	ebx, Vibratotable[edi]

VibSet:
	and	al, 0Fh
	imul	ebx, eax
	shr	ebx, 7
	mov	eax, [esi.CurPeriod]
	sub	eax, ebx
	test	cl, 20h
	jz	VibratoUp
	add	eax, ebx
	add	eax, ebx
VibratoUp:
;
	or	eax, eax
	jnz	NoZ4
	mov	ecx, 103h
	int	01h
NoZ4:
;
	call	PeriodToAcc
	mov	[esi.CurAcc], eax
	call	InstrumentAcc
	pop	edi
	ret

Vibrato 	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Tremolo 	Proc	Near

	push	edi
	xor	eax, eax
	mov	al, [esi.TremoloInfo]
	mov	edi, [esi.TremoloPos]
	mov	ecx, eax
	shr	ecx, 4
	add	[esi.TremoloPos], ecx
	mov	ecx, edi
	and	edi, 001Fh

	mov	dl, [esi.WaveCtrl]
	shr	dl, 4
	or	dl, dl
	je	TreSine
	shl	edi, 3
	cmp	dl, 1
	je	TreRampDown
	mov	ebx, 255
	jmp	TreSet

TreRampDown:
	mov	ebx, edi
	test	cl, 20h
	jz	TreSet
	mov	ebx, 255
	sub	ebx, edi
	jmp	TreSet

TreSine:
	movzx	ebx, VibratoTable[edi]

TreSet:
	and	al, 0Fh
	imul	ebx, eax
	shr	bx, 6
	mov	al, [esi.TrueVol]
	sub	al, bl
	test	cl, 20h
	jnz	TremoloTest
	add	al, bl
	add	al, bl

TremoloTest:
	or	al, al
	jns	TSkip
	xor	al, al
TSkip:	cmp	al, 40h
	jb	TSkip2
	mov	al, 40h
TSkip2: mov	[esi.TrueVol], al
	call	SetCurVol
	pop	edi
	ret

Tremolo 	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Arpeggio	Proc	Near

	xor	edx, edx
	cmp	BPtr [esi.CmdInfo], 0
	jz	Dummy
	mov	eax, TickCounter
	mov	dl, 3
	div	dl
	mov	dl, [esi.CmdInfo]
	cmp	ah, 1
	je	Arpeg1
	cmp	ah, 2
	je	Arpeg2
	mov	eax, [esi.CurPeriod]
	jmp	SetArpPeriod

Arpeg1: shr	dl, 4
	jmp	SetArpeggio
Arpeg2: and	dl, 0Fh

SetArpeggio:
	add	edx, edx
	mov	eax, [esi.CurPeriod]
	movzx	ebx, BPtr [esi.FineTune]
	imul	ebx, NoteNum
	lea	ebx, PeriodTable[ebx*2]
	mov	ecx, NoteNum
FindNoteLoop:
	cmp	ax, [ebx]
	jnb	GotTheNote
	add	ebx, 2
	loop	FindNoteLoop
	ret
GotTheNote:
	add	ebx, edx
	mov	ax, [ebx]
SetArpPeriod:
	and	eax, 0FFFFh		;!!!!!!!!!!!!!!!!!!!!
;
	or	eax, eax
	jnz	NoZ5
	mov	ecx, 42h
	int	01h
NoZ5:
;
	call	PeriodToAcc
	mov	[esi.CurAcc], eax
	call	InstrumentAcc
	ret

Arpeggio	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Port_&_Slide	Proc	Near

	call	TonePortamento
	call	VolumeSlide
	ret

Port_&_Slide	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Vibrato_&_Slide Proc	Near

	call	Vibrato
	call	VolumeSlide
	ret

Vibrato_&_Slide EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
RetrigNote	Proc	Near

	mov	bl, [esi.CmdInfo]
	and	bl, 0Fh
	jz	Dummy
	mov	eax, TickCounter
	div	bl
	or	ah, ah
	jnz	Dummy
	mov	SampleOffset, 0
	call	PlayInstrument
	ret

RetrigNote	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
NoteCut 	Proc	Near

	xor	eax, eax
	mov	al, [esi.CmdInfo]
	and	al, 0Fh
	jz	Dummy
	cmp	eax, TickCounter
	jne	Dummy
	xor	al, al
	mov	[esi.TrueVol], al
	call	SetCurVol
	ret

NoteCut 	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
NoteDelay	Proc	Near

	xor	eax, eax
	mov	al, [esi.CmdInfo]
	and	al, 0Fh
	cmp	eax, TickCounter
	jne	Dummy
	mov	eax, [esi.CurPeriod]
	call	PeriodToAcc
	mov	[esi.CurAcc], eax
	call	InstrumentAcc
	mov	SampleOffset, 0
	call	PlayInstrument
	ret

NoteDelay	EndP
;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º                            MOD Loader Routines                              º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
MOD_Load        Proc    Near

	pushad
        mov     FNamePtr, eax
        mov     ebx, 0
        mov     ecx, 1084
        mov     edx, FNamePtr
        lea     edi, ModHeader
        call    DataFileRead            ; Load the header.
        jc      LoadError
        call    DetectModType
        jc      LoadError
        call    GetNumPatts
        mov     HighestUsed, edx
        mov     HighestSaved, eax
        call    AllocModMem
        mov     ebx, PatternBase
        mov     ecx, PatternTotal
        mov     edx, FNamePtr
        mov     edi, ModDataPtr
        add     edi, ModDataSize
        call    DataFileRead            ; Load the patterns.
        jc      LoadError
        call    LoadSamples             ; Load the samples.
        jc      LoadError
        mov     edi, ModDataPtr
        add     edi, Orders
        lea     esi, ModHeader[952]
        mov     ecx, 32
        rep     movsd
	popad
	clc
	ret

LoadError:
	Print	FReadErrMsg
	popad
	stc
	ret

MOD_Load        EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
MOD_UnLoad      Proc

        pushad
        mov     ebp, AllocatedSize
        Free    ModDataPtr, ebp
        popad
        clc
        ret

MOD_UnLoad      EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
DetectModType	Proc	Near

	mov	PatternSize, 1024
	mov	PatternBase, 1084
	mov	NumChannels, 4
	mov	InstrCount, 31
	mov	SongSpeed, 6
        mov     SongTempo, 125
        cmp     DPtr ModHeader[1080], '.K.M'
	je	ItsMOD
        cmp     DPtr ModHeader[1080], '!K!M'
	je	ItsMOD
        cmp     DPtr ModHeader[1080], '4TLF'
	je	ItsMOD
        cmp     DPtr ModHeader[1080], 'NHC6'
	je	ItsMOD6
        cmp     DPtr ModHeader[1080], '8TLF'
	je	ItsMOD8
        cmp     DPtr ModHeader[1080], 'ATCO'
	je	ItsMOD8
        cmp     DPtr ModHeader[1080], 'NHC8'
	je	ItsMOD8
	stc
	ret
ItsMOD:
	clc
	ret
ItsMOD6:
	mov	NumChannels, 6
	mov	PatternSize, 1536
	clc
	ret
ItsMOD8:
	mov	NumChannels, 8
	mov	PatternSize, 2048
	clc
	ret

DetectModType	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
GetNumPatts	Proc	Near

	xor	ecx, ecx
	mov	cl, ModHeader[950]
        mov     SongLength, ecx
	lea	esi, ModHeader[952]
	xor	eax, eax
	call	FindHighest
	mov	edx, eax
	xor	eax, eax
	mov	ecx, 07Fh
	lea	esi, ModHeader[952]
FindHighest:
	cmp	[esi], al
	jbe	NotAbove
	mov	al, [esi]
  NotAbove:
	inc	esi
	dec	ecx
	jnz	FindHighest
	ret

GetNumPatts	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
AllocModMem	Proc	Near

	xor	ebp, ebp
        mov     ebx, MOD_FunctionPtr
        call    [ebx+Sd_GetInfo]
        mov     al, [eax+SdLoadMode]
        and     al, 02h
        jnz     NoSampleCalc

	lea	edi, ModHeader[42]
	xor	eax, eax
	xor	ebp, ebp
	mov	ecx, InstrCount
SampleCalcLoop:
	mov	ax, [edi]
        xchg    ah, al
	test	al, 01h
	jz	NoAdjust
	inc	ax
  NoAdjust:
	add	ebp, eax
	add	edi, 30
	dec	ecx
	jnz	SampleCalcLoop
	add	ebp, ebp
	
NoSampleCalc:
        mov     eax, PatternSize
        mul     HighestUsed
        add     eax, PatternSize
	mov	PatternTotal, eax
        add     ebp, eax
        add     ebp, ModDataSize
        mov     AllocatedSize, ebp
        AllocHi ModDataPtr, ebp
	clc
	ret

AllocModMem	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
LoadSamples	Proc	Near

        Print   LoadingMsg

	mov	eax, PatternBase
	add	eax, PatternTotal
	mov	FPos, eax
        mov     ebx, MOD_FunctionPtr
        call    [ebx+Sd_GetInfo]
	mov	al, [eax+SdLoadMode]
	and	al, 02h
	jnz	ChunkLoad
MemLoad:

        mov     esi, ModDataPtr
        add     esi, ModDataSize
        add     esi, PatternTotal
        lea     edx, ModHeader[42]
        mov     edi, ModDataPtr
        mov     ebp, 1
RegMemLoop:
        Print   DotMsg
        xor     eax, eax
        mov     ax, [edx]
        xchg    ah, al
        add     eax, eax
        mov     LSmplLen, eax
        xor     eax, eax
        mov     ax, [edx+4]
        xchg    ah, al
        push    eax
        mov     cx, [edx+6]
        xchg    ch, cl
        add     ax, cx
        add     eax, eax
        mov     LSmplRepeatTo, eax
        pop     eax
        add     eax, eax
        mov     LSmplRepeatFrom, eax
        mov     LSmplFlags, 0
        cmp     LSmplRepeatTo, 2
        jbe     NoLoop
        mov     LSmplFlags, 1
NoLoop:

        push    edx edi
        mov     ecx, LSmplLen
        mov     ebx, FPos
        add     FPos, ecx
        mov     edx, FNamePtr
        mov     edi, esi
        call    DataFileRead
        pop     edi edx

        mov     ebx, MOD_FunctionPtr
        lea     eax, TempSample
        call    [ebx+Sd_RegMemSmpl]
        mov     [edi+SampleHandles+ebp*4-4], eax
	mov	al, [edx+2]
	mov	[edi+Finetunes+ebp-1], al
	mov	al, [edx+3]
	mov	[edi+DefVolumes+ebp-1], al
	mov	DPtr [edi+MidCFreqs+ebp*4-4], ModMidCFreq
        add     esi, LSmplLen
	add	edx, 30
	inc	ebp
        cmp     ebp, InstrCount
        jbe     RegMemLoop

        Print   LoadedMsg
        clc
        ret

ChunkLoad:
        Alloc   ChunkBufPtr, 65536
        mov     esi, ChunkBufPtr
	lea	edx, ModHeader[42]
        mov     edi, ModDataPtr
	mov	ebp, 1
ChunkLoadLoop:
        Print   DotMsg
	movzx	eax, WPtr [edx]
	xchg	ah, al
	add	eax, eax
	mov	LSmplLen, eax
	movzx	eax, WPtr [edx+4]
	xchg	ah, al
	push	eax
	mov	cx, [edx+6]
	xchg	ch, cl
	add	ax, cx
	add	eax, eax
	mov	LSmplRepeatTo, eax
	pop	eax
	add	eax, eax
	mov	LSmplRepeatFrom, eax
	mov	LSmplFlags, 0
	cmp	LSmplRepeatTo, 2
	jbe	NotLooping
	mov	LSmplFlags, 1
  NotLooping:
	push	edx
        lea     eax, TempSample
	mov	esi, ChunkBufPtr
	mov	ecx, 65536
        lea     edx, GetChunk
        mov     ebx, MOD_FunctionPtr
        call    [ebx+Sd_ChunkLoad]
	pop	edx
        jc      SmplLoadError
        mov     [edi+SampleHandles+ebp*4-4], eax
	mov	al, [edx+2]
	mov	[edi+Finetunes+ebp-1], al
	mov	al, [edx+3]
	mov	[edi+DefVolumes+ebp-1], al
	mov	DPtr [edi+MidCFreqs+ebp*4-4], ModMidCFreq
	add	edx, 30
	inc	ebp
        cmp     ebp, InstrCount
	jbe	ChunkLoadLoop

	Free	ChunkBufPtr, 65536
        Print   LoadedMsg
	clc
	ret

SmplLoadError:
	Free	ChunkBufPtr, 65536
	stc
	ret

LoadSamples     EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
GetChunk        Proc    Near

	push	ebx ecx edx edi
	mov	ebx, FPos
	add	FPos, ecx
	mov	edx, FNamePtr
	mov	edi, esi
	call	DataFileRead
        pop     edi edx ecx ebx
	ret

GetChunk        EndP
;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º                                  D A T A                                    º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
ModCmdParsers   DD      Offset SlideCommands    ; Arpeggio initializer.
		DD	Offset SlideCommands	; PortamentoUp initializer.
		DD	Offset SlideCommands	; PortamentoDown initializer.
		DD	Offset InitTonePort	; Tone Portamento initializer.
		DD	Offset InitVibrato	; Vibrato initializer.
		DD	Offset InitTone&VSlide	; Portamento+Slide initializer.
		DD	Offset SlideCommands	; Vibrato+Slide initializer.
		DD	Offset InitTremolo	; Tremolo initializer.
		DD	Offset Dummy		; No command 8 --> No handler.
		DD	Offset SetSampleOffs	; Handler for Set Sampleoffset.
		DD	Offset SlideCommands	; VolumeSlide initializer.
		DD	Offset PositionJump	; Handler for Position Jump.
		DD	Offset SetVolume	; Handler for Volume Change.
		DD	Offset BreakPattern	; Handler for Break Pattern.
		DD	Offset ParsePTCommands	; ProTracker E-cmd initializer.
		DD	Offset SetTempo 	; Handler for Set Tempo.

ModCmdHandlers	DD	Offset Arpeggio 	; Handler for Arpeggio.
		DD	Offset PortamentoUp	; Handler for Portamento Up.
		DD	Offset PortamentoDown	; Handler for Portamento Down.
		DD	Offset TonePortamento	; Handler for Tone Portamento.
		DD	Offset Vibrato		; Handler for Vibrato.
		DD	Offset Port_&_Slide	; Handler for VolSlide+Port.
		DD	Offset Vibrato_&_Slide	; Handler for VolSlide+Vibrato.
		DD	Offset Tremolo		; Handler for Tremolo.
		DD	Offset Dummy		; No command 8 --> no handler.
		DD	Offset Dummy		; No handler for command #9.
		DD	Offset VolumeSlide	; Handler for Volume Slide.
		DD	Offset Dummy		; No handler for command #11.
		DD	Offset Dummy		; No handler for command #12.
		DD	Offset Dummy		; No handler for command #13.
		DD	Offset RetrigNote	; Handler for Retrig Note.
		DD	Offset NoteCut		; Handler for Note Cut.
		DD	Offset NoteDelay	; Handler for Note Delay.

PT_Parsers	DD	Offset Dummy		; No handler for Set Filter.
		DD	Offset FineSlideUp	; Handler for FineSlide Up.
		DD	Offset FineSlideDown	; Handler for FineSlide Down.
		DD	Offset SetGlissControl	; No Glissando Control yet.
		DD	Offset SetVibControl	; Handler for Set Vibrato Ctrl.
		DD	Offset SetFineTune	; Handler for Set FineTune.
		DD	Offset PatternLoop	; Handler for PatternLoop.
		DD	Offset SetTreControl	; Handler for Set Tremolo Ctrl.
		DD	Offset Dummy		; No KarPlusStrong yet.
		DD	Offset InitRetrigNote	; Handler for Retrig Note.
		DD	Offset FineVolSldUp	; Handler for FineVolSld Up.
		DD	Offset FineVolSldDown	; Handler for FineVolSld Down.
		DD	Offset InitNoteCut	; Initializer for Note Cut.
		DD	Offset InitNoteDelay	; Initializer for Note Delay.
		DD	Offset PatternDelay	; Handler for Pattern Delay.
		DD	Offset Dummy		; No FunkIt yet.

;ÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ
PeriodTable	Label	Word
	DW	856,808,762,720,678,640,604,570,538,508,480,453
	DW	428,404,381,360,339,320,302,285,269,254,240,226
	DW	214,202,190,180,170,160,151,143,135,127,120,113
	DW	850,802,757,715,674,637,601,567,535,505,477,450
	DW	425,401,379,357,337,318,300,284,268,253,239,225
	DW	213,201,189,179,169,159,150,142,134,126,119,113
	DW	844,796,752,709,670,632,597,563,532,502,474,447
	DW	422,398,376,355,335,316,298,282,266,251,237,224
	DW	211,199,188,177,167,158,149,141,133,125,118,112
	DW	838,791,746,704,665,628,592,559,528,498,470,444
	DW	419,395,373,352,332,314,296,280,264,249,235,222
	DW	209,198,187,176,166,157,148,140,132,125,118,111
	DW	832,785,741,699,660,623,588,555,524,495,467,441
	DW	416,392,370,350,330,312,294,278,262,247,233,220
	DW	208,196,185,175,165,156,147,139,131,124,117,110
	DW	826,779,736,694,655,619,584,551,520,491,463,437
	DW	413,390,368,347,328,309,292,276,260,245,232,219
	DW	206,195,184,174,164,155,146,138,130,123,116,109
	DW	820,774,730,689,651,614,580,547,516,487,460,434
	DW	410,387,365,345,325,307,290,274,258,244,230,217
	DW	205,193,183,172,163,154,145,137,129,122,115,109
	DW	814,768,725,684,646,610,575,543,513,484,457,431
	DW	407,384,363,342,323,305,288,272,256,242,228,216
	DW	204,192,181,171,161,152,144,136,128,121,114,108
	DW	907,856,808,762,720,678,640,604,570,538,508,480
	DW	453,428,404,381,360,339,320,302,285,269,254,240
	DW	226,214,202,190,180,170,160,151,143,135,127,120
	DW	900,850,802,757,715,675,636,601,567,535,505,477
	DW	450,425,401,379,357,337,318,300,284,268,253,238
	DW	225,212,200,189,179,169,159,150,142,134,126,119
	DW	894,844,796,752,709,670,632,597,563,532,502,474
	DW	447,422,398,376,355,335,316,298,282,266,251,237
	DW	223,211,199,188,177,167,158,149,141,133,125,118
	DW	887,838,791,746,704,665,628,592,559,528,498,470
	DW	444,419,395,373,352,332,314,296,280,264,249,235
	DW	222,209,198,187,176,166,157,148,140,132,125,118
	DW	881,832,785,741,699,660,623,588,555,524,494,467
	DW	441,416,392,370,350,330,312,294,278,262,247,233
	DW	220,208,196,185,175,165,156,147,139,131,123,117
	DW	875,826,779,736,694,655,619,584,551,520,491,463
	DW	437,413,390,368,347,328,309,292,276,260,245,232
	DW	219,206,195,184,174,164,155,146,138,130,123,116
	DW	868,820,774,730,689,651,614,580,547,516,487,460
	DW	434,410,387,365,345,325,307,290,274,258,244,230
	DW	217,205,193,183,172,163,154,145,137,129,122,115
	DW	862,814,768,725,684,646,610,575,543,513,484,457
	DW	431,407,384,363,342,323,305,288,272,256,242,228
	DW	216,203,192,181,171,161,152,144,136,128,121,114
	DW	850,802,757,715,674,637,601,567,535,505,477,450
	DW	425,401,379,357,337,318,300,284,268,253,239,225

VibratoTable	DB	  0, 24, 49, 74, 97,120,141,161
		DB	180,197,212,224,235,244,250,253
		DB	255,253,250,244,235,224,212,197
		DB	180,161,141,120, 97, 74, 49, 24

;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
ModPlayerInfo	Label	DWord
MOD_DrvID       DD      0103h

WrapCount	DB	0
MasterVolume	DB	0
TempoMode	DB	0
JumpsDisabled	DB	0
MinPeriod	DD	108
MaxPeriod	DD	894
NoteNum 	DD	36

SongSpeed	DB	0
SongTempo       DB      0

MOD_FunctionPtr DD      0
RowPtr		DD	0
OrigRowPtr	DD	0

; Miscellaneous variables

NextOrder	DD	0
PatternRow	DD	0
TickBytes	DD	0
ReParseCommand	DB	0
PattDelayCnt	DB	1
TickCounter	DD	0
SampleOffset	DD	0
ChannelNum	DD	0

ChannelHandle	DD	8 DUP (0)

; Command Info Blocks

InstrNum	EQU	0			; DD
CmdNumber	EQU	InstrNum+4		; DB
CmdInfo 	EQU	CmdNumber+1		; DB
CurPeriod	EQU	CmdInfo+1		; DD
CurAcc		EQU	CurPeriod+4		; DD
TrueVol 	EQU	CurAcc+4		; DB
FineTune	EQU	TrueVol+1		; DB
WaveCtrl	EQU	FineTune+1		; DB
GlisFunk	EQU	WaveCtrl+1		; DB
TPortaDirec	EQU	GlisFunk+1		; DB
PortInfo	EQU	TPortaDirec+1		; DB
DestPeriod	EQU	PortInfo+1		; DD
VibratoPos	EQU	DestPeriod+4		; DD
VibratoInfo	EQU	VibratoPos+4		; DB
TremoloPos	EQU	VibratoInfo+1		; DD
TremoloInfo	EQU	TremoloPos+4		; DB
LoopRowPtr	EQU	TremoloInfo+1		; DD
LoopPatRow	EQU	LoopRowPtr+4		; DB
LoopCount	EQU	LoopPatRow+1		; DB

CIBLen		EQU	LoopCount+1

; ModData

ChannelInfo	EQU	0h			; 8*CIBLen
Finetunes	EQU	ChannelInfo+(8*CIBLen)	; 32 bytes
DefVolumes	EQU	FineTunes+32		; 32 bytes
SampleHandles   EQU     DefVolumes+32           ; 32 dwords = 128 bytes
MidCFreqs       EQU     SampleHandles+128       ; 32 dwords = 128 bytes
Orders		EQU	MidCFreqs+128		; 128 bytes

ModDataSize     EQU     Orders+128

; Loader Variables

FPos		DD	0
FNamePtr	DD	0
FReadErrMsg     DB      'Error reading module file.',10,13,'$'
LoadingMsg      DB      'Loading instruments$'
DotMsg          DB      '.$'
LoadedMsg       DB      13,10,'$'

ModHeader       DB      1084 dup (0)
PatternSize     DD      0
NumChannels	DD	0
InstrCount	DD	0
PatternBase	DD	0
SongLength      DD      0
HighestUsed	DD	0
HighestSaved	DD	0
ModDataPtr      DD      0
PatternTotal	DD	0
ChunkBufPtr	DD	0
AllocatedSize   DD      0
RegMemBase      DD      0

TempSample      Label   DWord
LSmplLen	DD	0
LSmplRepeatFrom DD	0
LSmplRepeatTo	DD	0
LSmplFlags	DD	0
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Code32		EndS

                End

