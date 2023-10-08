setlocal
cd \asm\snd
del /q \asm\lib\soundsys.lib
tasm /z /s /t /m soundsys.386
tasm /z /s /t /m *.drv
tlib soundsys.lib +soundsys.obj+dac.obj+sbc.obj+gus.obj
move soundsys.lib \asm\lib
del /q *.obj
endlocal

