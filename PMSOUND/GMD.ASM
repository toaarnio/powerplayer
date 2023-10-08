TITLE GMD.ASM - EMF PM Sound System - General Mixer Device v0.2 23.04.95
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ

MaxChannels	EQU	16
MaxInstruments	EQU	31

Amplification   EQU     100

TempBufLen      EQU     1000

;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ

	INCLUDE stdrouts.hdr

Code32		Segment Para Public Use32
	ASSUME	CS:Code32,DS:Code32

	INCLUDE pmode.inc

;ÕÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÑ¸
;³³				    D A T A				      ³³
;ÔÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÏ¾

InstrInfo	DD	0
ChannelInfo	DD	0
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ

SmplLen 	EQU	0			; DD
SmplRepeatFrom	EQU	SmplLen+4		; DD
SmplRepeatTo	EQU	SmplRepeatFrom+4	; DD
SmplFlags	EQU	SmplRepeatTo+4		; DD
SmplOfs 	EQU	SmplFlags+4		; DD

InstrPtr	EQU	0			; dword
InstrLen	EQU	InstrPtr+4		; dword
InstrRepeatFrom EQU	InstrLen+4		; dword
InstrRepeatTo	EQU	InstrRepeatFrom+4	; dword
InstrFlags	EQU	InstrRepeatTo+4 	; byte
InstrUsed	EQU	InstrFlags+1		; byte
IIB_Len 	EQU	InstrUsed+1

ChnlIPtr	EQU	0			; dword
ChnlIPos	EQU	ChnlIPtr+4		; dword
ChnlIPosFract	EQU	ChnlIPos+4		; dword
ChnlAcc 	EQU	ChnlIPosFract+4 	; dword
ChnlAccFract	EQU	ChnlAcc+4		; dword
ChnlILen	EQU	ChnlAccFract+4		; dword
ChnlIRepeatFrom EQU	ChnlILen+4		; dword
ChnlIRepeatTo	EQU	ChnlIRepeatFrom+4	; dword
ChnlIFlags	EQU	ChnlIRepeatTo+4 	; byte
ChnlVolume	EQU	ChnlIFlags+1		; byte
ChnlBalance	EQU	ChnlVolume+1		; byte
ChnlPosition	EQU	ChnlBalance+1		; byte
ChnlActive	EQU	ChnlPosition+1		; byte
CIB_Len 	EQU	ChnlActive+1
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ

NumChannels	DD	0
OutputFreq	DD	0
MasterVolume	DD	255
TimerActive	DB	0
TimerFunction	DD	0
TimerCountOrg	DD	0
DMAPos		DD	0
MixPos		DD	0
MixCount	DD	0
TimerCount	DD	0

BufferStart	DD	0
BufferLen	DD	0
Temp16BitBuf    DD      0
Count16To8      DD      0

StereoMode	DB	0
Conv16To8Mode   DB      0

MixerUnR        DD      0
Mixer1          DD      0

Msg_NoChannels	DB	'Mixer: No free channels available!',10,13,'$'
Msg_NoInstrs	DB	'Mixer: Too many instruments!',10,13,'$'

VolTable        DB      2*65*256 DUP (0)

;ÕÑÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÑ¸
;³³				    C O D E				      ³³
;ÔÏÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÏ¾

public  Gmd_Reset
public	Gmd_AllocChan
public	Gmd_RegMemSmpl
public	Gmd_ChunkLoad
public	Gmd_SetSample
public	Gmd_StopSample
public	Gmd_SetVolume
public	Gmd_SetBalance
public	Gmd_SetFreq
public	Gmd_SetMastVol
public	Gmd_TmrReset
public	Gmd_TmrReqCall
public	Gmd_TmrDeInit

public	Gmd_Init
public	Gmd_DeInit
public	Gmd_Mixer

;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º Soundsys Function ID: Sd_Reset					       º
;º									       º
;º FUNCTION:	Initializes the sound card device for sound output.	       º
;º PARAMETERS:	None.							       º
;º RETURNS:	CF set on error, EAX --> Error message. 		       º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
Gmd_Reset       Proc    Near

	pushad

        xor     al, al                  ; Zero all channel and instrument data.
	mov	edi, ChannelInfo
	mov	ecx, MaxChannels*CIB_Len
	rep	stosb
	mov	edi, InstrInfo
	mov	ecx, MaxInstruments*IIB_Len
	rep	stosb

        mov     NumChannels, 0          ; Set the number of channels to zero.

	popad
	clc
	ret

