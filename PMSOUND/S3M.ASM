TITLE S3M.ASM - EMF PM Sound System - S3M Player Driver v0.81 by Saint
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ

MaxPatterns     EQU     256
MaxSamples      EQU     99
MaxOrders       EQU     256
ChunkBufSize    EQU     65536
HeadLen         EQU     512
PanLeft         EQU     030h
PanRight        EQU     0C0h


;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ

        .386P

        Uses_Timer = 1                  ; Include timer stuff.
	Uses_Kbd   = 1			; Include keyboard stuff.
	Uses_ExcHandling = 1		; Include the exception handler.
        Uses_DataFileRead = 1
        Uses_Debug=1

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

Public  S3MPlayerDriver
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
S3MPlayerDriver Proc    Near

	pushad
        mov     S3M_FunctionPtr, ebx
        mov     DPtr [ebx+Mus_Reset], Offset S3M_Reset
        mov     DPtr [ebx+Mus_GetInfo], Offset S3M_GetInfo
        mov     DPtr [ebx+Mus_Start], Offset S3M_Start
        mov     DPtr [ebx+Mus_Stop], Offset S3M_Stop
        mov     DPtr [ebx+Mus_Resume], Offset S3M_Resume
        mov     DPtr [ebx+Mus_SetPos], Offset S3M_SetPos
        mov     DPtr [ebx+Mus_GetPos], Offset S3M_GetPos
        mov     DPtr [ebx+Mus_Load], Offset S3M_Load
        mov     DPtr [ebx+Mus_UnLoad], Offset S3M_UnLoad
	or	DPtr [ebx+DrvInited], 08h
	popad
	clc
	ret

S3MPlayerDriver EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
S3M_Reset       Proc    Near

        pushad
        mov     ebx, S3M_FunctionPtr
        mov     ebp, 0
ChannelLoop:
        mov     cl, ChanSetting[ebp]
        cmp     cl, 16
        jnb     NoChannel
        call    [ebx+Sd_AllocChan]
        mov     ChannelHandle[ebp*4], eax
        test    DefPans[ebp], 32
        jz      UseDefaultPans
        xor     edx, edx
        mov     dl, DefPans[ebp]
        shl     dl, 4
        jmp     NotR
UseDefaultPans:
        cmp     StereoMode, 0
        jnz     IsStereo
        mov     edx, 128
        jmp     NotR
IsStereo:
        mov     edx, PanLeft
        cmp     cl, 8
        jb      NotR
        mov     edx, PanRight
NotR:   xor     eax, eax
        mov     eax, ChannelHandle[ebp*4]
        call    [ebx+Sd_SetBalance]
        mov     NumChannels, ebp
NoChannel:
        inc     ebp
        cmp     ebp, 32
        jb      ChannelLoop
        inc     NumChannels

        cmp     ChanInfoPtr, 0
        jz      NoCIBFree
        mov     edx, ChanInfoLen
        Free    ChanInfoPtr, edx
        mov     ChanInfoPtr, 0
NoCIBFree:

        mov     ecx, NumChannels
        imul    ecx, ChanIBLen
        mov     ChanInfoLen, ecx
        Alloc   ChanInfoPtr, ChanInfoLen

        mov     edi, ChanInfoPtr
        mov     ecx, ChanInfoLen
        mov     al, 0
        rep     stosb

        lea     edi, ClearBegin
        lea     ecx, ClearEnd
        sub     ecx, Offset ClearBegin
        xor     al, al
        rep     stosb

        mov     TickCounter, 0

        popad
        clc
        ret

S3M_Reset       EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
S3M_Start       Proc    Near

        mov     WrapCount, 0
        mov     PatternRow, 1
        mov     PattDelayCnt, 1
        mov     PattDelayFlag, 0
        mov     RowsToSkip, 0
        mov     NextOrder, 0
        mov     TickCounter, 0F0h
        mov     al, InitSpeed
        mov     SongSpeed, al
        mov     al, InitTempo
        mov     SongTempo, al
        mov     al, InitGlobalVol
        mov     GlobalVol, al
        call    S3M_Resume
        clc
        ret

S3M_Start       EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
S3M_Resume      Proc    Near

        push    eax ebx edi
        mov     ebx, S3M_FunctionPtr
        lea     edi, S3M_Update
        xor     eax, eax
        mov     al, SongTempo
        imul    eax, 26214
;
        push    ecx
        mov     cl, TempoFact
        cmp     cl, 0
        jz      NoFact
        jl      NegFact
        shl     eax, cl
        jmp     NoFact
NegFact:
        neg     cl
        shr     eax, cl
NoFact:
        pop     ecx
;
        call    [ebx+Sd_TmrReqCall]
        pop     edi ebx eax
        clc
        ret

S3M_Resume      EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
S3M_Stop        Proc    Near

        push    eax ebx ecx
        mov     ebx, S3M_FunctionPtr
        call    [ebx+Sd_TmrStop]
        mov     ecx, 0
StopLoop:
        xor     eax, eax
        mov     eax, ChannelHandle[ecx*4]
        call    [ebx+Sd_StopSample]
        inc     ecx
        cmp     ecx, NumChannels
        jb      StopLoop
        pop     ecx ebx eax
        clc
        ret

S3M_Stop        EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
S3M_SetPos      Proc    Near

        cmp     ebp, 291176h
        jne     IsItTrigger
        mov     TempoFact, cl
        call    S3M_Resume
        ret
IsItTrigger:
        cmp     ebp, 12345678h
        jne     NormalSetPos
        call    S3M_Resume
        ret
NormalSetPos:
        cmp     ebp, 57575757h
        jne     Normal2
        mov     esi, ChanInfoPtr
        mov     eax, ChanIbLen
        imul    eax, 2
        add     esi, eax
;        mov     BPtr [esi.CurCmd], 0
        mov     BPtr [esi.CmdNum], 0
        ret
Normal2:
        shr     eax, 6
        inc     eax
        mov     NextOrder, eax
        mov     PatternRow, 1
        clc
        ret

S3M_SetPos      EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
S3M_GetPos      Proc    Near

        cmp     ebp, 291176h
        jne     NoPlot
        mov     TempoFact, cl
        cmp     ebx, 8
        jne     SetSolo
        mov     SoloChan, 0
        jmp     CallScr
SetSolo:
        add     ebx, eax
        dec     ebx
        mov     SoloChan, ebx
CallScr:
        pushad
        call    PrepScreen
        call    PutScreen
        popad
NoPlot:
        push    ebx
        mov     eax, 64
        sub     eax, PatternRow
        mov     ebx, NextOrder
        dec     ebx
        shl     ebx, 6
;        shl     ebx, 8
        add     eax, ebx
;
;        and     eax, 0FFFFh
;        mov     bl, SongSpeed
;        mov     bh, SongTempo
;        shl     ebx, 16
;        or      eax, ebx
;
        pop     ebx
        mov     edx, WrapCount
;        lea     ebx, defvolumes
	clc
	ret

S3M_GetPos      EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
S3M_GetInfo     Proc    Near

        lea     eax, S3MPlayerInfo
	clc
	ret

S3M_GetInfo     EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
S3M_Update      Proc    Near

        call    UpdateModule
        clc
        ret

S3M_Update      EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
UpdateModule    Proc    Near

        mov     esi, ChanInfoPtr
        inc     TickCounter
        mov     eax, TickCounter
        cmp     al, SongSpeed
        jb      NoNewRow
        mov     TickCounter, 0

;        dec     PattDelayCnt
;        jnz     NoNewRow
;        mov     PattDelayCnt, 1

        call    ClearCmds
        call    ParsePattern
;;;;;;
        ret

NoNewRow:
        mov     esi, ChanInfoPtr
        mov     ChannelNum, 0
        mov     ecx, NumChannels
HandleLoop:
        push    ecx
        xor     ebx, ebx
        mov     bl, [esi.CmdNum]
        call    CommandHandlers[ebx*4]
        add     esi, ChanIBLen
        pop     ecx
        inc     ChannelNum
        loop    HandleLoop
        ret

UpdateModule    EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
ClearCmds       Proc    Near

        mov     esi, ChanInfoPtr
        mov     ecx, NumChannels
