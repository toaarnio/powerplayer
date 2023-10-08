        .386P
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
	Uses_Timer = 1			; Include timer stuff.
	Uses_Kbd   = 1			; Include keyboard stuff.
	Uses_ExcHandling = 1		; Include the exception handler.
	Uses_DataFileRead = 1
        Uses_RasterMeter = 1
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ

	INCLUDE stdrouts.inc
	INCLUDE filelib.inc
	INCLUDE debug.inc

Code32	Segment Para Public Use32
	ASSUME	CS:Code32,DS:Code32

	INCLUDE pmode.inc
;        INCLUDE callspec.inc

;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º				    C O D E				       º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
Extrn   InitSound:Near
Extrn   LoadMusic:Near
Extrn   UnLoadMusic:Near
Extrn   StartMusic:Near
Extrn   StopMusic:Near
Extrn   ResumeMusic:Near
Extrn   GetMusicPos:Near
Extrn   SetMusicPos:Near
Extrn   LoadSample:Near
Extrn   PlaySample:Near
Extrn   SetMasterVol:Near
Extrn   DeInitSound:Near
Extrn   DetectCard:Near

Public	_Main
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
_Main		Proc	Near

        Print   Message

	call	HookInts
        mov     TimerCount, 16700
	mov	TimerFlag, 1
        mov     RasterFlag, 1
	sti

        xor     eax, eax
        call    DetectCard
	call	InitSound
        jc      ErrorMain2
	mov	ebx, _PSPa
	sub	ebx, _Code32a
        lea     eax, [ebx+82h]
        mov     ParamPtr, eax
        mov     OrigParamPtr, eax

        call    ScanName
        jc      ErrorMain

        call    LoadMusic
	jc	ErrorMain
        mov     eax, 128
        mov     CurMaxVol, al
        call    SetMasterVol
        call    StartMusic

waitk:
        mov     eax, BegChan
        mov     ebx, SoloKey
        mov     ebp, 291176h
        call    GetMusicPos
        cmp     edx, 0
        jz      NotWrapped
        mov     PressedKey, 31h
NotWrapped:
        shr     eax, 6
        mov     MusPos, eax
;        mov     ebx, eax
;        lea     edi, PosMsg
;        call    PrintD
;        Print   PosMsg

        mov     al, CurMaxVol
        call    BtoH
        mov     edi, 0B8000h
        add     edi, 3834
        sub     edi, _Code32A
        stosb
        mov     al, 7
        stosb
        mov     al, ah
        stosb
        mov     al, 7
        stosb
        cmp     PressedKey, 4Dh
        jne     NotRight
        inc     BegChan
        mov     PressedKey, 0
NotRight:
        cmp     PressedKey, 4Bh
        jne     NotLeft
        cmp     BegChan, 1
        jle     NotLeft
        dec     BegChan
        mov     PressedKey, 0
NotLeft:
        cmp     PressedKey, 3Bh
        jb      NotFkey
        cmp     PressedKey, 42h
        ja      NotFkey
        xor     eax, eax
        mov     al, PressedKey
        sub     eax, 3Ah
        mov     SoloKey, eax
NotFkey:
        mov     eax, MusPos
        cmp     PressedKey, 43h
        jne     NotToBeg
        sub     eax, 2
        jmp     SetPos
NotToBeg:
        cmp     PressedKey, 44h
        jne     NotToEnd
SetPos:
        shl     eax, 6
        xor     ebp, ebp
        call    SetMusicPos
        mov     PressedKey, 0
NotToEnd:
        cmp     PressedKey, 4Ah ; grey-
        jne     NoSlowTempo
        dec     TempoFact
        mov     cl, TempoFact
        mov     ebp, 291176h
        call    SetMusicPos
        mov     PressedKey, 0
NoSlowTempo:
        cmp     PressedKey, 4Eh ; grey+
        jne     NoFastTempo
        inc     TempoFact
        mov     cl, TempoFact
        mov     ebp, 291176h
        call    SetMusicPos
        mov     PressedKey, 0
NoFastTempo:
        cmp     PressedKey, 34h
        jne     NoTrigger
        mov     ebp, 12345678h
        call    SetMusicPos
        mov     PressedKey, 0
NoTrigger:
        cmp     PressedKey, 25h
        jne     NoKill
        mov     ebp, 57575757h
        call    SetMusicPos
        mov     PressedKey, 0
NoKill:
        cmp     PressedKey, 31h
        jne     NoNext
        call    StopMusic
        call    beep
        call    UnloadMusic
;        call    DeInitSound
;        mov     bx, 0
;        call    ProgTimer
;        call    InitSound
        call    ScanName
        jc      ErrorMain
        call    LoadMusic
        call    StartMusic
        mov     PressedKey, 0

NoNext:
        cmp     PressedKey, 10h
        jne     NoVolUp
        inc     CurMaxVol
        xor     eax, eax
        mov     al, CurMaxVol
        call    SetMasterVol
        mov     PressedKey, 0
NoVolUp:
        cmp     PressedKey, 1Eh
        jne     NoVolDown
        dec     CurMaxVol
        xor     eax, eax
        mov     al, CurMaxVol
        call    SetMasterVol
        mov     PressedKey, 0
NoVolDown:

        cmp     PressedKey, 1
	jne	waitk

        call    StopMusic

ErrorMain:
	call	DeInitSound
        mov     bx, 0
        call    ProgTimer
ErrorMain2:
	call	GetCMOSTime
	call	RestoreInts
	ExitPM

_Main		EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
ScanName        Proc    Near

        mov     ebx, ParamPtr
        or      ebx, ebx
        jnz     ScanLoop
        stc
        ret

ScanLoop:
        cmp     BPtr [ebx], 32
        jbe     WSfound
        inc     ebx
        jmp     ScanLoop

WSfound:
        mov     eax, ParamPtr
        push    eax
        mov     eax, ebx
        inc     eax
        cmp     BPtr [ebx+1], 0
        jnz     NotEnd
        mov     eax, OrigParamPtr
NotEnd: mov     ParamPtr, eax
        mov     BPtr [ebx], 0
        pop     eax
        clc
        ret

ScanName        EndP
;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º                                  D A T A                                    º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
PosMsg          DB      '00000000 ',13,'$'

Message         DB      'EMF Protected Mode Sound System - Test Player - DO NOT DISTRIBUTE!',13,10,'$'
BegChan         DD      1
Solokey         DD      8
MusPos          DD      0
TempoFact       DB      0
ParamPtr        DD      0
OrigParamPtr    DD      0
CurMaxVol       DB      0
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Code32          EndS

                End
