TITLE DETECT.ASM - EMF PM Sound System - Soundcard Detection Routine by Saint
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
        .386P
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
;TestMain        EQU     joo
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ

        Uses_Timer = 1                  ; Include keyboard stuff.
        Uses_Kbd   = 1                  ; Include keyboard stuff.
        Uses_ExcHandling = 1            ; Include the exception handler.

        INCLUDE callspec.hdr
IFDEF Testmain
        INCLUDE stdrouts.inc
ELSE
        INCLUDE stdrouts.hdr
ENDIF

Code32  Segment Para Public Use32
	ASSUME	CS:Code32,DS:Code32

	INCLUDE pmode.inc

;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º				    C O D E				       º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
Public  DetectCard
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
IFDEF   TestMain
Public  _Main
_Main           Proc    Near

        sti
        call    HookInts
        call    DetectCard
        call    RestoreInts
        EXITPM

_Main           EndP
ENDIF
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
CheckCmdStatus  MACRO                   ; This one checks the 'SB ready' bit.
                Local   bwd

bwd:    in      al, dx                  ; Fetch the cmd port's contents.
        add     al, al                  ; Is the highest bit on?
        jc      bwd                     ; Wait until it's off.

                ENDM
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
DetectCard      Proc    Near

        mov     QueryMode, al
        call    SetDefaults
        call    GetGUSAddress
        jnc     CardFound
        call    GetSBAddress
CardFound:
        cmp     QueryMode, 1
        je      Not0
        call    AskConfirmation
        jnc     CardOk

        cmp     CardType, 1
        jne     WasntGUS
        mov     CardType, 0
        call    GetSBAddress
WasntGUS:
        cmp     CardType, 2
        jae     IsSB
        call    SetDefaults
IsSB:

        Print   CrLf
        Print   CrLf
        call    QueryCard
        jc      CardOk
        Print   CrLf
        Print   CrLf
        jmp     CardFound

CardOk:
        cmp     CardType, 0
        jne     EndLf
        Print   Notice0
        mov     PressedKey, 0
getk4:  cmp     PressedKey, 0
        jz      getk4
        mov     PressedKey, 0
EndLf:  Print   CrLf

Not0:   lea     esi, CardInfo
        ret

DetectCard      EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
SetDefaults     Proc    Near

        mov     CardType, 0
        mov     BaseAddr, 220h
        mov     IRQ, 7
        mov     DMA, 1
        mov     SampleRate, 22050
        ret

SetDefaults     EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
GetGUSAddress   Proc    Near

	pushad
	mov	eax, _PSPa
	movzx	edi, WPtr gs:[eax+2Ch]
	shl	edi, 4
        sub     edi, _Code32A

GGA_Long:
	xor	ecx, ecx
	lea	esi, GUS_EnvName
	lodsb
GGA_Short:
	cmp	BPtr [edi], 0
	jne	GGA_NotZero
	cmp	BPtr [edi-1], 0
	jz	GGA_EnvNotFound
  GGA_NotZero:
	scasb
	jne	GGA_Long
	inc	ecx
	cmp	ecx, GUS_EnvNameLen
	jae	GGA_LoopOver
	lodsb
	jmp	GGA_Short
GGA_LoopOver:
	dec	edi
	mov	ecx, 80

	call	ScanNum
	movzx	eax, BPtr [edi+1]
	sub	al, 30h
	shl	eax, 4
	add	eax, 200h
        mov     BaseAddr, eax
	call	ScanNum
	movzx	eax, BPtr [edi]
	sub	al, 30h
        mov     DMA, eax
	call	ScanNum
	call	ScanNum
	cmp	BPtr [edi], '1'
	je	GGA_OneTeen
	mov	al, [edi]
	sub	al, 30h
	jmp	GGA_FoundIRQ
GGA_OneTeen:
	cmp	BPtr [edi+1], 30h
	jb	IsOne
	cmp	BPtr [edi+1], 35h
	ja	IsOne
	mov	al, [edi+1]
	sub	al, 30h
	add	al, 10
	jmp	GGA_FoundIRQ
IsOne:
	mov	al, 1
GGA_FoundIRQ:
	and	eax, 0FFh
	cmp	eax, 02h
	jne	IrqOk
	mov	eax, 09h
IrqOk:  mov     IRQ, eax
        mov     CardType, 1
        mov     SampleRate, 44100
	popad
	clc
	ret

GGA_EnvNotFound:
	popad
	stc
	ret

