'$INCLUDE:'fmengine.bi'
'$INCLUDE:'include/adlib.bi'

IF FMinit < 0 THEN PRINT "FM sound not available.": END

' Written 2000-12-31 by Bisqwit (http://iki.fi/bisqwit/)
' Copyright (C) 1992,2004
' Home page: http://bisqwit.iki.fi/source/fmengineqb.html

'FMload "m:\warp\last_dep.s3m"
'FMload "m:\fmdrv\chmmr.s3m"
'FMload "m:\warp\time.s3m"

PRINT MPUDetect

'MPUwrite &HC0
'MPUwrite 0
'MPUwrite 1
'MPUwrite &H90
'MPUwrite 61
'MPUwrite 127

DO
    ' Put your program here.

    PRINT ".";
    DIM Ti&: Ti& = TIMER
    WHILE Ti& = CLNG(TIMER)
        DIM y$: y$ = INKEY$
        IF y$ = "0" THEN FMplayeffect 0
        IF y$ = "1" THEN FMplayeffect 1
        IF y$ = "a" THEN FMload "last_dep.s3m"
        IF y$ = "b" THEN FMload "jhmmid10.s3m"
        IF y$ = "c" THEN FMload "time.s3m"
        IF y$ = "d" THEN FMload "adlib.s3m"
        IF y$ = "e" THEN FMload "adlibsp.s3m"
        IF y$ = "f" THEN FMload "mysidia.s3m"
        IF y$ = "g" THEN TIMER(fmdata.timerHandle) OFF
        IF y$ = "h" THEN TIMER(fmdata.timerHandle) ON
        IF y$ = "i" THEN FMload "jhmmid68.s3m"
        IF y$ = "j" THEN FMload "jhmmid72.s3m"
        IF y$ = "v" THEN CALL BeSilent

        IF y$ = CHR$(27) THEN EXIT DO
    WEND
LOOP

FMend
END


SUB FMend
    TIMER(fmdata.timerHandle) OFF
    TIMER(fmdata.timerHandle) FREE
    BeSilent
    Adlib_Finalize
END SUB

FUNCTION FMinit
    CONST SONG_BPM_DEFAULT = 125 ' Default song BPM

    IF NOT Adlib_Initialize THEN FMinit = -1: EXIT FUNCTION

    Adlib_WriteRegister 4, 96: Adlib_WriteRegister 4, 128
    Adlib_WriteRegister 2, 255: Adlib_WriteRegister 4, 33
    Adlib_WriteRegister 4, 96: Adlib_WriteRegister 4, 128

    DIM a#: a# = 1712 'Base value for period table
    ' 1 / 2^(1/12) = 0.9438743126816934967
    DIM x: FOR x = 0 TO 11: fmperiod(x) = a#: a# = a# * .9438743126816934967#: NEXT
    CALL BeSilent
    ' Initialize the timered routine
    fmdata.timerHandle = _FREETIMER
    SetTimerBPM SONG_BPM_DEFAULT
    TIMER(fmdata.timerHandle) ON

    ' Let us load effects.
    FMload efffile

    CALL BeSilent
    fmdata.effind = 0
    FOR x = 0 TO 3: fmeff(x).effA = fmdata.effectA: NEXT
    FOR x = 0 TO 31: adlchan(x).effres = -1: NEXT
    FOR x = 1 TO fmdata.insnum
        DIM y: FOR y = 0 TO 11
            adldata(70 + x, y) = adldata(x, y)
        NEXT
        insdata(70 + x) = insdata(x)
    NEXT
    fmdata.effpptr = &H61 + fmdata.ordnum + fmdata.insnum * 2
    x = MPUDetect
    FMinit = 1
END FUNCTION

