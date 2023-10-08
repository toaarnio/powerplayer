.486P						; This program requires 80386.
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Sseg	Segment Para Use16 Stack 'Stack'
	DB	256 DUP (0)			; Set stack size to 256 bytes.
Sseg	EndS
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Cseg    Segment Para Use16 'Code'
	Assume	CS:Cseg, DS:Cseg, SS:Sseg	; Set the Assume.

UName   EQU     'TOMI AARNIO'                   ; Name of the registered user.

Begin:
	cld					; Clear the direction flag.
        mov     cs:PSP, ds                      ; Save the PSP's segment.
;	      ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;ÄÄÄÄÄÄÄÄÄÄÄÄÄ¶ Make sure the DOS version number is at least 3.30 ÇÄÄÄÄÄÄÄÄÄÄÄÄÄ
;	      ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
	mov	ah, 30h 			; Request DOS version number.
	int	21h				; Call DOS.
	xchg	ah, al				; Exchange version & subversion.
	cmp	ax, 031Eh			; Version at least 3.30?
	jae	DosOk				; Proceed if it is.
	mov	ax, MusicSys			; Fetch the segment address.
	mov	ds, ax				; Set DS to point to it.
	lea	dx, DosErr			; Point the message.
	mov	ah, 09				; Else request display message.
	int	21h				; Call DOS.
	int	20h				; Terminate.
DosOk:
;	     ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;ÄÄÄÄÄÄÄÄÄÄÄÄ¶ Make sure the main processor is a 80386 or higher ÇÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
;	     ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
	call	CPU_Type			; Detect the CPU type.
	cmp	ax, 0003			; 80386 or higher present?
	jae	CpuOk				; Proceed if yes.
        lea     dx, CpuErr                      ; Point the message.
        jmp     ErrorExit                       ; Display error message & quit.
CpuOk:
;                ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¶ Handle the command line parameters, if any ÇÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
;                ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
	mov	bx, 80h 			; Point the PSP DTA.
	cmp	Byte Ptr es:[bx], 0		; No command line?
	je	ParamsChecked			; Skip parsing if so.
	mov	bx, 82h 			; Else point the command line.
NextCmdByte:
	cmp	Byte Ptr es:[bx], '/'		; Parameter identifier found?
	je	CheckParam			; Check the parameter if so.
	cmp	Byte Ptr es:[bx], '-'		; Parameter identifier found?
	je	CheckParam			; Check the parameter if so.
	cmp	Byte Ptr es:[bx], 13		; End of command line?
	je	ParamsChecked			; Quit checking if yes.
NoParam:
	inc	bx				; Else increment the BX.
	jmp	NextCmdByte			; And go get the next byte.
CheckParam:
        cmp     Byte Ptr es:[bx-1], ' '         ; Is this a parameter at all?
        jne     NoParam
	cmp	Byte Ptr es:[bx+1], 'M' 	; Module type override letter?
	je	SetModType			; Go set module type if so.
	cmp	Byte Ptr es:[bx+1], 'm' 	; Module type override letter?
	je	SetModType			; Go get module type if so.
        cmp     Byte Ptr es:[bx+1], 'P'         ; PT-tempo override letter?
        je      OldTrackerMode                  ; If so, disable PT tempos.
        cmp     Byte Ptr es:[bx+1], 'p'         ; PT-tempo override letter?
        je      OldTrackerMode                  ; If so, disable PT tempos.
        cmp     Byte Ptr es:[bx+1], 'O'         ; 5-octave mode letter?
        je      FiveOctaveMode                  ; If so, go set the flag.
        cmp     Byte Ptr es:[bx+1], 'o'         ; 5-octave mode letter?
        je      FiveOctaveMode                  ; If so, go set the flag.
        inc     bx                              ; Increment the cmdline ptr.
        jmp     NextCmdByte                     ; Loop until cmdline parsed.
SetModType:
        mov     al, es:[bx+2]                   ; Get the module type code.
        sub     al, 30h                         ; Convert it to binary.
        mov     cs:ModType, al                  ; Store it into ModType.
	mov	Byte Ptr es:[bx], 20h		; Clear the parameter ID byte.
	mov	Byte Ptr es:[bx+1], 20h 	; Clear the parameter letter.
        mov     Byte Ptr es:[bx+2], 20h         ; Clear the mod-type override.
        add     bx, 3                           ; Point to the next parameter.
        jmp     NextCmdByte                     ; Loop until cmdline parsed.
OldTrackerMode:
        mov     cs:TempoFlag, 1                 ; Disable PT's extended tempos.
	mov	Byte Ptr es:[bx], 20h		; Clear the parameter ID byte.
	mov	Byte Ptr es:[bx+1], 20h 	; Clear the parameter letter.
        add     bx, 2                           ; Point to the next parameter.
        jmp     NextCmdByte                     ; Loop until cmdline parsed.
FiveOctaveMode:
        mov     cs:OctaveFlag, 1                ; Use five octaves.
	mov	Byte Ptr es:[bx], 20h		; Clear the parameter ID byte.
	mov	Byte Ptr es:[bx+1], 20h 	; Clear the parameter letter.
        add     bx, 2                           ; Point to the next parameter.
        jmp     NextCmdByte                     ; Loop until cmdline parsed.
ParamsChecked:
;		    ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¶ Initialize the EXEC parameter block ÇÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
;		    ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
	mov	cs:ExecParameters1+4, ds	; Store PSP value.
	mov	cs:ExecParameters1+8, ds	; Store PSP value.
	mov	cs:ExecParameters1+12, ds	; Store PSP value.
	mov	cs:ExecParameters2+4, cs	; Store CS value.
	mov	cs:ExecParameters2+8, cs	; Store CS value.
	mov	cs:ExecParameters2+12, cs	; Store CS value.
;	   ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;ÄÄÄÄÄÄÄÄÄÄ¶ Reduce the used memory block's size & get free memory ÇÄÄÄÄÄÄÄÄÄÄÄÄ
;	   ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
        mov     es, cs:PSP                      ; Get the PSP segment.
	mov	ax, 4A00h			; Request set memory block size.
	mov	bx, 0FFFFh			; This returns available memory.
	int	21h				; Call DOS.
	mov	cs:AvailableMemory, bx		; Store amount of free memory.
	mov	ax, ds				; Set AX = PSP segment.
	mov	cx, ModuleSeg			; Point the end of the EXE code.
	add	cx, 10h 			; Add the stack size.
	sub	cx, ax				; Calculate memory block size.
	mov	bx, cx				; Set it into the BX.
	mov	cs:CodeSize, bx 		; Store the size of the code.
	mov	ax, 4A00h			; Request set memory block size.
	int	21h				; Call DOS.
	jc	MemErr				; If error, quit.
;		       ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¶ Initialize the EXEC filenames ÇÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
;		       ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
	mov	bx, 2Ch 			; Set BX to be a pointer.
	mov	ax, [bx]			; Address of DOS Environment.
	mov	es, ax				; Set it into the ES.
	mov	cs:ExecParameters1, ax		; Save it.
	mov	cs:ExecParameters2, ax		; Save it.
        xor     bx, bx                          ; Point the DOS environment.
        mov     cx, 1000h                       ; Set max count.
        mov     eax, 'SMOC'                     ; Set the search string.
ScanComSpec:
        cmp     es:[bx], eax                    ; Compare the dword.
        je      ComSpecFound                    ; Jump if COMSPEC found.
        inc     bx                              ; Point the next byte.
        loop    ScanComSpec                     ; Loop until maximum count.
        lea     dx, EnvErrMsg1                  ; Point the error message.
        jmp     ErrorExit                       ; Display error message & quit.
ComSpecFound:
        add     bx, 8                           ; Point the DOS load path.
        mov     di, bx                          ; Scan the bytes at ES:DI.
        mov     cx, 256                         ; Set the maximum count.
        mov     al, 33                          ; Skip all chars below space.
ScanWhiteSpace:
        scasb                                   ; Is it valid character?
        jb      PathFound                       ; Comspec path found.
        loop    ScanWhiteSpace                  ; Scan the comspec string.
        lea     dx, EnvErrMsg1                  ; Point the error message.
        jmp     ErrorExit                       ; Display error message & quit.
PathFound:
        dec     di                              ; Adjust down the offset.
        mov     bx, di                          ; Copy the offset to the BX.
        xor     di, di                          ; Clear the DI.
NextByte:
	mov	al, es:[bx]			; Get a byte of the COMSPEC.
	inc	bx				; Increment the BX.
	or	al, al				; End of string?
        jz      ComSpecDone                     ; Proceed if yes.
	mov	cs:ComSpec[di], al		; Else store the byte.
	inc	di				; Increment the DI.
	jmp	NextByte			; And go get the next one.

ComSpecDone:
        mov     cs:ComSpec[di], al              ; Store the null byte.
	xor	ax, ax				; Scan for a null string.
	xor	di, di				; Start scanning at ES:0.
	mov	cx, 0FFFFh			; Set max count.
ScanNull:
	scasw					; Null string found?
	je	NullFound			; Proceed if yes.
	dec	di				; Advance only by one byte.
	loop	ScanNull			; Loop until max count.
        lea     dx, EnvErrMsg1                  ; Point the error message.
        jmp     ErrorExit                       ; Display error message & quit.
NullFound:
	add	di, 2				; Point the DOS load path.
	mov	si, di				; Set it's address into the SI.
	lea	di, MainModuleName		; Point the overlay's name.
	mov	ax, cs				; Fetch the CS value.
	mov	bx, es				; Fetch the ES value.
	mov	es, ax				; Set the ES.
	mov	ds, bx				; Set the DS.
CopyLoadPath:
	lodsb					; Get a byte of DOS load path.
        stosb                                   ; Store the byte.
	or	al, al				; Was it end of string marker?
        jnz     CopyLoadPath                    ; Continue copying if not.
	sub	di, 7				; Point the correct position.
	mov	Dword Ptr es:[di], 'NORF'	; Store filename.
	mov	Dword Ptr es:[di+4], 'DNET'	; Store 2nd byte of ovl name.
	mov	Dword Ptr es:[di+8], 'EXE.'	; Store 3rd byte of ovl name.
	mov	Dword Ptr es:[di+12], 00	; Store the ASCIIZ zero.
;    ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;ÄÄÄÄ¶ Copy FRONTEND.EXE from the end of this executable into an EXE-file ÇÄÄÄÄÄ
;    ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
	mov	ax, cs				; Fetch the CS value.
	mov	ds, ax				; Set it into the DS.
	mov	ax, 3C00h			; Request create a file.
	xor	cx, cx				; Set a normal attribute.
	lea	dx, MainModuleName		; Point the filename string.
	int	21h				; Call DOS.
	jnc	NoOvErr 			; Proceed if no error.
	lea	dx, OvlErrMsg			; Point the error message.
        jmp     ErrorExit                       ; Display error message & quit.
NoOvErr:
	mov	bx, ax				; Set the file handle in BX.
	mov	ax, ModuleSeg			; Get ModuleSeg's segment.
	mov	ds, ax				; Set it into the DS.
	mov	ax, 4000h			; Request write a file.
	lea	cx, OvlSize			; Set the byte count.
	xor	dx, dx				; Clear the DX.
	int	21h				; Write the overlay file.
	jnc	NoOvlErr			; Proceed if no error.
	lea	dx, OvlErrMsg			; Point the message.
        jmp     ErrorExit                       ; Display error message & quit.
NoOvlErr:
	mov	ax, 3E00h			; Request close a file.
	int	21h				; Close the overlay file.
	mov	ax, cs				; Fetch the CSeg address.
	mov	ds, ax				; Set it into the DS.
        mov     es, PSP                         ; Set the ES to point the PSP.
;	     ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;ÄÄÄÄÄÄÄÄÄÄÄÄ¶ Store a pointer into the PSP DTA for the C-module ÇÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
;	     ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
	cmp	Byte Ptr es:[80h], 0		; Command line?
	jne	NormOffs			; Use the normal offset if so.
	mov	di, 82h 			; Else set DI = 82h.
	mov	Byte Ptr es:[di], 13		; Store a return.
	inc	di				; Increment the DI.
	jmp	DefOffs 			; Skip.
NormOffs:
	mov	di, 82h 			; Point the DTA area.
	mov	al, 13				; Set the search character.
	mov	cx, 255 			; Initialize the search count.
	repne	scasb				; Point end of command line.
DefOffs:
	mov	es:[di+2], es			; Store the pointer's segment.
	mov	es:[di], di			; Store the pointer's offset.
	mov	RetValOffs, di			; Save the pointer's offset.
;		       ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¶ Load and execute the C-module ÇÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
;		       ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
        mov     OldSS, ss                       ; Save the SS.
        mov     OldSP, sp                       ; Save the SP.
	mov	ax, cs				; Fetch the CS value.
	mov	es, ax				; Set it into the ES.
	mov	ax, 4B00h			; Request load and execute.
	lea	bx, ExecParameters1		; Point the EPB.
	lea	dx, MainModuleName		; Point the Main Module's name.
	int	21h				; Call DOS.
        mov     ss, OldSS                       ; Restore the SS.
        mov     sp, OldSP                       ; Restore the SP.
	pushf					; Save the status flags.
	mov	ax, 4100h			; Request delete a file.
	lea	dx, MainModuleName		; Point the main module's name.
	int	21h				; Delete FRONTEND.EXE.
	popf					; Restore the status flags.
        jnc     ExitCode                        ; If no carry, get exit code.
	mov	ax, 4C01h			; Else request terminate.
	int	21h				; Call DOS (return to DOS).
ExitCode:
	mov	ax, 4D00h			; Request get exit code.
	int	21h				; Call DOS.
	or	ax, ax				; Normal termination?
	jz	NoError 			; Proceed if yes.
	cmp	al, 2				; Usage requested?
	jne	ErrRet				; Exit with error code if not.
        lea     dx, UsageMessage                ; Point the usage message.
        jmp     ErrorExit                       ; Display error message & quit.
ErrRet:
	mov	ax, 4C01h			; Request terminate.
	int	21h				; Call DOS (return to DOS).
;		     ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¶ Get the returned playing parameters ÇÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
;		     ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
NoError:
        mov     es, PSP                         ; Set the ES to point the PSP.
	mov	di, RetValOffs			; Point the returned parameters.
	mov	ax, es:[di]			; Fetch the playing device.
	mov	PlayingDevice, ax		; Store it.
	mov	ax, es:[di+2]			; Fetch the SB's IRQ number.
	mov	SbIrqLineNumber, ax		; Store it.
	mov	ax, es:[di+4]			; Fetch the filename's offset.
	mov	dx, es:[di+6]			; Fetch the filename's segment.
	mov	Word Ptr FilenamePointer, ax	; Store the offset.
	mov	Word Ptr FilenamePointer+2, dx	; Store the segment.
	mov	ax, es:[di+8]			; Fetch the playing frequency.
	mov	PlayingFrequency, ax		; Store it.
;                     ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¶ Check the module file's extension ÇÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
;                     ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
        cmp     ModType, 0FFh                   ; Is the module type defined?
        jne     OpenModule                      ; Skip extension check if yes.
        mov     ModType, 3                      ; Set the assumed module type.
        lds     si, FilenamePointer             ; Point DS:SI to the filename.
        mov     eax, 'WOW.'                     ; Search the .WOW extension.
        mov     ebx, 'wow.'                     ; Check also .wow extension.
        mov     cx, 250                         ; Maximum length of the path.
CheckModExt:
        cmp     [si], eax                       ; Is this a .WOW module?
        je      OpenModule                      ; Go open the file if so.
        cmp     [si], ebx                       ; Is the extension .wow?
        je      OpenModule                      ; Go open the file if so.
        inc     si                              ; Else point the next byte.
        loop    CheckModExt                     ; Check the whole filename.
        mov     cs:ModType, 0FFh                ; It wasn't 8-channel module.
;	   ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;ÄÄÄÄÄÄÄÄÄÄ¶ If no error in C-module,load the module & start playing ÇÄÄÄÄÄÄÄÄÄÄ
;	   ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
OpenModule:
	mov	ax, 3D00h			; Request open file.
        lds     dx, cs:FilenamePointer          ; Get the filename pointer.
	int	21h				; Call DOS.
	jc	FileErr 			; Exit if error.
	mov	bx, ax				; Set the file handle to BX.
	mov	ax, 4202h			; Request move file pointer.
	xor	cx, cx				; Clear the CX.
	mov	dx, cx				; Clear the DX, too.
	int	21h				; Call DOS.
	jc	FileErr 			; Exit if error.
	movzx	eax, ax 			; Clear EAX.H.
	shl	edx, 16 			; Set DX into EDX.H.
	add	eax, edx			; Combine the EDX and the EAX.
        movzx   ecx, cs:AvailableMemory         ; Get amount of free memory.
	shl	ecx, 4				; Convert to bytes.
	cmp	eax, ecx			; File too big?
	jb	FileOk				; Proceed if not.
	mov	ax, 3E00h			; Else request close a file.
	int	21h				; Call DOS.
        jmp     MemErr                          ; Exit.
FileOk:
	mov	bp, bx				; Save the file handle.
        mov     bx, cs                          ; Fetch the CS value.
        mov     ds, bx                          ; Set it into the DS.
	shr	eax, 4				; Cnvt file size to paragraphs.
	inc	ax				; Add one paragraph for safety.
	add	ax, CodeSize			; Add the size of the code.
	mov	bx, ax				; Set the result into the BX.
	add	bx, 20h 			; Add 512 bytes to size.
	cmp	bx, AvailableMemory		; Enough free memory available?
        ja      MemErr                          ; Exit if not.
	push	bx				; Save amount of memory needed.
	mov	bx, AvailableMemory		; Get amount of available mem.
	mov	ax, 4A00h			; Request set memory block size.
	int	21h				; Call DOS.
        jc      MemErr                          ; If error, quit.
        call    ClearMemory                     ; Clear the module buffer.
	mov	bx, bp				; Restore the file handle.
	mov	ax, 4200h			; Request move file pointer.
	xor	cx, cx				; Clear the CX.
	mov	dx, cx				; Clear the DX, too.
	int	21h				; Call DOS.
        jc      FileErr                         ; Exit if error.
        mov     ax, ModuleSeg                   ; Set AX = ModuleSeg.
        mov     ds, ax                          ; Set the DS to point it.
	mov	ax, bx				; Set the file handle to AX.
	xor	dx, dx				; Clear the DX.
	call	LoadModule			; Read the module into memory.
	pop	bx				; Restore needed amount of mem.
        jc      FileErr                         ; Exit if error.
	mov	ax, cs				; Fetch the CS value.
	mov	ds, ax				; Set it into the DS.
	or	edx, edx			; Was the module an STM?
	je	MemAlloc			; Normal mem block size if so.
	shr	edx, 4				; Calculate module's length.
	inc	dx				; Round it upwards.
        add     dx, CodeSize                    ; Add the code size.
	mov	bx, dx				; Set the result into the BX.
MemAlloc:
	mov	ax, 4A00h			; Request set memory block size.
	int	21h				; Call DOS.
        jc      MemErr                          ; If error, quit.
	mov	es, ExecParameters2		; Get DOS Environment segment.
	mov	ax, 4900h			; Request free memory.
	int	21h				; Call DOS.
	mov	ax, MusicSys			; Fetch the MusicSys segment.
	mov	es, ax				; Set it in the ES register.
	xor	di, di				; Clear Destination Index.
	mov	al, 80h 			; Initialize AL for clearing.
        mov     cx, 1001                        ; Clear 1001 bytes.
	rep	stosb				; Initialize the MixBuffers.
	mov	ax, PlayingDevice		; Fetch the playing device.
	cmp	al, 2				; SB used?
	jb	NoIniting			; No SB initializing if not.
	mov	ah, 7				; Else request initialize SB.
	call	MusicSystem			; Call the 386-only MusicSystem.