GetGUSAddress   EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
GetSBAddress    Proc    Near

        pushad
        mov     eax, _PSPa
        movzx   edi, WPtr gs:[eax+2Ch]
        shl     edi, 4
        sub     edi, _Code32A

SB_Long:
        xor     ecx, ecx
        lea     esi, SB_EnvName
        lodsb
SB_Short:
        cmp     BPtr [edi], 0
        jne     SB_NotZero
        cmp     BPtr [edi-1], 0
        jz      SB_EnvNotFound
SB_NotZero:
        scasb
        jne     SB_Long
        inc     ecx
        cmp     ecx, SB_EnvNameLen
        jae     SB_LoopOver
        lodsb
        jmp     SB_Short
SB_LoopOver:

        push    edi
SB_BaseLoop:
        cmp     BPtr [edi], 0
        jz      SB_EnvPopEdi
        cmp     BPtr [edi], 'A'
        je      SB_BaseFound
        cmp     BPtr [edi], 'a'
        je      SB_BaseFound
        inc     edi
        jmp     SB_BaseLoop
SB_BaseFound:
        xor     eax, eax
        mov     al, [edi+2]
        sub     al, '0'
        shl     eax, 4
        add     eax, 200h
        mov     BaseAddr, eax
        pop     edi

        push    edi
SB_DMALoop:
        cmp     BPtr [edi], 0
        jz      SB_EnvPopEdi
        cmp     BPtr [edi], 'D'
        je      SB_DMAFound
        cmp     BPtr [edi], 'd'
        je      SB_DMAFound
        inc     edi
        jmp     SB_DMALoop
SB_DMAFound:
        xor     eax, eax
        mov     al, [edi+1]
        sub     al, '0'
        mov     DMA, eax
        pop     edi

        push    edi
SB_IRQLoop:
        cmp     BPtr [edi], 0
        jz      SB_EnvPopEdi
        cmp     BPtr [edi], 'I'
        je      SB_IRQFound
        cmp     BPtr [edi], 'i'
        je      SB_IRQFound
        inc     edi
        jmp     SB_IRQLoop
SB_IRQFound:
        xor     eax, eax
        mov     al, [edi+1]
        sub     al, '0'
        mov     IRQ, eax
        pop     edi

        mov     CardType, 2
        call    SBDSPReset
        jc      EnvButNoCard
        call    GetSBDSPVersion
        cmp     ebx, 300h
        jb      Mono
        mov     CardType, 3
Mono:   popad
        clc
        ret

EnvButNoCard:
        Print   EnvNoCardMsg
        mov     CardType, 0
        jmp     SB_EnvNotFound

SB_EnvPopEdi:
        pop     edi

SB_EnvNotFound:
	popad
	stc
        ret

GetSBAddress    EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
GetSBDSPVersion Proc    Near

        xor     ebx, ebx
        mov     edx, BaseAddr            ; Fetch the card's base address.
	add	dx, 0Ch 		; Point the card's command port.
	mov	al, 0E1h		; Get DSP version number.
	out	dx, al

        mov     edx, BaseAddr            ; Fetch the card's base address.
	add	dx, 0Eh 		; Point the Data Available port.
	mov	ecx, 0FFFFh		; Wait until bit 7 is set.
bw1:    in      al, dx
	test	al, al
        js      fwd4
        loop    bw1
fwd4:   sub     dx, 04h                 ; Point the DSP Data port.
	in	al, dx
	mov	bh, al
        mov     edx, BaseAddr            ; Fetch the card's base address.
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

GetSBDSPVersion EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
SBDSPReset	Proc	Near

        mov     edx, BaseAddr
	mov	al, 1			; Set AL = The first init code.
	add	dx, 6			; Point the DSP reset port.
	out	dx, al			; Send the first reset code.
	mov	ecx, 5000		; Set the delay count to 5000.
	loop	$			; Give some time for the DSP.
	dec	al			; Clear the AL.
	out	dx, al			; Send the second reset code.
	mov	ecx, 5000		; Set the delay count to 5000.
	loop	$			; Give some time for the DSP.
	add	dx, 8			; Point the SB status port.

        mov     ecx, 1000
wd1:
	in	al, dx			; Clear the SB IRQ.
        js      ok1
        loop    wd1
ok1:

        sub     dx, 4                   ; Point the SB read data port.
        mov     ecx, 2000
wd2:
	in	al, dx			; Fetch a byte from it.
        cmp     al, 0AAh
        je      ok2
        loop    wd2
        jmp     notok
ok2:
	add	dx, 2			; Point the SB command port.
	CheckCmdStatus			; Wait until the DSP is ready.
        clc
	ret