Gmd_Reset       EndP
;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º Soundsys Function ID: Sd_AllocChan					       º
;º									       º
;º FUNCTION:	Allocate a channel.					       º
;º PARAMETERS:	None.							       º
;º RETURNS:	EAX = Channel handle.					       º
;º		CF set on error, EAX --> Error message. 		       º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
Gmd_AllocChan	Proc	Near

	pushad
	inc	NumChannels
	cmp	NumChannels, MaxChannels
	ja	NoChannels
	call	MakeVolTable

        mov     eax, NumChannels
        dec     eax
        imul    eax, CIB_Len
        mov     edi, ChannelInfo
        add     edi, eax
        mov     al, TempPos
        mov     [edi+ChnlPosition], al
        xor     TempPos, 1

	popad
	mov	eax, NumChannels
	dec	eax
	clc
	ret
NoChannels:
	popad
	lea	eax, Msg_NoChannels
	stc
	ret

TempPos         DB      0

Gmd_AllocChan	EndP
;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º Soundsys Function ID: Sd_RegMemSmpl					       º
;º									       º
;º FUNCTION:	Register a memory sample.				       º
;º PARAMETERS:	ESI --> Sample data.					       º
;º		EAX --> Sample info block.				       º
;º RETURNS:	EAX = Sample handle.					       º
;º		CF set on error, EAX --> Error message. 		       º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
Gmd_RegMemSmpl	Proc	Near

	pushad
	mov	edx, eax
	mov	edi, InstrInfo
	mov	ecx, MaxInstruments
SeekInstr:
	cmp	BPtr [edi+InstrUsed], 0
	je	InstrFound
	add	edi, IIB_Len
	dec	ecx
	jnz	SeekInstr
	popad
	lea	eax, Msg_NoInstrs
	stc
	ret

InstrFound:
	mov	[edi+InstrPtr], esi
	mov	eax, [edx+SmplLen]
	mov	[edi+InstrLen], eax
	mov	eax, [edx+SmplRepeatFrom]
	mov	[edi+InstrRepeatFrom], eax
	mov	eax, [edx+SmplRepeatTo]
	mov	[edi+InstrRepeatTo], eax
	mov	al, [edx+SmplFlags]
	mov	[edi+InstrFlags], al
	mov	BPtr [edi+InstrUsed], 1
	mov	TempStore, edi
	popad
	mov	eax, TempStore
	clc
	ret

TempStore	DD	0

Gmd_RegMemSmpl	EndP
;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º Soundsys Function ID: Sd_ChunkLoad					       º
;º									       º
;º FUNCTION:	Not implemented.					       º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
Gmd_ChunkLoad	Proc	Near

	stc
	ret

Gmd_ChunkLoad	EndP
;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º Soundsys Function ID: Sd_SetSample					       º
;º									       º
;º FUNCTION:	Play a sample on a channel.				       º
;º PARAMETERS:	EAX = Channel handle.					       º
;º		EDX = Sample handle.					       º
;º		ESI = Sample offset.					       º
;º RETURNS:	CF set on error, EAX --> Error message. 		       º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
Gmd_SetSample	Proc	Near

	pushad
	cmp	eax, NumChannels
	jb	ok
	int	01h
ok:	imul	eax, CIB_Len
	mov	edi, ChannelInfo
	add	edi, eax
	mov	eax, [edx+InstrPtr]
	mov	[edi+ChnlIPtr], eax
	mov	DPtr [edi+ChnlIPos], esi
	mov	DPtr [edi+ChnlIPosFract], 0
	mov	eax, [edx+InstrLen]
	mov	[edi+ChnlILen], eax
	mov	eax, [edx+InstrRepeatFrom]
	mov	[edi+ChnlIRepeatFrom], eax
	mov	eax, [edx+InstrRepeatTo]
	mov	[edi+ChnlIRepeatTo], eax
        mov     al, [edx+InstrFlags]
        mov     [edi+ChnlIFlags], al
	mov	BPtr [edi+ChnlActive], 1
	popad
	clc
	ret