ClearLoop:
        mov     BPtr [esi.CurCmd], 0
        mov     BPtr [esi.CmdNum], 0
        add     esi, ChanIBLen
        dec     ecx
        jnz     ClearLoop
        ret

ClearCmds       EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
ParsePattern    Proc    Near

        dec     PattDelayCnt
        jz      NoPattDelay
        mov     edi, OrigRowPtr
        mov     RowPtr, edi
        jmp     GotOrder
NoPattDelay:
        mov     PattDelayCnt, 1
        mov     PattDelayFlag, 0
        dec     PatternRow
        jnz     GotOrder
        call    GetNextOrder
GotOrder:
        mov     edi, RowPtr
        xor     ecx, ecx
        or      ecx, RowsToSkip
        jz      NoSkipRows
        call    SkipRows
NoSkipRows:
        mov     OrigRowPtr, edi
        mov     ebp, ChanInfoPtr

ParseLoop:
        xor     eax, eax
        mov     al, [edi]
        inc     edi
        cmp     al, 0
        jz      EndOfRow
        mov     CurFlags, al
        and     al, 1Fh
        cmp     ChanSetting[eax], 16
        jb      ChannelOk
        call    SkipChannel
        jmp     ParseLoop

ChannelOk:
        mov     ChannelNum, eax
        mov     esi, ChanIBLen
        imul    esi, eax
        add     esi, ebp
        mov     DPtr [esi.InstrPtr], 0FFFFFFFFh
        call    UnpackChannel
        call    GetNote
        call    ParseCommands
        cmp     BPtr [esi.CmdNum], 0Eh
        je      ParseLoop
        call    PlayChannel
        jmp     ParseLoop

EndOfRow:
        mov     RowPtr, edi
        ret

ParsePattern    EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
SkipRows        Proc    Near

        xor     eax, eax
        mov     al, [edi]
        inc     edi
        cmp     al, 0
        jz      NextRow
        mov     CurFlags, al
        call    SkipChannel
        jmp     SkipRows
NextRow:
        dec     PatternRow
        dec     ecx
        jnz     SkipRows
        mov     RowPtr, edi
        mov     RowsToSkip, 0
        ret

SkipRows        EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
SkipChannel     Proc    Near

        test    CurFlags, 20h
        jz      SkipNote
        add     edi, 2
SkipNote:
        test    CurFlags, 40h
        jz      SkipVol
        inc     edi
SkipVol:
        test    CurFlags, 80h
        jz      SkipCmd
        add     edi, 2
SkipCmd:
        mov     RowPtr, edi
        ret

SkipChannel     EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
UnpackChannel   Proc    Near

        mov     Note, 255
        mov     Inst, 0
        test    CurFlags, 20h
        jz      NoNote
        mov     al, [edi]
        mov     Note, al
        mov     al, [edi+1]
        mov     Inst, al
        add     edi, 2
NoNote: test    CurFlags, 40h
        jz      NoVol
        mov     al, [edi]
        inc     edi
        cmp     al, 255
        je      NoVol
        mov     [esi.CurVol], al
NoVol:  mov     BPtr [esi.CurCmd], 0
        test    CurFlags, 80h
        jz      NoCmd
        mov     al, [edi]
        and     al, 1Fh
        mov     [esi.CurCmd], al
        mov     al, [edi+1]
        mov     [esi.CurInfo], al
        add     edi, 2
NoCmd:
        mov     RowPtr, edi
        ret

UnpackChannel   EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
GetNote         Proc    Near

        cmp     PattDelayFlag, 0
        jnz     NoNoteFound

        cmp     Note, 254
        je      StopNote
        jnb     TakeDefVol
        jnb     NoNoteFound

        cmp     BPtr [esi.CurCmd], 7
        je      GetTonePortDest

NoteFound:
        xor     eax, eax
        mov     [esi.InstrPtr], eax
        mov     al, Inst
        cmp     al, 0
        jz      NoInstrFound
        dec     eax
        mov     [esi.InstrNum], eax
NoInstrFound:
        xor     eax, eax
        mov     al, Note
        mov     cl, al
        and     al, 0Fh
        shr     cl, 4
        mov     [esi.CurNote], al
        mov     [esi.CurOctave], cl
        call    NoteToPeriod
        mov     [esi.CurPeriod], eax
        call    PeriodToFreq
TakeDefVol:
        cmp     Inst, 0
        jz      NoNoteFound
        test    CurFlags, 40h
        jnz     NoNoteFound
        mov     eax, [esi.InstrNum]
        mov     al, DefVolumes[eax]
        mov     [esi.CurVol], al
NoNoteFound:
        ret

StopNote:
        mov     ecx, ChannelNum
        xor     eax, eax
        mov     eax, ChannelHandle[ecx*4]
;
;        cmp     eax, 0
;        jnz     Not0Ch
;        mov     eax, 29110000h
;        int     01h
;Not0Ch:
;
        mov     ebx, S3M_FunctionPtr
        call    [ebx+Sd_StopSample]
        ret

GetTonePortDest:
        xor     eax, eax
        mov     al, Inst
        cmp     al, 0
        jz      NoInstrFound2
        dec     eax
        mov     [esi.InstrNum], eax
        test    CurFlags, 40h
        jnz     NoInstrFound2
        mov     eax, [esi.InstrNum]
        mov     al, DefVolumes[eax]
        mov     [esi.CurVol], al
;        xor     eax, eax
;        mov     [esi.InstrPtr], eax
NoInstrFound2:
        xor     eax, eax
        mov     al, Note
        mov     cl, al
        and     al, 0Fh
        shr     cl, 4
        mov     [esi.CurNote], al
        mov     [esi.CurOctave], cl
        call    NoteToPeriod
        mov     [esi.DestPeriod], eax
        cmp     DPtr [esi.CurPeriod], 0
        jz      NoteFound
        ret

GetNote         EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
ParseCommands   Proc    Near

        push    edi
        xor     eax, eax
        mov     [esi.CmdNum], al
        mov     al, [esi.CurCmd]
        call    CommandParsers[eax*4]
        pop     edi
        ret

ParseCommands   EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
PlayChannel     Proc    Near

        cmp     [esi.InstrPtr], 0FFFFFFFFh
        je      DontPlay
        mov     ebx, S3M_FunctionPtr
        mov     ecx, ChannelNum
;        cmp     ecx, 3
;        jne     DontPlay
        xor     eax, eax
        mov     eax, ChannelHandle[ecx*4]
;
;        cmp     eax, 0
;        jnz     Not0Ch2
;        mov     eax, 29110002h
;        int     01h
;Not0Ch2:
;
        movzx   edx, BPtr [esi.InstrNum]
        mov     edx, SampleHandles[edx*4]
        push    esi
        mov     esi, [esi.InstrPtr]
        call    [ebx+Sd_SetSample]
        pop     esi
DontPlay:
        cmp     BPtr [esi.CmdNum], 08h
        je      NoDefFreq
        cmp     BPtr [esi.CmdNum], 0Bh
        je      NoDefFreq
        mov     eax, [esi.CurPeriod]
        call    PeriodToFreq
NoDefFreq:
        call    PlayFrequency
        call    SetCurVol
        ret

PlayChannel     EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
SetCurVol       Proc    Near

        mov     ecx, ChannelNum
        cmp     SoloChan, 0
        jz      NoSolo
        mov     eax, ecx
        inc     eax
        cmp     eax, SoloChan
        je      NoSolo
        mov     eax, ChannelHandle[ecx*4]
;
;        cmp     eax, 0
;        jnz     Not0Ch3
;        mov     eax, 29110003h
;        int     01h
;Not0Ch3:
;
        mov     ebx, S3M_FunctionPtr
        mov     edx, 0
        call    [ebx+Sd_SetVolume]
        ret
NoSolo:
        xor     eax, eax
        mov     eax, ChannelHandle[ecx*4]
;
;        cmp     eax, 0
;        jnz     Not0Ch4
;        mov     eax, 29110004h
;        int     01h
;Not0Ch4:
;
        mov     ebx, S3M_FunctionPtr
        xor     ecx, ecx
        mov     cl, [esi.CurVol]
        mov     edx, 255
        imul    edx, ecx
        xor     ecx, ecx
        mov     cl, GlobalVol
        imul    edx, ecx
        shr     edx, 12
        call    [ebx+Sd_SetVolume]
        ret

