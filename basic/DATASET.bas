1 REM ============================================================
2 REM SPDX-License-Identifier: GPL-3.0-or-later
3 REM Copyright (c) 2026 SnapKittyWest
4 REM Ahmad Ali Parr / Bel Esprit D'Accord Irrevocable Trust
5 REM CLONE GATE: Any clone, fork, or derivative of this node
6 REM MUST be released under GPL-3.0-or-later. No closed-source use.
7 REM ============================================================
10 REM NN/16 DATASET MODULE
20 REM INTEGER BASIC
30 REM EXPLICIT DETERMINISTIC SAMPLES
40 DIM X0(10)
50 DIM X1(10)
60 DIM X2(10)
70 DIM X3(10)
80 DIM Y(10)
90 N=0
100 REM LOAD DEMO SET
110 N=4
120 X0(1)=128:X1(1)=0:X2(1)=0:X3(1)=0:Y(1)=50
130 X0(2)=0:X1(2)=128:X2(2)=0:X3(2)=0:Y(2)=50
140 X0(3)=0:X1(3)=0:X2(3)=128:X3(3)=0:Y(3)=50
150 X0(4)=64:X1(4)=64:X2(4)=64:X3(4)=0:Y(4)=75
160 PRINT "DATASET READY N=";N
170 RETURN
200 REM PRINT DATASET
210 FOR I=1 TO N
220 PRINT X0(I);" ";X1(I);" ";X2(I);" ";X3(I);" -> ";Y(I)
230 NEXT I
240 RETURN
300 REM GET SAMPLE I INTO GLOBAL X()
310 X(1)=X0(I)
320 X(2)=X1(I)
330 X(3)=X2(I)
340 X(4)=X3(I)
350 T=Y(I)
360 RETURN