notok:
        stc
        ret

SBDSPReset      EndP
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
AskConfirmation Proc    Near

        cmp     CardType, 0
        jz      NoneFound

        Print   CardMsg
        mov     ebx, CardType
        mov     ebx, TypeMsgPtr[ebx*4]
        Print   [ebx]

        mov     ebx, BaseAddr
        lea     edi, BaseMsg
        call    PrintW
        mov     eax, IRQ
        mov     ecx, 2
        lea     edi, IrqMsg
        call    ToDecimal
        mov     eax, DMA
        mov     ecx, 2
        lea     edi, DmaMsg
        call    ToDecimal
        mov     eax, SampleRate
        mov     ecx, 5
        lea     edi, FreqMsg
        call    ToDecimal
        Print   AddrMsg

        mov     PressedKey, 0
getk1:  cmp     PressedKey, 0
        jz      getk1
        cmp     PressedKey, 31h
        je      NotCorrect
        clc
        ret

NotCorrect:
        stc
        ret

NoneFound:
        Print   NoneMsg
        mov     PressedKey, 0
getk2:  cmp     PressedKey, 0
        jz      getk2
        cmp     PressedKey, 31h
        jne     NotCorrect
        clc
        ret


AskConfirmation EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
QueryCard       Proc    Near

        mov     eax, CardType
        mov     ecx, 1
        lea     edi, DefType
        call    ToDecimal
        Print   TypeQuery
        mov     cl, 3
        call    ReadNumber
        cmp     eax, 0Dh
        je      UseDefType
        mov     CardType, eax
UseDefType:
        cmp     CardType, 0
        jnz     NotNoCard
        stc
        ret

NotNoCard:
        mov     ebx, BaseAddr
        lea     edi, DefBase
        call    PrintW
        Print   BaseQuery
        mov     cl, 9
        call    ReadNumber
        cmp     eax, 0Dh
        je      UseDefBase
        shl     eax, 4
        add     eax, 200h
        mov     BaseAddr, eax
UseDefBase:

        mov     eax, IRQ
        mov     ecx, 2
        lea     edi, DefIrq
        call    ToDecimal
        Print   IrqQuery
        mov     cl, 9
        call    ReadNumber
        cmp     eax, 0Dh
        je      UseDefIrq
        cmp     eax, 01h
        je      Irq1
        mov     IRQ, eax
        jmp     UseDefIRQ
Irq1:   mov     cl, 5
        call    ReadNumber
        cmp     eax, 0Dh
        jne     Irq10
        mov     IRQ, 1
        jmp     UseDefIrq
Irq10:  add     eax, 10
        mov     IRQ, eax
UseDefIrq:

        mov     eax, DMA
        mov     ecx, 2
        lea     edi, DefDma
        call    ToDecimal
        Print   DmaQuery
        mov     cl, 7
        call    ReadNumber
        cmp     eax, 0Dh
        je      UseDefDma
        mov     DMA, eax
UseDefDMA:

        cmp     CardType, 1
        jne     NotGUS
        mov     SampleRate, 44100
        clc
        ret

NotGUS:

        Print   RateQuery
        cmp     CardType, 2
        jne     NoHighMono
        call    GetSBDSPVersion

        cmp     ebx, 201h
        jb      NoHighMono
        mov     MaxRateNum, 5
        cmp     SampleRate, 44100
        jb      HighRateOk
        mov     SampleRate, 44100
HighRateOk:
        Print   RateHigh
        jmp     RateCommon
NoHighMono:
        mov     MaxRateNum, 3
        cmp     SampleRate, 22050
        jb      LowRateOk
        mov     SampleRate, 22050
LowRateOk:
RateCommon:
        mov     eax, SampleRate
        mov     ecx, 5
        lea     edi, DefRate
        call    ToDecimal
        Print   RateRest
        mov     cl, MaxRateNum
        call    ReadNumber
        cmp     eax, 0Dh
        je      UseDefRate
        mov     eax, Rates[eax*4]
        mov     SampleRate, eax
UseDefRate:
        clc
        ret

QueryCard       EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
;ecx: digits, eax: number, edi: dest. buffer
ToDecimal       Proc    Near

        pushad
        add     edi, ecx
        dec     edi
DigitLoop:
        xor     edx, edx
        mov     ebx, 10
        div     ebx
        add     dl, '0'
        mov     [edi], dl
        dec     edi
        dec     ecx
        jnz     DigitLoop
        popad
        ret

ToDecimal       EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
ReadNumber      Proc    Near

        mov     PressedKey, 0