SetCurVol       EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
PlayFrequency   Proc    Near

        mov     ecx, ChannelNum
        xor     eax, eax
        mov     eax, ChannelHandle[ecx*4]
;
;        cmp     eax, 0
;        jnz     Not0Ch5
;        mov     eax, 29110005h
;        int     01h
;Not0Ch5:
;
        mov     ebx, S3M_FunctionPtr
        mov     edx, [esi.CurFreq]
        call    [ebx+Sd_SetFreq]
        ret

PlayFrequency   EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
GetNextOrder    Proc    Near

        mov     PatternRow, 64
;
;        mov     al, 65
;        mov     esi, ChanInfoPtr
;        mov     ecx, NumChannels
;LoopRowLoop:
;        mov     [esi.LoopPatRow], al
;        add     esi, ChanIBLen
;        loop    LoopRowLoop
;

ReGetOrder:
        mov     ebx, NextOrder
        cmp     ebx, NumOrders
        jb      NoWrapAround

WrapAround:
        inc     WrapCount
        xor     eax, eax
        mov     al, InitSpeed
        mov     SongSpeed, al
        mov     al, InitTempo
        mov     SongTempo, al
        imul    eax, 26214
;
        push    ecx
        mov     cl, TempoFact
        cmp     cl, 0
        jz      NoFact2
        jl      NegFact2
        shl     eax, cl
        jmp     NoFact2
NegFact2:
        neg     cl
        shr     eax, cl
NoFact2:
        pop     ecx
;
        lea     edi, S3M_Update
        mov     ebx, S3M_FunctionPtr
        call    [ebx+Sd_TmrReqCall]
        xor     ebx, ebx

NoWrapAround:
        xor     eax, eax
        mov     al, Orders[ebx]
        inc     ebx
        mov     NextOrder, ebx
        cmp     al, 254
        je      ReGetOrder
        ja      WrapAround
        mov     eax, PatternPtr[eax*4]
        mov     RowPtr, eax
;
;        mov     esi, ChanInfoPtr
;        mov     ecx, NumChannels
;LoopPtrLoop:
;        mov     [esi.LoopPatPtr], eax
;        add     esi, ChanIBLen
;        loop    LoopPtrLoop
;
        ret

GetNextOrder    EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
; note in al and octave in cl to period in eax
; changes: ebx, ecx, edx
NoteToPeriod    Proc    Near

;        cmp     ChannelNum, 2
;        jne     No3
;        cmp     DPtr [esi.InstrNum], 7
;        jne     No3
;        mov     PressedKey, 0
;@wk7:   cmp     PressedKey, 0
;        jz      @wk7
;        int     01h
;No3:
        mov     eax, OrigPeriod[eax*4]
        shr     eax, cl
        imul    eax, 8363
        xor     edx, edx
        mov     ebx, [esi.InstrNum]
        mov     ecx, C4Freqs[ebx*4]
        cmp     ecx, 0                  ; MICKUS.S3M: pattern 24 row 1,
        jnz     InstrOk                 ; uses illegal instrument!
        mov     ecx, 8363
InstrOk:
        div     ecx
        ret

NoteToPeriod    EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
PeriodToFreq    Proc    Near

        mov     ecx, eax
        xor     edx, edx
        mov     eax, 14317056*4
        cmp     ecx, 0
        jnz     PeriodOk
        inc     ecx
PeriodOk:
        div     ecx
        mov     [esi.CurFreq], eax
        ret

PeriodToFreq    EndP
;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º									       º
;º		O N E - P A S S   C O M M A N D   H A N D L E R S	       º
;º									       º
;ÇÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¶
;º Information about all one-pass command handlers in general:		       º
;º									       º
;º INPUT:       ESI = Pointer to current channel's Command Info Block.         º
;º FUNCTION:	Init the possible multiple-pass commands for each channel.     º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
SetSpeed        Proc    Near

        mov     al, [esi.CurInfo]
        mov     SongSpeed, al
        mov     TickCounter, 0
        ret

SetSpeed        EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
SetTempo        Proc    Near

        xor     eax, eax
        mov     al, [esi.CurInfo]
        mov     SongTempo, al
        imul    eax, 26214
;
        push    ecx
        mov     cl, TempoFact
        cmp     cl, 0
        jz      NoFact3
        jl      NegFact3
        shl     eax, cl
        jmp     NoFact3
NegFact3:
        neg     cl
        shr     eax, cl
NoFact3:
        pop     ecx
;
        lea     edi, S3M_Update
        mov     ebx, S3M_FunctionPtr
        call    [ebx+Sd_TmrReqCall]
        ret

SetTempo        EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
PositionJump    Proc    Near

        cmp     JumpsDisabled, 0
        jnz     Dummy
        xor     eax, eax
        mov     al, [esi.CurInfo]
        mov     NextOrder, eax
        mov     PatternRow, 1
        ret

PositionJump    EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
PatternBreak    Proc    Near

        xor     eax, eax
        mov     al, [esi.CurInfo]
        mov     ebx, eax
        shr     ebx, 4
        imul    ebx, 10
        and     eax, 0Fh
        add     eax, ebx
        mov     RowsToSkip, eax
        mov     PatternRow, 1
        ret

PatternBreak    EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
SampleOffset    Proc    Near

        xor     eax, eax
        or      al, [esi.CurInfo]
        jz      OldOfs
        mov     [esi.OffsetInfo], al
OldOfs: mov     al, [esi.OffsetInfo]
        shl     eax, 8
        mov     [esi.InstrPtr], eax
        ret

SampleOffset    EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
ParseExtra      Proc    Near

        xor     eax, eax
        mov     al, [esi.CurInfo]
        shr     eax, 4
        call    ExtraParsers[eax*4]
        ret

ParseExtra      EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
GlissandoCtrl   Proc    Near

        mov     al, [esi.CurInfo]
        and     al, 0Fh
        and     BPtr [esi.GlisFunk], 0F0h
        or      [esi.GlisFunk], al
        ret

GlissandoCtrl   EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
SetC4Spd        Proc    Near

        xor     eax, eax
        mov     al, [esi.CurInfo]
        and     al, 0Fh
        mov     eax, FineC4Spd[eax*4]
        xor     ebx, ebx
        mov     bl, [esi.InstrNum]
        mov     C4Freqs[ebx*4], eax
        ret

SetC4Spd        EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
VibratoCtrl     Proc    Near

        mov     al, [esi.CurInfo]
        and     al, 0Fh
        and     BPtr [esi.WaveCtrl], 0F0h
        or      [esi.WaveCtrl], al
        ret

VibratoCtrl     EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
TremoloCtrl     Proc    Near

        mov     al, [esi.CurInfo]
        shl     al, 4
        and     BPtr [esi.WaveCtrl], 0Fh
        or      [esi.WaveCtrl], al
        ret

TremoloCtrl     EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
SetPanPos       Proc    Near

        mov     ecx, ChannelNum
        mov     eax, ChannelHandle[ecx*4]
        xor     edx, edx
        mov     dl, [esi.CurInfo]
        shl     dl, 4
        mov     ebx, S3M_FunctionPtr
        call    [ebx+Sd_SetBalance]
        ret

SetPanPos       EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
SetGlobalVol    Proc    Near

        mov     al, [esi.CurInfo]
        mov     GlobalVol, al
        ret

SetGlobalVol    EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
PatternDelay    Proc    Near

        cmp     PattDelayFlag, 0
        jnz     DontDelay
        not     PattDelayFlag
        xor     eax, eax
        mov     al, [esi.CurInfo]
        and     al, 0Fh
        inc     al
        add     PattDelayCnt, eax
DontDelay:
        ret

PatternDelay    EndP
;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º									       º
;º     M U L T I P L E - P A S S   C O M M A N D   I N I T I A L I Z E R S     º
;º									       º
;ÇÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¶
;º Information about all command initializers in general:		       º
;º									       º
;º INPUT:       ESI = Pointer to current channel's Command Info Block.         º
;º FUNCTION:	Init the possible multiple-pass commands for each channel.     º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
VolSlideInit    Proc    Near

        xor     eax, eax
        or      al, [esi.CurInfo]
        jz      OldVS
        mov     [esi.CmdInfo], al
