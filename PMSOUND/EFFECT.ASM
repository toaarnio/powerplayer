TITLE Sound Effect Driver for EMF Protected Mode Music System by Saint

        INCLUDE callspec.hdr
        INCLUDE stdrouts.hdr
        INCLUDE debug.inc

Code32  Segment Para Public Use32
	ASSUME	CS:Code32,DS:Code32

	INCLUDE pmode.inc

;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º				    C O D E				       º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½

Public  SndEffectDriver:Near

;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
SndEffectDriver Proc    Near

        mov     SED_FunctionPtr, ebx
        mov     DPtr [ebx+Snd_Reset], Offset SED_Reset
        mov     DPtr [ebx+Snd_GetInfo], Offset SED_GetInfo
        mov     DPtr [ebx+Snd_LoadSample], Offset SED_LoadSample
        mov     DPtr [ebx+Snd_PlaySample], Offset SED_PlaySample
        mov     DPtr [ebx+Snd_DeInit], Offset DummyFunc
        or      DPtr [ebx+DrvInited], 20h
        clc
        ret

SndEffectDriver EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
SED_Reset       Proc    Near

        pushad
        mov     ebx, SED_FunctionPtr
        lea     edi, SED_ChanHandle
        mov     ecx, NumEffectChans
ChanAllocLoop:
        call    [ebx+Sd_AllocChan]
        stosd
        loop    ChanAllocLoop
        mov     NextChan, 0
        popad
        clc
        ret

SED_Reset       EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
SED_GetInfo     Proc    Near

        lea     eax, SndEffectInfo
        clc
        ret

SED_GetInfo     EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
; eax->filename
; ecx-sample length
; ebx-sample flags
SED_LoadSample  Proc    Near

        push    ebx ecx edx esi
        mov     FNamePtr, eax
        mov     LSmplLen, ecx
        and     ebx, 0FFFFFFFEh
        mov     LSmplFlags, ebx
        mov     FPos, 0
        call    Function[Sd_GetInfo]
        mov     al, [eax+SdLoadMode]
        and     al, 20h
        jnz     SED_ChunkLoad
SED_MemLoad:

; This section is still under construction.

SED_ChunkLoad:
        Alloc   esi, 180000
        lea     eax, TempSample
        mov     ecx, 180000
        lea     edx, ML_GetChunk
        call    Function[Sd_ChunkLoad]
        push    eax
        Free    esi, 180000
        pop     eax
        pop     esi edx ecx ebx
        clc
        ret

SED_LoadSample  EndP
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
SED_PlaySample  Proc    Near

        pushad
        mov     ebx, SED_FunctionPtr
        push    eax
        push    edx
        mov     eax, NextChan
        inc     eax
        cmp     eax, NumEffectChans
        jb      ChanOk
        xor     eax, eax
ChanOk: mov     eax, SED_ChanHandle[eax*4]
        mov     edx, ecx
        call    [ebx+Sd_SetVolume]
        mov     edx, ebp
        call    [ebx+Sd_SetBalance]
        pop     edx
        push    eax
        call    [ebx+Sd_GetInfo]
        mov     ecx, [eax+SdOutputFreq]
        xor     eax, edx
        shl     ecx, 16
        div     ecx
        mov     edx, eax
        pop     eax
        call    [ebx+Sd_SetAcc]
        pop     edx
        call    [ebx+Sd_SetSample]
        popad
        ret

SED_PlaySample  EndP
;ÖÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ·
;º                                  D A T A                                    º
;ÓÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ½
SED_FunctionPtr DD      0
SED_ChanHandle  DD      NumEffectChans dup (0)
NextChan        DD      0

SndEffectInfo   Label   Byte
SED_DrvID       DD      0105h
;ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ
Code32		EndS

                End