NoIniting:
	mov	ax, PlayingDevice		; Fetch the playing device.
	mov	bx, PlayingFrequency		; Fetch the playing frequency.
        mov     cl, TempoFlag                   ; Fetch tempo mode byte in CL.
        mov     ch, OctaveFlag                  ; Fetch the octave mode flag.
	mov	dx, SbIrqLineNumber		; Get the SB's IRQ number.
	mov	dh, dl				; Set it into the DH.
	mov	dl, ModType			; Get the module's type.
	mov	di, 70				; Set vertical retrace freq.
        xor     bp, bp                          ; Request auto-play mode.
	mov	si, ModuleSeg			; Get ModuleSeg address.
	mov	es, si				; Then set it into the ES.
	call	MusicSystem			; Call the 386-only MusicSystem.

DosShell:
	mov	ax, cs				; Fetch the CS value.
        mov     ds, ax                          ; Set it into the DS.
        mov     es, ax                          ; Set it into the ES as well.
        lea     dx, ShellMsg                    ; Point the DOS-Shell message.
	mov	ah, 9				; Request display a message.
	int	21h				; Call DOS.
        mov     OldSS, ss                       ; Save the SS.
        mov     OldSP, sp                       ; Save the SP.
	mov	ax, 4B00h			; Request load and execute.
	lea	bx, ExecParameters2		; Point the EPB.
	lea	dx, ComSpec			; Point the COMSPEC.
	int	21h				; Call DOS.
        mov     ss, OldSS                       ; Restore the SS.
        mov     sp, OldSP                       ; Restore the SP.
	jnc	Quit				; Normally, quit.
	lea	dx, KeyMsg			; Point the message.
        mov     ah, 9                           ; Request display a message.
	int	21h				; Call DOS.
	xor	ah, ah				; Request wait for a key.
	int	16h				; Call BIOS.

Quit:
        mov     ax, PlayingDevice               ; Fetch the playing device.
	mov	ah, 2				; Request stop playing.
        call    MusicSystem                     ; Call the EMF MusicSystem.
        lea     dx, ThanxMsg                    ; Point the ending message.
        mov     ah, 9                           ; Request display a message.
	int	21h				; Call DOS.
	IF	Unreg
	call	TimerDelay			; Delay a little.
	ENDIF
	mov	ax, 4C00h			; Request terminate.
	int	21h				; Call DOS (return to DOS).

ErrorExit:                                      ; -- General Error Handler --
	mov	ax, MusicSys			; Fetch the segment address.
	mov	ds, ax				; Set DS to point to it.
	mov	ah, 09				; Else request display message.
	int	21h				; Call DOS.
	mov	ax, 4C01h			; Request terminate.
	int	21h				; Call DOS (return to DOS).

FileErr:
	lea	dx, FileErrorMsg		; Point the error message.
        jmp     ErrorExit                       ; Display error message & quit.
MemErr:
        lea     dx, MemErrMsg                   ; Point the error message.
        jmp     ErrorExit                       ; Display error message & quit.
;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º FUNCTION:    This routine causes a 4-sec delay.                             º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
TimerDelay	Proc	Near

	mov	ax, 0040h			; Set BIOS data segment in AX.
	mov	es, ax				; Copy it into the ES.
	mov	bx, 006Ch			; Set the offset into the BX.
	mov	eax, es:[bx]			; Get current count.
        add     eax, 4*18                       ; Set the target count.
WaitLoop:
	cmp	Dword Ptr es:[bx], eax		; Target count reached?
	jb	WaitLoop			; Wait if not.
	ret					; Return.

TimerDelay	EndP
;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º INPUT:	BX = The number of paragraphs to clear. 		       º
;º FUNCTION:	This routine clears BX paragraphs of memory.		       º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
ClearMemory	Proc	Near

	pusha					; Save all registers.
	push	es				; Save the ES.
	mov	cx, ModuleSeg			; Fetch the module's segment.
	mov	es, cx				; Set the ES to point it.
	xor	ax, ax				; Clear the AX.
MemClr:
	mov	di, ax				; Start storing from ES:0.
	mov	cx, 16				; Set the byte count to 16.
	rep	stosb				; Clear a paragraph.
	mov	cx, es				; Fetch the ES value.
	inc	cx				; Point the next segment.
	mov	es, cx				; Set it into the ES.
	dec	bx				; Any more segments to clear.
	jnz	MemClr				; Loop if that is the case.
	pop	es				; Restore the ES.
	popa					; Restore all general registers.
	ret					; Return.

ClearMemory	EndP
;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º INPUT:	AX = The file handle of the module to load.		       º
;º		DS:DX = Address of the buffer where to read the file.	       º
;º RETURNS:	EDX = The size of the MOD in memory (zero if STM).	       º
;º		CF = 0 means no error.					       º
;º		CF = 1 means read error.				       º
;º FUNCTION:	This routine detects the module's type & loads it into DS:DX.  º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
LoadModule	Proc	Near

	cld					; Clear the direction flag.
	push	bx				; Save the BX.
	push	es				; Save the ES.
	mov	bp, ax				; Save the file handle.
	cmp	cs:ModType, 0			; STM to be loaded?
	je	LoadSTM 			; Use a different loader if so.
ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
º;		   Load the instrument headers & order bytes		       º
ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
	mov	bx, ax				; Set the file handle into BX.
	mov	ax, 3F00h			; Request read a file.
	mov	cx, 1084			; Set the byte count.
	int	21h				; Call DOS.
	jc	ModLoadError			; Exit if an error occurred.
	mov	ax, ds				; Fetch the module's segment.
	mov	es, ax				; Set it into the ES.
	mov	cs:InstrCnt, 31 		; Set the default sample count.
	mov	cs:SngLenOffs, (31*30)+20	; Set the default song len offs.
	mov	cs:PatternBase, 1084		; Set the default pattern offs.
        mov     cs:PatternSize, 1024            ; Set the default pattern size.
	cmp	Byte Ptr cs:ModType, 0FFh	; Module type specified?
	je	DetectType			; Detect it if not.
	cmp	Byte Ptr cs:ModType, 1		; Normal MOD?
        je      NormMod                         ; Proceed if so.
	cmp	Byte Ptr cs:ModType, 3		; 8-channel MOD?
        jne     Chn15                           ; If not, it must by old MOD.
        mov     cs:PatternSize, 2048            ; Store the pattern's size.
        jmp     NormMod                         ; Then continue normally.
DetectType:
	mov	bx, 28				; Point the STM signature.
	cmp	Word Ptr [bx], 021Ah		; Is this an STM?
	je	LoadSTM 			; Go load an STM if it is.
	mov	bx, 1080			; Set BX to point MOD signature.
	cmp	Dword Ptr [bx], '.K.M'		; Is this a normal PT MOD?
        je      NormMod                         ; Skip if it's a normal module.
        cmp     Dword Ptr [bx], '!K!M'          ; Is this a PT2.2 100-patt MOD?
        je      NormMod                         ; Go initialize it if yes.
	cmp	Dword Ptr [bx], '4TLF'		; Is this an FLT4 module?
        je      NormMod                         ; Skip if it's a normal module.
	cmp	Dword Ptr [bx], '8TLF'		; Is this an FLT8 module?
        je      OctaMod                         ; Go handle it if yes.
        cmp     Dword Ptr [bx], 'NHC8'          ; Is this a Fast Tracker MOD?
        je      OctaMod                         ; Go handle it if yes.
        cmp     Dword Ptr [bx], 'ATCO'          ; Is this an Octa Composer MOD?
        jne     Chn15                           ; If not, it must be old MOD.
OctaMod:
        mov     cs:PatternSize, 2048            ; Store the pattern's size.
        jmp     NormMod                         ; Then continue normally.
Chn15:
	push	dx				; Save the DX.
	mov	cs:InstrCnt, 15 		; Use only 15 samples if not.
	mov	cs:SngLenOffs, (15*30)+20	; Set the song length offset.
	mov	cs:PatternBase, (15*30)+150	; Set the default pattern offs.
	mov	ax, 4200h			; Request move file pointer.
	mov	bx, bp				; Fetch the file handle.
	xor	cx, cx				; Clear the offset's high word.
	mov	dx, cx				; Clear the offset's low word.
	int	21h				; Call DOS.
	pop	dx				; Restore the DX.
	jc	ModLoadError			; Exit if an error occurred.
	mov	ax, 3F00h			; Request read from file.
	mov	bx, bp				; Get the file handle.
	mov	cx, (15*30)+150 		; Set the byte count.
	int	21h				; Call DOS.
	jc	ModLoadError			; Exit if an error occurred.
NormMod:
	mov	si, cs:SngLenOffs		; Point the songlength.
	lodsw					; Fetch it.
	push	si				; Save the offset.
        xor     ah, ah                          ; Clear the highest byte.
        movzx   cx, al                          ; Set the loop count in CX.
        or      cx, cx                          ; Length of the song zero?
        jnz     FindHighest                     ; Skip if length normal.
        mov     cx, 7Fh                         ; Otherwise set max. count.
FindHighest:
	lodsb					; Get the next order byte.
	cmp	al, ah				; Is it above the previous one?
	jbe	$+4				; Save the previous one if not.
	mov	ah, al				; Else overwrite it.
	loop	FindHighest			; Loop through the order list.
	pop	si				; Restore the offset.
	mov	bh, ah				; BH = highest order number.
	xor	ah, ah				; Clear the highest byte again.
	mov	cx, 7Fh 			; Search the whole order list.
FindHighest2:
	lodsb					; Get the next order byte.
	cmp	al, ah				; Is it above the previous one?
	jbe	$+4				; Save the previous one if not.
	mov	ah, al				; Else overwrite it.
	loop	FindHighest2			; Loop through the order list.
	push	0000h				; Assume that patterns are OK.
	cmp	bh, ah				; Are they equal?
	je	PatternsOK			; Patterns are OK if so.
	mov	ch, ah				; Copy number of patterns to CH.
	sub	ch, bh				; Calc # of unneeded patterns.
	shr	cx, 8				; # of null patterns in CL.
        imul    cx, Word Ptr cs:PatternSize     ; Multiply by pattern size.
	mov	ah, bh				; Number of real patterns in AH.
	pop	bx				; Discard the zero from stack.
	push	cx				; Save the # of bytes to skip.
ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
º;			      Load the patterns 			       º
ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
PatternsOK:
	inc	ah				; AH = number of patterns.
	shr	ax, 8				; Number of patterns in AL.
	mov	si, ax				; Set the loop counter.
	movzx	eax, ax 			; Clear the upper half of EAX.
        imul    eax, cs:PatternSize             ; Multiply by pattern size.
	movzx	edx, cs:PatternBase		; Fetch the pattern base offset.
	add	eax, edx			; EAX now has offset of samples.
	mov	edi, eax			; Save the 32-bit sample offset.
	mov	ax, es				; Get ModuleSegment.
	mov	ds, ax				; Set it into the DS.
LoadPatterns:
	mov	ax, 3F00h			; Request read from file.
	mov	bx, bp				; Fetch the file handle.
        mov     cx, Word Ptr cs:PatternSize     ; Set the length of pattern.
	int	21h				; Read one pattern to DS:DX.
	jc	ModLoadError			; Exit if an error occurred.
	mov	ax, ds				; Fetch the DS value.
        mov     bx, Word Ptr cs:PatternSize     ; Fetch the length of pattern.
        shr     bx, 4                           ; Get the length in paragraphs.
        add     ax, bx                          ; Point to the next pattern.
	mov	ds, ax				; Set the result into the DS.
	dec	si				; All patterns read?
	jnz	LoadPatterns			; Loop until they are.
ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
º;			 Skip the possible null patterns		       º
ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
	pop	cx				; Fetch # of bytes to skip.
	jcxz	NoNullPatts			; Skip if no dummy patterns.
	mov	dx, cx				; Set the byte count in DX.
	xor	cx, cx				; Zero the upper word.
	mov	bx, bp				; Fetch the file handle.
	mov	ax, 4201h			; Request move file pointer.
	int	21h				; Skip the dummy patterns.
	jc	ModLoadError			; Exit if an error occurred.
ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
º;			       Load the samples 			       º
ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
NoNullPatts:
	mov	ax, es				; Get ModuleSegment.
	mov	ds, ax				; Set it into the DS.
	mov	edx, edi			; Get the 32-bit sample offset.
	mov	si, 20				; Point the sample headers.
	mov	cx, cs:InstrCnt 		; Get the instrument count.
LoadSamples:
	movzx	eax, Word Ptr es:[si+22]	; Fetch the sample's length.
	or	ax, ax				; Is it zero?
	jz	NoSpl				; Don't load the sample if yes.
	xchg	ah, al				; Switch to PC word format.
	add	eax, eax			; Convert to a byte count.
	push	edx				; Save the 32-bit offset.
	call	LoadSample			; Load a sample into memory.
	pop	edx				; Restore the 32-bit offset.
	jc	ModLoadError			; Exit if an error occurred.
	add	edx, eax			; Set next sample's offset.
NoSpl:
	add	si, 30				; Point the next sample header.
	loop	LoadSamples			; Loop until all samples loaded.
	mov	bx, bp				; Get the module's file handle.
	mov	ax, 3E00h			; Request close a file.
	int	21h				; Close the module file.
	pop	es				; Restore the ES.
	pop	bx				; Restore the BX.
	clc					; Clear the carry.
	ret					; Then return.
ModLoadError:
	mov	bx, bp				; Get the module's file handle.
	mov	ax, 3E00h			; Request close a file.
	int	21h				; Close the module file.
	pop	es				; Restore the ES.
	pop	bx				; Restore the BX.
	stc					; Set the carry.
	ret					; Then return.

;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
;	   This code loads an STM-file as a single block into memory
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
LoadSTM:
	mov	bx, bp				; Set the file handle in the BX.
	mov	ax, 4200h			; Request move file pointer.
	xor	cx, cx				; Clear the offset's high word.
	mov	dx, cx				; Clear the low word.
	int	21h				; Call DOS.
ReadBlock:
	mov	ah, 3Fh 			; Request "read file" function.
	mov	cx, 8000h			; Set the block length in CX.
	int	21h				; Call DOS.
	jc	ReadError			; Exit if an error occurred.
	cmp	ax, cx				; Did we get a full block ??
	jne	LastBlock			; This is the last one if not.
	mov	ax, ds				; Set AX = DS.
	add	ax, 800h			; Set AX = AX + 32767 bytes.
	mov	ds, ax				; Set the new segment in the DS.
	jmp	ReadBlock			; Then read the next block.
LastBlock:
	mov	bx, bp				; Get the module's file handle.
	mov	ax, 3E00h			; Request close a file.
	int	21h				; Close the module file.
	xor	edx, edx			; Set the STM flag (length = 0).
	pop	es				; Restore the ES.
	pop	bx				; Restore the BX.
	clc					; Clear the error code (CF).
	ret					; Return.

ReadError:
	mov	bx, bp				; Get the module's file handle.
	mov	ax, 3E00h			; Request close a file.
	int	21h				; Close the module file.
	pop	es				; Restore the ES.
	pop	bx				; Restore the BX.
	stc					; Set the carry flag.
	ret					; Return.

InstrCnt	DW	0			; The number of instruments.
SngLenOffs	DW	0			; The offset of the song length.
PatternBase	DW	0			; The base offset of patterns.

LoadModule	EndP
;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º INPUT:	EAX = The length of the sample to load in bytes.	       º
;º		EDX = The offset where to read the sample (DS = the segment).  º
;º		 BP = The module file handle (DOS file ptr must point samples).º
;º RETURNS:	EAX = The new length of the sample.			       º
;º		 CF = 0 means no error. 				       º
;º		 CF = 1 means read error.				       º
;º FUNCTION:    This routine reads from disk and paragraph-aligns a sample.    º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
LoadSample	Proc	Near

	push	cx				; Save the CX.
	push	ds				; Save the DS.
	push	eax				; Save the EAX.
	xor	cx, cx				; Assume PadCount = 0.
	test	dx, 0Fh 			; DX already paragraph-aligned?
	jz	OffsetAligned			; Proceed if it is.
        mov     di, dx                          ; Destination offset to DI.
	mov	cx, 10h 			; Set the maximum count in CX.
        and     di, 0Fh                         ; Extract the four lowmost bits.
	sub	cx, di				; Calculate the padder's length.
        add     edx, 10h                        ; Finally round up the offset.
OffsetAligned:
	push	cx				; Save the # of bytes to pad.
	shr	edx, 4				; Convert the EDX to paragraphs.
	mov	cx, ds				; Fetch the module's segment.
	add	dx, cx				; Add the CX to the DX.
	mov	ds, dx				; Set DS to point the result.
	xor	dx, dx				; Clear the offset.
	mov	bx, bp				; Get the module's file handle.
	mov	ebp, eax			; Set the byte count into EBP.
	rol	ebp, 16 			; Swap the EBP's words.
	or	bp, bp				; Any 64kB blocks to read?
	jz	ReadSmlBlc			; Read a smaller block if not.
ReadSample:
	mov	ax, 3F00h			; Request read from a file.
	mov	cx, 0FFFFh			; Set the byte count to 0FFFFh.
	int	21h				; Read a 64kB block.
	jc	SplLoadError			; Exit if an error occurred.
	mov	ax, ds				; Get current DS value.
	add	ax, 1000h			; Add 65536/4 to it.
	mov	ds, ax				; Store the new DS value.
	dec	bp				; Any more 64kB blocks?
	jnz	ReadSample			; Loop if yes.
ReadSmlBlc:
	shr	ebp, 16 			; Get the last block's length.
	mov	ax, 3F00h			; Request read from a file.
	mov	cx, bp				; Set the byte count.
	int	21h				; Read a 64kB block.
	jc	SplLoadError			; Exit if an error occurred.
	mov	bp, bx				; Save the file handle.
	pop	cx				; Fetch the # of bytes to pad.
	pop	eax				; Restore the EAX.
	and	ecx, 0Fh			; Clear unneeded bits.
	add	eax, ecx			; Add pad count to sample len.
	pop	ds				; Restore the DS.
	pop	cx				; Restore the CX.
	clc					; Clear the carry.
	ret					; Return.
SplLoadError:
	pop	cx				; Discard # of bytes to pad.
	pop	eax				; Restore the EAX.
	pop	ds				; Restore the DS.
	pop	cx				; Restore the CX.
	stc					; Set the carry.
	ret					; Return.

LoadSample	EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
; Input:   None
; Output:  AX = CPU type
;	    0 = 8086/8088
;	    1 = 80186/80188
;	    2 = 80286
;	    3 = 80386
;	    4 = 80486
;	 FFFF = Unknown CPU type
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ

	INT6	equ	[bp-4]

ABS0	Segment Use16 At 0

	org 6*4

Orig_INT6	dd	?

ABS0	ends

CPU_Type	Proc	Near

	xor	ax,ax			; Clear CPU type return register.
	push	sp			; Save SP on stack to look at.
	pop	bx			; Get SP saved on stack.
	cmp	bx,sp			; If 8086/88, these values will differ.
	jnz	CPU_8086_exit		; Jump if 8086/8088.

	enter	4,0			; Create stack frame
	mov	WPtr INT6, Offset INT6_handler
	mov	WPtr INT6+2, cs
	call	set_INT6_vector 	; Set pointer to our INT6 handler.
	mov	ax, 4			; Initialize CPU flag=4 (80486).
	xor	cx, cx			; Initialize semaphore.

	xadd	dx, dx			; 80486 instruction, XCHG & ADD.
	jcxz	CPU_exit		; Jump if 486 detected.
	dec	ax			; set 80386 semaphore.
	inc	cx			; CX=0.

	mov	edx, cr0		; 80386 instruction CR0 --> EDX.
	jcxz	CPU_exit		; Jump if 386 detected.
	dec	ax			; Set 80286 semaphore.
	inc	cx			; CX=0.

	smsw	dx			; 80286: Store Machine Status Word.
	jcxz	CPU_exit		; Jump if 286 detected.
	dec	ax			; Set 80186 semaphore.
	inc	cx			; CX=0.

	shl	dx, 5			; 80186/80188: Shift, immediate count.
	jcxz	CPU_exit		; Jump if 186/188 detected.
	dec	ax			; set UNKNOWN_CPU semaphore.