OldVS:  mov     al, [esi.CmdInfo]
        mov     ah, al
        and     ah, 0Fh
        cmp     ah, 0Fh
        je      FineVolUp
        mov     ah, al
        and     ah, 0F0h
        cmp     ah, 0F0h
        je      FineVolDown
NormalVSlide:
        mov     BPtr [esi.CmdNum], 04h
        ret

FineVolUp:
        shr     al, 4
        jz      NormalVSlide
AddUp:  add     al, [esi.CurVol]
        cmp     al, 64
        jbe     UpOk
        mov     al, 64
UpOk:   mov     [esi.CurVol], al
        ret

FineVolDown:
        mov     ah, [esi.CurVol]
        and     al, 0Fh
        jz      NormalVSlide
        sub     ah, al
        jnb     DownOk
        xor     ah, ah
DownOk: mov     [esi.CurVol], ah
        ret

VolSlideInit    EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
SlideDownInit   Proc    Near

        xor     eax, eax
        or      al, [esi.CurInfo]
        jz      OldSd
        mov     [esi.CmdInfo], al
OldSd:  mov     al, [esi.CmdInfo]
        cmp     al, 0DFh
        ja      FineSlideDown
        cmp     al, 0
        jz      SkpSD
        mov     [esi.CmdInfo], al
SkpSD:  mov     BPtr [esi.CmdNum], 05h
        ret

FineSlideDown:
        cmp     al, 0F0h
        jb      ExtraFineDown
        and     al, 0Fh
        shl     eax, 4
DoDown: add     [esi.CurPeriod], eax
        ret

ExtraFineDown:
        and     al, 0Fh
        shl     eax, 2
        jmp     DoDown

SlideDownInit   EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
SlideUpInit     Proc    Near

        xor     eax, eax
        or      al, [esi.CurInfo]
        jz      OldSu
        mov     [esi.CmdInfo], al
OldSu:  mov     al, [esi.CmdInfo]
        cmp     al, 0DFh
        ja      FineSlideUp
        mov     BPtr [esi.CmdNum], 06h
        ret

FineSlideUp:
        cmp     al, 0F0h
        jb      ExtraFineUp
        and     al, 0Fh
        shl     eax, 4
DoUp:   sub     [esi.CurPeriod], eax
        ret

ExtraFineUp:
        and     al, 0Fh
        shl     eax, 2
        jmp     DoUp

SlideUpInit     EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
TonePortaInit   Proc    Near

        xor     eax, eax
        or      al, [esi.CurInfo]
        jz      NoPortInfo
        mov     [esi.PortInfo], al
NoPortInfo:
        mov     eax, [esi.CurPeriod]
        cmp     eax, [esi.DestPeriod]
        seta    [esi.TPortaDirec]
        mov     BPtr [esi.CmdNum], 07h
        ret

TonePortaInit   EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
VibratoInit     Proc    Near

        mov     BPtr [esi.CmdNum], 08h
        xor     edx, edx
        or      dh, [esi.CurInfo]
        jz      Dummy
        xor     eax, eax
        mov     al, [esi.VibratoInfo]
        mov     dl, dh
        and     dl, 0Fh
        jz      VibSkip
        and     al, 0F0h
        or      al, dl
VibSkip:
        mov     dl, dh
        and     dl, 0F0h
        jz      VibSkip2
        and     al, 0Fh
        or      al, dl
VibSkip2:
        mov     [esi.VibratoInfo], eax
        ret

VibratoInit     EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
TremoloInit     Proc    Near

        mov     BPtr [esi.CmdNum], 12h
        xor     edx, edx
        or      dh, [esi.CurInfo]
        jz      Dummy
        xor     eax, eax
        mov     al, [esi.TremoloInfo]
        mov     dl, dh
        and     dl, 0Fh
        jz      TreSkip
        and     al, 0F0h
        or      al, dl
TreSkip:
        mov     dl, dh
        and     dl, 0F0h
        jz      TreSkip2
        and     al, 0Fh
        or      al, dl
TreSkip2:
        mov     [esi.TremoloInfo], eax
        ret

TremoloInit     EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
FineVibratoInit Proc    Near

        mov     BPtr [esi.CmdNum], 15h
        xor     edx, edx
        or      dh, [esi.CurInfo]
        jz      Dummy
        mov     eax, 100h
        mov     al, [esi.VibratoInfo]
        mov     dl, dh
        and     dl, 0Fh
        jz      FineSkip
        and     al, 0F0h
        or      al, dl
FineSkip:
        mov     dl, dh
        and     dl, 0F0h
        jz      FineSkip2
        and     al, 0Fh
        or      al, dl
FineSkip2:
        mov     [esi.VibratoInfo], eax
        ret

FineVibratoInit EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
NoteCutInit     Proc    Near

        mov     al, 0Dh
        mov     [esi.CmdNum], al
        xor     eax, eax
        or      al, [esi.CurInfo]
        jz      OldCut
        mov     [esi.CmdInfo], al
OldCut: ret

NoteCutInit     EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
NoteDelayInit   Proc    Near

        mov     al, 0Eh
        mov     [esi.CmdNum], al
        xor     eax, eax
        or      al, [esi.CurInfo]
        jz      OldDly
        mov     [esi.CmdInfo], al
OldDly: ret

NoteDelayInit   EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
SlideInit       Proc    Near

        mov     al, [esi.CurCmd]
        mov     [esi.CmdNum], al
        xor     eax, eax
        or      al, [esi.CurInfo]
        jz      OldSl
        mov     [esi.CmdInfo], al
OldSl:  mov     eax, [esi.CurPeriod]
        cmp     eax, [esi.DestPeriod]
        seta    [esi.TPortaDirec]
        ret

SlideInit       EndP
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
VolumeSlide     Proc    Near

        mov     bl, [esi.CmdInfo]
        mov     al, [esi.CurVol]
        test    bl, 0F0h
        jnz     SlideVolUp
        and     bl, 0Fh
        sub     al, bl
        jnb     SaveNewVol
        xor     al, al

SaveNewVol:
        mov     [esi.CurVol], al
        call    SetCurVol
        ret

SlideVolUp:
        shr     bl, 4
        add     al, bl
        cmp     al, 64
        jbe     SaveNewVol
        mov     al, 64
        jmp     SaveNewVol

VolumeSlide     EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
SlideDown       Proc    Near

        mov     eax, [esi.CurPeriod]
        xor     ebx, ebx
        mov     bl, [esi.CmdInfo]
        shl     ebx, 4
        add     eax, ebx
; Check limits?
        mov     [esi.CurPeriod], eax
        call    PeriodToFreq
        call    PlayFrequency
        ret

SlideDown       EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
SlideUp         Proc    Near

        mov     eax, [esi.CurPeriod]
        xor     ebx, ebx
        mov     bl, [esi.CmdInfo]
        shl     ebx, 4
        sub     eax, ebx
; Check limits?
        mov     [esi.CurPeriod], eax
        call    PeriodToFreq
        call    PlayFrequency
        ret

SlideUp         EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
TonePortamento  Proc    Near

        xor     eax, eax
        mov     al, [esi.PortInfo]
        shl     eax, 4
        mov     ecx, [esi.CurPeriod]
        mov     edx, [esi.DestPeriod]
        or      edx, edx
        jz      NoPortamento
        cmp     ecx, edx
        je      NoPortamento
        cmp     BPtr [esi.TPortaDirec], 1
        je      PortaUp
PortaDown:
        add     ecx, eax
        cmp     ecx, edx
        jle     NoPortamento
        mov     ecx, edx
        mov     DPtr [esi.DestPeriod], 0
        jmp     NoPortamento
PortaUp:
        sub     ecx, eax
        cmp     ecx, edx
        jg      NoPortamento
        mov     ecx, edx
        mov     DPtr [esi.DestPeriod], 0

NoPortamento:
        mov     [esi.CurPeriod], ecx
        mov     al, [esi.GlisFunk]
        and     al, 0Fh
        jz      NoGlissando

        mov     ebx, [esi.InstrNum]
        mov     eax, C4Freqs[ebx*4]
        cmp     eax, 0
        jnz     InstrOk2
        mov     eax, 8636
InstrOk2:
        imul    eax, ecx
        xor     edx, edx
        mov     ecx, 8363
        div     ecx

        xor     ebx, ebx