SUB FMload (fs$)
    IF NOT _FILEEXISTS(fs$) THEN
        PRINT "FILE NOT FOUND ERROR: "; fs$
        EXIT SUB
    END IF

    fmfilename$ = ""
    TIMER(fmdata.timerHandle) STOP

    CALL BeSilent

    DIM fp: fp = FREEFILE
    OPEN fs$ FOR BINARY AS fp
    IF LOF(fp) = 0 THEN
        CLOSE fp
        EXIT SUB
    END IF

    SEEK fp, &H21
    fmdata.ordnum = CVI(INPUT$(2, fp))
    fmdata.insnum = CVI(INPUT$(2, fp))
    fmdata.patnum = CVI(INPUT$(2, fp))

    SEEK fp, &H32
    fmdata.effectA = ASC(INPUT$(1, fp))
    fmdata.effectT = ASC(INPUT$(1, fp))
    SetTimerBPM fmdata.effectT

    SEEK fp, &H61
    DIM x: FOR x = 1 TO fmdata.ordnum
        order(x - 1) = ASC(INPUT$(1, 1))
    NEXT
    FOR x = 1 TO fmdata.insnum
        SEEK fp, &H61 + fmdata.ordnum + (x - 1) * 2
        DIM insptr: insptr = CVI(INPUT$(2, fp))
        SEEK fp, insptr * 16& + 1 + &H10
        DIM y: FOR y = 0 TO 11
            adldata(x, y) = ASC(INPUT$(1, fp))
        NEXT
        SEEK fp, insptr * 16& + 1 + &H1C
        insdata(x).vol = ASC(INPUT$(1, fp))
        SEEK fp, insptr * 16& + 1 + &H20
        insdata(x).c4spd = CVI(INPUT$(2, fp))
        SEEK fp, insptr * 16& + 1 + &H30
        DIM s$: s$ = INPUT$(28, fp)

        DIM g
        IF LEFT$(s$, 2) = "GM" THEN
            g = 0
        ELSEIF LEFT$(s$, 2) = "GP" THEN
            g = 1
        ELSE
            g = -1
        END IF
        IF g < 0 THEN
            insdata(x).gm = 0
            insdata(x).gmadd = 0
            insdata(x).gmvol = 0
        ELSE
            DIM n: n = VAL(MID$(s$, 3))
            DIM n1
            IF LEFT$(s$, 2) = "GP" THEN
                n1 = n - 35 + 128
            ELSE
                n1 = n - 1
            END IF

            insdata(x).gmadd = 0
            insdata(x).gmvol = 64
            insdata(x).gm = n1
            DIM c
            IF n < 10 THEN c = 1 ELSE IF n < 100 THEN c = 2 ELSE c = 3
            DIM p: p = 3 + c
            DO WHILE p < LEN(s$)
                DIM c$: c$ = MID$(s$, p, 1)
                IF c$ = "+" OR c$ = "-" THEN
                    p = p + 1
                    n = VAL(MID$(s$, p))
                    IF n < 10 THEN c = 1 ELSE IF n < 100 THEN c = 2 ELSE c = 3
                    IF c$ = "-" THEN n = -n
                    insdata(x).gmadd = n
                    p = p + c
                ELSEIF c$ = "" THEN
                    p = p + 1
                    n = VAL(MID$(s$, p))
                    IF n < 10 THEN c = 1 ELSE IF n < 100 THEN c = 2 ELSE c = 3
                    insdata(x).gmbank = n
                    p = p + c
                ELSEIF c$ = "/" THEN
                    p = p + 1
                    n = VAL(MID$(s$, p))
                    IF n < 10 THEN c = 1 ELSE IF n < 100 THEN c = 2 ELSE c = 3
                    insdata(x).gmvol = n
                    p = p + c
                ELSEIF c$ = "&" THEN
                    p = p + 1
                    n = VAL(MID$(s$, p))
                    IF n < 10 THEN c = 1 ELSE IF n < 100 THEN c = 2 ELSE c = 3
                    p = p + c
                ELSE
                    EXIT DO
                END IF
            LOOP
            ' GM123+4/6: blah blah
        END IF
    NEXT
    FOR x = 0 TO 31
        adlchan(x).CurInst = 0
        adlchan(x).CurVol = 0
        adlchan(x).n = 255
        adlchan(x).s = 0
        adlchan(x).v = 255
        adlchan(x).c = 0
        adlchan(x).i = 0
        MIDIchan(x) = -1
    NEXT

    fmdata.CurRow = 0
    fmdata.CurOrd = 0
    fmdata.SkipRow = 0
    fmdata.NeedPat = TRUE
    fmdata.LoopBegin = 0
    fmdata.LoopCount = 0
    fmdata.TickPos = 0
    fmdata.EdPat = -1

    CLOSE fp
    fmfilename$ = fs$

    IF order(fmdata.CurOrd) < 255 THEN
        TIMER(fmdata.timerHandle) ON
    END IF
