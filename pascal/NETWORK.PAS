{ ============================================================
  SPDX-License-Identifier: GPL-3.0-or-later
  Copyright (c) 2026 SnapKittyWest
  Ahmad Ali Parr / Bel Esprit D'Accord Irrevocable Trust
  CLONE GATE: Any clone, fork, or derivative of this node
  MUST be released under GPL-3.0-or-later. No closed-source use.
  ============================================================ }
(* NN/16 Network Kernel
   Default topology: 4 -> 3 -> 1
*)

unit NetworkUnit;

interface

uses VectorUnit, MatrixUnit, FixedPoint, ActivationUnit, DotProductUnit;

const
  DEF_INPUT  = 4;
  DEF_HIDDEN = 3;
  DEF_OUTPUT = 1;

type
  Network = record
    NInput  : Integer;
    NHidden : Integer;
    NOutput : Integer;
    W1      : Matrix;
    B1      : Vector;
    W2      : Matrix;
    B2      : Vector;
    X       : Vector;
    HSum    : Vector;
    H       : Vector;
    OSum    : Vector;
    O       : Vector;
    Seed    : Integer;
    LR      : Integer;
    Epoch   : Integer;
  end;

procedure NetInit(var Net : Network; NI, NH, NO : Integer);
procedure NetClearWeights(var Net : Network);
procedure Forward(var Net : Network);
procedure SetInput(var Net : Network; const InVec : Vector);
function GetOutput(const Net : Network) : Integer;

implementation

procedure NetInit(var Net : Network; NI, NH, NO : Integer);
begin
  Net.NInput  := NI;
  Net.NHidden := NH;
  Net.NOutput := NO;
  Net.Seed    := 1;
  Net.LR      := 16;
  Net.Epoch   := 0;
  NetClearWeights(Net);
  VecClear(Net.X, NI);
  VecClear(Net.H, NH);
  VecClear(Net.O, NO);
end;

procedure NetClearWeights(var Net : Network);
begin
  MatClear(Net.W1, Net.NHidden, Net.NInput);
  VecClear(Net.B1, Net.NHidden);
  MatClear(Net.W2, Net.NOutput, Net.NHidden);
  VecClear(Net.B2, Net.NOutput);
end;

procedure SetInput(var Net : Network; const InVec : Vector);
begin
  VecCopy(InVec, Net.X, Net.NInput);
end;

procedure Forward(var Net : Network);
var
  I, J, Sum : Integer;
begin
  for I := 1 to Net.NHidden do
  begin
    Sum := Net.B1[I];
    for J := 1 to Net.NInput do
      Sum := SATADD(Sum, FXMUL(Net.X[J], Net.W1[I, J]));
    Net.HSum[I] := Sum;
    Net.H[I] := ACT(Sum);
  end;

  for I := 1 to Net.NOutput do
  begin
    Sum := Net.B2[I];
    for J := 1 to Net.NHidden do
      Sum := SATADD(Sum, FXMUL(Net.H[J], Net.W2[I, J]));
    Net.OSum[I] := Sum;
    Net.O[I] := ACT(Sum);
  end;
end;

function GetOutput(const Net : Network) : Integer;
begin
  if Net.NOutput >= 1 then
    GetOutput := Net.O[1]
  else
    GetOutput := 0;
end;

end.
