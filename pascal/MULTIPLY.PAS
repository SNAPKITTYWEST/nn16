(* NN/16 Signed Multiplication Kernel
   Explicit integer multiplication exposing intermediate steps.
   No floating point, no external library.
*)

unit Multiply;

interface

uses Accumulator;

procedure SignedMul(X, Y : Integer; var Acc : AccRec);
procedure ShiftAddMul(MagA, MagB : Integer; var Acc : AccRec);

implementation

procedure ShiftAddMul(MagA, MagB : Integer; var Acc : AccRec);
var
  A, B : Integer;
  Prod : LongInt;
begin
  A := MagA;
  B := MagB;
  Prod := 0;
  while B <> 0 do
  begin
    if (B and 1) <> 0 then
      Prod := Prod + LongInt(A);
    A := A * 2;
    B := B div 2;
  end;
  LongToAcc(Acc, Prod);
end;

procedure SignedMul(X, Y : Integer; var Acc : AccRec);
var
  Sign : Integer;
  MagX, MagY : Integer;
begin
  if ((X < 0) and (Y >= 0)) or ((X >= 0) and (Y < 0)) then
    Sign := 1
  else
    Sign := 0;

  if X < 0 then MagX := -X else MagX := X;
  if Y < 0 then MagY := -Y else MagY := Y;

  ShiftAddMul(MagX, MagY, Acc);

  if Sign = 1 then
  begin
    Acc.N0 := 1 - Acc.N0;
    if (Acc.L1 = 0) and (Acc.L2 = 0) then
      Acc.N0 := 0;
  end;
end;

end.
