{ ============================================================
  SPDX-License-Identifier: GPL-3.0-or-later
  Copyright (c) 2026 SnapKittyWest
  Ahmad Ali Parr / Bel Esprit D'Accord Irrevocable Trust
  CLONE GATE: Any clone, fork, or derivative of this node
  MUST be released under GPL-3.0-or-later. No closed-source use.
  ============================================================ }
(* NN/16 Training Kernel
   Explicit integer gradient / weight update
*)

unit TrainingUnit;

interface

uses VectorUnit, MatrixUnit, NetworkUnit, FixedPoint;

procedure ComputeError(const Net : Network; Target : Integer; var Err : Integer);
procedure Backward(var Net : Network; Target : Integer;
                   var dW1 : Matrix; var dB1 : Vector;
                   var dW2 : Matrix; var dB2 : Vector);
procedure WeightUpdate(var Net : Network;
                       const dW1 : Matrix; const dB1 : Vector;
                       const dW2 : Matrix; const dB2 : Vector);
procedure TrainSample(var Net : Network; const InVec : Vector; Target : Integer);

implementation

procedure ComputeError(const Net : Network; Target : Integer; var Err : Integer);
begin
  Err := Target - Net.O[1];
end;

procedure Backward(var Net : Network; Target : Integer;
                   var dW1 : Matrix; var dB1 : Vector;
                   var dW2 : Matrix; var dB2 : Vector);
var
  Err, DeltaO, DeltaH : Integer;
  I, J : Integer;
begin
  MatClear(dW1, Net.NHidden, Net.NInput);
  VecClear(dB1, Net.NHidden);
  MatClear(dW2, Net.NOutput, Net.NHidden);
  VecClear(dB2, Net.NOutput);

  ComputeError(Net, Target, Err);
  DeltaO := Err;

  dB2[1] := DeltaO;
  for J := 1 to Net.NHidden do
    dW2[1, J] := FXMUL(DeltaO, Net.H[J]);

  for I := 1 to Net.NHidden do
  begin
    DeltaH := FXMUL(DeltaO, Net.W2[1, I]);
    dB1[I] := DeltaH;
    for J := 1 to Net.NInput do
      dW1[I, J] := FXMUL(DeltaH, Net.X[J]);
  end;
end;

procedure WeightUpdate(var Net : Network;
                       const dW1 : Matrix; const dB1 : Vector;
                       const dW2 : Matrix; const dB2 : Vector);
var
  I, J, Delta : Integer;
begin
  for I := 1 to Net.NHidden do
  begin
    Delta := FXMUL(Net.LR, dB1[I]);
    Net.B1[I] := SATADD(Net.B1[I], Delta);
    for J := 1 to Net.NInput do
    begin
      Delta := FXMUL(Net.LR, dW1[I, J]);
      Net.W1[I, J] := SATADD(Net.W1[I, J], Delta);
    end;
  end;

  for I := 1 to Net.NOutput do
  begin
    Delta := FXMUL(Net.LR, dB2[I]);
    Net.B2[I] := SATADD(Net.B2[I], Delta);
    for J := 1 to Net.NHidden do
    begin
      Delta := FXMUL(Net.LR, dW2[I, J]);
      Net.W2[I, J] := SATADD(Net.W2[I, J], Delta);
    end;
  end;
end;

procedure TrainSample(var Net : Network; const InVec : Vector; Target : Integer);
var
  dW1 : Matrix;
  dB1 : Vector;
  dW2 : Matrix;
  dB2 : Vector;
begin
  SetInput(Net, InVec);
  Forward(Net);
  Backward(Net, Target, dW1, dB1, dW2, dB2);
  WeightUpdate(Net, dW1, dB1, dW2, dB2);
end;

end.