Gmd_SetSample	EndP
;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º Soundsys Function ID: Sd_SetSample					       º
;º									       º
;º FUNCTION:	Stop a sample on a channel.				       º
;º PARAMETERS:	EAX = Channel handle.					       º
;º RETURNS:	CF set on error, EAX --> Error message. 		       º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
Gmd_StopSample	Proc	Near

	pushad
	imul	eax, CIB_Len
	mov	edi, ChannelInfo
	add	edi, eax
	mov	BPtr [edi+ChnlActive], 0
	popad
	clc
	ret

Gmd_StopSample	EndP
;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º Soundsys Function ID: Sd_SetVolume					       º
;º									       º
;º FUNCTION:	Set the volume of a channel.				       º
;º PARAMETERS:	EAX = Channel handle.					       º
;º		EDX = Volume [0..255]					       º
;º RETURNS:	CF set on error, EAX --> Error message. 		       º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
Gmd_SetVolume	Proc	Near

	pushad
	imul	eax, CIB_Len
	mov	edi, ChannelInfo
	add	edi, eax
	imul	edx, MasterVolume
	shr	edx, 8+2
	mov	[edi+ChnlVolume], dl
	popad
	clc
	ret

Gmd_SetVolume	EndP
;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º Soundsys Function ID: Sd_SetBalance					       º
;º									       º
;º FUNCTION:	Set the balance of a channel.				       º
;º PARAMETERS:	EAX = Channel handle.					       º
;º		EDX = Balance: 0 = left, 128 = middle, 255 = right.	       º
;º RETURNS:	CF set on error, EAX --> Error message. 		       º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
Gmd_SetBalance	Proc	Near

	clc
	ret

Gmd_SetBalance	EndP
;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º Soundsys Function ID: Sd_SetFreq					       º
;º									       º
;º FUNCTION:	Set the playing frequency of a sample.			       º
;º PARAMETERS:	EAX = Channel handle.					       º
;º		EDX = Sample frequency. 				       º
;º RETURNS:	CF set on error, EAX --> Error message. 		       º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
Gmd_SetFreq	Proc	Near

	pushad
	imul	eax, CIB_Len
	mov	edi, ChannelInfo
	add	edi, eax

	mov	eax, edx
	shl	eax, 16
	xor	edx, edx
	mov	ecx, OutputFreq
	idiv	ecx

	mov	edx, eax
	shr	edx, 16
	shl	eax, 16

	mov	[edi+ChnlAcc], edx
	mov	[edi+ChnlAccFract], eax
	popad
	clc
	ret

Gmd_SetFreq	EndP
;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º Soundsys Function ID: Sd_SetMastVol					       º
;º									       º
;º FUNCTION:	Set the master output volume.				       º
;º PARAMETERS:  EAX = Master volume [0..255]                                   º
;º RETURNS:	CF set on error, EAX --> Error message. 		       º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
Gmd_SetMastVol	Proc	Near

	push	eax
	and	eax, 0FFh
        mov     MasterVolume, eax
	pop	eax
	clc
	ret

Gmd_SetMastVol	EndP
;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º Soundsys Function ID: Sd_TmrReset					       º
;º									       º
;º FUNCTION:	Reset the timer device. 				       º
;º PARAMETERS:	None.							       º
;º RETURNS:	CF set on error, EAX --> Error message. 		       º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
Gmd_TmrReset	Proc	Near

	mov	TimerActive, 0
	clc
	ret

Gmd_TmrReset	EndP
;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º Soundsys Function ID: Sd_TmrReqCall					       º
;º									       º
;º FUNCTION:	Set the timer call address and frequency.		       º
;º PARAMETERS:	EDI --> The timer call address. 			       º
;º		EAX = Timer frequency in Hz, multiplied by 65536.	       º
;º RETURNS:	CF set on error, EAX --> Error message. 		       º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
Gmd_TmrReqCall	Proc	Near

	pushad
	mov	TimerActive, 1
	mov	TimerFunction, edi
	mov	ebx, eax
	mov	eax, OutputFreq
	xor	edx, edx
	shl	eax, 16
	idiv	ebx
	mov	TimerCountOrg, eax
	mov	TimerCount, eax
	popad
	clc
	ret