OctaveLoop:
        cmp     eax, OrigPeriod[11*4]
        ja      OctaveFound
        shl     eax, 1
        inc     ebx
        jmp     OctaveLoop

OctaveFound:
        mov     ecx, 0
NoteLoop:
        cmp     eax, OrigPeriod[ecx*4]
        ja      NoteFound2
        inc     ecx
        jmp     NoteLoop

NoteFound2:
        mov     eax, ecx
        mov     ecx, ebx
        sub     eax, 1
        jnc     OctOk
        dec     ecx
        mov     eax, 11
OctOk:  call    NoteToPeriod
        mov     ecx, eax

NoGlissando:
        mov     eax, ecx                  ;[esi.CurPeriod]
        call    PeriodToFreq
        call    PlayFrequency
        ret

TonePortamento  EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Vibrato         Proc    Near

        xor     eax, eax
        mov     al, [esi.VibratoInfo]
        mov     edi, [esi.VibratoPos]
        mov     ecx, eax
        shr     ecx, 4
        add     [esi.VibratoPos], ecx
        mov     ecx, edi
        and     edi, 001Fh

        mov     dl, [esi.WaveCtrl]
        and     dl, 0Fh
        jz      VibSine
        shl     edi, 3
        cmp     dl, 1
        je      VibRampDown
        mov     ebx, 255
        jmp     VibSet

VibRampDown:
        mov     ebx, edi
        test    cl, 20h
        jz      VibSet
        mov     ebx, 255
        sub     ebx, edi
        jmp     VibSet

VibSine:
        movzx   ebx, VibratoTable[edi]

VibSet:
        and     al, 0Fh
        imul    ebx, eax
        shr     ebx, 3
        test    BPtr [esi.VibratoInfo+1], 01h
        jz      NotFine
        shr     ebx, 2
NotFine:
        mov     eax, [esi.CurPeriod]
        sub     eax, ebx
        test    cl, 20h
        jz      VibratoUp
        add     eax, ebx
        add     eax, ebx
VibratoUp:
        call    PeriodToFreq
        call    PlayFrequency
        ret

Vibrato         EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Tremolo         Proc    Near

        xor     eax, eax
        mov     al, [esi.TremoloInfo]
        mov     edi, [esi.TremoloPos]
        mov     ecx, eax
        shr     ecx, 4
        add     [esi.TremoloPos], ecx
        mov     ecx, edi
        and     edi, 001Fh

        mov     dl, [esi.WaveCtrl]
        shr     dl, 4
        or      dl, dl
        jz      TreSine
        shl     edi, 3
        cmp     dl, 1
        je      TreRampDown
        mov     ebx, 255
        jmp     TreSet

TreRampDown:
        mov     ebx, edi
        test    cl, 20h
        jz      TreSet
        mov     ebx, 255
        sub     ebx, edi
        jmp     TreSet

TreSine:
        movzx   ebx, VibratoTable[edi]

TreSet:
        and     al, 0Fh
        imul    ebx, eax
        shr     ebx, 7
        mov     al, [esi.CurVol]
        sub     al, bl
        test    cl, 20h
        jnz     TremoloTest
        add     al, bl
        add     al, bl

TremoloTest:
        or      al, al
        jns     TSkip
        xor     al, al
TSkip:
        cmp     al, 40h
        jb      TSkip2
        mov     al, 40h
TSkip2:
        mov     cl, [esi.CurVol]
        push    ecx
        mov     [esi.CurVol], al
        mov     [esi.TreCurVol], al
        call    SetCurVol
        pop     ecx
        mov     [esi.CurVol], cl
        ret

Tremolo         EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Port&Slide      Proc    Near

        call    TonePortamento
        call    VolumeSlide
        ret

Port&Slide      EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Vibrato&Slide   Proc    Near

        call    Vibrato
        call    VolumeSlide
        ret

Vibrato&Slide   EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Tremor          Proc    Near

        cmp     BPtr [esi.CmdInfo], 0
        jz      Dummy
        mov     eax, TickCounter
        mov     bl, [esi.CmdInfo]
        mov     dl, bl
        and     dl, 0Fh
        shr     bl, 4
        add     dl, bl
        div     dl
        mov     cl, [esi.CurVol]
        mov     dl, cl
        cmp     ah, bl
        jb      VolOn
        mov     dl, 0
VolOn:
        push    ecx
        mov     [esi.CurVol], dl
        call    SetCurVol
        pop     ecx
        mov     [esi.CurVol], cl
        ret

Tremor          EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Arpeggio        Proc    Near

        cmp     BPtr [esi.CmdInfo], 0
        jz      Dummy
        mov     eax, TickCounter
        mov     edx, 3
        div     dl
        mov     dl, [esi.CmdInfo]
        cmp     ah, 1
        je      Arpeg1
        cmp     ah, 2
        je      Arpeg2
        mov     eax, [esi.CurPeriod]
        jmp     SetArpPeriod

Arpeg1: shr     dl, 4
        jmp     SetArpeggio
Arpeg2: and     dl, 0Fh

SetArpeggio:
        mov     ebx, ArpegFact[edx*4]
        mov     eax, [esi.CurPeriod]
        mul     ebx
        shrd    eax, edx, 16
SetArpPeriod:
        call    PeriodToFreq
        call    PlayFrequency
        ret

Arpeggio        EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
RetrigNote      Proc    Near

        mov     bl, [esi.CmdInfo]
        and     bl, 0Fh
        jz      Dummy
        mov     eax, TickCounter
        div     bl
        or      ah, ah
        jnz     Dummy
        xor     ebx, ebx
        mov     bl, [esi.CmdInfo]
        shr     bl, 4
        xor     eax, eax
        mov     al, [esi.CurVol]
        test    bl, 8
        jnz     VolAdd
VolSub: and     bl, 7
        cmp     bl, 5
        ja      SubSpecial
        cmp     bl, 0
        jz      StoreVol
        sub     al, RetrigVol[ebx]
        jmp     StoreVol
SubSpecial:
        cmp     bl, 6
        jne     HalfVol
        imul    eax, 43691
        shr     eax, 16
        jmp     StoreVol
HalfVol:
        shr     al, 1
        jmp     StoreVol

VolAdd: and     bl, 7
        cmp     bl, 5
        ja      AddSpecial
        add     al, RetrigVol[ebx]
        jmp     StoreVol
AddSpecial:
        cmp     bl, 6
        jne     DoubleVol
        imul    eax, 3
        shr     eax, 1
        jmp     StoreVol
DoubleVol:
        shl     al, 1
StoreVol:
        cmp     al, 0
        jge     NotLo
        mov     al, 0
NotLo:  cmp     al, 64
        jle     NotHi
        mov     al, 64
NotHi:  mov     [esi.CurVol], al
        mov     DPtr [esi.InstrPtr], 0
        call    PlayChannel
        ret

RetrigNote      EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
NoteCut         Proc    Near

        xor     eax, eax
        mov     al, [esi.CmdInfo]
        and     al, 0Fh
        jz      Dummy
        cmp     eax, TickCounter
        jne     Dummy
        xor     eax, eax
        mov     [esi.CurVol], al
        call    SetCurVol
        ret

NoteCut         EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
NoteDelay       Proc    Near

        xor     eax, eax
        mov     al, [esi.CmdInfo]
        and     al, 0Fh
        cmp     eax, TickCounter
        jne     Dummy
        mov     DPtr [esi.InstrPtr], 0
        call    PlayChannel
        ret

NoteDelay       EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Dummy           Proc    Near

        ret

Dummy           EndP
;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º                             S3M Loader Routines                             º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
S3M_Load        Proc    Near

        pushad
        mov     S3MNamePtr, eax
        call    ClearLoadVars
        call    ReadS3MHeader
        jc      LoadError
        call    ReadOrders
        jc      LoadError
        call    LoadDefPans
        jc      LoadError
        call    LoadPatterns
        jc      LoadError
        call    LoadSamples
        jc      LoadError
        popad
        clc
        ret

LoadError:
        Print   S3MLoadErrorMsg
        popad
        stc
        ret

S3M_Load        EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
S3M_UnLoad      Proc    Near

        pushad
        call    UnloadSamples
        jc      UnloadError
        call    UnloadPatterns
        jc      UnloadError
        Free    ChanInfoPtr, ChanInfoLen
        mov     ChanInfoPtr, 0
        jc      UnloadError
        popad
        clc
        ret