CPU_exit:
	call	set_INT6_vector
	leave

CPU_8086_exit:
	ret

set_INT6_vector:
	push	ds
	push	ABS0			; Save interrupt vector segment
	pop	ds			; Make DS=INT vector segment
	mov	dx, ds:WPtr Orig_INT6;	; Get offset if INT6 handler
	xchg	INT6, dx		; Set new INT6 offset
	mov	ds:Word Ptr Orig_INT6, dx
	mov	dx, ds:WPtr Orig_INT6+2 ; get segment of INT6 handler
	xchg	INT6+2, dx		; set new INT6 segment
	mov	ds:Word Ptr Orig_INT6+2, dx
	pop	ds			; restore segment register
	ret				; split

INT6_handler:
	enter	0,0			; Create new stack frame.
	dec	cx			; Make CX=FFFF.
	add	word ptr ss:[bp][2], 3	; Point past invalid opcode.
	leave
	iret

CPU_Type	Endp
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
;
;		    DATA FOR THE LOAD AND EXECUTE FUNCTIONS
;
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
PSP             DW  0000h                   ; The segment of the PSP.
OldSS		DW  0000h		    ; Old stack segment.
OldSP		DW  0000h		    ; Old SP.

ExecParameters2 DW  0000h		    ; Address of DOS Environment.
		DW  Offset CommandLine2     ; Offset of the command line.
		DW  0000		    ; Segment of the command line.
		DW  Offset Fcb21	    ; Offset of FCB #1.
		DW  0000		    ; Segment of FCB #1.
		DW  Offset Fcb22	    ; Offset of FCB #2.
		DW  0000		    ; Segment of FCB #2.

CommandLine2	DB  00,0Dh		    ; A buffer for the command line.
Fcb21		DB  16 Dup(00h) 	    ; An FCB.
Fcb22		DB  16 Dup(00h) 	    ; An FCB.
ComSpec 	DB  75 Dup(00h) 	    ; The COMSPEC.

ExecParameters1 DW  0000h		    ; Address of DOS Environment.
		DW  80h 		    ; Offset of the command line.
		DW  0000		    ; Segment of the command line.
		DW  5Ch 		    ; Offset of FCB #1.
		DW  0000		    ; Segment of FCB #1.
		DW  6Ch 		    ; Offset of FCB #2.
		DW  0000		    ; Segment of FCB #2.

DelaySwc	DB  00h 		    ; The delay disable switch.
LoaderName	DB  76 Dup(0)		    ; This module's name.
MainModuleName	DB  76 Dup(0)		    ; The name of the main C-module.
RetValOffs	DW  0000h		    ; Offset of the return values.
CodeSize	DW  0000h		    ; The size of the .EXE code.
AvailableMemory DW  0000h		    ; The amount of free memory.

ShellMsg     DB  13,10, 'Type ''EXIT'' to remove '
             DB  'the player from memory.',13,10,'$'
KeyMsg       DB  13,10, 'Press any key to quit!',13,10,'$'

	IF  Unreg

ThanxMsg	Label	Byte
DB      7
DB	'ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·'
DB      'º      PowerPlayer v1.4 - (c) The Electromotive Force 1993 - Unregistered      º'
DB	'ÇÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¶'
DB	'º You should register this product so that your conscience wouldn''t bother you º'
DB      'º for the rest of your life. ;)  You will get the  next upgrade free of charge º'
DB      'º and a disk filled with modules of your choice!  Please pay 10 bucks (50 FIM) º'
DB      'º today and  support the  Shareware concept!  Besides - you''ll get rid of this º'
DB      'º annoying message and those damn beeps... :-)                                 º'
DB	'ÇÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¶'
DB      'º Send 10 USD or the same amount in your currency via mail to: Tomi Aarnio     º'
DB      'º                                                              Seljatie 3 B    º'
DB      'º Or use a bank giro inside Finland:   TOP Turku               SF-20900 Turku  º'
DB      'º                                      571004-5480249          Finland         º'
DB	'ÈÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍÍ¼'
DB	7,'$'

	ELSE

ThanxMsg        DB      10,13,'PowerPlayer v1.3 - registered to: '
                DB      UName,10,13,'$'

	ENDIF
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
;
;				MAIN DATA AREA
;
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
PlayingDevice	    DW	0			; The playing device number.
SbIrqLineNumber     DW	0			; The SB's IRQ number.
PlayingFrequency    DW	0			; The playing frequency.
FilenamePointer     DD	0			; A pointer to the filename.
PatternSize         DD  1024                    ; Size of each pattern.
ModType             DB  0FFh                    ; The type of the module.
TempoFlag           DB  0                       ; 1 = Disable BPM tempos.
OctaveFlag          DB  0                       ; 1 = Use five octaves.
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Cseg	EndS

Include \asm\inc\musicsys.386			; Include the 80386 MusicSystem.

ModuleSeg	Segment Para Use16 'MODULE'