END SUB

SUB FMnoteoff (chan, ope)
    Adlib_WriteRegister &HB0 + chan, 0
    Adlib_WriteRegister &H40 + ope, 255
    Adlib_WriteRegister &H43 + ope, 255

    ' Issue MIDI noteoff command
    MPUwrite &H80 + MIDIchan(chan)
    MPUwrite MIDInote(chan)
    MPUwrite 127

    MIDIchan(chan) = -1
END SUB

SUB FMplayeffect (ind)
    TIMER(fmdata.timerHandle) STOP

    DIM fp: fp = FREEFILE
    OPEN efffile FOR BINARY AS fp

    SEEK fp, fmdata.effpptr + ind * 2
    DIM patptr: patptr = CVI(INPUT$(2, fp))
    SEEK fp, patptr * 16& + 1
    DIM patlen: patlen = CVI(INPUT$(2, fp))
    fmeffect$(fmdata.effind) = INPUT$(patlen, fp)
    fmeff(fmdata.effind).effptr = 1
    fmeff(fmdata.effind).effTickPos = 0
    fmdata.effind = (fmdata.effind + 1) AND 3

    CLOSE fp

    TIMER(fmdata.timerHandle) ON
END SUB

SUB FMplayrowfrom (pat$, ofs, effnum)
    IF LEN(pat$) = 0 THEN EXIT SUB
    DIM termination: termination = FALSE

    DIM c: FOR c = 0 TO 31
        IF adlchan(c).effres = effnum THEN
            adlchan(c).n = 255
            adlchan(c).s = 0
            adlchan(c).v = 255
            adlchan(c).c = 0
            adlchan(c).i = 0
        END IF
    NEXT

    DO
        c = ASC(MID$(pat$, ofs, 1))
        DIM n: n = ofs + 1

        IF c > 0 THEN
            DIM chan: chan = c AND 31

            IF effnum >= 0 THEN
                adlchan(chan).effres = effnum
                'PRINT "effect"; effnum; "active at channel"; chan
            END IF

            IF (c AND 32) THEN
                DIM note: note = ASC(MID$(pat$, n, 1)): n = n + 1
                DIM ins: ins = ASC(MID$(pat$, n, 1)): n = n + 1
                IF effnum >= 0 OR adlchan(chan).effres < 0 THEN
                    IF effnum >= 0 THEN ins = ins + 70
                    adlchan(chan).n = note
                    adlchan(chan).s = ins
                END IF
            END IF
            IF (c AND 64) THEN
                DIM vol: vol = ASC(MID$(pat$, n, 1)): n = n + 1
                IF effnum >= 0 OR adlchan(chan).effres < 0 THEN
                    adlchan(chan).v = vol
                END IF
            END IF
            IF (c AND 128) THEN
                DIM cmd: cmd = ASC(MID$(pat$, n, 1)): n = n + 1
                DIM info: info = ASC(MID$(pat$, n, 1)): n = n + 1

                IF effnum >= 0 AND cmd = 3 THEN 'C'
                    termination = TRUE
                    adlchan(chan).effres = -1
                    'PRINT "effect terminated at channel"; chan
                ELSE
                    IF effnum >= 0 OR adlchan(chan).effres < 0 THEN
                        adlchan(chan).c = cmd
                        adlchan(chan).i = info
                    END IF

                    IF cmd = 1 THEN fmdata.effectA = adlchan(chan).i 'A'
                    IF info = 20 THEN
                        fmdata.effectT = adlchan(chan).i 'T'
                        SetTimerBPM fmdata.effectT
                    END IF

                    'IF effnum >= 0 THEN
                    '    PRINT "Found Effect Cmd at channel"; chan; ": ";
                    '    PRINT CHR$(adlchan(chan).c OR 64); HEX$(adlchan(chan).i)
                    'END IF
                END IF
            END IF
        END IF
        ofs = n
    LOOP UNTIL c = 0

    IF termination THEN
        ' Terminate this effect!
        pat$ = ""
        ofs = 1
        EXIT SUB
    END IF
