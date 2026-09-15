{ ============================================================
  SPDX-License-Identifier: GPL-3.0-or-later
  Copyright (c) 2026 SnapKittyWest
  Ahmad Ali Parr / Bel Esprit D'Accord Irrevocable Trust
  CLONE GATE: Any clone, fork, or derivative of this node
  MUST be released under GPL-3.0-or-later. No closed-source use.
  ============================================================ }
(* NN/16 Validation & Golden Test Kernel *)

unit ValidationUnit;

interface

uses FixedPoint, DotProductUnit, VectorUnit, NetworkUnit,
     SerializationUnit, TrainingUnit;

function TestFXMUL : Boolean;
function TestSATADD : Boolean;
function TestACT : Boolean;
function TestDotProduct : Boolean;
function TestForward : Boolean;
function TestSerialization : Boolean;
function RunAllGolden : Boolean;

implementation

function TestFXMUL : Boolean;
begin
  TestFXMUL :=
    (FXMUL( 300, 200) = 234) and
    (FXMUL(-300, 200) = -234) and
    (FXMUL( 100, 100) = 39) and
    (FXMUL( 0, 999) = 0) and
    (FXMUL( 256, 256) = 256);
end;

function TestSATADD : Boolean;
begin
  TestSATADD :=
    (SATADD( 30000, 5000) = 32767) and
    (SATADD(-30000, -5000) = -32768) and
    (SATADD( 20000, 10000) = 30000) and
    (SATADD(-20000,-10000) = -30000);
end;

function TestACT : Boolean;
begin
  TestACT :=
    (ACT( 200) = 200) and
    (ACT( 300) = 255) and
    (ACT(-300) = -256) and
    (ACT( 0) = 0) and
    (ACT( 255) = 255) and
    (ACT(-256) = -256) and
    (ACT( 256) = 255) and
    (ACT(-257) = -256);
end;

function TestDotProduct : Boolean;
var
  A, B : Vector;
begin
  A[1] := 1; A[2] := 2; A[3] := 3; A[4] := 4;
  B[1] := 5; B[2] := 6; B[3] := 7; B[4] := 8;
  TestDotProduct := (DotProduct(A, B, 4) = 70);
end;

function TestForward : Boolean;
var
  Net  : Network;
  InV  : Vector;
begin
  NetInit(Net, 4, 3, 1);
  Net.W1[1,1] := 100; Net.W1[1,2] := 0; Net.W1[1,3] := 0; Net.W1[1,4] := 0;
  Net.W1[2,1] := 0; Net.W1[2,2] := 100; Net.W1[2,3] := 0; Net.W1[2,4] := 0;
  Net.W1[3,1] := 0; Net.W1[3,2] := 0; Net.W1[3,3] := 100; Net.W1[3,4] := 0;
  Net.B1[1] := 0; Net.B1[2] := 0; Net.B1[3] := 0;
  Net.W2[1,1] := 100; Net.W2[1,2] := 100; Net.W2[1,3] := 100;
  Net.B2[1] := 0;
  InV[1] := 128; InV[2] := 128; InV[3] := 128; InV[4] := 0;
  SetInput(Net, InV);
  Forward(Net);
  TestForward := (Net.H[1] = 50) and (Net.H[2] = 50) and (Net.H[3] = 50)
                 and (Net.O[1] = 57);
end;

function TestSerialization : Boolean;
var
  Net1, Net2 : Network;
  Buf : ByteArray;
  Len : Integer;
begin
  NetInit(Net1, 4, 3, 1);
  Net1.W1[1,1] := 42;
  Net1.B2[1]   := -7;
  Serialize(Net1, Buf, Len);
  TestSerialization := Deserialize(Net2, Buf, Len)
                       and (Net2.W1[1,1] = 42)
                       and (Net2.B2[1]   = -7)
                       and (Net2.NInput  = 4);
end;

function RunAllGolden : Boolean;
begin
  RunAllGolden :=
    TestFXMUL and
    TestSATADD and
    TestACT and
    TestDotProduct and
    TestForward and
    TestSerialization;
end;

end.