UnloadError:
        popad
        stc
        ret

S3M_UnLoad      EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
ClearLoadVars   Proc    Near

        lea     edi, LoadClearBegin
        lea     ecx, LoadClearEnd
        sub     ecx, Offset LoadClearBegin
        xor     al, al
        rep     stosb
        ret

ClearLoadVars   EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
ReadS3MHeader   Proc    Near

        mov     edx, S3MNamePtr
        mov     ebx, 0
        mov     ecx, 64
        lea     edi, S3MHeader
        call    DataFileRead
        jc      HeaderError
        cmp     DPtr S3MHeader[2Ch], 'MRCS'     ; SCRM-signature missing?
        jne     HeaderError
        cmp     WPtr S3MHeader[2Ah], 2          ; File format version not 2?
        jne     HeaderError
        mov     ebx, 64
        mov     ecx, 32
        lea     edi, ChanSetting
        call    DataFileRead
        xor     eax, eax
        mov     ax, WPtr S3MHeader[20h]
        mov     NumOrders, eax
        mov     ax, WPtr S3MHeader[24h]
        mov     NumPatterns, eax
        mov     ax, WPtr S3MHeader[22h]
        mov     InstrCount, eax

        mov     al, BPtr S3MHeader[30h]
        mov     InitGlobalVol, al
        mov     al, BPtr S3MHeader[31h]
        mov     InitSpeed, al
        mov     al, BPtr S3MHeader[32h]
        mov     InitTempo, al
        mov     al, BPtr S3MHeader[35h]
        mov     DefaultPan, al
        mov     al, BPtr S3MHeader[33h]
        and     al, 80h
        mov     StereoMode, al

        clc
        ret

HeaderError:
        stc
        ret

ReadS3MHeader   EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
ReadOrders      Proc Near

        mov     edx, S3MNamePtr
        mov     ebx, 60h
        mov     ecx, NumOrders
        lea     edi, Orders
        call    DataFileRead
        ret

ReadOrders      EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
LoadDefPans     Proc    Near

        cmp     DefaultPan, 0FCh
        je      ReadDefPans
        lea     edi, DefPans
        mov     ecx, 32
        mov     al, 0
        rep     stosb
        clc
        ret

ReadDefPans:
        mov     edx, S3MNamePtr
        mov     ebx, 60h
        add     ebx, NumOrders
        add     ebx, InstrCount
        add     ebx, InstrCount
        add     ebx, NumPatterns
        add     ebx, NumPatterns
        mov     ecx, 32
        lea     edi, DefPans
        call    DataFileRead
        clc
        ret

LoadDefPans     EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
LoadPatterns    Proc    Near

        mov     edx, S3MNamePtr
        mov     ebx, 60h
        add     ebx, NumOrders
        add     ebx, InstrCount
        add     ebx, InstrCount
        mov     ecx, NumPatterns
        shl     ecx, 1
        lea     edi, S3MHeader
        call    DataFileRead

        mov     ebp, 0
PatternLoadLoop:
        xor     ebx, ebx
        mov     bx, WPtr S3MHeader[ebp*2]
        shl     ebx, 4
        mov     ecx, 2
        lea     edi, PattLen[ebp*4]
        call    DataFileRead
        sub     PattLen[ebp*4], 2
        Alloc   PatternPtr[ebp*4], PattLen[ebp*4]
        add     ebx, 2
        mov     ecx, PattLen[ebp*4]
        mov     edi, PatternPtr[ebp*4]
        call    DataFileRead
        inc     ebp
        cmp     ebp, NumPatterns
        jb      PatternLoadLoop

        ret

LoadPatterns    EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
UnloadPatterns  Proc    Near

        mov     ebp, NumPatterns
        dec     ebp
UlPattLoop:
        Free    PatternPtr[ebp*4], PattLen[ebp*4]
        mov     PatternPtr[ebp*4], 0
        dec     ebp
        jns     UlPattLoop
        clc
        ret

UnloadPatterns  EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
LoadSamples     Proc    Near

        Print   S3M_Loading

        lea     edi, SamplePtrs
        mov     ecx, MaxSamples
        xor     eax, eax
        rep     stosd

        mov     edx, S3MNamePtr
        mov     ebx, 60h
        add     ebx, NumOrders
        mov     ecx, InstrCount
        shl     ecx, 1
        lea     edi, S3MHeader
        call    DataFileRead

        mov     ebx, S3M_FunctionPtr
        call    [ebx+Sd_GetInfo]
        mov     al, [eax+SdLoadMode]
        and     al, 02h
        jnz     ChunkLoad
MemLoad:

        mov     ebp, 0
MemLoadLoop:
        Print   S3M_Dot
        mov     edx, S3MNamePtr
        xor     ebx, ebx
        mov     bx, WPtr S3MHeader[ebp*2]
        shl     ebx, 4
        add     ebx, 0Ch
        mov     ecx, 40
        lea     edi, SamplePos
        call    DataFileRead

        cmp     LSmplLen, 0
        jz      DontBother

        mov     al, BPtr LSmplFlags
        mov     DefVolumes[ebp], al
        mov     eax, C4Speed
        mov     C4Freqs[ebp*4], eax

        mov     al, BPtr LSmplFlags[03h]
        mov     ebx, eax
        and     ebx, 1
        test    al, 2
        jz      MNotSt
        or      ebx, 8
MNotSt: test    al, 4
        jz      MNot16
        or      ebx, 4
MNot16: mov     LSmplFlags, ebx
        shr     SamplePos, 16
        shl     SamplePos, 4

        Alloc   SamplePtrs[ebp*4], LSmplLen
        mov     eax, LSmplLen
        mov     SampleLens[ebp*4], eax
        mov     edi, SamplePtrs[ebp*4]
        mov     ecx, LSmplLen
        mov     ebx, SamplePos
        add     SamplePos, ecx
        mov     edx, S3MNamePtr
        call    DataFileRead
MConvLoop:
        add     BPtr [edi], 80h
        inc     edi
        loop    MConvLoop

        mov     ebx, S3M_FunctionPtr
        lea     eax, TempSample
        mov     esi, SamplePtrs[ebp*4]
        call    [ebx+Sd_RegMemSmpl]
        jc      SmplLoadError
        mov     SampleHandles[ebp*4], eax
DontBother:
        inc     ebp
        cmp     ebp, InstrCount
        jb      MemLoadLoop

        Print   S3M_Loaded
        clc
        ret

ChunkLoad:
        Alloc   ChunkBufPtr, ChunkBufSize

        mov     ebp, 0
ChunkLoadLoop:
        Print   S3M_Dot
        mov     edx, S3MNamePtr
        xor     ebx, ebx
        mov     bx, WPtr S3MHeader[ebp*2]
        shl     ebx, 4
        add     ebx, 0Ch
        mov     ecx, 40
        lea     edi, SamplePos
        call    DataFileRead

        mov     al, BPtr LSmplFlags
        mov     DefVolumes[ebp], al
        mov     eax, C4Speed
        mov     C4Freqs[ebp*4], eax

        mov     al, BPtr LSmplFlags[03h]
        mov     ebx, eax
        and     ebx, 1
        test    al, 2
        jz      NotSt
        or      ebx, 8
NotSt:  test    al, 4
        jz      Not16
        or      ebx, 4
Not16:  mov     LSmplFlags, ebx
        shr     SamplePos, 16
        shl     SamplePos, 4

        lea     eax, TempSample
        mov     esi, ChunkBufPtr
        mov     ecx, ChunkBufSize
        lea     edx, GetChunk
        mov     ebx, S3M_FunctionPtr
        call    [ebx+Sd_ChunkLoad]
        jc      SmplLoadError
        mov     SampleHandles[ebp*4], eax
        inc     ebp
        cmp     ebp, InstrCount
        jb      ChunkLoadLoop

        Free    ChunkBufPtr, ChunkBufSize
        Print   S3M_Loaded
        clc
        ret

SmplLoadError:
        Free    ChunkBufPtr, ChunkBufSize
        stc
        ret

LoadSamples     EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
UnloadSamples   Proc

        mov     ebp, MaxSamples
        dec     ebp