Gmd_TmrReqCall	EndP
;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º Soundsys Function ID: Sd_TmrDeInit					       º
;º									       º
;º FUNCTION:	Deinitialize the timer device.				       º
;º PARAMETERS:	None.							       º
;º RETURNS:	CF set on error, EAX --> Error message. 		       º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
Gmd_TmrDeInit	Proc	Near

	mov	TimerActive, 0
	clc
	ret

Gmd_TmrDeInit	EndP
;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º FUNCTION:	Initialize the mixer.					       º
;º PARAMETERS:	EAX = Output frequency. 				       º
;º		EDI --> DMA buffer.					       º
;º		ECX = Length of the DMA buffer. 			       º
;º		BL = Stereo mode: 0 - mono, 1 - stereo. 		       º
;º              BH = 16bit mixing: 0 - 8bit, 1 - 16bit.                        º
;º RETURNS:	CF set on error, EAX --> Error message. 		       º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
Gmd_Init	Proc	Near

	pushad
	mov	StereoMode, bl
        mov     Conv16To8Mode, 1 ;bh
	mov	OutputFreq, eax
	mov	BufferStart, edi
	mov	BufferLen, ecx
	Alloc	ChannelInfo, MaxChannels*CIB_Len
	Alloc	InstrInfo, MaxInstruments*IIB_Len

	xor	al, al
	mov	edi, ChannelInfo
	mov	ecx, MaxChannels*CIB_Len
	rep	stosb
	mov	edi, InstrInfo
	mov	ecx, MaxInstruments*IIB_Len
	rep	stosb

	mov	NumChannels, 0

        cmp     Conv16To8Mode, 1
        jne     Mix8Bit

        Alloc   Temp16BitBuf, 2*TempBufLen

        lea     eax, Mix16bStereoUnR
        lea     ebx, Mix16bStereo1
        cmp     StereoMode, 1           ; Stereo mode requested?
        je      SetMixers               ; Use the stereo mixer routines if yes.
        lea     eax, Mix16bMonoUnR
        lea     ebx, Mix16bMono1
        jmp     SetMixers

Mix8Bit:
        lea     eax, Mix8bStereoUnR
        lea     ebx, Mix8bStereo1
        cmp     StereoMode, 1           ; Stereo mode requested?
        je      SetMixers               ; Use the stereo mixer routines if yes.
        lea     eax, Mix8bMonoUnR
        lea     ebx, Mix8bMono1

SetMixers:
        mov     MixerUnR, eax
        mov     Mixer1, ebx

	popad
	clc
	ret

Gmd_Init	EndP
;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º FUNCTION:    Deinitialize the mixer.                                        º
;º PARAMETERS:  None.                                                          º
;º RETURNS:	CF set on error, EAX --> Error message. 		       º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
Gmd_DeInit	Proc	Near

	pushad

        cmp     Conv16To8Mode, 1
        jne     NoTempBuf
        Free    Temp16BitBuf, 2*TempBufLen
NoTempBuf:
        Free    InstrInfo, MaxInstruments*IIB_Len
	Free	ChannelInfo, MaxChannels*CIB_Len
	popad
	clc
	ret

Gmd_DeInit	EndP
;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º FUNCTION:	Update the DMA buffer.					       º
;º PARAMETERS:	EDI = Playing (DMA) position.				       º
;º RETURNS:	Nothing.						       º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
Gmd_Mixer	Proc	Near

        cmp     StereoMode, 1
        jne     fwd4
        shr     edi, 1
fwd4:
	mov	DMAPos, edi

	mov	eax, DMAPos
	mov	ebx, MixPos
	cmp	eax, ebx
	je	fwd2
	jb	fwd1
	mov	ecx, DMAPos
	sub	ecx, MixPos
	sub	ecx, 16
	jbe	fwd2
	mov	edi, MixPos
	call	MixData
	mov	MixPos, edi
	jmp	fwd2
