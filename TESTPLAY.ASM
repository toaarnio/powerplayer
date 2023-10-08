.386					       ; This program requires 80386.
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
EXTRN   InitSound:FAR
EXTRN   StartPlay:FAR
EXTRN   PlaySample:FAR
EXTRN   CallPlay:FAR
EXTRN   QuitPlay:FAR
EXTRN   Module:FAR
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Sseg	Segment Para Private Use16 Stack 'STACK'
	DB	256 DUP (0)			; Set stack size to 256 bytes.
Sseg	EndS
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Dseg	Segment Para Private Use16 Public 'DATA'

AutoMode	EQU	0
CallMode	EQU	1

PlayingInfo	Label	Word
PlayMode	DW	CallMode
CallFreq	DW	70
MixFreq 	DW	22000
TempoMode	DW	0
OctaveMode	DW	0
ModuleType      DW      1

DeviceInfo      Label   Word
Device		DW	3		; 3 = SB
Addr            DW      -1
IRQ		DW	7
DMA		DW	1
FilterMode      DW      0

Dseg	EndS
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Cseg    Segment Para Public Use16 'CODE'
	Assume	CS:Cseg, DS:Cseg, SS:Sseg	; Set the Assume.

PSP     DW      0

Begin:
	cld					; Clear the direction flag.
	mov	cs:PSP, ds			; Save the PSP's segment.
	mov	ax, Dseg			; Set AX = Data Segment.
	mov	ds, ax				; Set the DS to point it.

OpenModule:
	push	ds				; Save the data segment.
        mov     es, cs:PSP                      ; Fetch the PSP segment.
	mov	bx, 82h 			; Point to start of DOS cmdline.
	add	bl, es:[80h]			; Add the command line length.
	mov	Byte Ptr es:[bx-1], 0		; Set the terminating null.
        mov     ds, cs:PSP                      ; Fetch the PSP segment again.
	mov	dx, 82h 			; Point to start of commandline.
	mov	ax, 3D00h			; Request open file.
	int	21h				; Call DOS.
	pop	ds				; Restore the data segment.
	jc	ErrorExit			; Exit if error.

	mov	bx, ax				; Save the file handle to BX.
	mov	ax, SEG Module			; Set AX = ModuleSeg.
	mov	es, ax				; Set the ES to point it.
	mov	al, 3				; AL = 3: Sound Blaster.
	lea	si, DeviceInfo			; SI = Ptr to Device Info blk.
	lea	di, PlayingInfo 		; DI = Ptr to Playing Info blk.
        call    InitSound                       ; Initialize the SoundSystem.
        call    StartPlay                       ; Start playing the module.

PollPlay:
        call    CallPlay
	mov	ah, 1
	int	16h
	jz	PollPlay

Quit:
        call    QuitPlay
	mov	ax, 4C00h			; Request terminate.
	int	21h				; Call DOS (return to DOS).

ErrorExit:
	mov	ax, 4C01h
	int	21h

;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
WaitRetr	Proc	Near

	mov	dx, 3DAh
	in	al, dx
	test	al, 8
	jz	$-3
	ret

WaitRetr	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
WaitRetrOff	Proc	Near

	mov	dx, 3DAh
	in	al, dx
	test	al, 8
	jnz	$-3
	ret

WaitRetrOff	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Cseg	EndS

	End	Begin