getk3:  cmp     PressedKey, 0
        jz      getk3
        xor     eax, eax
        mov     al, PressedKey
        cmp     al, 1Ch
        je      EnterPrsd
        mov     al, NumberScan[eax-02h]
        cmp     al, cl
        ja      ReadNumber
        push    eax
        mov     NumberPut, al
        add     NumberPut, '0'
        Print   NumberPut
        pop     eax
        ret

EnterPrsd:
        mov     eax, 0Dh
        ret

ReadNumber      EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ



;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º                                  D A T A                                    º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
GUS_EnvName	DB	'ULTRASND='
GUS_EnvNameLen	EQU	$-GUS_EnvName
GUS_EnvMsg	DB	'GUS Driver: ULTRASND environment variable not found!',10,13,'$'

SB_EnvName      DB      'BLASTER='
SB_EnvNameLen   EQU     $-SB_EnvName

CardMsg         DB      'Your soundcard has been detected to be $'
AddrMsg         DB      13,10,'with base address '
BaseMsg         DB      '0000h, IRQ '
IrqMsg          DB      '00, DMA '
DmaMsg          DB      '00 and output frequency '
FreqMsg         DB      '00000Hz.',13,10,'Is this correct (Y/n)?$'

TypeMsgPtr      Label   DWord
                DD      Offset NoneName
                DD      Offset GUSName
                DD      Offset SBName
                DD      Offset ProName

NoneName        DB      '[none]$'
GUSName         DB      'Gravis Ultrasound$'
SBName          DB      'Sound Blaster (mono)$'
ProName         DB      'Sound Blaster Pro (stereo)$'

CrLf            DB      13,10,'$'

NoneMsg         DB      'No soundcard has been detected. The detection is based on the ULTRASND-',13,10
                DB      'and BLASTER-environment variables, which should be defined if you have',13,10
                DB      'a Gravis Ultrasound or a Sound Blaster compatible sound card.',13,10,13,10
                DB      'We try to avoid using any undocumented hardware detection methods,',13,10
                DB      'since they might not work properly and often interfere with other hardware,',13,10
                DB      'such as certain network- and SCSI-adapters.',13,10,13,10
                DB      'Do you wish to specify a soundcard manually (Y/n)?$'

TypeQuery       DB      13,10
                DB      '  0 - none',13,10
                DB      '  1 - Gravis Ultrasound',13,10
                DB      '  2 - Sound Blaster (mono)',13,10
                DB      '  3 - Sound Blaster Pro (stereo)',13,10,13,10
                DB      'Which of the above soundcards do you have (Enter='
DefType         DB      '0)? $'

BaseQuery       DB      13,10,13,10,'Please enter the middle digit of the hexadecimal base address 2x0h,',13,10,'(Enter='
DefBase         DB      '0000h)? $'

IrqQuery        DB      13,10,'Please enter the IRQ number in decimal (Enter='
DefIrq          DB      '00)? $'

DmaQuery        DB      13,10,'Please enter the DMA channel number (Enter='
DefDma          DB      '00)? $'

RateQuery       DB      13,10,13,10,'  0 - 8000 Hz ',13,10
                DB      '  1 - 11025 Hz',13,10
                DB      '  2 - 16000 Hz',13,10
                DB      '  3 - 22050 Hz',13,10,'$'
RateHigh        DB      '  4 - 33075 Hz',13,10
                DB      '  5 - 44100 Hz',13,10,'$'
RateRest        DB      13,10,'Please choose one of the above output frequencies (Enter='
DefRate         DB      '00000)? $'

NumberScan      DB      1,2,3,4,5,6,7,8,9,0
NumberPut       DB      '0$'

Rates           DD      8000,11025,16000,22050,33075,44100

Notice0         DB      13,10,13,10,'Notice! This demo is an audiovisual presentation, in which the music',13,10
                DB      'plays an essential role. Therefore it is encouraged that this demo were',13,10
                DB      'run on a machine equipped with a sound card, such as the Gravis Ultrasound.',13,10,13,10
                DB      'Press any key to continue... $'

EnvNoCardMsg    DB      7,13,10,'BLASTER environment variable was found, but couldn''t initialize SB!',13,10,13,10,'$'

QueryMode       DB      0
MaxRateNum      DB      0

CardInfo        Label   DWord
CardType        DD      0
BaseAddr        DD      0
IRQ             DD      0
DMA             DD      0
SampleRate      DD      0

; 0 - None
; 1 - GUS
; 2 - SB mono
; 3 - SB Pro stereo

;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Code32		EndS

                End