fwd1:	mov	ecx, BufferLen
	sub	ecx, MixPos
	jbe	fwd3
	mov	edi, MixPos
	call	MixData
fwd3:	mov	DPtr MixPos, 0
	xor	edi, edi
	mov	ecx, DMAPos
	sub	ecx, 16
	jbe	fwd2
	call	MixData
	mov	MixPos, edi
fwd2:	ret

Gmd_Mixer	EndP
;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º FUNCTION:	Mix data from separate channels into one buffer.	       º
;º PARAMETERS:	EDI --> The DMA buffer. 				       º
;º		ECX = Number of bytes to mix.				       º
;º RETURNS:	Nothing.						       º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
MixData 	Proc	Near

        cmp     StereoMode, 1
        jne     NoStereo1
        add     edi, edi
NoStereo1:
        add     edi, BufferStart

        cmp     Conv16To8Mode, 1
        je      NoBufferClear

	push	edi ecx
        cmp     StereoMode, 1
        jne     NoStereo4
        add     ecx, ecx
NoStereo4:
        mov     al, 80h
	rep	stosb			; Clear the DMA buffer.
	pop	ecx edi
NoBufferClear:

	cmp	NumChannels, 0
	je	NoMixing

        cmp     Conv16To8Mode, 1
        jne     StartMixing
        mov     Count16To8, ecx
More16To8:
        cmp     StereoMode, 1
        jne     NoStereo6
        cmp     ecx, TempBufLen/2
        jbe     FitsInBuf
        mov     ecx, TempBufLen/2
        jmp     FitsInBuf
NoStereo6:

        cmp     ecx, TempBufLen
        jbe     FitsInBuf
        mov     ecx, TempBufLen
FitsInBuf:
        push    ecx edi
        mov     edi, Temp16BitBuf

	push	edi ecx
        cmp     StereoMode, 1
        jne     NoStereo5
        add     ecx, ecx
NoStereo5:
        mov     ax, 8000h
        rep     stosw                   ; Clear the temporary buffer.
	pop	ecx edi

StartMixing:
        jecxz   NoMoreMixing
	mov	MixCount, ecx
	cmp	TimerActive, 1
	jne	NoTimerCall
	cmp	ecx, TimerCount
	jb	NoTimerCall
	mov	ecx, TimerCount
NoTimerCall:

	mov	esi, ChannelInfo	; Point the channel info structure.
	mov	ebp, NumChannels	; Fetch the number of active channels.
MixNextChannel:
	cmp	BPtr [esi+ChnlActive], 1
	jne	NoData
	push	esi edi ebp ecx 	; Save some registers.
        call    MixChannel              ; Go mix the channel.
	pop	ecx ebp edi esi 	; Restore the registers.
NoData: add	esi, CIB_Len		; Point the next channel.
	dec	ebp
	jnz	MixNextChannel

        push    ecx
        mov     eax, ecx
        mov     cl, StereoMode
        add     cl, Conv16To8Mode
        shl     eax, cl
        pop     ecx

        add     edi, eax                ; Update the buffer pointer.

	sub	TimerCount, ecx
	sub	MixCount, ecx
	jnz	TimerCall
	cmp	TimerCount, 0
	je	TimerCall

NoMoreMixing:
        cmp     Conv16To8Mode, 1
        jne     NoMixing

        pop     edi ecx
        mov     esi, Temp16BitBuf
        push    ecx
        cmp     StereoMode, 1
        jne     NoStereo7
        add     ecx, ecx
NoStereo7:
        call    Conv16To8Bit
        pop     ecx
        sub     Count16To8, ecx
        mov     ecx, Count16To8
        jnz     More16To8
NoMixing:

	sub	edi, BufferStart
	cmp	StereoMode, 1

        jne     NoStereo2
	shr	edi, 1
NoStereo2:
	ret

TimerCall:
	cmp	TimerActive, 1
	jne	NoTimer
	push	esi edi ebp ecx 	; Save some registers.
	call	[TimerFunction]
	pop	ecx ebp edi esi 	; Restore the registers.
NoTimer:mov	eax, TimerCountOrg
	mov	TimerCount, eax
	mov	ecx, MixCount
	jmp	StartMixing
	ret