END SUB

' Calculates and sets the timer speed
SUB SetTimerBPM (nBPM AS _UNSIGNED _BYTE)
    ' S / (2 * B / 5) (where S is second and B is BPM)
    ON TIMER(fmdata.timerHandle, 5 / _SHL(nBPM, 1)) FMtimer
END SUB

SUB FMtimer
    ' Exit quickly if adlib has not been recognized
    IF fmperiod(0) = 0 OR LEN(fmfilename$) = 0 THEN EXIT SUB

    ' S3M effectT determines how many frames to handle in 24 seconds.
    ' S3M effectA determines, how many frames there are per a row
    ' This function will always process one frame.

    ' The accuracy of PLAY... might not be good. Let us test.

    ' With PLAY, the command "T" determines the number of quarter notes in a minute.
    ' L4 = quarter note. L1 = whole note (four quarter notes).
    ' L64 is a 16th of a quarter note.
    '
    ' According to T, the length of a quarter note is 60/T seconds.
    ' L determines the length of the note such...
    ' that 240/T/L = length of a note in seconds.

    ' frame length      = effectT * 0.4 seconds.
    ' half frame length = effectT * 0.2 seconds.

    ' 240/255/effectT/0.2 = L
    ' 240/255/0.2 = 4.7058823529411764703

    DIM looper
    FOR looper = 0 TO 1
        IF fmdata.TickPos = 0 THEN
            IF fmdata.patdelay = 0 THEN
                'PRINT "Ticking CurOrd="; fmdata.CurOrd; ", CurRow="; fmdata.CurRow

                ' We do not keep all the patterns in memory,
                ' due to the limited memory space of QuickBasic.
                ' Instead, we load them from disk when we need them.

                IF fmdata.NeedPat THEN
                    DIM c: c = 0
                    DO
                        DIM CurPat: CurPat = order(fmdata.CurOrd)
                        IF CurPat < 254 THEN EXIT DO
                        fmdata.CurOrd = (fmdata.CurOrd + 1) MOD fmdata.ordnum
                        c = c + 1
                    LOOP WHILE c < fmdata.ordnum

                    IF CurPat <> fmdata.EdPat THEN
                        fmdata.EdPat = CurPat

                        DIM CurOrd: LOCATE 1, 10: COLOR 1: PRINT "Loading pattern"; CurPat; "(order"; CurOrd; ")"

                        DIM fp: fp = FREEFILE
                        OPEN fmfilename$ FOR BINARY AS fp

                        SEEK fp, &H61 + fmdata.ordnum + fmdata.insnum * 2 + CurPat * 2
                        DIM patptr: patptr = CVI(INPUT$(2, fp))
                        SEEK fp, patptr * 16& + 1
                        DIM patlen: patlen = CVI(INPUT$(2, fp))
                        fmpattern$ = INPUT$(patlen, fp)

                        LOCATE 2, 10: COLOR 1: PRINT "Fetched:"; LEN(fmpattern$); "bytes"

                        CLOSE fp
                    END IF

                    fmdata.CurRow = 0
                    fmdata.NeedPat = FALSE
                    fmdata.patpos = 1
                END IF

                ' Now fmpattern$ contains the remainder of the pattern.
                ' fmdata.SkipRow contains the number of rows to be skipped (may originate from Cxx)

                WHILE fmdata.SkipRow > 0
                    DO
                        DIM n: n = 1
                        c = ASC(MID$(fmpattern$, fmdata.patpos, 1))
                        IF (c AND 32) THEN n = n + 2
                        IF (c AND 64) THEN n = n + 1
                        IF (c AND 128) THEN n = n + 2
                        fmdata.patpos = fmdata.patpos + n
                    LOOP UNTIL c = 0
                    fmdata.SkipRow = fmdata.SkipRow - 1
                    fmdata.CurRow = fmdata.CurRow + 1
                WEND

                ' Now fmpattern$ points to the beginning of the current row.
                FMplayrowfrom fmpattern$, fmdata.patpos, -1
            END IF
            fmdata.TickPos = fmdata.effectA
        END IF
        DIM x: FOR x = 0 TO 3
            IF fmeff(x).effTickPos = 0 THEN
                ' Time to fetch a new row for the effect...
                ' TODO: Somehow clean the adlchan table...

                c = fmdata.effectA
                fmdata.effectA = fmeff(x).effA
                FMplayrowfrom fmeffect$(x), fmeff(x).effptr, x
                ' Muuttaa fmdata.effectA:ta
                fmeff(x).effA = fmdata.effectA
                fmdata.effectA = c
                fmeff(x).effTickPos = fmeff(x).effA
                fmeff(x).effTickPos = fmeff(x).effA
            END IF
        NEXT

        DIM loophere: loophere = FALSE
        FOR x = -1 TO 3
            DIM CurTick
            IF x >= 0 THEN
                CurTick = fmeff(x).effA - fmeff(x).effTickPos
            ELSE
                CurTick = fmdata.effectA - fmdata.TickPos '0..(A-1)
            END IF

            FOR c = 0 TO 8
                IF adlchan(c).effres = x THEN
                    ' Mark the vibrato obsolete
                    IF adlchan(c).VibEff = 2 THEN adlchan(c).VibEff = 1

                    DIM chan: chan = c 'FIXME: Take from the headers
                    DIM ope: ope = chan
                    IF chan > 2 THEN ope = ope + 5
                    IF chan > 5 THEN ope = ope + 5

                    DIM notedelay: notedelay = 0
                    DIM notecut: notecut = -1

                    DIM cmd: cmd = adlchan(c).c
                    DIM info: info = adlchan(c).i

                    IF cmd = 19 THEN 'S'
                        DIM sclass: sclass = info \ 16
                        DIM sinfo: sinfo = info AND 15

                        'Supported S commands:
                        '   SB0..SBF (loop)
                        '   SCx      (notecut)
                        '   SDx      (notedelay)
                        '   SEx      (patterndelay (handled later))
                        'A=10, B=11, jne.  (hex)

                        IF sclass = 11 THEN 'B'
                            IF CurTick = 0 THEN
                                IF sinfo = 0 THEN
                                    fmdata.LoopBegin = fmdata.CurRow
                                ELSE
                                    IF fmdata.LoopCount = 0 THEN
                                        fmdata.LoopCount = sinfo + 1
                                    END IF
                                END IF
                            END IF
                            IF sinfo > 0 THEN loophere = TRUE
                        END IF
                        IF sclass = 12 THEN notecut = sinfo 'C'
                        IF sclass = 13 THEN notedelay = sinfo 'D'
                        IF sclass = 14 THEN 'E'
                            'PRINT fmdata.patdelay;
                            IF CurTick = 0 THEN
                                IF fmdata.patdelay = 0 THEN
                                    fmdata.patdelay = sinfo
                                    fmdata.patdelaymax = sinfo
                                ELSE
                                    fmdata.patdelay = fmdata.patdelay - 1
                                END IF
                            END IF
                        END IF
                    END IF
                    IF notedelay = CurTick AND (fmdata.patdelay = fmdata.patdelaymax OR CurTick > 0) THEN
                        DIM vol: vol = adlchan(c).v
                        DIM note: note = adlchan(c).n
                        DIM ins: ins = adlchan(c).s
                        IF ins = 0 THEN
                            ins = adlchan(c).CurInst
                        ELSE
                            adlchan(c).CurInst = ins
                        END IF
                        IF ins > 0 THEN
                            IF vol = 255 THEN
                                vol = insdata(ins).vol
                            ELSE
                                FMtouch chan, ope, vol, ins
                                adlchan(c).CurVol = vol
                            END IF
                            IF note < 255 THEN 'Something indeed mentioned
                                FMnoteoff chan, ope
                                IF note <> 254 THEN 'adlib notecut
                                    DIM Oct: Oct = note \ 16
                                    note = note AND 15

                                    adlchan(c).Period = note2period(note, Oct, ins)

                                    FMupdate chan, ope, adlchan(c).Period, ins, vol
                                    adlchan(c).CurVol = vol
                                END IF
                            END IF
                        END IF
                    END IF
                    IF adlchan(c).CurInst > 0 THEN ' No command on channels without instrus playing
                        IF cmd = 4 OR cmd = 11 THEN 'D', 'K'
                            vol = adlchan(c).CurVol
                            IF info = 0 THEN info = adlchan(c).DefD ELSE adlchan(c).DefD = info
                            IF info = 255 THEN 'FF
                                vol = 64
                            ELSEIF info >= 240 THEN 'F0..FE
                                IF CurTick = 0 THEN vol = vol - (info AND 15)
                            ELSEIF info < 16 THEN '01..0F
                                vol = vol - (info AND 15)
                            ELSEIF (info AND 15) = 15 THEN
                                IF CurTick = 0 THEN vol = vol + (info \ 16)
                            ELSEIF info <= 240 THEN '10..F0
                                vol = vol + (info \ 16)
                            END IF
                            IF vol < 0 THEN vol = 0 ELSE IF vol > 64 THEN vol = 64
                            adlchan(c).CurVol = vol
                            FMtouch chan, ope, vol, adlchan(c).CurInst
                        END IF
                        IF cmd = 5 OR cmd = 6 THEN 'E' or 'F'
                            IF info = 0 THEN info = adlchan(c).DefE ELSE adlchan(c).DefE = info
                            IF cmd = 6 THEN info = -info
                            adlchan(c).Period = adlchan(c).Period + info * 4
                            FMupdate chan, ope, adlchan(c).Period, adlchan(c).CurInst, adlchan(c).CurVol
                        END IF
                        IF cmd = 8 OR cmd = 11 THEN 'H', 'K'
                            IF cmd = 11 THEN info = 0
                            IF info = 0 THEN info = adlchan(c).DefH ELSE adlchan(c).DefH = info
                            IF adlchan(c).VibEff = 0 THEN
                                adlchan(c).VibPos = 0
                            END IF
                            DIM vspeed: vspeed = info \ 16
                            DIM vdepth: vdepth = info AND 15
                            DIM value: value = VibVal(adlchan(c).VibPos, 0) * vdepth \ 32
                            FMupdate chan, ope, adlchan(c).Period + value, adlchan(c).CurInst, adlchan(c).CurVol
                            adlchan(c).VibPos = adlchan(c).VibPos + vspeed
                            adlchan(c).VibEff = 2
                        END IF
                        IF notecut = CurTick AND (fmdata.patdelay = fmdata.patdelaymax OR CurTick > 0) THEN
                            FMnoteoff chan, ope
                        END IF
                    END IF
                    IF adlchan(c).VibEff = 1 THEN 'Vibrato still obsolete?
                        adlchan(c).VibEff = 0 'No more vibrato
                        FMupdate chan, ope, adlchan(c).Period, adlchan(c).CurInst, adlchan(c).CurVol
                    END IF
                END IF
            NEXT
        NEXT

        fmdata.TickPos = fmdata.TickPos - 1
        FOR x = 0 TO 3
            fmeff(x).effTickPos = fmeff(x).effTickPos - 1
        NEXT

        ' If this row is finished, find out where to go next.
        IF fmdata.TickPos = 0 AND fmdata.patdelay = 0 THEN
            fmdata.patdelaymax = 0
            DIM brkord: brkord = -1
            DIM brkrow: brkrow = -1

            fmdata.CurRow = fmdata.CurRow + 1
            IF fmdata.CurRow = 64 THEN
                brkrow = 0
            END IF

            DIM doloop: doloop = FALSE
            IF fmdata.LoopCount > 0 AND loophere = TRUE THEN
                fmdata.LoopCount = fmdata.LoopCount - 1
                IF fmdata.LoopCount = 0 THEN
                    ' SB0 pending.
                    fmdata.LoopBegin = fmdata.CurRow
                ELSE
                    brkord = fmdata.CurOrd
                    brkrow = fmdata.LoopBegin
                    doloop = TRUE
                END IF
            END IF

            IF doloop = FALSE THEN
                FOR c = 0 TO 8
                    cmd = adlchan(c).c '1=A, 2=B, and so on... 0=none
                    info = adlchan(c).i

                    IF cmd = 2 THEN 'B'
                        brkord = info
                        fmdata.LoopBegin = 0
                    END IF
                    IF cmd = 3 THEN 'C'
                        brkrow = (info \ 16) * 10 + (info AND 15)
                        fmdata.LoopBegin = 0
                    END IF
                NEXT
                IF brkord >= 0 AND brkrow = -1 THEN brkrow = 0
            END IF
            IF brkrow >= 0 THEN
                fmdata.CurOrd = (fmdata.CurOrd + 1) MOD fmdata.ordnum
                fmdata.NeedPat = TRUE
                IF brkord >= 0 THEN fmdata.CurOrd = brkord
                fmdata.SkipRow = brkrow
            END IF
        END IF
    NEXT
