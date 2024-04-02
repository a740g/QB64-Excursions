' Adapted from Paul Dunn's SpecBAS demo code - https://github.com/ZXDunny/SpecBAS-Demos

OPTION _EXPLICIT

CONST SCREENWIDTH& = 512&, SCREENHEIGHT& = 512&
CONST HW = SCREENWIDTH& \ 2&, HH = SCREENHEIGHT& \ 2&
CONST TAU! = _PI(2!)
CONST NUMITERATIONS& = 200&
CONST ANGULARINCREMENT! = TAU / 235!
CONST TIMEINCREMENT! = 0.001!

SCREEN _NEWIMAGE(SCREENWIDTH, SCREENHEIGHT, 32)

DIM AS SINGLE x, u, v, t

DO
    CLS

    DIM i AS LONG: FOR i = 0 TO NUMITERATIONS
        DIM j AS LONG: FOR j = 0 TO NUMITERATIONS
            u = SIN(i + v) + SIN(ANGULARINCREMENT * i + x)
            v = COS(i + v) + COS(ANGULARINCREMENT * i + x)
            x = u + t

            PSET (HW + u * HW * 0.4!, HH + v * HH * 0.4!), _RGB32(i, j, 99&)
        NEXT
    NEXT

    t = t + TIMEINCREMENT!

    _DISPLAY

    _LIMIT 60
LOOP UNTIL _KEYHIT = 27

SYSTEM