UlSLoop:
        cmp     SamplePtrs[ebp*4], 0
        jz      ulsskp
        Free    SamplePtrs[ebp*4], SampleLens[ebp*4]
        mov     SamplePtrs[ebp*4], 0
ulsskp: dec     ebp
        jns     UlSLoop
        clc
        ret

UnloadSamples   EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
GetChunk        Proc    Near

        push    ebx ecx edx edi
        mov     ebx, SamplePos
        add     SamplePos, ecx
        mov     edx, S3MNamePtr
        mov     edi, esi
        call    DataFileRead
ConvLoop:
        add     BPtr [edi], 80h
        inc     edi
        loop    ConvLoop
        pop     edi edx ecx ebx
        ret

GetChunk        EndP
;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º                                  D A T A                                    º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
CommandParsers  DD      Offset Dummy            ; @ - No command
                DD      Offset SetSpeed         ; A - Set speed
                DD      Offset PositionJump     ; B - Position jump
                DD      Offset PatternBreak     ; C - Pattern Break
                DD      Offset VolSlideInit     ; D - Volume slides
                DD      Offset SlideDownInit    ; E - Slides down
                DD      Offset SlideUpInit      ; F - Slides up
                DD      Offset TonePortaInit    ; G - Tone portamento
                DD      Offset VibratoInit      ; H - Vibrato
                DD      Offset SlideInit        ; I - Tremor
                DD      Offset SlideInit        ; J - Arpeggio
                DD      Offset SlideInit        ; K - Vibrato + Volume slide
                DD      Offset SlideInit        ; L - Portamento + Volume slide
                DD      Offset Dummy            ; M - none
                DD      Offset Dummy            ; N - none
                DD      Offset SampleOffset     ; O - Sample offset
                DD      Offset Dummy            ; P - none
                DD      Offset SlideInit        ; Q - Retrig note
                DD      Offset TremoloInit      ; R - Tremolo
                DD      Offset ParseExtra       ; S - Extra commands
                DD      Offset SetTempo         ; T - Tempo
                DD      Offset FineVibratoInit  ; U - Fine vibrato
                DD      Offset SetGlobalVol     ; V - Set master volume

CommandHandlers DD      Offset Dummy            ; 00 - none
                DD      Offset Dummy            ; 01 - none
                DD      Offset Dummy            ; 02 - none
                DD      Offset Dummy            ; 03 - none
                DD      Offset VolumeSlide      ; 04 - Volume Slide
                DD      Offset SlideDown        ; 05 - Slides down
                DD      Offset SlideUp          ; 06 - Slides up
                DD      Offset TonePortamento   ; 07 - Tone portamento
                DD      Offset Vibrato          ; 08 - Vibrato
                DD      Offset Tremor           ; 09 - Tremor
                DD      Offset Arpeggio         ; 0A - Arpeggio
                DD      Offset Vibrato&Slide    ; 0B - Vibrato + Volume slide
                DD      Offset Port&Slide       ; 0C - Portamento + Volume slide
                DD      Offset NoteCut          ; 0D - NoteCut
                DD      Offset NoteDelay        ; 0E - NoteDelay
                DD      Offset Dummy            ; 0F - none
                DD      Offset Dummy            ; 10 - none
                DD      Offset RetrigNote       ; 11 - Retrig note
                DD      Offset Tremolo          ; 12 - Tremolo
                DD      Offset Dummy            ; 13 - Extra commands
                DD      Offset Dummy            ; 14 - Tempo
                DD      Offset Vibrato          ; 15 - none
                DD      Offset Dummy            ; 16 - Set master volume

ExtraParsers    DD      Offset Dummy            ; 0 - none
                DD      Offset GlissandoCtrl    ; 1 - Glissando control
                DD      Offset SetC4Spd         ; 2 - Set C4Spd
                DD      Offset VibratoCtrl      ; 3 - Vibrato waveform
                DD      Offset TremoloCtrl      ; 4 - Tremolo waveform
                DD      Offset Dummy            ; 5 - none
                DD      Offset Dummy            ; 6 - none
                DD      Offset Dummy            ; 7 - none
                DD      Offset SetPanPos        ; 8 - Panning
                DD      Offset Dummy            ; 9 - none
                DD      Offset Dummy            ; A - none
                DD      Offset Dummy            ; B - Pattern loop
                DD      Offset NoteCutInit      ; C - Note cut
                DD      Offset NoteDelayInit    ; D - Note delay
                DD      Offset PatternDelay     ; E - Pattern delay
                DD      Offset Dummy            ; F - none
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
S3MLoadErrorMsg DB      'Error loading the S3M-file!',13,10,'$'
S3M_Loading     DB      'Loading instruments$'
S3M_Dot         DB      '.$'
S3M_Loaded      DB      13,10,'$'

S3M_FunctionPtr DD      0
S3MPlayerInfo   Label   DWord
JumpsDisabled   DD      0

OrigPeriod      DD      109568,103424,097536,092160,086784,081920
                DD      077312,072960,068864,065024,061440,058048
FineC4Spd       DD      7895,7941,7985,8046,8107,8169,8232,8280
                DD      8363,8413,8463,8529,8581,8651,8723,8757
ArpegFact       DD      10000h,0F1A2h,0E412h,0D745h,0CB30h,0BFC9h,0B505h,0AADCh
                DD      0A145h,09838h,08FADh,0879Ch,08000h,078D1h,07209h,06BA2h
VibratoTable    DB        0, 24, 49, 74, 97,120,141,161
		DB	180,197,212,224,235,244,250,253
		DB	255,253,250,244,235,224,212,197
                DB      180,161,141,120, 97, 74, 49, 24
RetrigVol       DB      0,1,2,4,8,16

ClearBegin      Label   Byte

WrapCount       DD      0
SongSpeed       DB      0
SongTempo       DB      0
TickBytes       DD      0
TickCounter     DD      0
CurFlags        DB      0
NextOrder       DD      0
PatternRow      DD      0
RowPtr          DD      0
OldRowPtr       DD      0
OrigRowPtr      DD      0
ChannelNum      DD      0
PattDelayCnt    DD      0
PattDelayFlag   DD      0
RowsToSkip      DD      0
GlobalVol       DB      0

; Unpacked channel
Note            DB      0
Inst            DB      0

ClearEnd        Label   Byte

LoadClearBegin  Label   Byte

ChannelHandle   DD      32              DUP (0)
ChanSetting     DB      32              DUP (0)
DefPans         DB      32              DUP (0)

ChanInfoPtr     DD      0
ChanInfoLen     DD      0
PatternPtr      DD      MaxPatterns     DUP (0)
PattLen         DD      MaxPatterns     DUP (0)
SampleHandles   DD      MaxSamples      DUP (0)
C4Freqs         DD      MaxSamples      DUP (0)
DefVolumes      DB      MaxSamples      DUP (0)
SamplePtrs      DD      MaxSamples      DUP (0)
SampleLens      DD      MaxSamples      DUP (0)
Orders          DB      MaxOrders       DUP (0)

InstrCount      DD      0
NumChannels     DD      0
InitSpeed       DB      0
InitTempo       DB      0
InitGlobalVol   DB      0
SoloChan        DD      0
DefaultPan      DB      0
StereoMode      DB      0

LoadClearEnd    Label   Byte

; Channel Info Block Structure

TreCurVol       EQU     0
InstrNum        EQU     TreCurVol+1
InstrPtr        EQU     InstrNum+4
CmdNum          EQU     InstrPtr+4
CmdInfo         EQU     CmdNum+1
CurCmd          EQU     CmdInfo+1
CurInfo         EQU     CurCmd+1
CurVol          EQU     CurInfo+1
CurFreq         EQU     CurVol+1
CurPeriod       EQU     CurFreq+4
LoopPatRow      EQU     CurPeriod+4
LoopPatPtr      EQU     LoopPatRow+1
GlisFunk        EQU     LoopPatPtr+4
WaveCtrl        EQU     GlisFunk+1
VibratoPos      EQU     WaveCtrl+1
VibratoInfo     EQU     VibratoPos+4
TremoloPos      EQU     VibratoInfo+4
TremoloInfo     EQU     TremoloPos+4
TPortaDirec     EQU     TremoloInfo+4
PortInfo        EQU     TPortaDirec+1
DestPeriod      EQU     PortInfo+1
OffsetInfo      EQU     DestPeriod+4
CurNote         EQU     OffsetInfo+1
CurOctave       EQU     CurNote+1
ChanIBLen       EQU     CurOctave+1