END SUB

SUB FMtouch (chan, ope, vol, ins)
    DIM v: v = vol * 63 \ 64

    DIM c: c = (adldata(ins, 2) AND &HC0)
    c = c OR (63 + (adldata(ins, 2) AND 63) * v \ 63 - v)
    Adlib_WriteRegister &H40 + ope, c

    c = (adldata(ins, 3) AND &HC0)
    c = c OR (63 + (adldata(ins, 3) AND 63) * v \ 63 - v)
    Adlib_WriteRegister &H43 + ope, c

    MPUwrite &HB0 + MIDIchan(chan)
    MPUwrite 7 'Master volume

    v = MPUvol(vol, ins)
    MPUwrite v
END SUB

SUB FMupdate (chan, ope, period, ins, vol)
    ' Patch with the instrument data

    IF ins <= 0 THEN EXIT SUB

    Adlib_WriteRegister &H20 + ope, adldata(ins, 0)
    Adlib_WriteRegister &H60 + ope, adldata(ins, 4)
    Adlib_WriteRegister &H80 + ope, adldata(ins, 6)
    Adlib_WriteRegister &HE0 + ope, adldata(ins, 8) AND 3

    Adlib_WriteRegister &H23 + ope, adldata(ins, 1)
    Adlib_WriteRegister &H63 + ope, adldata(ins, 5)
    Adlib_WriteRegister &H83 + ope, adldata(ins, 7)
    Adlib_WriteRegister &HE3 + ope, adldata(ins, 9) AND 3

    Adlib_WriteRegister &HC0 + chan, adldata(ins, 10) OR &H30

    IF insdata(ins).gm < 128 THEN
        DIM n
        IF period = 0 THEN
            n = 0
        ELSE
            ' Converting a period into MIDI note number:

            ' Hz = fmperiod(0) * 5500& / Period
            ' 2 ^ (notenumber / 12) = Hz
            ' Solve notenumber, get:
            ' notenumber = 12 * log(Hz) / log(2)
            'n = 12 * LOG(fmperiod(0) * 5500& / period) / LOG(2) + insdata(ins).gmadd - 89
            ' Simplify:
            n = insdata(ins).gmadd + CINT(60.10259 + 17.31234 * LOG(fmperiod(0) / period))
            IF n < 1 THEN n = 1
            IF n > 127 THEN n = 127
        END IF

        IF MIDIchan(chan) = -1 THEN
            MIDIchan(chan) = chan
            MIDInote(chan) = n

            MPUwrite &HC0 + MIDIchan(chan) ' Patch
            MPUwrite insdata(ins).gm

            MPUwrite &H90 + MIDIchan(chan)
            MPUwrite MIDInote(chan)
            MPUwrite 127
        END IF
    ELSE
        IF MIDIchan(chan) = -1 THEN
            MIDIchan(chan) = 9 'Percussion
            MIDInote(chan) = insdata(ins).gm + 35 - 128

            MPUwrite &H90 + MIDIchan(chan)
            MPUwrite MIDInote(chan)
            MPUwrite 127 'MPUvol(vol, ins)
        END IF
    END IF

    FMtouch chan, ope, vol, ins

    DIM Oct: Oct = 0
    DIM Herz&
    IF period = 0 THEN
        ' Exception, circumvention of a bug or something
        Herz& = 0
    ELSE
        '5500 = 22000 / 4
        Herz& = fmperiod(0) * 5500& / period
    END IF

    WHILE Herz& >= 512
        Oct = Oct + 1
        Herz& = Herz& \ 2
    WEND

    Adlib_WriteRegister &HA0 + chan, Herz& AND 255
    Adlib_WriteRegister &HB0 + chan, 32 OR ((Herz& \ 256) AND 3) OR ((Oct AND 7) * 4)