MixData 	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
MixChannel	Proc	Near

        cmp     StereoMode, 1
        jne     NoChannelChange
        cmp     BPtr [esi+ChnlPosition], 1      ; Is the channel on right?
        jne     NoChannelChange
        cmp     Conv16To8Mode, 1
        jne     ByteRes
        inc     edi
ByteRes:inc     edi
NoChannelChange:

	test	BPtr [esi+ChnlIFlags], 1
	jz	NoRepeat
Repeat: mov	eax, [esi+ChnlIRepeatTo]
	shl	eax, 16
	mov	ebx, [esi+ChnlIPos]
	shl	ebx, 16
	mov	bx, [esi+ChnlIPosFract+2]
	sub	eax, ebx
	xor	edx, edx
	mov	ebx, [esi+ChnlAcc]
	or	ebx, [esi+ChnlAccFract]
	rol	ebx, 16
	idiv	ebx
        or      edx, edx
        jz      fwd
        inc     eax
fwd:	cmp	ecx, eax
        jb      NoEnd
        sub     ecx, eax
	push	ecx
	mov	ecx, eax
	call	MixBytes
	pop	ecx
	cmp	eax, [esi+ChnlIRepeatTo]
	jb	Repeat
	mov	eax, [esi+ChnlIRepeatFrom]
	add	[esi+ChnlIPos], eax
        mov     eax, [esi+ChnlIRepeatTo]
	sub	[esi+ChnlIPos], eax
	jecxz	NoBytes
        jmp     Repeat
NoRepeat:
	mov	eax, [esi+ChnlILen]
	shl	eax, 16
	mov	ebx, [esi+ChnlIPos]
	shl	ebx, 16
	mov	bx, [esi+ChnlIPosFract+2]
	sub	eax, ebx
	xor	edx, edx
	mov	ebx, [esi+ChnlAcc]
	or	ebx, [esi+ChnlAccFract]
	rol	ebx, 16
	idiv	ebx
	cmp	ecx, eax
	jb	NoEnd
	mov	ecx, eax
	mov	BPtr [esi+ChnlActive], 0
	jecxz	NoBytes
NoEnd:	call	MixBytes
	cmp	eax, [esi+ChnlILen]
        jb      NoBytes ;jbe
	mov	BPtr [esi+ChnlActive], 0
NoBytes:
	ret

MixChannel	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
MixBytes	Proc	Near

	xor	ebx, ebx
	mov	eax, ecx

	mov	bh, [esi+ChnlVolume]
	mov	ecx, [esi+ChnlAcc]
	mov	ebp, [esi+ChnlAccFract]
	push	esi
	mov	edx, [esi+ChnlIPtr]
	add	edx, [esi+ChnlIPos]
	mov	esi, [esi+ChnlIPosFract]
	xchg	edx, esi

        push    eax
        shr     eax, 3
        jz      NoMix1
        dec     eax                     ; Adjust the counter.
	shl	eax, 16
        call    [MixerUnR]
NoMix1: pop     eax
        and     eax, 07h
        jz      NoMix2
        dec     eax                     ; Adjust the counter.
	shl	eax, 16
        call    [Mixer1]
NoMix2:

	mov	eax, esi
	pop	esi
	sub	eax, [esi+ChnlIPtr]
	mov	[esi+ChnlIPos], eax
	mov	[esi+ChnlIPosFract], edx
	ret

MixBytes	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Mix8bMonoUnR    Proc    Near

MixLoop1UnR:
        TmpVar = 0
        REPT    8
	mov	bl, [esi]
	mov	al, VolTable[ebx]
	add	edx, ebp
	adc	esi, ecx
        add     [edi+TmpVar], al
        TmpVar = TmpVar + 1
        ENDM

        add     edi, 8
	sub	eax, 10000h
        jns     MixLoop1UnR
	ret

Mix8bMonoUnR    EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Mix8bMono1      Proc    Near

MixLoop1:
	mov	bl, [esi]
	mov	al, VolTable[ebx]
	add	edx, ebp
	adc	esi, ecx
	add	[edi], al
	inc	edi

	sub	eax, 10000h
	jns	MixLoop1
	ret