S3MHeader       DB      HeadLen         DUP (0)
S3MNamePtr      DD      0
ChunkBufPtr     DD      0
NumOrders       DD      0
NumPatterns     DD      0

SamplePos       DD      0
TempSample      Label   DWord
LSmplLen	DD	0
LSmplRepeatFrom DD	0
LSmplRepeatTo	DD	0
LSmplFlags      DD      0
C4Speed         DD      0

DD      10 dup (0)

;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
PrepScreen      Proc    Near

        pushad
        dec     eax
        mov     ebp, eax
        lea     edi, Screen[11]
        mov     esi, ChanInfoPtr
        imul    eax, ChanIBLen
        add     esi, eax
        mov     ecx, 7
PS_ChanLoop:
        push    edi
        mov     ebx, ebp
        inc     ebx
        call    PrintD
        add     edi, 80
        mov     BPtr [edi], ' '
        mov     eax, ebp
        inc     eax
        cmp     eax, SoloChan
        jne     NotASolo
        mov     BPtr [edi], '*'
NotASolo:
        add     edi, 80
        mov     ebx, [esi+InstrNum]
        call    PrintD
        add     edi, 80
        mov     ebx, [esi+InstrPtr]
        call    PrintD
        add     edi, 80
        mov     ebx, [esi+CmdNum]
        and     ebx, 0FFh
        call    PrintD
        mov     bl, [esi+CmdNum]
        add     bl, 64
        mov     [edi], bl
        add     edi, 80
        mov     ebx, [esi+CmdInfo]
        and     ebx, 0FFh
        call    PrintD
        add     edi, 80
        mov     ebx, [esi+CurCmd]
        and     ebx, 0FFh
        call    PrintD
        mov     bl, [esi+CurCmd]
        add     bl, 64
        mov     [edi], bl
        add     edi, 80
        mov     ebx, [esi+CurInfo]
        and     ebx, 0FFh
        call    PrintD
        add     edi, 80
        mov     ebx, [esi+CurVol]
        and     ebx, 0FFh
        call    PrintD
        add     edi, 80
        mov     ebx, [esi+CurFreq]
        call    PrintD
        add     edi, 80
        mov     ebx, [esi+CurPeriod]
        call    PrintD
        add     edi, 80
        mov     ebx, [esi+WaveCtrl]
        and     ebx, 0FFh
        call    PrintD
        add     edi, 80
        mov     ebx, [esi+VibratoPos]
        call    PrintD
        add     edi, 80
        mov     ebx, [esi+VibratoInfo]
        call    PrintD
        add     edi, 80
        mov     ebx, [esi+TPortaDirec]
        and     ebx, 0FFh
        mov     eax, [esi+GlisFunk]
        and     eax, 0FFh
        shl     eax, 16
        or      ebx, eax
        call    PrintD
        add     edi, 80
        mov     ebx, [esi+DestPeriod]
        call    PrintD
        add     edi, 80
;        mov     ebx, [esi+PortInfo]
        mov     ebx, [esi+TreCurVol]
        and     ebx, 0FFh
        call    PrintD
        add     edi, 80
        xor     ebx, ebx
        mov     bl, [esi+CurNote]
        shl     ebx, 16
        or      bl, [esi+CurOctave]
        call    PrintD
        add     edi, 80
        mov     eax, [esi+InstrNum]
        mov     ebx, SampleHandles[eax*4]
        call    PrintD
        add     edi, 80
        mov     eax, [esi+InstrNum]
        mov     ebx, C4Freqs[eax*4]
        call    PrintD
        add     edi, 80
        mov     eax, [esi+InstrNum]
        xor     ebx, ebx
        mov     bl, DefVolumes[eax]
        call    PrintD
        add     edi, 80
        mov     eax, [esi+InstrNum]
        mov     ebx, SamplePtrs[eax*4]
        call    PrintD
        pop     edi
        add     esi, ChanIBLen
        add     edi, 9
        inc     ebp
        dec     ecx
        jnz     PS_ChanLoop

        lea     edi, Screen[23*80+11]
        mov     ebx, PatternRow
        call    PrintD
        add     edi, 27
        mov     ebx, PattDelayCnt
        call    PrintD
        add     edi, 27
        mov     ebx, TickCounter
        call    PrintD
        lea     edi, Screen[24*80+11]
        xor     ebx, ebx
        mov     bl, SongSpeed
        call    PrintD
        add     edi, 27
        xor     ebx, ebx
        mov     bl, SongTempo
        mov     al, TempoFact
        shl     eax, 24
        or      ebx, eax
        call    PrintD
        add     edi, 27
        mov     ebx, NextOrder
        call    PrintD
        popad
        ret

PrepScreen      EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
PutScreen       Proc    Near

        pushad
        lea     esi, Screen
        mov     edi, 0B8000h
        sub     edi, _Code32a
        mov     ecx, 80*25
        mov     ah, 07h
@psloop:
        mov     al, [esi]
        mov     [edi], ax
        inc     esi
        add     edi, 2
        dec     ecx
        jnz     @psloop
        popad
        ret

PutScreen       EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Screen          Label   Byte
DB      'Channel    00000000 00000000 00000000 00000000 00000000 00000000 00000000  ÚÄÄÄ¿' ;1
DB      '                                                                           ³   ³' ;2
DB      'InstrNum   00000000 00000000 00000000 00000000 00000000 00000000 00000000  ³ E ³' ;3
DB      'InstrPtr   00000000 00000000 00000000 00000000 00000000 00000000 00000000  ³ M ³' ;4
DB      'CmdNum     00000000 00000000 00000000 00000000 00000000 00000000 00000000  ³ F ³' ;5
DB      'CmdInfo    00000000 00000000 00000000 00000000 00000000 00000000 00000000  ³   ³' ;6
DB      'CurCmd     00000000 00000000 00000000 00000000 00000000 00000000 00000000  ³ * ³' ;7
DB      'CurInfo    00000000 00000000 00000000 00000000 00000000 00000000 00000000  ³   ³' ;8
DB      'CurVol     00000000 00000000 00000000 00000000 00000000 00000000 00000000  ³ T ³' ;9
DB      'CurFreq    00000000 00000000 00000000 00000000 00000000 00000000 00000000  ³ e ³' ;10
DB      'CurPeriod  00000000 00000000 00000000 00000000 00000000 00000000 00000000  ³ s ³' ;11
DB      'WaveCtrl   00000000 00000000 00000000 00000000 00000000 00000000 00000000  ³ t ³' ;12
DB      'VibratoPos 00000000 00000000 00000000 00000000 00000000 00000000 00000000  ³   ³' ;13
DB      'VibraInfo  00000000 00000000 00000000 00000000 00000000 00000000 00000000  ³ S ³' ;14
DB      'GlsF+TPDir 00000000 00000000 00000000 00000000 00000000 00000000 00000000  ³ 3 ³' ;15
DB      'DestPeriod 00000000 00000000 00000000 00000000 00000000 00000000 00000000  ³ M ³' ;16
DB      'PortInfo   00000000 00000000 00000000 00000000 00000000 00000000 00000000  ³   ³' ;17
DB      'Note+Oct   00000000 00000000 00000000 00000000 00000000 00000000 00000000  ³ p ³' ;18
DB      'SmplHandle 00000000 00000000 00000000 00000000 00000000 00000000 00000000  ³ l ³' ;19
DB      'SmplC4Freq 00000000 00000000 00000000 00000000 00000000 00000000 00000000  ³ a ³' ;20
DB      'SmplDefVol 00000000 00000000 00000000 00000000 00000000 00000000 00000000  ³ y ³' ;21
DB      'SmplPtr    00000000 00000000 00000000 00000000 00000000 00000000 00000000  ³ e ³' ;22
DB      '                                                                           ³ r ³' ;23
DB      'PatternRow 00000000     PattDelayCnt  00000000      TickCounter  00000000  ³   ³' ;24
DB      'SongSpeed  00000000        SongTempo  00000000        NextOrder  00000000  ÀÄÄÄÙ' ;25

TempoFact       DB      0
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Code32		EndS

                End