DB	77,90,191,0,45,0,59,1,81,0,87,0,255,255,138,5
DB	128,0,159,198,8,0,124,1,28,0,0,0,0,0,60,4
DB	5,0,60,4,8,0,64,4,10,0,65,4,15,0,69,4
DB	1,0,71,4,7,0,78,4,3,0,80,4,8,0,80,4
DB	2,0,81,4,11,0,81,4,4,0,82,4,9,0,82,4
DB	2,0,83,4,7,0,83,4,1,0,52,2,4,0,49,2
DB	5,0,210,3,4,0,225,3,12,0,230,3,14,0,7,4
DB	10,0,182,3,9,0,184,3,14,0,184,3,15,0,185,3
DB	12,0,195,3,15,0,196,3,10,0,197,3,10,0,199,3
DB	2,0,203,3,5,0,57,2,0,0,56,2,13,0,54,2
DB	10,0,53,2,15,0,138,3,6,0,147,3,10,0,144,3
DB	11,0,149,3,12,0,161,3,13,0,164,3,3,0,167,3
DB	13,0,170,3,14,0,173,3,4,0,176,3,11,0,115,3
DB	10,0,118,3,0,0,120,3,1,0,122,3,12,0,116,3
DB	1,0,103,3,8,0,96,3,7,0,92,3,15,0,85,3
DB	12,0,78,3,1,0,68,3,1,0,35,2,15,0,135,3
DB	2,0,138,3,0,0,28,3,0,0,32,3,4,0,33,3
DB	5,0,36,3,9,0,40,3,12,0,71,3,4,0,73,3
DB	6,0,98,3,5,0,100,3,10,0,30,2,4,0,29,2
DB	5,0,4,3,4,0,11,5,14,0,5,3,3,0,16,3
DB	7,0,17,3,13,0,190,2,5,0,172,2,0,0,152,2
DB	14,0,110,2,2,0,103,2,12,0,95,2,10,0,73,2
DB	12,0,62,2,14,0,22,2,8,0,126,2,4,0,123,2
DB	13,0,116,2,10,0,184,2,4,0,174,2,15,0,153,2
DB	11,0,120,2,5,0,181,2,12,0,165,2,10,0,195,2
DB	5,0,118,2,8,0,135,2,11,0,138,2,9,0,69,2
DB	15,0,76,2,11,0,79,2,4,0,72,2,1,0,68,2
DB	6,0,65,2,5,0,254,1,15,0,248,1,2,0,246,1
DB	4,0,238,1,1,0,236,1,7,0,234,1,13,0,233,1
DB	3,0,18,2,14,0,16,2,15,0,15,2,14,0,14,2
DB	1,0,11,2,2,0,10,2,5,0,7,2,6,0,6,2
DB	15,0,3,2,1,0,2,2,3,0,0,2,9,0,214,1
DB	0,0,204,1,11,0,161,1,2,0,173,1,6,0,145,1
DB	6,0,149,1,4,0,150,1,10,0,150,1,15,0,150,1
DB	14,0,36,0,1,0,30,0,10,0,25,0,14,0,24,0
DB	1,0,24,0,7,0,21,0,4,0,19,0,8,0,18,0
DB	14,0,14,0,2,0,14,0,10,0,5,0,13,0,3,0
DB	3,0,238,4,10,0,124,1,8,0,108,0,13,0,107,0
DB	5,0,106,0,8,0,105,0,12,0,104,0,6,0,101,0
DB	8,0,94,0,12,0,93,0,2,0,92,0,0,0,90,0
DB	3,0,74,0,8,0,64,0,7,0,50,0,3,0,45,0
DB	10,0,144,0,14,0,143,0,5,0,142,0,2,0,133,0
DB	6,0,128,0,14,0,126,0,2,0,126,0,9,0,124,0
DB	11,0,115,0,15,0,114,0,6,0,113,0,6,0,111,0
DB	11,0,110,0,3,0,109,0,7,0,212,0,10,0,211,0
DB	11,0,210,0,10,0,208,0,11,0,206,0,6,0,206,0
DB	13,0,196,0,6,0,186,0,2,0,182,0,1,0,176,0
DB	11,0,166,0,4,0,161,0,0,0,157,0,12,0,152,0
DB	15,0,224,0,2,0,224,0,2,0,223,0,5,0,222,0
DB	5,0,221,0,8,0,220,0,8,0,219,0,11,0,218,0
DB	14,0,217,0,1,0,217,0,1,0,216,0,4,0,215,0
DB	4,0,214,0,7,0,213,0,10,0,237,0,13,0,236,0
DB	13,0,235,0,0,0,235,0,0,0,234,0,3,0,233,0
DB	3,0,232,0,6,0,231,0,6,0,230,0,9,0,229,0
DB	9,0,228,0,12,0,227,0,12,0,226,0,15,0,225,0
DB	1,0,0,1,14,0,254,0,2,0,254,0,2,0,253,0
DB	11,0,251,0,15,0,248,0,1,0,246,0,13,0,243,0
DB	1,0,243,0,4,0,242,0,4,0,241,0,7,0,240,0
DB	7,0,239,0,10,0,238,0,5,0,27,1,13,0,18,1
DB	5,0,18,1,3,0,17,1,3,0,16,1,7,0,15,1
DB	11,0,14,1,7,0,11,1,5,0,10,1,5,0,9,1
DB	9,0,8,1,13,0,7,1,9,0,2,1,5,0,1,1
DB	3,0,51,1,2,0,50,1,5,0,49,1,6,0,45,1
DB	9,0,42,1,14,0,41,1,14,0,40,1,4,0,39,1
DB	10,0,37,1,1,0,36,1,7,0,34,1,9,0,32,1
DB	11,0,30,1,15,0,28,1,0,0,69,1,3,0,68,1
DB	3,0,67,1,7,0,66,1,11,0,63,1,13,0,62,1
DB	2,0,60,1,12,0,58,1,15,0,57,1,10,0,56,1
DB	13,0,55,1,1,0,54,1,4,0,53,1,0,0,52,1
DB	12,0,86,1,4,0,84,1,3,0,83,1,7,0,82,1
DB	2,0,81,1,5,0,80,1,0,0,78,1,11,0,76,1
DB	10,0,75,1,12,0,74,1,12,0,72,1,15,0,71,1
DB	14,0,70,1,1,0,70,1,6,0,101,1,14,0,99,1
DB	2,0,99,1,8,0,98,1,2,0,96,1,1,0,95,1
DB	5,0,94,1,0,0,93,1,4,0,92,1,8,0,91,1
DB	11,0,90,1,10,0,89,1,14,0,88,1,9,0,87,1
DB	11,0,13,1,13,0,6,1,12,0,111,1,15,0,110,1
DB	5,0,110,1,10,0,109,1,1,0,109,1,14,0,106,1
DB	4,0,106,1,2,0,105,1,8,0,104,1,9,0,4,1
DB	9,0,3,1,15,0,32,0,5,0,11,0,14,0,4,0
DB	8,0,31,0,13,0,2,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	85,137,229,131,236,4,86,87,139,126,6,131,255,1,117,62
DB	196,94,8,38,255,119,2,38,255,55,154,0,7,0,0,131
DB	196,4,9,192,120,11,184,2,0,80,154,199,0,12,2,68
DB	68,196,94,8,38,255,119,2,38,255,55,154,214,12,0,0
DB	131,196,4,184,1,0,80,154,199,0,12,2,68,68,199,70
DB	254,1,0,139,199,137,70,252,139,70,254,59,70,252,124,3
DB	233,120,1,209,224,209,224,196,94,8,3,216,38,196,31,38
DB	138,7,60,45,116,7,60,47,116,3,233,88,1,140,194,137
DB	216,64,137,22,232,18,163,230,18,142,194,137,195,38,138,7
DB	60,67,116,4,60,99,117,18,196,94,8,38,255,119,2,38
DB	255,55,154,214,12,0,0,131,196,4,196,30,230,18,38,138
DB	7,60,68,116,4,60,100,117,47,38,138,71,1,4,208,162
DB	106,0,60,1,124,4,60,3,126,24,30,184,176,1,80,154
DB	120,0,61,2,131,196,4,184,1,0,80,154,199,0,12,2
DB	68,68,199,6,96,0,1,0,196,30,230,18,38,138,7,60
DB	73,116,4,60,105,117,55,38,138,71,1,4,208,162,107,0
DB	60,2,124,12,60,7,127,8,60,4,116,4,60,6,117,24
DB	30,184,217,1,80,154,120,0,61,2,131,196,4,184,1,0
DB	80,154,199,0,12,2,68,68,199,6,98,0,1,0,196,30
DB	230,18,38,138,7,60,83,116,4,60,115,117,87,140,194,137
DB	216,64,82,80,154,49,0,235,2,131,196,4,163,102,0,61
DB	160,15,125,8,185,232,3,247,233,163,102,0,161,102,0,61
DB	160,15,124,5,61,240,85,126,37,30,184,250,1,80,154,120
DB	0,61,2,131,196,4,30,184,30,2,80,154,120,0,61,2
DB	131,196,4,184,1,0,80,154,199,0,12,2,68,68,199,6
DB	100,0,1,0,139,22,232,18,161,230,18,137,22,224,18,163
DB	222,18,142,194,137,195,38,138,15,128,225,95,142,194,137,198
DB	38,136,12,196,30,222,18,38,138,7,60,67,116,23,60,68
DB	116,19,60,73,116,15,60,83,116,11,184,2,0,80,154,199
DB	0,12,2,68,68,255,70,254,233,125,254,196,94,8,38,255
DB	119,2,38,255,55,154,0,7,0,0,131,196,4,131,248,255
DB	117,18,196,94,8,38,255,119,2,38,255,55,154,214,12,0
DB	0,131,196,4,199,6,208,18,1,0,161,208,18,59,70,252
DB	125,29,209,224,209,224,196,94,8,3,216,38,196,31,38,138
DB	7,60,45,116,4,60,47,117,6,255,6,208,18,235,219,161
DB	208,18,59,70,252,117,11,184,1,0,80,154,199,0,12,2
DB	68,68,184,2,0,163,104,0,199,6,222,18,0,14,140,30
DB	224,18,139,14,208,18,209,225,209,225,196,94,8,3,217,38
DB	139,87,2,38,139,7,137,22,220,18,163,218,18,196,30,218
DB	18,38,138,7,8,192,116,17,196,30,222,18,38,136,7,255
DB	6,222,18,255,6,218,18,235,228,196,30,222,18,38,198,7
DB	0,199,6,216,18,0,0,139,30,216,18,138,135,0,14,60
DB	46,116,10,8,192,116,6,255,6,216,18,235,234,139,30,216
DB	18,128,191,0,14,0,117,102,49,192,80,30,187,0,14,83
DB	154,42,0,242,2,131,196,6,163,210,18,131,248,255,117,64
DB	139,30,216,18,198,135,0,14,46,139,30,216,18,67,198,135
DB	0,14,77,139,30,216,18,131,195,2,198,135,0,14,79,139
DB	30,216,18,131,195,3,198,135,0,14,68,139,30,216,18,131
DB	195,4,198,135,0,14,0,199,6,104,0,0,0,233,208,0
DB	255,54,210,18,154,76,0,242,2,68,68,233,194,0,255,6
DB	216,18,139,30,216,18,140,218,141,159,0,14,138,7,36,95
DB	142,194,137,222,38,136,4,139,30,216,18,67,140,218,141,159
DB	0,14,138,7,36,95,142,194,137,222,38,136,4,139,30,216
DB	18,131,195,2,140,218,141,159,0,14,138,7,36,95,142,194
DB	137,222,38,136,4,139,30,216,18,138,135,0,14,60,77,117
DB	22,67,128,191,0,14,79,117,14,139,30,216,18,131,195,2
DB	128,191,0,14,68,116,30,60,78,117,32,139,30,216,18,67
DB	128,191,0,14,83,117,20,139,30,216,18,131,195,2,128,191
DB	0,14,84,117,6,199,6,104,0,0,0,139,30,216,18,128
DB	191,0,14,83,117,28,67,128,191,0,14,84,117,20,139,30
DB	216,18,131,195,2,128,191,0,14,77,117,6,199,6,104,0
DB	1,0,131,6,216,18,3,139,30,216,18,198,135,0,14,0
DB	49,192,163,216,18,199,6,222,18,0,17,140,30,224,18,80
DB	30,184,0,14,80,154,42,0,242,2,131,196,6,163,210,18
DB	131,248,255,116,3,233,134,2,131,62,104,0,0,116,7,131
DB	62,104,0,2,117,10,199,6,226,18,0,15,140,30,228,18
DB	131,62,104,0,1,117,10,199,6,226,18,0,16,140,30,228
DB	18,196,30,226,18,38,138,7,8,192,116,17,196,30,222,18
DB	38,136,7,255,6,222,18,255,6,226,18,235,228,196,30,222
DB	18,176,92,38,56,71,255,116,7,38,136,7,255,6,222,18
DB	139,30,216,18,138,135,0,14,8,192,116,17,196,30,222,18
DB	38,136,7,255,6,222,18,255,6,216,18,235,227,196,30,222
DB	18,38,198,7,0,49,192,163,216,18,80,30,184,0,17,80
DB	154,42,0,242,2,131,196,6,163,210,18,131,248,255,116,3
DB	233,25,2,199,6,226,18,0,15,140,30,228,18,199,6,222
DB	18,0,17,140,30,224,18,196,30,226,18,38,138,7,8,192
DB	116,17,196,30,222,18,38,136,7,255,6,222,18,255,6,226
DB	18,235,228,196,30,222,18,176,92,38,56,71,255,116,7,38
DB	136,7,255,6,222,18,139,30,216,18,138,135,0,14,8,192
DB	116,17,196,30,222,18,38,136,7,255,6,222,18,255,6,216
DB	18,235,227,196,30,222,18,38,198,7,46,196,30,222,18,38
DB	198,71,1,77,196,30,222,18,38,198,71,2,79,196,30,222
DB	18,38,198,71,3,68,196,30,222,18,38,198,71,4,0,199
DB	6,216,18,0,0,139,30,216,18,138,135,0,14,60,46,116
DB	10,8,192,116,6,255,6,216,18,235,234,139,30,216,18,198
DB	135,0,14,46,139,30,216,18,67,198,135,0,14,77,139,30
DB	216,18,131,195,2,198,135,0,14,79,139,30,216,18,131,195
DB	3,198,135,0,14,68,139,30,216,18,131,195,4,198,135,0
DB	14,0,49,192,163,216,18,80,30,184,0,17,80,154,42,0
DB	242,2,131,196,6,163,210,18,131,248,255,116,3,233,28,1
DB	199,6,222,18,0,17,140,30,224,18,30,184,53,2,80,154
DB	4,0,0,3,131,196,4,137,22,228,18,163,226,18,137,209
DB	9,193,117,24,30,184,58,2,80,154,120,0,61,2,131,196
DB	4,184,1,0,80,154,199,0,12,2,68,68,196,30,226,18
DB	38,128,127,255,0,117,3,233,131,0,38,138,7,196,30,222
DB	18,38,136,7,196,30,226,18,38,138,7,60,59,116,4,8
DB	192,117,95,196,30,222,18,176,92,38,56,71,255,116,7,38
DB	136,7,255,6,222,18,139,30,216,18,138,135,0,14,8,192
DB	116,17,196,30,222,18,38,136,7,255,6,222,18,255,6,216
DB	18,235,227,196,30,222,18,38,198,7,0,49,192,80,30,187
DB	0,17,83,154,42,0,242,2,131,196,6,163,210,18,9,192
DB	126,2,235,25,199,6,222,18,0,17,140,30,224,18,255,14
DB	222,18,255,6,222,18,255,6,226,18,233,111,255,131,62,210
DB	18,255,117,72,30,184,100,2,80,154,120,0,61,2,131,196
DB	4,184,1,0,80,154,199,0,12,2,68,68,235,46,255,54
DB	210,18,154,76,0,242,2,68,68,255,54,102,0,30,184,0
DB	14,80,255,54,107,0,255,54,106,0,154,8,0,114,1,131
DB	196,10,49,192,80,154,199,0,12,2,68,68,255,54,210,18
DB	154,76,0,242,2,68,68,255,54,102,0,30,184,0,17,80
DB	255,54,107,0,255,54,106,0,154,8,0,114,1,131,196,10
DB	49,192,80,154,199,0,12,2,68,68,95,94,139,229,93,203
DB	85,137,229,131,236,14,86,87,191,255,255,49,192,80,30,187
DB	108,0,83,154,42,0,242,2,131,196,6,163,210,18,9,192
DB	126,35,185,144,1,81,30,187,0,17,83,80,154,8,0,242
DB	2,131,196,8,255,54,210,18,154,76,0,242,2,68,68,191
DB	0,0,233,213,1,139,86,8,139,70,6,137,22,224,18,163
DB	222,18,199,6,216,18,0,0,196,30,222,18,38,138,7,8
DB	192,116,18,139,30,216,18,136,135,0,17,255,6,216,18,255
DB	6,222,18,235,227,139,30,216,18,128,191,0,17,92,116,10
DB	9,219,126,6,255,14,216,18,235,235,255,6,216,18,199,6
DB	222,18,108,0,140,30,224,18,196,30,222,18,38,138,7,8
DB	192,116,18,139,30,216,18,136,135,0,17,255,6,216,18,255
DB	6,222,18,235,227,139,30,216,18,198,135,0,17,0,49,192
DB	80,30,187,0,17,83,154,42,0,242,2,131,196,6,163,210
DB	18,9,192,126,35,185,144,1,81,30,187,0,17,83,80,154
DB	8,0,242,2,131,196,8,255,54,210,18,154,76,0,242,2
DB	68,68,191,0,0,233,34,1,199,6,208,18,0,0,30,184
DB	118,2,80,154,4,0,0,3,131,196,4,137,22,224,18,163
DB	222,18,137,209,9,193,117,9,184,255,255,95,94,139,229,93
DB	203,196,30,222,18,38,128,63,0,116,31,255,6,222,18,196
DB	30,222,18,38,138,7,60,59,116,10,8,192,116,6,255,6
DB	222,18,235,235,255,6,208,18,235,215,30,184,123,2,80,154
DB	4,0,0,3,131,196,4,137,22,224,18,163,222,18,49,192
DB	57,6,208,18,127,3,233,177,0,163,216,18,196,30,222,18
DB	38,138,7,60,59,116,22,8,192,116,18,139,30,216,18,136
DB	135,0,17,255,6,216,18,255,6,222,18,235,223,255,6,222
DB	18,139,30,216,18,75,176,92,56,135,0,17,116,12,139,30
DB	216,18,136,135,0,17,255,6,216,18,199,6,226,18,108,0
DB	140,30,228,18,196,30,226,18,38,138,7,8,192,116,18,139
DB	30,216,18,136,135,0,17,255,6,216,18,255,6,226,18,235
DB	227,139,30,216,18,198,135,0,17,0,49,192,80,30,187,0
DB	17,83,154,42,0,242,2,131,196,6,163,210,18,9,192,126
DB	34,185,144,1,81,30,187,0,17,83,80,154,8,0,242,2
DB	131,196,8,255,54,210,18,154,76,0,242,2,68,68,191,0
DB	0,235,7,255,14,208,18,233,68,255,131,255,255,117,9,184
DB	255,255,95,94,139,229,93,203,199,6,222,18,0,17,140,30
DB	224,18,199,6,208,18,0,0,161,208,18,61,144,1,125,41
DB	137,195,140,218,141,159,0,17,138,7,60,97,137,70,254,124
DB	18,152,61,129,0,127,12,139,70,254,36,95,142,194,137,222
DB	38,136,4,255,6,208,18,235,207,199,6,208,18,0,0,161
DB	208,18,61,131,1,125,54,185,13,0,81,30,187,108,1,83
DB	140,218,187,0,17,3,216,82,83,154,12,0,232,2,131,196
DB	10,9,192,117,18,131,62,96,0,1,117,3,233,159,0,198
DB	6,106,0,1,233,151,0,255,6,208,18,235,194,199,6,208
DB	18,0,0,161,208,18,61,131,1,125,54,185,11,0,81,30
DB	187,126,1,83,140,218,187,0,17,3,216,82,83,154,12,0
DB	232,2,131,196,10,9,192,117,18,131,62,96,0,1,117,3
DB	233,238,0,198,6,106,0,2,233,230,0,255,6,208,18,235
DB	194,199,6,208,18,0,0,161,208,18,61,131,1,125,54,185
DB	11,0,81,30,187,138,1,83,140,218,187,0,17,3,216,82
DB	83,154,12,0,232,2,131,196,10,9,192,117,18,131,62,96
DB	0,1,117,3,233,170,0,198,6,106,0,3,233,162,0,255
DB	6,208,18,235,194,184,255,255,95,94,139,229,93,203,131,62
DB	98,0,1,117,3,233,137,0,199,6,208,18,0,0,161,208
DB	18,61,141,1,125,123,185,3,0,81,30,187,122,1,83,140
DB	218,187,0,17,3,216,82,83,154,12,0,232,2,131,196,10
DB	9,192,117,86,139,30,208,18,128,191,0,17,61,116,14,255
DB	6,208,18,129,62,208,18,144,1,117,233,235,168,255,6,208
DB	18,139,30,208,18,138,135,0,17,60,48,124,12,60,57,127
DB	8,60,52,116,4,60,54,117,15,255,6,208,18,129,62,208
DB	18,144,1,117,220,233,125,255,139,30,208,18,138,135,0,17
DB	162,107,0,128,6,107,0,208,235,7,255,6,208,18,233,125
DB	255,131,62,100,0,1,117,3,233,165,0,199,6,208,18,0
DB	0,161,208,18,61,135,1,124,3,233,148,0,185,9,0,81
DB	30,187,150,1,83,140,218,187,0,17,3,216,82,83,154,12
DB	0,232,2,131,196,10,9,192,117,111,139,30,208,18,128,191
DB	0,17,61,116,15,255,6,208,18,129,62,208,18,144,1,117
DB	233,233,17,255,255,6,208,18,139,30,208,18,138,135,0,17
DB	60,48,124,4,60,57,126,15,255,6,208,18,129,62,208,18
DB	144,1,117,228,233,238,254,139,30,208,18,131,195,5,198,135
DB	0,17,0,161,208,18,140,218,187,0,17,3,216,82,83,154
DB	49,0,235,2,131,196,4,163,102,0,61,160,15,125,17,185
DB	232,3,247,233,163,102,0,235,7,255,6,208,18,233,97,255
DB	199,6,208,18,0,0,161,208,18,61,136,1,124,3,233,150
DB	0,185,8,0,81,30,187,160,1,83,140,218,187,0,17,3
DB	216,82,83,154,12,0,232,2,131,196,10,9,192,117,113,139
DB	30,208,18,128,191,0,17,61,116,15,255,6,208,18,129,62
DB	208,18,144,1,117,233,233,108,254,255,6,208,18,139,30,208
DB	18,138,135,0,17,60,33,124,8,60,92,127,4,60,91,117
DB	14,255,6,208,18,129,62,208,18,144,1,117,224,235,56,199
DB	6,216,18,0,0,139,30,208,18,138,135,0,17,60,13,116
DB	38,60,32,116,34,139,30,216,18,136,135,0,15,255,6,208
DB	18,255,6,216,18,129,62,208,18,144,1,117,216,233,21,254
DB	255,6,208,18,233,95,255,199,6,208,18,0,0,161,208,18
DB	61,136,1,124,3,233,150,0,185,8,0,81,30,187,168,1
DB	83,140,218,187,0,17,3,216,82,83,154,12,0,232,2,131
DB	196,10,9,192,117,113,139,30,208,18,128,191,0,17,61,116
DB	15,255,6,208,18,129,62,208,18,144,1,117,233,233,197,253
DB	255,6,208,18,139,30,208,18,138,135,0,17,60,33,124,8
DB	60,92,127,4,60,91,117,14,255,6,208,18,129,62,208,18
DB	144,1,117,224,235,56,199,6,216,18,0,0,139,30,208,18
DB	138,135,0,17,60,13,116,38,60,32,116,34,139,30,216,18
DB	136,135,0,16,255,6,208,18,255,6,216,18,129,62,208,18
DB	144,1,117,216,233,110,253,255,6,208,18,233,95,255,139,199
DB	95,94,139,229,93,203,85,137,229,131,236,2,86,87,198,6
DB	106,0,1,154,116,0,114,1,154,14,0,161,1,49,192,137
DB	199,137,70,254,163,208,18,129,62,208,18,208,7,125,37,184
DB	177,23,80,255,118,254,87,154,238,1,161,1,131,196,6,255
DB	70,254,131,126,254,80,117,6,199,70,254,0,0,71,255,6
DB	208,18,235,211,184,23,0,80,154,120,3,161,1,68,68,184
DB	7,0,80,185,3,0,81,154,195,2,161,1,131,196,4,30
DB	184,128,2,80,154,14,0,232,1,131,196,4,184,7,0,80
DB	185,4,0,81,154,195,2,161,1,131,196,4,30,184,193,2
DB	80,154,14,0,232,1,131,196,4,184,7,0,80,185,5,0
DB	81,154,195,2,161,1,131,196,4,30,184,2,3,80,154,14
DB	0,232,1,131,196,4,184,7,0,80,185,6,0,81,154,195
DB	2,161,1,131,196,4,30,184,67,3,80,154,14,0,232,1
DB	131,196,4,184,7,0,80,80,154,195,2,161,1,131,196,4
DB	30,184,132,3,80,154,14,0,232,1,131,196,4,184,7,0
DB	80,185,8,0,81,154,195,2,161,1,131,196,4,30,184,197
DB	3,80,154,14,0,232,1,131,196,4,184,7,0,80,185,9
DB	0,81,154,195,2,161,1,131,196,4,30,184,6,4,80,154
DB	14,0,232,1,131,196,4,184,7,0,80,185,10,0,81,154
DB	195,2,161,1,131,196,4,30,184,71,4,80,154,14,0,232
DB	1,131,196,4,184,7,0,80,185,11,0,81,154,195,2,161
DB	1,131,196,4,30,184,136,4,80,154,14,0,232,1,131,196
DB	4,184,7,0,80,185,12,0,81,154,195,2,161,1,131,196
DB	4,30,184,201,4,80,154,14,0,232,1,131,196,4,184,7
DB	0,80,185,13,0,81,154,195,2,161,1,131,196,4,30,184
DB	10,5,80,154,14,0,232,1,131,196,4,184,7,0,80,185
DB	14,0,81,154,195,2,161,1,131,196,4,30,184,75,5,80
DB	154,14,0,232,1,131,196,4,184,7,0,80,185,15,0,81
DB	154,195,2,161,1,131,196,4,30,184,140,5,80,154,14,0
DB	232,1,131,196,4,184,7,0,80,185,16,0,81,154,195,2
DB	161,1,131,196,4,30,184,205,5,80,154,14,0,232,1,131
DB	196,4,184,7,0,80,185,17,0,81,154,195,2,161,1,131
DB	196,4,30,184,14,6,80,154,14,0,232,1,131,196,4,184
DB	7,0,80,185,18,0,81,154,195,2,161,1,131,196,4,30
DB	184,79,6,80,154,14,0,232,1,131,196,4,184,7,0,80
DB	185,19,0,81,154,195,2,161,1,131,196,4,30,184,144,6
DB	80,154,14,0,232,1,131,196,4,184,7,0,80,184,20,0
DB	80,154,195,2,161,1,131,196,4,30,184,209,6,80,154,14
DB	0,232,1,131,196,4,184,16,0,80,154,120,3,161,1,68
DB	68,191,21,0,199,70,254,8,0,199,6,208,18,0,0,131
DB	62,208,18,64,125,25,184,177,16,80,255,118,254,87,154,238
DB	1,161,1,131,196,6,255,70,254,255,6,208,18,235,224,191
DB	21,0,199,70,254,71,0,199,6,208,18,0,0,131,62,208
DB	18,18,125,23,184,177,16,80,255,118,254,87,154,238,1,161
DB	1,131,196,6,79,255,6,208,18,235,226,191,21,0,199,70
DB	254,72,0,199,6,208,18,0,0,131,62,208,18,18,125,23
DB	184,177,16,80,255,118,254,87,154,238,1,161,1,131,196,6
DB	79,255,6,208,18,235,226,184,2,0,80,49,192,80,80,154
DB	122,0,114,1,131,196,6,184,29,0,80,184,6,0,80,154
DB	195,2,161,1,131,196,4,184,30,0,80,154,120,3,161,1
DB	68,68,128,62,106,0,1,117,13,30,184,18,7,80,154,14
DB	0,232,1,131,196,4,128,62,106,0,2,117,13,30,184,39
DB	7,80,154,14,0,232,1,131,196,4,128,62,106,0,3,117
DB	13,30,184,60,7,80,154,14,0,232,1,131,196,4,184,29
DB	0,80,184,6,0,80,154,179,18,0,0,131,196,4,184,35
DB	0,80,184,10,0,80,154,151,20,0,0,131,196,4,184,14
DB	0,137,199,185,15,0,137,78,254,140,218,187,0,15,137,22
DB	220,18,137,30,218,18,81,80,82,83,154,13,22,0,0,131
DB	196,8,184,15,0,80,185,14,0,81,154,195,2,161,1,131
DB	196,4,184,23,0,80,154,120,3,161,1,68,68,30,184,81
DB	7,80,154,14,0,232,1,131,196,4,184,15,0,80,185,14
DB	0,81,154,195,2,161,1,131,196,4,30,184,0,15,80,30
DB	184,130,7,80,154,14,0,232,1,131,196,8,184,18,0,137
DB	199,185,15,0,137,78,254,140,218,187,0,16,137,22,220,18
DB	137,30,218,18,81,80,82,83,154,13,22,0,0,131,196,8
DB	184,15,0,80,185,18,0,81,154,195,2,161,1,131,196,4
DB	184,23,0,80,154,120,3,161,1,68,68,30,184,133,7,80
DB	154,14,0,232,1,131,196,4,184,15,0,80,184,18,0,80
DB	154,195,2,161,1,131,196,4,30,184,0,16,80,30,184,182
DB	7,80,154,14,0,232,1,131,196,8,154,183,0,161,1,139
DB	86,8,139,70,6,137,22,224,18,163,222,18,199,6,216,18
DB	0,0,196,30,222,18,38,138,7,8,192,116,18,139,30,216
DB	18,136,135,0,17,255,6,216,18,255,6,222,18,235,227,139
DB	30,216,18,128,191,0,17,92,116,10,9,219,126,6,255,14
DB	216,18,235,235,255,6,216,18,199,6,222,18,108,0,140,30
DB	224,18,196,30,222,18,38,138,7,8,192,116,18,139,30,216
DB	18,136,135,0,17,255,6,216,18,255,6,222,18,235,227,139
DB	30,216,18,198,135,0,17,0,30,184,185,7,80,30,184,0
DB	17,80,154,109,0,12,2,131,196,8,137,22,214,18,163,212
DB	18,137,209,9,193,117,13,30,184,187,7,80,154,120,0,61
DB	2,131,196,4,128,62,106,0,1,117,23,30,184,228,7,80
DB	255,54,214,18,255,54,212,18,154,35,0,61,2,131,196,8
DB	235,58,128,62,106,0,2,117,23,30,184,255,7,80,255,54
DB	214,18,255,54,212,18,154,35,0,61,2,131,196,8,235,28
DB	128,62,106,0,3,117,21,30,184,24,8,80,255,54,214,18
DB	255,54,212,18,154,35,0,61,2,131,196,8,160,107,0,152
DB	80,30,184,49,8,80,255,54,214,18,255,54,212,18,154,35
DB	0,61,2,131,196,10,255,54,102,0,30,184,65,8,80,255
DB	54,214,18,255,54,212,18,154,35,0,61,2,131,196,10,30
DB	184,0,15,80,30,184,84,8,80,255,54,214,18,255,54,212
DB	18,154,35,0,61,2,131,196,12,30,184,0,16,80,30,184
DB	100,8,80,255,54,214,18,255,54,212,18,154,35,0,61,2
DB	131,196,12,255,54,214,18,255,54,212,18,154,2,0,12,2
DB	131,196,4,176,3,80,154,220,3,161,1,68,68,95,94,139
DB	229,93,203,85,137,229,131,236,4,86,87,139,118,6,139,126
DB	8,199,70,252,0,0,129,126,252,13,28,117,3,233,153,0
DB	49,192,80,154,10,0,231,1,68,68,137,70,252,61,0,80
DB	117,16,254,6,106,0,128,62,106,0,3,126,5,198,6,106
DB	0,1,129,126,252,0,72,117,16,254,14,106,0,128,62,106
DB	0,1,125,5,198,6,106,0,3,128,62,106,0,1,117,23
DB	87,86,154,195,2,161,1,131,196,4,30,184,116,8,80,154
DB	14,0,232,1,131,196,4,128,62,106,0,2,117,23,87,86
DB	154,195,2,161,1,131,196,4,30,184,137,8,80,154,14,0
DB	232,1,131,196,4,128,62,106,0,3,116,3,233,119,255,87
DB	86,154,195,2,161,1,131,196,4,30,184,158,8,80,154,14
DB	0,232,1,131,196,4,233,93,255,128,62,106,0,1,116,3
DB	233,169,0,198,6,107,0,7,87,86,154,195,2,161,1,131
DB	196,4,30,184,179,8,80,154,14,0,232,1,131,196,4,49
DB	192,80,139,207,131,193,9,81,86,137,78,254,154,122,0,114
DB	1,131,196,6,139,70,254,80,86,154,195,2,161,1,131,196
DB	4,199,70,252,0,0,131,126,252,13,116,96,49,192,80,154
DB	10,0,231,1,68,68,137,70,252,48,228,137,70,252,131,248
DB	50,124,47,131,248,55,127,42,131,248,52,116,37,131,248,54
DB	116,32,4,208,162,107,0,255,118,252,154,230,0,161,1,68
DB	68,139,199,131,192,9,80,86,154,195,2,161,1,131,196,4
DB	235,180,160,107,0,60,50,124,173,60,55,127,169,60,52,116
DB	165,60,54,116,161,198,6,107,0,7,235,154,184,1,0,80
DB	49,192,80,80,154,122,0,114,1,131,196,6,184,23,0,80
DB	154,120,3,161,1,68,68,128,62,106,0,1,117,23,87,86
DB	154,195,2,161,1,131,196,4,30,184,200,8,80,154,14,0
DB	232,1,131,196,4,128,62,106,0,2,117,23,87,86,154,195
DB	2,161,1,131,196,4,30,184,221,8,80,154,14,0,232,1
DB	131,196,4,128,62,106,0,3,117,23,87,86,154,195,2,161
DB	1,131,196,4,30,184,242,8,80,154,14,0,232,1,131,196
DB	4,95,94,139,229,93,203,85,137,229,131,236,2,86,87,139
DB	118,6,139,126,8,184,30,0,80,154,120,3,161,1,68,68
DB	199,70,254,0,0,87,86,154,195,2,161,1,131,196,4,255
DB	54,102,0,30,184,7,9,80,154,14,0,232,1,131,196,6
DB	129,126,254,13,28,117,3,233,217,0,49,192,80,154,10,0
DB	231,1,68,68,137,70,254,61,0,80,117,93,161,102,0,5
DB	24,252,163,102,0,185,160,15,59,193,125,4,137,14,102,0
DB	87,86,154,195,2,161,1,131,196,4,30,184,13,9,80,154
DB	14,0,232,1,131,196,4,129,62,102,0,16,39,125,15,139
DB	199,64,80,86,154,195,2,161,1,131,196,4,235,10,87,86
DB	154,195,2,161,1,131,196,4,255,54,102,0,30,184,19,9
DB	80,154,14,0,232,1,131,196,6,129,126,254,0,72,116,3
DB	233,125,255,161,102,0,5,232,3,163,102,0,185,240,85,59
DB	193,126,4,137,14,102,0,87,86,154,195,2,161,1,131,196
DB	4,30,184,22,9,80,154,14,0,232,1,131,196,4,129,62
DB	102,0,16,39,125,15,139,199,64,80,86,154,195,2,161,1
DB	131,196,4,235,10,87,86,154,195,2,161,1,131,196,4,255
DB	54,102,0,30,184,28,9,80,154,14,0,232,1,131,196,6
DB	233,29,255,87,86,154,195,2,161,1,131,196,4,184,23,0
DB	80,154,120,3,161,1,68,68,30,184,31,9,80,154,14,0
DB	232,1,131,196,4,129,62,102,0,16,39,125,15,139,199,64
DB	80,86,154,195,2,161,1,131,196,4,235,10,87,86,154,195
DB	2,161,1,131,196,4,255,54,102,0,30,184,40,9,80,154
DB	14,0,232,1,131,196,6,95,94,139,229,93,203,85,137,229
DB	131,236,4,86,87,139,118,10,139,126,12,139,199,137,70,254
DB	49,201,81,80,86,154,122,0,114,1,131,196,6,87,86,154
DB	195,2,161,1,131,196,4,184,30,0,80,154,120,3,161,1
DB	68,68,199,70,252,0,0,131,126,252,13,117,3,233,192,0
DB	49,192,80,154,10,0,231,1,68,68,137,70,252,48,228,137
DB	70,252,131,248,8,117,77,139,199,59,70,254,126,217,79,49
DB	192,196,94,6,38,136,7,255,78,6,196,94,6,38,136,7
DB	49,192,80,87,86,154,122,0,114,1,131,196,6,87,86,154
DB	195,2,161,1,131,196,4,184,32,0,137,70,252,185,23,0
DB	81,154,120,3,161,1,68,68,255,118,252,154,230,0,161,1
DB	68,68,235,147,139,70,252,131,248,32,124,139,131,248,126,127
DB	134,196,94,6,38,136,7,255,70,6,185,30,0,81,154,120
DB	3,161,1,68,68,87,86,154,195,2,161,1,131,196,4,255
DB	118,252,154,230,0,161,1,68,68,71,87,86,154,195,2,161
DB	1,131,196,4,49,192,80,87,86,154,122,0,114,1,131,196
DB	6,131,255,63,116,3,233,62,255,196,94,6,38,198,7,0
DB	49,192,196,94,6,38,136,7,75,38,128,63,92,117,3,38
DB	136,7,95,94,139,229,93,203,252,6,86,87,85,139,236,184
DB	0,98,205,33,142,195,191,130,0,176,13,185,255,0,242,174
DB	38,139,85,2,38,139,5,142,194,139,248,139,70,12,50,228
DB	61,1,0,117,6,187,2,0,235,14,144,61,2,0,117,5
DB	51,219,235,4,144,187,1,0,38,137,29,131,199,2,139,70
DB	14,50,228,38,137,5,131,199,2,139,70,16,139,86,18,38
DB	137,5,38,137,85,2,131,199,4,139,70,20,38,137,5,93
DB	95,94,7,203,184,3,0,205,16,203,85,139,236,139,70,8
DB	138,208,139,70,6,138,240,139,94,10,11,219,116,12,186,212
DB	3,176,14,238,66,176,255,238,93,203,184,0,2,205,16,93
DB	203,0,186,71,10,233,72,2,250,184,91,4,219,227,142,216
DB	140,6,199,9,139,216,43,30,199,9,137,30,193,9,38,139
DB	30,2,0,43,216,129,251,0,16,114,3,187,255,15,139,208
DB	3,211,66,177,4,211,227,142,208,139,227,129,235,240,18,129
DB	251,0,2,119,6,186,144,9,233,5,2,251,180,48,205,33
DB	163,201,9,60,2,115,6,186,195,9,233,243,1,140,192,142
DB	216,140,208,142,192,190,128,0,252,172,50,228,139,200,191,240
DB	18,243,164,50,192,170,140,208,142,216,71,131,231,254,137,62
DB	185,9,221,62,197,9,190,240,18,187,4,0,172,60,61,117
DB	10,131,62,92,0,0,116,3,232,63,1,10,192,116,68,186
DB	32,9,60,32,116,230,60,9,116,226,60,34,116,4,60,39
DB	117,5,138,208,138,240,70,129,251,128,0,118,6,186,222,9
DB	233,141,1,78,137,183,49,9,140,159,51,9,131,195,4,172
DB	10,192,116,15,58,194,116,4,58,198,117,243,50,192,136,68
DB	255,235,169,209,235,209,235,137,30,47,9,51,192,247,6,197
DB	9,191,184,117,1,64,163,197,9,139,30,92,0,11,219,117
DB	3,187,0,32,129,251,0,2,115,3,187,0,2,137,30,92
DB	0,139,30,185,9,131,195,17,114,41,131,227,240,137,30,189
DB	9,137,30,191,9,177,4,211,235,137,30,187,9,3,30,193
DB	9,137,30,195,9,142,6,199,9,250,180,74,205,33,30,7
DB	115,7,251,186,144,9,233,7,1,199,6,0,11,0,0,255
DB	54,92,0,154,14,0,54,3,89,61,255,255,116,229,250,142
DB	194,139,216,38,139,39,131,196,16,74,142,210,251,137,38,191
DB	9,199,6,185,9,16,0,54,199,6,16,0,170,85,232,48
DB	0,30,7,185,240,18,191,0,14,43,207,227,4,50,192,243
DB	170,51,237,154,7,0,4,3,30,184,49,9,80,255,54,47
DB	9,154,2,0,4,3,80,154,33,2,124,1,154,199,0,12
DB	2,128,62,201,9,3,114,33,142,6,199,9,38,142,6,44
DB	0,51,255,50,192,185,255,255,252,242,174,174,117,251,131,199
DB	2,137,62,49,9,140,6,51,9,195,191,10,0,51,201,172
DB	10,192,116,31,60,32,116,27,60,9,116,23,44,48,120,14
DB	152,59,199,115,9,145,247,231,114,4,3,200,115,225,186,166
DB	9,235,77,137,14,92,0,195,180,48,205,33,60,2,114,9
DB	139,236,138,70,4,180,76,205,33,255,54,199,9,51,192,80
DB	203,139,30,185,9,54,129,63,170,85,117,33,139,196,43,195
DB	118,27,59,38,191,9,119,21,203,90,89,43,224,118,14,139
DB	30,185,9,54,129,63,170,85,117,3,81,82,203,186,125,9
DB	180,9,205,33,184,1,0,80,154,8,2,124,1,0,128,62
DB	112,10,0,116,1,203,198,6,112,10,1,85,87,51,210,50
DB	255,184,48,17,205,16,10,210,116,16,198,6,113,10,1,198
DB	6,110,10,0,254,194,137,22,98,10,180,15,205,16,136,38
DB	100,10,162,111,10,60,7,117,19,198,6,110,10,0,205,17
DB	37,48,0,61,48,0,116,35,176,7,235,9,60,15,116,5
DB	198,6,109,10,0,199,6,116,10,0,184,60,3,118,12,60
DB	7,116,8,199,6,116,10,0,0,235,29,184,1,43,185,69
DB	68,186,81,83,205,33,60,255,116,14,142,6,116,10,51,255
DB	180,254,205,16,140,6,116,10,180,3,205,16,137,14,118,10
DB	136,54,103,10,136,22,102,10,138,198,152,163,104,10,50,246
DB	137,22,106,10,95,93,203,128,62,112,10,0,116,20,85,154
DB	212,2,161,1,180,1,139,14,118,10,205,16,198,6,112,10
DB	0,93,203,199,6,116,10,0,0,203,85,139,236,139,78,6
DB	180,1,205,16,93,203,85,139,236,138,70,6,60,32,114,56
DB	60,127,116,16,232,117,1,161,106,10,64,59,6,100,10,115
DB	10,163,106,10,50,228,138,70,6,93,203,51,192,139,30,104
DB	10,67,59,30,98,10,114,10,232,104,2,51,192,139,30,98
DB	10,75,137,30,104,10,235,217,50,228,139,216,3,216,46,255
DB	167,51,1,244,0,244,0,244,0,244,0,244,0,244,0,244
DB	0,115,1,126,1,178,1,147,1,147,1,147,1,139,1,244
DB	0,244,0,244,0,244,0,244,0,244,0,244,0,244,0,244
DB	0,244,0,244,0,244,0,244,0,244,0,244,0,244,0,244
DB	0,244,0,178,7,180,2,205,33,184,7,0,93,203,139,30
DB	106,10,75,120,4,137,30,106,10,93,203,199,6,106,10,0
DB	0,93,203,199,6,106,10,0,0,139,22,104,10,66,59,22
DB	98,10,114,8,232,220,1,184,10,0,93,203,137,22,104,10
DB	93,203,161,106,10,13,7,0,64,59,6,100,10,114,4,161
DB	100,10,72,163,106,10,184,9,0,93,203,85,139,236,138,70
DB	6,138,110,8,138,78,10,138,118,12,138,86,14,138,126,16
DB	180,6,10,192,121,4,246,216,254,196,205,16,93,203,85,139
DB	236,139,78,10,138,118,6,138,86,8,131,62,116,10,0,116
DB	51,161,100,10,246,230,50,246,3,194,209,224,139,216,142,6
DB	116,10,128,62,110,10,0,116,22,186,218,3,180,1,236,132
DB	196,117,251,250,236,132,196,116,251,38,137,15,251,93,203,38
DB	137,15,93,203,136,54,103,10,136,22,102,10,138,62,114,10
DB	180,2,205,16,138,193,138,221,180,9,185,1,0,205,16,93
DB	203,85,139,236,138,118,6,138,86,8,137,22,102,10,138,62
DB	114,10,180,2,205,16,180,8,205,16,93,203,131,62,116,10
DB	0,116,57,138,200,138,46,108,10,161,100,10,247,38,104,10
DB	3,6,106,10,209,224,139,216,142,6,116,10,128,62,110,10
DB	0,116,21,186,218,3,180,1,236,132,196,117,251,250,236,132
DB	196,116,251,38,137,15,251,195,38,137,15,195,80,154,212,2
DB	161,1,88,180,9,138,62,114,10,138,30,108,10,185,1,0
DB	205,16,195,85,139,236,139,70,6,163,104,10,139,70,8,163
DB	106,10,93,203,138,54,104,10,138,22,106,10,59,22,102,10
DB	116,14,137,22,102,10,138,62,114,10,180,2,85,205,16,93
DB	203,139,14,100,10,43,14,106,10,161,100,10,247,38,104,10
DB	3,6,106,10,235,22,161,100,10,247,38,98,10,139,200,161
DB	100,10,247,38,104,10,3,6,106,10,43,200,87,209,224,139
DB	248,131,62,116,10,0,116,46,142,6,116,10,252,176,32,138
DB	38,108,10,128,62,110,10,0,117,4,243,171,95,203,186,218
DB	3,139,216,236,168,1,117,251,250,236,168,1,116,251,139,195
DB	171,251,226,239,95,203,154,212,2,161,1,184,32,9,138,62
DB	114,10,138,30,108,10,85,205,16,93,95,203,198,6,108,10
DB	112,203,198,6,108,10,7,203,85,139,236,138,70,6,162,108
DB	10,93,203,128,62,110,10,0,117,54,131,62,116,10,0,116
DB	47,30,86,87,161,100,10,139,240,139,216,247,38,98,10,43
DB	198,139,200,209,230,51,255,176,32,138,38,108,10,142,6,116
DB	10,142,30,116,10,252,243,165,139,203,243,171,95,94,31,195
DB	51,201,139,22,100,10,74,182,24,138,62,108,10,184,1,6
DB	205,16,195,85,180,15,205,16,50,228,93,203,85,139,236,50
DB	228,138,70,6,205,16,93,203,128,62,113,10,1,117,72,131
DB	62,98,10,25,117,65,85,184,3,0,128,62,109,10,0,116
DB	3,184,7,0,162,111,10,205,16,184,18,17,179,0,205,16
DB	184,0,18,179,32,205,16,184,0,1,185,7,0,205,16,184
DB	48,17,205,16,50,246,59,22,104,10,115,4,137,22,104,10
DB	254,194,137,22,98,10,93,203,128,62,113,10,1,117,248,131
DB	62,98,10,25,118,241,85,184,3,0,128,62,109,10,0,116
DB	3,184,7,0,162,111,10,205,16,184,1,17,179,0,205,16
DB	184,0,18,179,32,205,16,235,182,0,85,139,236,138,102,6
DB	205,22,117,8,128,126,6,1,117,2,51,192,93,203,85,137
DB	229,22,141,70,10,80,255,118,8,255,118,6,186,161,1,184
DB	230,0,82,80,154,72,1,61,2,131,196,12,93,203,85,137
DB	229,235,18,196,94,6,255,70,6,38,138,7,152,80,154,230
DB	0,161,1,68,68,196,94,6,38,128,63,0,117,229,93,203
DB	85,137,229,86,87,139,126,10,235,32,139,118,12,235,21,86
DB	87,154,81,2,161,1,131,196,4,196,94,6,131,70,6,2
DB	38,137,7,70,59,118,16,118,230,71,59,126,14,118,219,95
DB	94,93,203,85,137,229,131,236,2,86,87,131,62,116,10,0
DB	116,100,128,62,110,10,0,117,93,139,54,100,10,209,230,139
DB	70,14,247,230,139,78,12,209,225,3,193,137,70,14,139,70
DB	16,43,70,12,209,224,131,192,2,137,70,16,139,70,10,247
DB	230,137,199,3,249,139,70,16,209,232,209,224,137,70,254,235
DB	30,255,118,16,255,118,8,255,118,6,87,255,54,116,10,154
DB	34,0,60,3,131,196,10,139,70,254,1,70,6,1,247,59
DB	126,14,119,44,235,219,139,126,10,235,32,139,118,12,235,21
DB	196,94,6,131,70,6,2,38,255,55,86,87,154,238,1,161
DB	1,131,196,6,70,59,118,16,118,230,71,59,126,14,118,219
DB	95,94,139,229,93,203,85,137,229,131,236,2,86,87,139,70
DB	6,185,6,0,247,233,140,218,187,120,10,3,216,137,22,146
DB	18,137,30,144,18,185,8,0,139,70,8,211,224,137,70,8
DB	142,194,137,222,38,138,12,48,237,3,193,80,255,118,12,255
DB	118,10,154,238,1,161,1,131,196,6,139,70,8,196,30,144
DB	18,38,138,79,1,48,237,3,193,80,255,118,16,255,118,10
DB	154,238,1,161,1,131,196,6,139,70,8,196,30,144,18,38
DB	138,79,2,48,237,3,193,80,255,118,12,255,118,14,154,238
DB	1,161,1,131,196,6,139,70,8,196,30,144,18,38,138,79
DB	3,48,237,3,193,80,255,118,16,255,118,14,154,238,1,161
DB	1,131,196,6,139,70,8,196,30,144,18,38,138,79,5,48
DB	237,3,193,137,70,254,139,126,12,71,235,31,255,118,254,87
DB	255,118,10,154,238,1,161,1,131,196,6,255,118,254,87,255
DB	118,14,154,238,1,161,1,131,196,6,71,59,126,16,114,220
DB	139,70,8,196,30,144,18,38,138,79,4,48,237,3,193,137
DB	70,254,139,126,10,71,235,31,255,118,254,255,118,12,87,154
DB	238,1,161,1,131,196,6,255,118,254,255,118,16,87,154,238
DB	1,161,1,131,196,6,71,59,126,14,114,220,95,94,139,229
DB	93,203,85,137,229,86,139,70,8,11,70,6,117,6,184,255
DB	255,94,93,203,49,246,196,94,6,38,139,79,10,246,193,131
DB	116,35,246,193,4,117,14,255,118,8,83,154,51,1,12,2
DB	131,196,4,137,198,196,94,6,38,255,119,12,154,76,0,242
DB	2,68,68,9,198,255,118,8,255,118,6,154,47,1,65,3
DB	131,196,4,184,16,0,80,49,192,80,255,118,8,255,118,6
DB	154,12,0,63,3,131,196,8,139,198,94,93,203,85,137,229
DB	131,236,8,184,228,12,137,194,199,70,252,174,11,140,94,254
DB	137,209,131,193,10,235,52,196,94,252,38,246,7,131,117,39
DB	140,194,137,216,131,192,246,137,86,250,137,70,248,82,80,255
DB	118,12,255,118,10,255,118,8,255,118,6,154,187,1,12,2
DB	131,196,12,139,229,93,203,131,70,252,16,59,78,252,119,199
DB	49,192,153,139,229,93,203,85,137,229,131,236,12,86,131,62
DB	234,18,0,116,31,235,14,137,86,246,137,70,244,255,94,244
DB	131,6,234,18,252,139,30,234,18,139,87,2,139,7,137,209
DB	9,193,117,227,199,70,252,164,11,140,94,254,184,228,12,137
DB	198,235,26,196,94,252,38,246,71,10,131,116,12,255,118,254
DB	83,154,2,0,12,2,131,196,4,131,70,252,16,139,70,252
DB	59,198,114,223,255,118,6,154,8,2,124,1,68,68,94,139
DB	229,93,203,85,137,229,87,196,94,6,38,139,71,10,37,38
DB	0,131,248,2,117,88,38,139,71,6,38,11,71,8,116,78
DB	38,139,87,2,38,139,7,137,199,38,139,87,8,38,139,71
DB	6,43,248,9,255,116,27,87,82,80,38,255,119,12,154,35
DB	0,242,2,131,196,8,59,199,116,8,196,94,6,38,128,79
DB	10,32,196,94,6,38,139,71,14,38,137,71,4,38,139,87
DB	8,38,139,71,6,38,137,87,2,38,137,7,235,9,196,94
DB	6,38,199,71,4,0,0,196,94,6,38,246,71,10,32,116
DB	5,184,255,255,235,2,49,192,95,93,203,85,137,229,131,236
DB	2,86,87,139,70,8,11,70,6,116,64,139,70,16,11,70
DB	14,116,56,196,94,6,38,128,63,0,116,47,199,70,254,0
DB	0,196,94,10,255,70,10,38,138,7,152,131,248,114,116,12
DB	131,248,97,116,12,131,248,119,116,12,235,15,190,1,0,235
DB	19,199,70,254,1,0,190,2,0,235,9,49,192,153,95,94
DB	139,229,93,203,196,94,10,38,128,63,43,117,7,129,206,128
DB	0,255,70,10,196,94,10,38,128,63,98,116,4,129,206,0
DB	1,139,198,37,2,0,139,206,246,193,128,116,43,9,192,116
DB	6,131,126,254,0,116,109,184,2,0,80,255,118,8,255,118
DB	6,154,42,0,242,2,131,196,6,137,199,131,255,255,116,84
DB	131,126,254,0,116,118,235,37,247,198,2,0,116,91,131,126
DB	254,0,116,64,184,1,0,80,255,118,8,255,118,6,154,42
DB	0,242,2,131,196,6,137,199,131,255,255,116,39,184,2,0
DB	80,49,192,153,82,80,87,154,123,0,242,2,131,196,8,131
DB	250,255,117,3,131,248,255,117,51,87,154,76,0,242,2,68
DB	68,233,87,255,49,192,80,255,118,8,255,118,6,154,59,0
DB	242,2,131,196,6,137,199,235,19,49,192,80,255,118,8,255
DB	118,6,154,42,0,242,2,131,196,6,137,199,196,94,14,38
DB	137,127,12,131,255,255,117,3,233,32,255,139,198,168,128,116
DB	2,36,252,38,137,71,10,38,199,71,4,0,0,49,192,153
DB	38,137,87,8,38,137,71,6,38,137,87,2,38,137,7,140
DB	194,137,216,95,94,139,229,93,203,85,137,229,255,54,150,18
DB	255,54,148,18,138,70,6,152,80,154,2,0,194,3,131,196
DB	6,93,203,85,137,229,139,86,8,139,70,6,137,22,150,18
DB	163,148,18,22,141,70,14,80,255,118,12,255,118,10,14,184
DB	9,0,80,154,72,1,61,2,131,196,12,93,203,85,137,229
DB	139,86,8,139,70,6,137,22,150,18,163,148,18,255,118,16
DB	255,118,14,255,118,12,255,118,10,14,184,9,0,80,154,72
DB	1,61,2,131,196,12,93,203,85,137,229,22,141,70,10,80
DB	255,118,8,255,118,6,154,144,0,61,2,131,196,8,93,203
DB	85,137,229,86,140,218,184,180,11,137,22,150,18,163,148,18
DB	255,118,12,255,118,10,255,118,8,255,118,6,14,187,9,0
DB	83,154,72,1,61,2,131,196,12,137,198,246,6,190,11,64
DB	116,13,30,184,180,11,80,154,51,1,12,2,131,196,4,139
DB	198,94,93,203,85,137,229,138,70,6,196,30,152,18,255,6
DB	152,18,38,136,7,152,93,203,85,137,229,22,141,70,14,80
DB	255,118,12,255,118,10,255,118,8,255,118,6,154,6,1,61
DB	2,131,196,12,93,203,85,137,229,86,139,86,8,139,70,6
DB	137,22,154,18,163,152,18,255,118,16,255,118,14,255,118,12
DB	255,118,10,14,184,212,0,80,154,72,1,61,2,131,196,12
DB	137,198,49,192,59,240,121,2,137,198,196,94,6,3,222,38
DB	198,7,0,139,198,94,93,203,85,137,229,131,236,98,86,87
DB	199,70,158,0,0,141,70,182,137,70,252,141,70,212,137,70
DB	254,233,203,7,131,248,37,116,20,80,255,94,6,68,68,131
DB	248,255,117,3,233,229,7,255,70,158,233,178,7,140,218,184
DB	150,10,137,86,174,137,70,172,199,70,232,0,0,235,20,191
DB	164,10,185,4,0,30,7,252,242,175,117,44,255,101,6,128
DB	78,232,1,196,94,10,255,70,10,38,138,7,152,137,70,162
DB	9,192,116,20,235,217,128,78,232,2,235,231,128,78,232,4
DB	235,225,128,78,232,8,235,219,49,192,137,70,176,131,126,162
DB	42,117,41,196,94,14,38,139,15,137,78,176,131,70,14,2
DB	59,200,121,9,128,78,232,1,247,217,137,78,176,196,94,10
DB	255,70,10,38,138,7,152,137,70,162,235,56,131,126,162,48
DB	117,36,128,78,232,64,235,30,139,70,176,185,10,0,247,233
DB	3,70,162,131,192,208,137,70,176,196,94,10,255,70,10,38
DB	138,7,152,137,70,162,255,118,162,154,1,0,193,3,68,68
DB	9,192,117,212,49,192,137,70,180,131,126,162,46,117,107,128
DB	78,232,128,196,94,10,255,70,10,38,138,7,152,137,70,162
DB	131,248,42,117,71,196,94,14,38,139,7,137,70,180,131,70
DB	14,2,9,192,121,9,128,102,232,127,199,70,180,0,0,196
DB	94,10,255,70,10,38,138,7,152,137,70,162,235,44,139,70
DB	180,185,10,0,247,233,3,70,162,131,192,208,137,70,180,196
DB	94,10,255,70,10,38,138,7,152,137,70,162,255,118,162,154
DB	1,0,193,3,68,68,9,192,117,212,131,126,162,108,117,19
DB	128,78,232,16,196,94,10,255,70,10,38,138,7,152,137,70
DB	162,235,23,131,126,162,76,117,17,128,78,232,32,196,94,10
DB	255,70,10,38,138,7,152,137,70,162,139,70,162,191,180,10
DB	185,17,0,30,7,252,242,175,116,3,233,111,6,255,101,32
DB	196,94,14,38,139,87,2,38,139,7,137,86,228,137,70,226
DB	131,70,14,4,137,209,9,193,117,11,140,218,184,151,10,137
DB	86,228,137,70,226,255,118,228,255,118,226,154,14,0,140,3
DB	131,196,4,137,70,230,246,70,232,128,117,3,233,50,5,139
DB	78,180,59,200,125,3,137,78,230,49,192,57,70,230,120,3
DB	233,30,5,137,70,230,233,24,5,198,70,182,37,235,13,196
DB	94,14,38,138,7,136,70,182,131,70,14,2,140,210,141,70
DB	182,137,86,228,137,70,226,199,70,230,1,0,233,242,4,190
DB	10,0,255,118,232,22,141,70,14,80,154,101,9,61,2,131
DB	196,6,137,86,166,137,70,164,137,86,170,137,70,168,49,219
DB	137,217,154,218,0,126,3,121,20,199,70,212,1,0,247,218
DB	247,216,131,218,0,137,86,170,137,70,168,235,5,199,70,212
DB	0,0,255,118,232,255,118,212,154,81,10,61,2,131,196,4
DB	137,86,174,137,70,172,235,126,190,2,0,235,8,190,8,0
DB	235,3,190,10,0,139,70,232,128,204,2,80,22,141,70,14
DB	80,154,101,9,61,2,131,196,6,137,86,170,137,70,168,235
DB	85,129,78,232,80,4,139,70,232,168,128,117,5,199,70,180
DB	9,0,128,78,233,1,190,16,0,139,70,232,128,204,2,80
DB	22,141,70,14,80,154,101,9,61,2,131,196,6,137,86,170
DB	137,70,168,139,78,232,246,193,8,116,27,9,194,116,23,246
DB	197,1,116,7,140,218,184,158,10,235,5,140,218,184,161,10
DB	137,86,174,137,70,172,140,210,141,70,211,137,86,228,137,70
DB	226,139,70,170,11,70,168,117,3,233,151,0,139,70,232,37
DB	0,4,137,70,242,139,198,153,137,86,246,137,70,244,139,70
DB	232,37,0,1,137,70,248,131,126,242,0,116,28,139,86,228
DB	139,70,226,140,209,141,94,207,59,209,117,2,59,195,117,9
DB	196,94,226,38,198,7,58,235,74,139,86,170,139,70,168,139
DB	78,246,139,94,244,154,66,0,126,3,128,195,48,196,118,226
DB	38,136,28,128,251,57,126,20,131,126,248,0,116,5,184,7
DB	0,235,3,184,39,0,196,94,226,38,0,7,139,78,246,139
DB	94,244,139,70,168,139,86,170,154,66,0,126,3,137,70,168
DB	137,86,170,255,78,226,139,70,170,11,70,168,117,137,255,70
DB	226,235,7,196,94,226,38,198,7,48,139,70,254,43,70,226
DB	137,70,230,59,70,180,124,3,233,86,3,184,30,0,57,70
DB	180,126,3,137,70,180,139,70,180,43,70,230,137,70,160,139
DB	118,232,129,230,0,4,235,40,9,246,116,24,139,86,228,139
DB	70,226,140,209,141,94,207,59,209,117,2,59,195,117,5,184
DB	58,0,235,3,184,48,0,255,78,226,196,94,226,38,136,7
DB	139,70,160,255,78,160,9,192,117,206,139,70,180,137,70,230
DB	233,254,2,198,70,236,0,246,70,232,128,117,5,199,70,180
DB	6,0,196,94,14,38,139,71,6,38,139,79,2,38,139,23
DB	38,139,95,4,137,70,220,137,94,218,137,78,216,137,86,214
DB	131,70,14,8,22,141,70,212,80,22,141,70,234,80,255,118
DB	180,255,118,220,255,118,218,255,118,216,255,118,214,154,49,0
DB	142,3,131,196,18,137,86,224,137,70,222,140,210,141,70,182
DB	137,86,228,137,70,226,255,118,232,255,118,212,154,81,10,61
DB	2,131,196,4,137,86,174,137,70,172,131,126,234,0,127,33
DB	196,94,226,255,70,226,38,198,7,48,235,21,196,94,222,255
DB	70,222,38,138,7,196,94,226,255,70,226,38,136,7,255,78
DB	234,49,192,57,70,234,126,10,139,78,226,141,94,211,59,203
DB	114,218,57,70,180,127,6,246,70,232,8,116,122,196,94,226
DB	255,70,226,38,198,7,46,235,16,196,94,226,255,70,226,38
DB	198,7,48,255,70,234,255,78,180,49,192,57,70,234,121,35
DB	57,70,180,126,30,139,70,226,141,94,212,59,195,115,20,235
DB	216,196,94,222,255,70,222,38,138,7,196,94,226,255,70,226
DB	38,136,7,139,70,180,255,78,180,9,192,126,10,139,70,226
DB	141,94,212,59,195,114,218,128,126,236,0,116,26,246,70,232
DB	8,117,20,255,118,228,255,118,226,154,129,10,61,2,131,196
DB	4,137,86,228,137,70,226,139,70,226,43,70,252,137,70,230
DB	140,210,141,70,182,137,86,228,137,70,226,233,179,1,198,70
DB	236,0,246,70,232,128,117,5,199,70,180,6,0,196,94,14
DB	38,139,71,6,38,139,79,2,38,139,23,38,139,95,4,137
DB	70,220,137,94,218,137,78,216,137,86,214,131,70,14,8,22
DB	141,118,212,86,22,141,118,234,86,139,118,180,70,86,80,83
DB	81,82,154,6,0,142,3,131,196,18,137,86,224,137,70,222
DB	140,210,141,70,182,137,86,228,137,70,226,255,118,232,255,118
DB	212,154,81,10,61,2,131,196,4,137,86,174,137,70,172,196
DB	94,222,255,70,222,38,138,7,196,94,226,255,70,226,38,136
DB	7,131,126,180,0,127,7,139,70,232,168,8,116,82,196,94
DB	226,255,70,226,38,198,7,46,235,18,196,94,222,255,70,222
DB	38,138,7,196,94,226,255,70,226,38,136,7,139,70,180,255
DB	78,180,9,192,126,10,139,70,226,141,94,207,59,195,114,218
DB	128,126,236,0,116,26,246,70,232,8,117,20,255,118,228,255
DB	118,226,154,129,10,61,2,131,196,4,137,86,228,137,70,226
DB	139,70,162,196,94,226,255,70,226,38,136,7,139,70,220,209
DB	224,11,70,218,11,70,216,11,70,214,116,3,255,78,234,255
DB	118,234,22,141,70,226,80,154,199,9,61,2,131,196,6,139
DB	70,226,43,70,252,137,70,230,140,210,141,70,182,137,86,228
DB	137,70,226,233,139,0,198,70,236,1,246,70,232,128,117,5
DB	199,70,180,6,0,196,94,14,38,139,71,6,38,139,79,2
DB	38,139,23,38,139,95,4,137,70,220,137,94,218,137,78,216
DB	137,86,214,131,70,14,8,22,141,118,212,86,22,141,118,234
DB	86,139,118,180,70,86,80,83,81,82,154,6,0,142,3,131
DB	196,18,137,86,224,137,70,222,139,70,234,131,248,253,124,9
DB	72,59,70,180,127,3,233,91,253,131,70,162,254,233,192,254
DB	196,94,14,38,139,87,2,38,139,7,137,86,240,137,70,238
DB	131,70,14,4,139,78,158,142,194,137,195,38,137,15,233,206
DB	0,255,118,174,255,118,172,154,14,0,140,3,131,196,4,137
DB	198,137,240,3,70,230,1,70,158,139,78,176,43,200,137,78
DB	178,246,70,232,64,116,28,235,16,80,255,94,6,68,68,9
DB	192,121,3,233,198,0,255,70,172,196,94,172,38,138,7,8
DB	192,117,230,139,70,178,9,192,126,72,1,70,158,139,70,232
DB	168,1,117,62,37,64,0,137,70,250,255,78,178,49,192,57
DB	70,178,120,46,131,126,250,0,116,5,185,48,0,235,3,185
DB	32,0,81,255,94,6,68,68,49,201,59,193,121,220,235,124
DB	196,94,172,38,255,55,255,94,6,68,68,9,192,120,109,255
DB	70,172,196,94,172,38,128,63,0,117,229,199,70,160,0,0
DB	235,21,196,94,226,3,94,160,38,255,55,255,94,6,68,68
DB	9,192,120,72,255,70,160,139,70,160,59,70,230,124,227,246
DB	70,232,1,116,10,255,78,178,49,192,57,70,178,121,20,196
DB	94,10,255,70,10,38,138,7,152,137,70,162,9,192,116,19
DB	233,33,248,177,32,81,255,94,6,68,68,49,201,59,193,121
DB	212,235,9,139,70,158,95,94,139,229,93,203,184,255,255,95
DB	94,139,229,93,203,85,137,229,131,236,4,86,196,94,6,38
DB	139,87,2,38,139,7,246,70,10,16,116,26,142,194,137,198
DB	38,139,84,2,38,139,4,137,86,254,137,70,252,196,118,6
DB	38,131,4,4,235,38,196,94,6,38,196,31,38,139,7,153
DB	137,86,254,137,70,252,246,70,11,2,116,9,128,102,252,255
DB	129,102,254,0,0,196,94,6,38,131,7,2,139,86,254,139
DB	70,252,94,139,229,93,203,85,137,229,131,236,4,86,87,139
DB	126,10,196,94,6,38,139,87,2,38,139,7,137,86,254,137
DB	70,252,9,255,121,11,137,248,247,216,137,199,184,45,0,235
DB	3,184,43,0,196,118,252,255,70,252,38,136,4,139,199,185
DB	100,0,153,247,249,4,48,196,118,252,255,70,252,38,136,4
DB	139,199,153,247,249,137,215,137,208,185,10,0,153,247,249,4
DB	48,196,118,252,255,70,252,38,136,4,139,199,153,247,249,128
DB	194,48,196,118,252,255,70,252,38,136,20,139,86,254,139,70
DB	252,196,118,6,38,137,84,2,38,137,4,95,94,139,229,93
DB	203,85,137,229,131,126,6,0,116,7,140,218,184,248,10,235
DB	30,139,70,8,168,2,116,7,140,218,184,250,10,235,16,168
DB	4,116,7,140,218,184,252,10,235,5,140,218,184,254,10,93
DB	203,85,137,229,131,236,4,139,86,8,139,70,6,72,137,86
DB	254,137,70,252,235,6,255,78,252,255,78,6,196,94,252,38
DB	128,63,48,116,241,196,94,6,38,128,127,255,46,117,3,255
DB	78,6,139,86,8,139,70,6,139,229,93,203,85,139,236,86
DB	87,140,219,196,126,10,197,118,6,51,192,185,255,255,252,242
DB	174,247,209,43,249,59,78,14,114,3,139,78,14,243,166,116
DB	6,27,192,245,21,0,0,142,219,95,94,93,203,0,85,139
DB	236,139,70,6,153,51,194,43,194,93,203,85,139,236,139,70
DB	6,139,86,8,11,210,121,7,247,218,247,216,131,218,0,93
DB	203,85,139,236,86,30,197,118,6,252,172,60,32,116,251,60
DB	9,114,4,60,13,118,243,51,201,139,217,50,228,60,43,116
DB	5,60,45,117,2,75,172,44,48,114,18,60,10,115,14,209
DB	225,139,209,209,225,209,225,3,202,3,200,235,233,139,193,51
DB	195,43,195,31,94,93,203,0,180,63,85,139,236,139,94,6
DB	30,197,86,8,139,78,12,205,33,31,115,5,163,203,9,27
DB	192,93,203,180,64,235,227,140,216,203,85,139,236,180,61,138
DB	70,10,30,197,86,6,205,33,31,235,223,85,139,236,51,201
DB	235,6,85,139,236,139,78,10,180,60,235,230,85,139,236,139
DB	94,6,180,62,205,33,235,26,144,85,139,236,87,180,86,196
DB	126,10,235,6,85,139,236,87,180,65,30,197,86,6,205,33
DB	31,95,115,3,163,203,9,27,192,93,203,85,139,236,139,94
DB	6,139,86,8,139,78,10,138,70,12,180,66,205,33,115,6
DB	163,203,9,27,192,153,93,203,85,30,131,236,44,139,236,22
DB	31,139,213,180,26,205,33,197,86,52,185,6,0,180,78,205
DB	33,114,12,139,86,28,139,70,26,131,196,44,31,93,203,142
DB	94,44,163,203,9,27,192,153,235,239,139,220,54,139,95,4
DB	184,0,68,205,33,114,6,138,194,152,138,196,203,163,203,9
DB	51,192,203,0,85,139,236,86,87,252,142,6,199,9,38,142
DB	6,44,0,51,255,51,192,185,255,255,139,217,30,197,118,6
DB	243,166,38,56,1,116,23,56,0,116,4,242,174,235,238,38
DB	128,57,61,117,246,139,199,140,194,31,95,94,93,203,153,235
DB	248,0,234,16,0,0,0,203,85,139,236,139,70,6,139,94
DB	8,131,251,1,116,4,247,227,114,36,80,154,67,0,4,3
DB	139,229,11,210,116,22,87,142,194,139,248,139,216,38,139,77
DB	254,209,233,73,51,192,252,243,171,139,195,95,93,203,51,192
DB	153,93,203,85,30,131,62,8,11,255,117,36,161,4,11,139
DB	30,2,11,139,203,131,227,15,209,233,209,233,209,233,209,233
DB	3,193,163,4,11,137,30,2,11,163,10,11,137,30,8,11
DB	139,236,86,87,139,110,8,131,197,3,131,229,254,131,253,4
DB	115,3,233,219,0,131,253,6,115,3,189,6,0,139,22,4
DB	11,139,62,2,11,139,202,139,247,142,193,38,139,68,2,38
DB	139,28,142,192,38,59,111,4,118,59,139,200,139,243,59,202
DB	117,2,59,247,117,227,129,253,0,2,115,3,189,0,2,85
DB	154,14,0,54,3,93,139,216,139,194,131,251,255,116,179,131
DB	195,2,80,83,154,23,2,4,3,131,196,4,61,255,255,116
DB	127,95,94,235,139,137,14,10,11,137,54,8,11,139,213,131
DB	194,6,114,6,38,59,87,4,118,28,38,139,87,2,38,139
DB	63,142,193,38,137,84,2,38,137,60,142,192,38,139,87,4
DB	38,137,23,235,65,144,139,208,139,251,3,253,139,199,131,231
DB	15,209,232,209,232,209,232,209,232,3,208,140,192,85,247,221
DB	38,3,111,4,142,194,38,137,109,4,142,216,139,23,38,137
DB	21,139,87,2,38,137,85,2,140,194,142,193,38,137,84,2
DB	38,137,60,93,137,47,131,195,2,146,147,95,94,31,93,203
DB	51,192,153,235,246,85,139,236,139,70,10,11,192,117,4,93
DB	233,164,0,196,94,6,140,193,11,203,117,10,80,154,67,0
DB	4,3,139,229,93,203,131,235,2,38,139,15,5,3,0,36
DB	254,43,200,114,57,131,249,6,114,44,87,139,251,3,248,38
DB	137,13,38,137,7,139,223,140,192,139,203,131,227,15,209,233
DB	209,233,209,233,209,233,3,193,131,195,2,80,83,154,23,2
DB	4,3,131,196,4,95,139,86,8,139,70,6,235,71,255,118
DB	10,154,67,0,4,3,139,229,11,210,116,54,80,86,87,82
DB	30,197,118,6,142,194,139,248,139,76,254,38,59,77,254,118
DB	4,38,139,77,254,209,233,73,252,243,165,31,255,118,8,255
DB	118,6,154,23,2,4,3,131,196,4,90,95,94,11,192,88
DB	116,3,51,192,153,93,203,85,139,236,86,87,30,139,86,8
DB	139,126,6,139,194,11,199,117,3,233,244,0,247,199,1,0
DB	116,3,233,243,0,131,239,2,139,14,10,11,139,54,8,11
DB	59,202,117,2,59,247,114,6,185,91,4,190,2,11,142,193
DB	38,139,68,2,38,139,28,59,202,117,2,59,247,115,211,59
DB	194,117,2,59,223,119,14,59,193,117,2,59,222,118,6,139
DB	200,139,243,235,217,137,14,10,11,137,54,8,11,142,218,139
DB	45,137,109,4,137,69,2,137,29,142,217,137,84,2,137,60
DB	139,193,139,222,3,92,4,139,203,131,227,15,209,233,209,233
DB	209,233,209,233,3,193,140,217,59,194,117,2,59,223,116,4
DB	139,202,139,247,142,217,139,193,139,222,3,92,4,139,211,131
DB	227,15,209,234,209,234,209,234,209,234,3,194,139,84,2,139
DB	60,142,194,59,194,117,2,59,223,117,69,139,108,4,38,3
DB	109,4,114,17,137,108,4,38,139,5,137,4,38,139,69,2
DB	137,68,2,235,191,139,193,5,255,15,142,216,38,139,69,2
DB	38,139,29,137,68,2,137,28,131,237,240,137,108,4,140,216
DB	142,217,137,68,2,137,52,199,68,4,240,255,139,200,235,148
DB	51,192,153,31,95,94,93,203,184,255,255,235,246,0,85,139
DB	236,139,94,6,131,195,15,131,227,240,116,63,139,211,177,4
DB	211,235,139,203,3,30,195,9,6,142,6,199,9,180,74,205
DB	33,7,115,15,61,8,0,117,37,139,217,180,72,205,33,114
DB	29,235,11,161,199,9,3,6,195,9,1,14,195,9,51,219
DB	142,192,38,137,23,139,208,139,195,93,203,184,8,0,163,203
DB	9,184,255,255,153,93,203,0,85,139,236,86,87,252,30,142
DB	94,6,139,118,8,196,126,10,139,78,14,243,164,31,95,94
DB	93,203,85,139,236,86,87,252,30,142,70,6,139,126,8,197
DB	118,10,139,78,14,243,164,31,95,94,93,203,85,139,236,87
DB	196,126,6,139,223,138,70,10,139,78,12,252,243,170,139,195
DB	140,194,95,93,203,85,137,229,131,236,4,86,199,70,252,164
DB	11,140,94,254,184,228,12,137,198,235,31,196,94,252,38,139
DB	71,10,168,131,116,16,168,64,116,12,255,118,254,83,154,51
DB	1,12,2,131,196,4,131,70,252,16,139,70,252,59,198,114
DB	218,94,139,229,93,203,85,137,229,184,0,2,80,139,70,12
DB	11,70,10,116,4,49,192,235,3,184,4,0,80,255,118,12
DB	255,118,10,255,118,8,255,118,6,154,115,0,65,3,131,196
DB	12,93,203,85,137,229,86,87,139,126,14,255,118,8,255,118
DB	6,154,47,1,65,3,131,196,4,184,4,0,57,199,117,38
DB	139,70,6,187,164,11,43,195,185,4,0,211,248,140,218,187
DB	156,18,3,216,196,118,6,38,137,84,8,38,137,92,6,199
DB	70,16,1,0,235,73,131,255,64,116,4,9,255,117,57,139
DB	86,12,139,70,10,196,94,6,38,137,87,8,38,137,71,6
DB	137,209,9,193,117,41,255,118,16,154,67,0,4,3,68,68
DB	196,94,6,38,137,87,8,38,137,71,6,137,209,9,193,116
DB	7,38,128,79,10,8,235,7,184,255,255,95,94,93,203,196
DB	94,6,38,139,87,8,38,139,71,6,38,137,87,2,38,137
DB	7,49,192,38,137,71,4,38,139,79,10,128,225,187,11,207
DB	38,137,79,10,139,78,16,38,137,79,14,95,94,93,203,85
DB	137,229,196,94,6,38,246,71,10,8,116,32,38,139,87,8
DB	38,139,71,6,137,209,9,193,116,10,82,80,154,23,2,4
DB	3,131,196,4,196,94,6,38,128,103,10,247,196,94,6,38
DB	199,71,6,0,0,38,199,71,8,0,0,93,203,85,137,229
DB	131,236,4,86,87,196,94,8,38,139,71,10,168,128,116,8
DB	36,254,12,2,38,137,71,10,196,94,8,38,139,71,10,137
DB	70,254,37,50,0,131,248,2,116,3,233,14,1,139,70,254
DB	168,4,116,52,184,1,0,80,22,141,70,6,80,196,94,8
DB	38,255,119,12,154,35,0,242,2,131,196,8,131,248,1,116
DB	3,233,223,0,196,94,8,38,199,71,4,0,0,139,70,6
DB	48,228,95,94,139,229,93,203,38,139,79,6,38,11,79,8
DB	117,91,137,198,129,230,68,0,9,246,117,2,49,246,196,94
DB	8,38,255,119,12,154,202,0,242,2,68,68,9,192,116,3
DB	190,64,0,184,0,2,80,86,49,192,153,82,80,255,118,10
DB	255,118,8,154,115,0,65,3,131,196,12,9,192,116,75,184
DB	1,0,80,184,4,0,80,49,192,153,82,80,255,118,10,255
DB	118,8,154,115,0,65,3,131,196,12,233,103,255,196,94,8
DB	38,139,87,2,38,139,7,137,199,38,139,87,8,38,139,71
DB	6,43,248,9,255,116,19,87,82,80,38,255,119,12,154,35
DB	0,242,2,131,196,8,59,199,117,57,196,94,8,38,139,87
DB	8,38,139,71,6,38,137,87,2,38,137,7,139,78,6,142
DB	194,137,195,38,136,15,196,94,8,38,255,7,196,94,8,38
DB	139,71,14,72,38,137,71,4,139,70,6,48,228,95,94,139
DB	229,93,203,196,94,8,38,128,79,10,32,196,94,8,38,199
DB	71,4,0,0,184,255,255,95,94,139,229,93,203,85,137,229
DB	131,236,4,86,196,94,6,38,139,71,10,168,128,116,8,36
DB	253,12,1,38,137,71,10,139,86,8,139,70,6,142,194,137
DB	195,38,139,79,10,137,78,254,129,225,49,0,131,249,1,116
DB	3,233,205,0,142,194,137,198,38,139,68,6,38,11,68,8
DB	117,97,139,118,254,129,230,68,0,9,246,117,2,49,246,247
DB	198,4,0,116,29,184,1,0,80,184,4,0,80,49,192,153
DB	82,80,255,118,8,255,118,6,154,115,0,65,3,131,196,12
DB	235,49,196,94,6,38,255,119,12,154,202,0,242,2,68,68
DB	9,192,116,3,190,64,0,184,0,2,80,86,49,192,153,82
DB	80,255,118,8,255,118,6,154,115,0,65,3,131,196,12,9
DB	192,117,178,196,94,6,38,246,71,10,68,116,5,154,5,0
DB	65,3,196,94,6,38,139,87,8,38,139,71,6,38,137,87
DB	2,38,137,7,38,255,119,14,82,80,38,255,119,12,154,8
DB	0,242,2,131,196,8,196,94,6,38,137,71,4,9,192,127
DB	49,9,192,117,20,38,128,79,10,16,38,139,71,10,168,128
DB	116,15,38,128,103,10,223,235,8,196,94,6,38,128,79,10
DB	32,196,94,6,38,199,71,4,0,0,184,255,255,94,139,229
DB	93,203,49,192,94,139,229,93,203,0,86,139,242,145,11,192
DB	116,2,247,225,150,11,192,116,4,247,227,3,240,139,193,247
DB	227,3,214,94,203,11,210,117,7,247,243,139,218,139,209,203
DB	139,200,139,194,51,210,247,243,145,247,243,139,218,139,209,51
DB	201,203,227,225,85,189,1,0,10,237,120,24,117,15,131,197
DB	8,138,233,138,207,138,251,50,219,10,237,120,7,69,209,227
DB	209,209,113,249,139,241,139,251,139,202,139,216,51,192,153,59
DB	241,119,11,114,4,59,251,119,5,43,223,27,206,249,209,208
DB	209,210,209,238,209,223,77,117,230,93,203,184,255,255,153,93
DB	203,11,201,121,173,247,217,247,219,131,217,0,154,66,0,126
DB	3,247,218,247,216,131,218,0,203,11,210,121,228,247,218,247
DB	216,131,218,0,11,201,121,20,247,217,247,219,131,217,0,154
DB	66,0,126,3,247,217,247,219,131,217,0,203,154,66,0,126
DB	3,247,217,247,219,131,217,0,235,199,59,209,117,14,82,51
DB	210,59,195,116,6,119,3,74,90,203,66,90,203,0,139,220
DB	139,215,54,196,127,4,51,192,185,255,255,252,242,174,139,193
DB	247,208,72,139,250,203,85,137,229,255,118,22,255,118,20,255
DB	118,18,255,118,16,255,118,14,255,118,12,255,118,10,255,118
DB	8,255,118,6,49,192,80,154,93,0,142,3,131,196,20,93
DB	203,85,137,229,255,118,22,255,118,20,255,118,18,255,118,16
DB	255,118,14,255,118,12,255,118,10,255,118,8,255,118,6,184
DB	1,0,80,154,93,0,142,3,131,196,20,93,203,85,137,229
DB	131,236,26,86,87,255,118,14,255,118,12,255,118,10,255,118
DB	8,49,192,153,137,193,137,195,154,57,3,204,3,125,32,139
DB	70,14,139,94,12,139,78,10,139,86,8,128,244,128,137,70
DB	14,137,94,12,137,78,10,137,86,8,184,1,0,235,2,49
DB	192,196,94,22,38,137,7,139,70,16,49,201,59,193,121,2
DB	235,13,186,30,0,59,194,125,4,137,193,235,2,137,209,137
DB	78,16,184,176,18,139,86,14,209,226,11,86,12,11,86,10
DB	11,86,8,117,34,199,70,232,176,18,140,94,234,137,202,3
DB	208,235,10,196,94,232,38,198,7,48,255,70,232,59,86,232
DB	119,241,49,255,233,33,2,161,197,9,137,70,230,199,6,197
DB	9,0,0,191,1,0,190,0,1,199,70,238,92,11,140,94
DB	240,199,70,242,20,11,140,94,244,235,97,255,118,14,255,118
DB	12,255,118,10,255,118,8,196,94,238,38,139,71,6,38,139
DB	79,2,38,139,23,38,139,95,4,154,224,4,204,3,137,70
DB	14,137,94,12,137,78,10,137,86,8,41,247,255,118,14,255
DB	118,12,255,118,10,255,118,8,196,94,242,38,139,71,6,38
DB	139,79,2,38,139,23,38,139,95,4,154,57,3,204,3,124
DB	170,209,254,184,8,0,1,70,238,1,70,242,255,118,14,255
DB	118,12,255,118,10,255,118,8,184,240,63,153,137,209,137,211
DB	154,57,3,204,3,124,181,190,0,1,199,70,246,12,11,140
DB	94,248,199,70,250,92,11,140,94,252,235,97,255,118,14,255
DB	118,12,255,118,10,255,118,8,196,94,246,38,139,71,6,38
DB	139,79,2,38,139,23,38,139,95,4,154,224,4,204,3,137
DB	70,14,137,94,12,137,78,10,137,86,8,1,247,255,118,14
DB	255,118,12,255,118,10,255,118,8,196,94,250,38,139,71,6
DB	38,139,79,2,38,139,23,38,139,95,4,154,57,3,204,3
DB	125,170,209,254,184,8,0,1,70,246,1,70,250,255,118,14
DB	255,118,12,255,118,10,255,118,8,184,36,64,153,137,209,137
DB	211,154,57,3,204,3,125,181,139,70,230,163,197,9,131,126
DB	6,1,117,30,1,126,16,49,192,57,70,16,121,2,235,15
DB	185,30,0,57,78,16,125,5,139,70,16,235,2,137,200,137
DB	70,16,140,218,184,176,18,137,86,234,137,70,232,139,118,16
DB	3,240,184,193,18,137,70,254,235,102,139,70,232,59,70,254
DB	114,9,196,94,232,38,198,7,48,235,82,139,70,14,139,94
DB	12,139,78,10,139,86,8,154,87,7,204,3,137,70,236,4
DB	48,196,94,232,38,136,7,255,118,14,255,118,12,255,118,10
DB	255,118,8,139,70,236,154,150,6,204,3,154,113,1,204,3
DB	80,83,81,82,184,36,64,153,137,209,137,211,154,224,4,204
DB	3,137,70,14,137,94,12,137,78,10,137,86,8,255,70,232
DB	59,118,232,115,149,255,78,232,196,94,232,38,128,63,53,124
DB	55,139,86,234,139,70,232,140,217,187,176,18,59,209,117,2
DB	59,195,117,14,139,70,6,1,70,16,71,198,6,176,18,49
DB	235,22,196,94,232,38,198,7,48,255,78,232,196,94,232,38
DB	128,63,57,116,204,38,254,7,196,94,18,38,137,63,139,94
DB	16,198,135,176,18,0,140,218,184,176,18,95,94,139,229,93
DB	203,85,137,229,139,94,6,138,135,255,12,152,37,128,0,93
DB	203,0,85,139,236,139,70,6,140,217,197,94,8,60,10,117
DB	48,246,71,11,1,116,15,176,13,154,66,0,194,3,139,70
DB	6,140,217,197,94,8,246,71,11,0,116,21,154,66,0,194
DB	3,255,118,10,255,118,8,154,51,1,12,2,131,196,4,93
DB	203,93,255,79,4,120,11,87,252,196,63,170,137,63,142,217
DB	95,203,30,142,217,83,80,154,109,1,65,3,131,196,6,203
DB	85,139,236,196,94,6,38,255,79,4,120,33,86,252,140,217
DB	38,197,55,172,50,228,142,217,38,137,55,38,246,71,11,1
DB	94,116,8,60,13,116,223,60,26,116,17,93,203,6,83,154
DB	189,2,65,3,139,229,11,192,116,201,93,203,184,255,255,38
DB	128,79,10,16,38,199,71,4,0,0,93,203,139,250,209,226
DB	134,242,50,246,139,242,139,215,128,202,128,138,242,138,212,138
DB	224,50,192,195,131,238,8,10,246,116,17,209,234,209,216,70
DB	115,245,10,246,117,245,64,117,3,66,235,235,11,210,117,9
DB	11,192,117,5,186,128,0,51,246,246,194,128,117,7,209,224
DB	209,210,78,235,244,247,198,0,255,116,23,186,1,0,120,1
DB	66,82,154,6,0,90,4,90,51,192,74,116,23,186,128,127
DB	235,12,81,185,7,0,211,230,89,128,226,127,11,214,129,231
DB	0,128,11,215,195,139,248,139,240,129,230,240,127,209,238,209
DB	238,209,238,209,238,12,16,138,224,138,199,138,251,138,221,138
DB	233,138,206,138,242,50,210,209,226,209,209,209,211,209,208,209
DB	226,209,209,209,211,209,208,209,226,209,209,209,211,209,208,195
DB	131,238,11,246,196,192,116,19,138,214,138,241,138,205,138,235
DB	138,223,138,248,138,196,50,228,131,198,8,169,224,255,116,29
DB	209,232,209,219,209,217,209,218,70,115,240,169,224,255,117,240
DB	131,194,1,131,209,0,131,211,0,18,196,235,222,10,192,117
DB	33,11,219,117,33,135,218,135,217,131,238,16,11,219,117,22
DB	135,217,131,238,16,11,219,116,48,10,255,117,9,134,251,131
DB	238,8,168,16,117,11,209,226,209,209,209,211,208,208,78,235
DB	241,247,198,0,248,117,19,209,230,209,230,209,230,209,230,36
DB	15,11,198,129,231,0,128,11,199,195,176,1,120,1,64,87
DB	80,154,6,0,90,4,88,95,51,219,139,203,139,211,72,116
DB	232,184,240,127,235,221,80,209,224,11,194,11,193,11,195,88
DB	203,85,129,236,38,0,139,236,131,62,197,9,0,116,65,155
DB	221,134,44,0,80,83,81,82,155,220,102,248,155,221,126,254
DB	155,246,70,255,28,116,24,184,1,0,246,70,255,16,117,8
DB	64,246,70,255,8,117,1,64,80,154,6,0,90,4,88,155
DB	221,94,248,155,90,89,91,88,129,196,38,0,93,202,8,0
DB	249,235,51,85,131,236,38,139,236,131,62,197,9,0,116,38
DB	155,221,70,44,80,83,81,82,155,220,70,248,235,174,139,70
DB	50,139,94,48,139,78,46,139,86,44,233,68,1,129,231,0
DB	128,51,199,233,59,1,87,209,223,80,209,224,11,194,11,193
DB	11,195,88,116,217,80,139,70,50,136,102,31,209,224,11,70
DB	48,11,70,46,11,70,44,88,116,211,86,51,248,137,126,32
DB	51,126,30,137,126,36,232,92,254,137,118,34,137,86,0,137
DB	78,2,137,94,4,137,70,6,139,70,50,139,94,48,139,78
DB	46,139,86,44,232,62,254,43,118,34,119,68,131,254,192,127
DB	17,139,126,32,139,86,0,139,78,2,139,94,4,139,70,6
DB	235,57,131,254,248,127,21,138,214,138,241,138,205,138,235,138
DB	223,138,248,138,196,50,228,131,198,8,117,230,135,206,227,12
DB	247,217,209,232,209,219,209,222,209,218,226,246,135,206,235,86
DB	1,118,34,131,254,64,114,12,139,126,30,139,118,34,232,31
DB	254,233,140,0,135,86,0,135,78,2,135,94,4,135,70,6
DB	131,254,8,114,23,138,214,138,241,138,205,138,235,138,223,138
DB	248,138,196,50,228,131,238,8,117,230,235,14,135,206,209,232
DB	209,219,209,222,209,218,226,246,135,206,135,86,0,135,78,2
DB	135,94,4,135,70,6,208,102,37,115,35,43,86,0,27,78
DB	2,27,94,4,27,70,6,115,46,128,118,31,128,247,209,247
DB	211,247,208,247,218,245,19,206,19,222,19,198,235,25,3,86
DB	0,19,78,2,19,94,4,19,70,6,115,11,209,216,209,219
DB	209,217,209,218,255,70,34,139,126,30,139,118,34,232,144,253
DB	94,95,131,196,38,93,202,8,0,85,139,236,87,80,139,248
DB	209,231,11,250,11,249,11,251,117,3,128,228,127,139,126,12
DB	209,231,11,126,10,11,126,8,11,126,6,117,4,128,102,13
DB	127,139,248,51,126,12,120,41,191,1,0,11,192,121,2,247
DB	223,57,70,12,117,15,57,94,10,117,10,57,78,8,117,5
DB	57,86,6,116,6,119,2,247,223,11,255,88,95,93,202,8
DB	0,57,70,12,235,245,128,244,128,203,85,131,236,38,139,236
DB	131,62,197,9,0,116,49,155,221,70,44,80,83,81,82,155
DB	220,118,248,233,214,253,80,184,3,0,80,154,6,0,90,4
DB	88,88,51,70,50,37,0,128,13,240,127,51,219,139,203,139
DB	211,233,3,1,51,192,235,243,86,87,139,126,50,209,231,11
DB	126,48,11,126,46,11,126,44,116,234,139,248,209,231,11,251
DB	11,249,11,250,116,192,137,70,32,139,248,129,231,240,127,51
DB	199,12,16,137,86,0,137,78,2,137,94,4,137,70,6,139
DB	70,50,139,94,48,139,78,46,139,86,44,49,70,32,139,240
DB	129,230,240,127,51,198,12,16,129,239,240,63,43,247,209,238
DB	209,238,209,238,209,238,137,118,34,139,241,138,102,6,185,16
DB	0,58,196,119,21,114,30,59,94,4,119,14,114,23,59,118
DB	2,119,7,114,16,59,86,0,114,11,43,86,0,27,118,2
DB	27,94,4,26,196,209,215,209,226,209,214,209,211,208,208,226
DB	208,247,215,87,177,16,139,86,4,58,196,119,13,114,18,59
DB	218,119,7,114,12,59,118,2,114,7,43,118,2,27,218,26
DB	196,209,215,209,230,209,211,208,208,226,222,247,215,87,177,16
DB	58,196,119,6,114,8,59,218,114,4,43,218,26,196,209,215
DB	209,227,208,208,226,234,247,215,177,8,58,196,114,2,42,196
DB	208,214,208,224,226,244,246,214,138,213,139,207,91,88,139,118
DB	34,139,126,32,232,233,251,95,94,131,196,38,93,202,8,0
DB	85,131,236,38,139,236,131,62,197,9,0,116,18,155,221,70
DB	44,80,83,81,82,155,220,78,248,233,144,252,233,139,1,86
DB	87,139,248,209,231,209,94,32,11,251,11,249,11,250,116,236
DB	137,70,34,129,102,34,240,127,12,16,37,31,0,137,86,0
DB	137,78,2,137,94,4,137,70,6,139,70,50,139,94,48,139
DB	78,46,139,86,44,139,248,209,231,11,251,11,249,11,250,116
DB	187,49,70,32,139,240,129,230,240,127,3,118,34,209,238,209
DB	238,209,238,209,238,129,198,24,252,137,118,34,12,16,37,31
DB	0,140,198,140,215,142,199,141,126,14,137,86,8,137,78,10
DB	137,94,12,252,171,51,192,185,8,0,243,171,142,198,30,140
DB	208,142,216,131,239,24,51,219,139,77,6,139,117,4,139,70
DB	0,247,37,137,86,18,139,70,0,247,101,2,1,70,18,17
DB	86,20,139,70,0,247,230,1,70,20,17,86,22,139,70,0
DB	247,225,1,70,22,17,86,24,139,70,2,247,37,1,70,18
DB	17,86,20,17,94,22,17,94,24,139,70,2,247,101,2,1
DB	70,20,17,86,22,17,94,24,139,70,2,247,230,1,70,22
DB	17,86,24,17,94,26,139,70,2,247,225,1,70,24,17,86
DB	26,139,70,4,247,37,1,70,20,17,86,22,17,94,24,17
DB	94,26,139,70,4,247,101,2,1,70,22,17,86,24,17,94
DB	26,139,70,4,247,230,1,70,24,17,86,26,17,94,28,139
DB	70,4,247,225,1,70,26,17,86,28,139,70,6,247,37,1
DB	70,22,17,86,24,17,94,26,17,94,28,139,70,6,247,101
DB	2,1,70,24,17,86,26,17,94,28,139,70,6,247,230,1
DB	70,26,19,86,28,139,70,6,246,225,3,194,31,139,86,22
DB	139,78,24,139,94,26,209,232,209,219,209,217,209,218,209,232
DB	209,219,209,217,209,218,209,232,209,219,209,217,209,218,139,118
DB	34,131,238,24,139,126,32,232,81,250,95,94,131,196,38,93
DB	202,8,0,248,235,27,131,62,197,9,0,116,14,80,131,236
DB	6,85,139,236,155,223,70,8,235,115,144,11,192,121,2,247
DB	216,86,87,209,223,153,139,202,139,218,190,14,4,232,0,250
DB	95,94,203,248,235,34,131,62,197,9,0,116,15,82,80,131
DB	236,4,85,139,236,155,219,70,6,235,66,144,11,210,121,8
DB	247,218,247,216,131,218,0,249,86,87,209,223,51,201,139,217
DB	147,146,190,30,4,232,200,249,95,94,203,83,81,154,10,7
DB	204,3,154,174,7,204,3,89,91,203,131,62,197,9,0,116
DB	23,82,80,131,236,4,85,139,236,155,217,70,6,155,221,94
DB	2,93,155,90,89,91,88,203,87,51,201,139,217,139,250,209
DB	231,11,248,116,14,86,232,211,248,147,146,129,198,128,3,232
DB	126,249,94,95,203,154,102,1,204,3,116,54,86,87,232,52
DB	249,11,255,120,43,235,13,154,102,1,204,3,116,36,86,87
DB	232,34,249,249,208,219,129,238,255,3,120,20,185,15,0,43
DB	206,114,18,116,33,211,232,11,255,121,2,247,216,95,94,203
DB	95,94,51,192,203,184,255,255,10,219,121,241,209,232,11,255
DB	121,235,247,208,235,231,10,219,120,235,235,225,154,102,1,204
DB	3,116,69,86,87,232,221,248,11,255,120,58,235,13,154,102
DB	1,204,3,116,51,86,87,232,203,248,249,139,208,139,195,208
DB	219,129,238,255,3,120,31,185,31,0,59,241,119,30,43,206
DB	227,46,209,234,209,216,226,250,11,255,121,7,247,218,247,216
DB	131,218,0,95,94,203,95,94,51,192,153,203,184,255,255,153
DB	10,219,121,239,209,234,11,255,121,233,247,208,247,210,235,227
DB	10,219,120,232,235,221,131,62,197,9,0,116,23,80,83,81
DB	82,85,139,236,155,221,70,2,155,217,94,6,93,131,196,4
DB	155,88,90,203,154,102,1,204,3,116,17,86,87,232,85,248
DB	129,238,128,3,146,147,232,235,247,95,94,203,152,203,83,81
DB	154,150,6,204,3,154,6,8,204,3,89,91,203,83,81,154
DB	147,6,204,3,235,239,83,81,154,198,6,204,3,235,230,83
DB	81,154,10,7,204,3,154,87,7,204,3,235,221,83,81,154
DB	10,7,204,3,154,69,7,204,3,235,207,155,217,228,155,221
DB	216,85,139,236,131,236,2,155,221,126,254,80,155,138,102,255
DB	158,88,139,229,93,203,85,139,236,80,83,81,82,155,221,70
DB	248,155,139,229,93,203,85,139,236,82,80,155,217,70,252,235
DB	240,85,139,236,131,236,4,155,217,126,254,155,217,46,252,12
DB	155,223,94,252,155,88,217,110,254,155,139,229,93,203,85,139
DB	236,131,236,6,155,217,126,254,155,217,46,252,12,155,219,94
DB	250,155,88,90,235,224,85,137,229,93,203,0,0,0,0,0
DB	69,82,82,79,82,58,32,78,85,76,76,32,112,111,105,110
DB	116,101,114,0,90,111,114,116,101,99,104,32,67,32,52,46
DB	48,48,32,108,105,98,114,97,114,121,44,32,67,111,112,121
DB	114,105,103,104,116,32,40,67,41,32,49,57,56,56,32,76
DB	44,32,119,114,105,116,116,101,110,32,98,121,32,87,97,108
DB	116,101,114,32,66,114,105,103,104,116,0,0,0,8,0,0
DB	0,0,0,0,0,0,240,85,0,0,1,7,80,80,46,67
DB	70,71,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,83,79,85,78
DB	68,32,66,76,65,83,84,69,82,0,73,82,81,0,68,65
DB	67,32,73,78,32,76,80,84,49,0,68,65,67,32,73,78
DB	32,76,80,84,50,0,70,82,69,81,85,69,78,67,89,0
DB	77,79,68,45,80,65,84,72,83,84,77,45,80,65,84,72
DB	10,68,101,118,105,99,101,32,110,117,109,98,101,114,32,109
DB	117,115,116,32,98,101,32,98,101,116,119,101,101,110,32,49
DB	32,97,110,100,32,51,46,10,0,10,73,82,81,32,110,117
DB	109,98,101,114,32,109,117,115,116,32,98,101,32,50,44,51
DB	44,53,32,111,114,32,55,46,10,0,10,80,108,97,121,105
DB	110,103,32,102,114,101,113,117,101,110,99,121,32,109,117,115
DB	116,32,98,101,32,98,101,116,119,101,101,110,32,0,52,48
DB	48,48,32,72,122,32,97,110,100,32,50,50,48,48,48,32
DB	72,122,46,10,0,80,65,84,72,0,69,114,114,111,114,32
DB	105,110,32,68,79,83,32,101,110,118,105,114,111,110,109,101
DB	110,116,44,32,112,97,116,104,32,110,111,116,32,102,111,117
DB	110,100,33,0,77,111,100,117,108,101,32,110,111,116,32,102
DB	111,117,110,100,33,0,80,65,84,72,0,80,65,84,72,0
DB	201,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205
DB	205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205
DB	205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205
DB	205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,187
DB	0,186,32,32,32,32,32,32,32,32,32,32,32,32,32,32
DB	32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
DB	32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
DB	32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
DB	186,0,186,32,32,32,32,32,32,32,32,32,32,32,32,32
DB	32,32,32,32,32,32,218,196,196,196,196,196,196,196,196,196
DB	196,196,196,196,196,196,196,196,196,196,196,196,196,191,32,32
DB	32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
DB	32,186,0,186,32,32,32,32,32,32,32,32,32,32,32,32
DB	32,32,32,32,32,32,32,179,32,83,111,117,110,100,32,66
DB	108,97,115,116,101,114,32,40,77,79,78,79,41,32,179,32
DB	32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
DB	32,32,186,0,186,32,32,32,32,32,32,32,32,32,32,32
DB	32,32,32,32,32,32,32,32,192,196,196,196,196,196,196,196
DB	196,196,196,196,196,196,196,196,196,196,196,196,196,196,196,217
DB	32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
DB	32,32,32,186,0,186,32,80,108,97,121,105,110,103,32,70
DB	114,101,113,117,101,110,99,121,58,32,32,32,32,32,32,32
DB	32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
DB	32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
DB	32,32,32,32,186,0,186,32,32,32,32,32,32,32,32,32
DB	32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
DB	218,196,196,196,196,196,196,196,196,196,196,191,32,32,32,32
DB	32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
DB	32,32,32,32,32,186,0,186,32,32,32,32,32,32,32,32
DB	32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
DB	32,179,32,50,50,48,48,48,32,72,122,32,179,32,32,32
DB	32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
DB	32,32,32,32,32,32,186,0,186,32,32,32,32,32,32,32
DB	32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
DB	32,32,192,196,196,196,196,196,196,196,196,196,196,217,32,32
DB	32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
DB	32,32,32,32,32,32,32,186,0,186,32,68,101,102,97,117
DB	108,116,32,112,97,116,104,32,102,111,114,32,77,79,68,115
DB	58,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
DB	32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
DB	32,32,32,32,32,32,32,32,186,0,186,32,32,32,32,32
DB	218,196,196,196,196,196,196,196,196,196,196,196,196,196,196,196
DB	196,196,196,196,196,196,196,196,196,196,196,196,196,196,196,196
DB	196,196,196,196,196,196,196,196,196,196,196,196,196,196,196,196
DB	196,196,196,191,32,32,32,32,32,186,0,186,32,32,32,32
DB	32,179,32,32,32,32,32,32,32,32,32,32,32,32,32,32
DB	32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
DB	32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
DB	32,32,32,32,179,32,32,32,32,32,186,0,186,32,32,32
DB	32,32,192,196,196,196,196,196,196,196,196,196,196,196,196,196
DB	196,196,196,196,196,196,196,196,196,196,196,196,196,196,196,196
DB	196,196,196,196,196,196,196,196,196,196,196,196,196,196,196,196
DB	196,196,196,196,196,217,32,32,32,32,32,186,0,186,32,68
DB	101,102,97,117,108,116,32,112,97,116,104,32,102,111,114,32
DB	83,84,77,115,58,32,32,32,32,32,32,32,32,32,32,32
DB	32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
DB	32,32,32,32,32,32,32,32,32,32,32,32,186,0,186,32
DB	32,32,32,32,218,196,196,196,196,196,196,196,196,196,196,196
DB	196,196,196,196,196,196,196,196,196,196,196,196,196,196,196,196
DB	196,196,196,196,196,196,196,196,196,196,196,196,196,196,196,196
DB	196,196,196,196,196,196,196,191,32,32,32,32,32,186,0,186
DB	32,32,32,32,32,179,32,32,32,32,32,32,32,32,32,32
DB	32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
DB	32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
DB	32,32,32,32,32,32,32,32,179,32,32,32,32,32,186,0
DB	186,32,32,32,32,32,192,196,196,196,196,196,196,196,196,196
DB	196,196,196,196,196,196,196,196,196,196,196,196,196,196,196,196
DB	196,196,196,196,196,196,196,196,196,196,196,196,196,196,196,196
DB	196,196,196,196,196,196,196,196,196,217,32,32,32,32,32,186
DB	0,200,205,205,205,205,205,205,205,205,205,205,205,205,205,205
DB	205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205
DB	205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205
DB	205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205
DB	188,0,83,111,117,110,100,32,66,108,97,115,116,101,114,32
DB	40,77,79,78,79,41,0,32,68,65,67,32,105,110,32,76
DB	80,84,49,32,40,77,79,78,79,41,32,0,32,68,65,67
DB	32,105,110,32,76,80,84,50,32,40,77,79,78,79,41,32
DB	0,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
DB	32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
DB	32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
DB	32,0,37,115,0,32,32,32,32,32,32,32,32,32,32,32
DB	32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
DB	32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32
DB	32,32,32,32,32,0,37,115,0,119,0,69,114,114,111,114
DB	44,32,99,97,110,110,111,116,32,99,114,101,97,116,101,32
DB	99,111,110,102,105,103,117,114,97,116,105,111,110,32,102,105
DB	108,101,33,0,68,101,118,105,99,101,32,32,32,32,61,32
DB	83,111,117,110,100,32,66,108,97,115,116,101,114,10,0,68
DB	101,118,105,99,101,32,32,32,32,61,32,68,65,67,32,105
DB	110,32,76,80,84,49,10,0,68,101,118,105,99,101,32,32
DB	32,32,61,32,68,65,67,32,105,110,32,76,80,84,50,10
DB	0,73,82,81,32,32,32,32,32,32,32,61,32,37,100,10
DB	0,70,114,101,113,117,101,110,99,121,32,61,32,37,100,32
DB	72,122,10,0,77,111,100,45,112,97,116,104,32,32,61,32
DB	37,115,10,0,83,116,109,45,112,97,116,104,32,32,61,32
DB	37,115,10,0,83,111,117,110,100,32,66,108,97,115,116,101
DB	114,32,40,77,79,78,79,41,0,32,68,65,67,32,105,110
DB	32,76,80,84,49,32,40,77,79,78,79,41,32,0,32,68
DB	65,67,32,105,110,32,76,80,84,50,32,40,77,79,78,79
DB	41,32,0,83,66,32,73,82,81,32,61,32,55,32,32,32
DB	32,32,32,32,32,32,32,0,83,111,117,110,100,32,66,108
DB	97,115,116,101,114,32,40,77,79,78,79,41,0,32,68,65
DB	67,32,105,110,32,76,80,84,49,32,40,77,79,78,79,41
DB	32,0,32,68,65,67,32,105,110,32,76,80,84,50,32,40
DB	77,79,78,79,41,32,0,37,100,32,72,122,0,32,32,32
DB	32,32,0,37,100,0,32,32,32,32,32,0,37,100,0,32
DB	32,32,32,32,32,32,32,0,37,100,32,72,122,0,0,0
DB	0,46,9,91,4,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,255,255,0,0,0,0,0,0,13,10,83
DB	116,97,99,107,32,79,118,101,114,102,108,111,119,13,10,36
DB	13,10,78,111,116,32,101,110,111,117,103,104,32,109,101,109
DB	111,114,121,13,10,36,13,10,66,97,100,32,115,116,97,99
DB	107,32,115,105,122,101,32,112,97,114,97,109,101,116,101,114
DB	13,10,36,13,10,68,79,83,32,49,46,120,120,32,110,111
DB	116,32,115,117,112,112,111,114,116,101,100,13,10,36,13,10
DB	79,110,108,121,32,51,50,32,97,114,103,115,32,97,108,108
DB	111,119,101,100,13,10,36,13,10,78,85,76,76,32,102,117
DB	110,99,116,105,111,110,32,112,111,105,110,116,101,114,13,10
DB	36,0,25,0,0,0,0,0,0,0,0,0,7,1,1,0
DB	0,0,0,0,0,176,0,0,201,187,200,188,186,205,218,191
DB	192,217,179,196,219,219,219,219,219,219,213,184,212,190,205,196
DB	214,183,211,189,186,196,0,40,110,117,108,108,41,0,48,88
DB	0,48,120,0,45,0,43,0,32,0,35,0,159,1,182,1
DB	188,1,194,1,115,0,37,0,99,0,100,0,105,0,98,0
DB	111,0,117,0,112,0,88,0,120,0,102,0,101,0,69,0
DB	103,0,71,0,110,0,240,2,73,3,79,3,111,3,111,3
DB	200,3,205,3,210,3,241,3,2,4,6,4,99,5,174,6
DB	174,6,214,7,214,7,64,8,45,0,43,0,32,0,0,0
DB	1,0,2,11,91,4,0,0,255,255,0,0,64,111,172,100
DB	40,6,200,10,154,151,140,207,8,186,91,37,60,167,244,68
DB	253,15,165,50,50,167,168,213,35,246,73,57,188,137,216,151
DB	178,210,156,60,58,140,48,226,142,121,69,62,45,67,28,235
DB	226,54,26,63,123,20,174,71,225,122,132,63,154,153,153,153
DB	153,153,185,63,0,0,0,0,0,0,240,63,63,191,115,127
DB	221,79,21,117,51,29,48,249,72,119,130,90,246,249,63,233
DB	3,79,56,77,23,110,5,181,181,184,147,70,0,128,224,55
DB	121,195,65,67,0,0,0,0,132,215,151,65,0,0,0,0
DB	0,136,195,64,0,0,0,0,0,0,89,64,0,0,0,0
DB	0,0,36,64,0,0,0,0,0,0,0,0,0,0,1,1
DB	0,0,1,0,0,0,0,0,0,0,0,0,0,0,2,1
DB	1,0,1,0,0,0,0,0,0,0,0,0,0,0,6,1
DB	2,0,1,0,0,0,0,0,0,0,0,0,0,0,128,1
DB	3,0,1,0,0,0,0,0,0,0,0,0,0,0,2,1
DB	4,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,240,127,0,0,0,0
DB	0,0,16,0,0,0,128,127,0,0,128,0,191,15,0,2
DB	2,2,2,2,2,2,2,2,3,3,3,3,3,2,2,2
DB	2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,5
DB	64,64,64,64,64,64,64,64,64,64,64,64,64,64,64,128
DB	128,128,128,128,128,128,128,128,128,64,64,64,64,64,64,64
DB	24,24,24,24,24,24,16,16,16,16,16,16,16,16,16,16
DB	16,16,16,16,16,16,16,16,16,16,64,64,64,64,64,64
DB	40,40,40,40,40,40,32,32,32,32,32,32,32,32,32,32
DB	32,32,32,32,32,32,32,32,32,32,64,64,64,64,2,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

OvlSize DB 0

ModuleSeg	EndS

	End	Begin