Mix8bMono1      EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Mix8bStereoUnR  Proc    Near

MixLoop2UnR:
        TmpVar = 0
        REPT    8
	mov	bl, [esi]
	mov	al, VolTable[ebx]
	add	edx, ebp
	adc	esi, ecx
        add     [edi+TmpVar], al
        TmpVar = TmpVar + 2
        ENDM

        add     edi, 16
	sub	eax, 10000h
        jns     MixLoop2UnR
	ret

Mix8bStereoUnR  EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Mix8bStereo1    Proc    Near

MixLoop2:
	mov	bl, [esi]
	mov	al, VolTable[ebx]
	add	edx, ebp
	adc	esi, ecx
        add     [edi], al
        add     edi, 2

	sub	eax, 10000h
        jns     MixLoop2
	ret

Mix8bStereo1    EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Mix16bMonoUnR   Proc    Near

MixLoop3UnR:
        TmpVar = 0
        REPT    8
	mov	bl, [esi]
        mov     ax, WPtr VolTable[2*ebx]
	add	edx, ebp
	adc	esi, ecx
        add     [edi+TmpVar], ax
        TmpVar = TmpVar + 2
        ENDM

        add     edi, 16
	sub	eax, 10000h
        jns     MixLoop3UnR
	ret

Mix16bMonoUnR   EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Mix16bMono1     Proc    Near

MixLoop3:
	mov	bl, [esi]
        mov     ax, WPtr VolTable[2*ebx]
	add	edx, ebp
	adc	esi, ecx
        add     [edi], ax
        add     edi, 2

	sub	eax, 10000h
        jns     MixLoop3
	ret

Mix16bMono1     EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Mix16bStereoUnR Proc    Near

MixLoop4UnR:
        TmpVar = 0
        REPT    8
	mov	bl, [esi]
        mov     ax, WPtr VolTable[2*ebx]
	add	edx, ebp
	adc	esi, ecx
        add     [edi+TmpVar], ax
        TmpVar = TmpVar + 4
        ENDM

        add     edi, 32
	sub	eax, 10000h
        jns     MixLoop4UnR
	ret

Mix16bStereoUnR EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Mix16bStereo1   Proc    Near

MixLoop4:
	mov	bl, [esi]
        mov     ax, WPtr VolTable[2*ebx]
	add	edx, ebp
	adc	esi, ecx
        add     [edi], ax
        add     edi, 4

	sub	eax, 10000h
        jns     MixLoop4
	ret

Mix16bStereo1   EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
MakeVolTable	Proc	Near

	xor	edi, edi
	xor	ebp, ebp
NextVolumeVal:
	xor	ecx, ecx
NextSampleVal:
	mov	eax, ecx		; Get the sample value.
	add	al, 128
	sub	eax, 128		; Convert it to a signed value.
	imul	ebp			; Multiply the sample by the volume.
        mov     ebx, Amplification
        imul    ebx
        mov     ebx, 64*100             ; Get the maximum volume.
	idiv	ebx			; Divide by it.

        cmp     StereoMode, 1
        jne     OneOutputChn
        add     eax, eax
OneOutputChn:

        cmp     Conv16To8Mode, 1
        jne     NoWords1
        shl     eax, 9
NoWords1:

        mov     ebx, NumChannels        ; Get the number of channels.
	cdq
	idiv	ebx			; Divide by it.

        cmp     Conv16To8Mode, 1
        jne     NoWords2
        mov     WPtr VolTable[2*edi], ax; Store the resulting word.
        jmp     UseWords
NoWords2:
	mov	VolTable[edi], al	; Store the resulting byte.
UseWords:

	inc	edi
	inc	ecx
	cmp	ecx, 255
	jbe	NextSampleVal
	inc	ebp
	cmp	ebp, 64
	jbe	NextVolumeVal
	ret

MakeVolTable	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Conv16To8Bit    Proc    Near

        jecxz   NoData2
L16To8: lodsw
        mov     [edi], ah
        inc     edi
        dec     ecx
        jnz     L16To8
NoData2:ret

Conv16To8Bit    EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Code32		EndS

		End