END SUB

FUNCTION MPUDetect
    EXIT FUNCTION
    MPUDetect = 0

    OUT MPUBASE + 1, 255
    DIM b: b = 10000
    WHILE (INP(MPUBASE + 1) AND &H40) <> 0
        b = b - 1
        IF b = 0 THEN EXIT FUNCTION
    WEND
    OUT MPUBASE + 1, 255
    b = 10000
    MPULoop:
    WHILE (INP(MPUBASE + 1) AND &H80) <> 0
        b = b - 1
        IF b = 0 THEN EXIT FUNCTION
    WEND

    IF INP(MPUBASE) <> 254 THEN GOTO MPULoop

    MPUDetect = 0

    WHILE (INP(MPUBASE + 1) AND &H40) <> 0: WEND
    OUT MPUBASE + 1, 63
    b = 10000
    MPULoop2:
    WHILE (INP(MPUBASE + 1) AND &H80) <> 0
        b = b - 1
        IF b = 0 THEN EXIT FUNCTION
    WEND

    IF INP(MPUBASE) <> 254 THEN GOTO MPULoop2

    MPUDetect = -1
END FUNCTION

FUNCTION MPUvol (vol, ins)
    DIM v: v = vol * insdata(ins).gmvol \ 64
    IF v > 0 THEN v = EXP(v / (64 / 4)) * 127 / EXP(4)
    IF v < 0 THEN v = 0 ELSE IF v > 127 THEN v = 127
    MPUvol = v
