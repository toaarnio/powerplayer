;ЦДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДД·
;є .	    ъ			.      THE			    щ	       є
;є		     .				      . 		       є
;є  ЯЯЯЯ ЯЯЫЯЫ ЯЯЯЯ   ЯЯЫЯЫ Я  Ы ЯЯЯЯ Я ЯЯЯЯ . ЯЯЯЯ Я  Ы ЯЯЯЯ ЯЯЯЯ ЯЯЯЯ ЯЯЫЯЫ  є
;є  ЫЯЯ  Ы Ы Ы ЫЯЯ    Ы Ы Ы Ы  Ы ЯЯЯЫ Ы Ы      ЯЯЯЫ ЯЯЫЯ ЯЯЯЫ . Ы  ЫЯЯ	Ы Ы Ы  є
;є  ЯЯЯЯ Я Я Я Я   .  Я Я Я ЯЯЯЯ ЯЯЯЯ Я ЯЯЯЯ   ЯЯЯЯ   Я  ЯЯЯЯ	Я  ЯЯЯЯ Я Я Я  є
;є	.			       щ	     .		   ъ	       є
;є			       FOR PROTECTED MODE			       є
;є .				   щ		    .			    ъ  є
;є         CODED BY SAINT, SARACEN & DEVASTATOR OF ELECTROMOTIVE FORCE ъ       є
;є   .		   ъ			     щ		   .		  ъ    є
;УДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДЅ
	.386P
;ДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДД
	Uses_Timer = 1			; Include timer stuff.
	Uses_Kbd   = 1			; Include keyboard stuff.
	Uses_ExcHandling = 1		; Include the exception handler.
	Uses_DataFileRead = 1

	INCLUDE stdrouts.hdr
	INCLUDE filelib.hdr
	INCLUDE debug.inc

Code32	Segment Para Public Use32
	ASSUME	CS:Code32,DS:Code32

	INCLUDE pmode.inc
        INCLUDE callspec.hdr

;ЦДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДД·
;є				    C O D E				       є
;УДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДЅ
Public	InitSound
Public	LoadMusic
Public  UnLoadMusic
Public	StartMusic
Public	StopMusic
Public	ResumeMusic
Public	GetMusicPos
Public	SetMusicPos
Public	LoadSample
Public	PlaySample
Public	SetMasterVol
Public  GetDriverInfo
Public	DeInitSound

Public  DummyFunc

Extrn   GusDriver:Near
Extrn   SBDriver:Near
Extrn   MODPlayerDriver:Near
Extrn   S3MPlayerDriver:Near
;ДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДД
; esi -> ParamBlock
InitSound       Proc    Near

	lea	edi, Function
	lea	eax, DummyFunc
        mov     ecx, NumFunctions
	rep	stosd
	mov	DriversInited, 0
        lea     ebx, Function
        mov     eax, [esi]
        call    Sd_Driver[eax*4]
        jc      isexit
;        call    S3MPlayerDriver
        call    MODPlayerDriver
;        call    SndEffectDriver
        call    Function[Sd_Reset]
	jc	isexit
        call    Function[Sd_TmrReset]
	call	Function[Snd_Reset]
isexit: ret

InitSound	EndP
;ДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДД
DeInitSound	Proc	Near

	call	Function[Snd_DeInit]
	call	Function[Mus_DeInit]
        call    Function[Sd_TmrDeInit]
	call	Function[Sd_DeInit]
	ret

DeInitSound	EndP
;ДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДД
; eax -> filename
LoadMusic	Proc	Near

        call    Function[Mus_Load]
	jc	lmexit
        call    Function[Mus_Reset]
lmexit: ret

LoadMusic	EndP
;ДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДД
UnloadMusic     Proc    Near

        call    Function[Mus_UnLoad]
        call    Function[Sd_Reset]
        call    Function[Sd_TmrReset]
        ret

UnloadMusic     EndP
;ДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДД
StartMusic	Proc	Near

	call	Function[Mus_Start]
	ret

StartMusic	EndP
;ДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДД
StopMusic	Proc	Near

	call	Function[Mus_Stop]
	ret

StopMusic	EndP
;ДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДД
ResumeMusic	Proc	Near

	call	Function[Mus_Resume]
	ret

ResumeMusic	EndP
;ДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДД
GetMusicPos	Proc	Near

	call	Function[Mus_GetPos]
	ret

GetMusicPos	EndP
;ДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДД
SetMusicPos	Proc	Near

	call	Function[Mus_SetPos]
	ret

SetMusicPos	EndP
;ДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДД
LoadSample	Proc	Near

	call	Function[Snd_LoadSample]
	ret

LoadSample	EndP
;ДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДД
PlaySample	Proc	Near

	call	Function[Snd_PlaySample]
	ret

PlaySample	EndP
;ДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДД
SetMasterVol	Proc	Near

        call    Function[Sd_SetMastVol]
	ret

SetMasterVol	EndP
;ДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДД
; In: ebx = driver type (0=soundcard device), Out: eax -> driver info block
GetDriverInfo	Proc	Near

        shl     ebx, 4
        inc     ebx
        call    Function[ebx*4]
	ret

GetDriverInfo	EndP
;ДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДД
DummyFunc	Proc	Near

	clc
	ret

DummyFunc	EndP
;ЦДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДД·
;є                                  D A T A                                    є
;УДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДЅ
DriversInited   DD      0               ; Bit mapped, which drivers inited
Function        DD      NumFunctions dup (Offset DummyFunc)

Sd_Driver       DD      DummyFunc
                DD      GUSDriver
                DD      SBDriver                ; mono
                DD      SBDriver                ; stereo
;ДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДДД
Code32		EndS

                End
