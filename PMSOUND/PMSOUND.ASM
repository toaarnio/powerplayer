;靈컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�
;� .	    �			.      THE			    �	       �
;�		     .				      . 		       �
;�  賽賽 賽幡� 賽賽   賽幡� �  � 賽賽 � 賽賽 . 賽賽 �  � 賽賽 賽賽 賽賽 賽幡�  �
;�  幡�  � � � 幡�    � � � �  � 賽賞 � �      賽賞 賽幡 賽賞 . �  幡�	� � �  �
;�  賽賽 � � � �   .  � � � 賽賽 賽賽 � 賽賽   賽賽   �  賽賽	�  賽賽 � � �  �
;�	.			       �	     .		   �	       �
;�			       FOR PROTECTED MODE			       �
;� .				   �		    .			    �  �
;�         CODED BY SAINT, SARACEN & DEVASTATOR OF ELECTROMOTIVE FORCE �       �
;�   .		   �			     �		   .		  �    �
;聃컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�
	.386P
;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�
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

;靈컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�
;�				    C O D E				       �
;聃컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�
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
;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�
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
;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�
DeInitSound	Proc	Near

	call	Function[Snd_DeInit]
	call	Function[Mus_DeInit]
        call    Function[Sd_TmrDeInit]
	call	Function[Sd_DeInit]
	ret

DeInitSound	EndP
;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�
; eax -> filename
LoadMusic	Proc	Near

        call    Function[Mus_Load]
	jc	lmexit
        call    Function[Mus_Reset]
lmexit: ret

LoadMusic	EndP
;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�
UnloadMusic     Proc    Near

        call    Function[Mus_UnLoad]
        call    Function[Sd_Reset]
        call    Function[Sd_TmrReset]
        ret

UnloadMusic     EndP
;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�
StartMusic	Proc	Near

	call	Function[Mus_Start]
	ret

StartMusic	EndP
;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�
StopMusic	Proc	Near

	call	Function[Mus_Stop]
	ret

StopMusic	EndP
;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�
ResumeMusic	Proc	Near

	call	Function[Mus_Resume]
	ret

ResumeMusic	EndP
;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�
GetMusicPos	Proc	Near

	call	Function[Mus_GetPos]
	ret

GetMusicPos	EndP
;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�
SetMusicPos	Proc	Near

	call	Function[Mus_SetPos]
	ret

SetMusicPos	EndP
;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�
LoadSample	Proc	Near

	call	Function[Snd_LoadSample]
	ret

LoadSample	EndP
;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�
PlaySample	Proc	Near

	call	Function[Snd_PlaySample]
	ret

PlaySample	EndP
;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�
SetMasterVol	Proc	Near

        call    Function[Sd_SetMastVol]
	ret

SetMasterVol	EndP
;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�
; In: ebx = driver type (0=soundcard device), Out: eax -> driver info block
GetDriverInfo	Proc	Near

        shl     ebx, 4
        inc     ebx
        call    Function[ebx*4]
	ret

GetDriverInfo	EndP
;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�
DummyFunc	Proc	Near

	clc
	ret

DummyFunc	EndP
;靈컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�
;�                                  D A T A                                    �
;聃컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�
DriversInited   DD      0               ; Bit mapped, which drivers inited
Function        DD      NumFunctions dup (Offset DummyFunc)

Sd_Driver       DD      DummyFunc
                DD      GUSDriver
                DD      SBDriver                ; mono
                DD      SBDriver                ; stereo
;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�
Code32		EndS

                End