END FUNCTION

SUB MPUwrite (b)
    EXIT SUB 'disabled for now

    WHILE (INP(MPUBASE + 1) AND &H40) <> 0
        GOSUB MPUwritedcheck
        DIM d&
        IF d& = 0 THEN GOTO MPUwriteesub
    WEND
    OUT MPUBASE, b ' And a little delay then? Nah, QBasic is slow enough.
    MPUwriteesub:
    EXIT SUB
    MPUwritedcheck:
    d& = d& + 1
    'b# = b# * .0001
    IF d& > 800000 THEN
        d& = MPUDetect
        'COLOR 11
        'PRINT "It appears that your MPU-401 crashed... ";
        IF d& = 1 THEN
            dsuccess: 'PRINT "But it woke up again";
            'IF d& > 1 THEN PRINT " (after few tries...)";
            'PRINT
        ELSE
            d& = MPUDetect
            IF d& = 0 THEN d& = MPUDetect
            IF d& = 1 THEN d& = 2: GOTO dsuccess
            'PRINT "Argh"
        END IF
        'COLOR 7
    END IF
    RETURN 'This was a GOSUB label
END SUB

FUNCTION note2period (note, Oct, ins)
    DIM c4spd: c4spd = insdata(ins).c4spd

    DIM tmp&: tmp& = 8363& * 16& * fmperiod(note)

    IF c4spd = 0 THEN
        ' Exception, circumvention of a bug or something
        note2period = 0
    ELSE
        note2period = (tmp& \ (2 ^ Oct)) / c4spd
    END IF
END FUNCTION

SUB BeSilent
    DIM j: FOR j = 0 TO 31
        FMnoteoff j, j
    NEXT
    FOR j = 0 TO 244: Adlib_WriteRegister j, 0: NEXT
END SUB

FUNCTION VibVal (ind, mode)
    '
    ' The variable pointed by "ind" is MODIFIED in this function
    ' mode... 0..3 = type, [+4] = loop

    IF mode >= 4 THEN
        ind = ind AND 63
    ELSEIF ind >= 64 THEN
        ind = 0
    END IF

    SELECT CASE mode
        CASE 0:
            'VibVal = 255*SIN(ind * 3.1415926535968# / 32)
            VibVal = 255 * SIN(ind * .098174770424681038701957605727484#)
            EXIT FUNCTION
        CASE 1:
            IF ind = 0 THEN VibVal = 0 ELSE VibVal = (-256 + ind * 8)
            EXIT FUNCTION
        CASE 2:
            IF ind < 0 THEN VibVal = 0 ELSE VibVal = 255
            EXIT FUNCTION
    END SELECT
    EXIT FUNCTION
END FUNCTION

'$INCLUDE:'include/adlib.bas'
