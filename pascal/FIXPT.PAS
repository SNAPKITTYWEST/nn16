(* NN/16 Fixed-Point Kernel
   FXMUL, SATADD, ACT according to NUMERICS.md contract
*)

unit FixedPoint;

interface

uses Accumulator;

function FXMUL(A, B : Integer) : Integer;
function SATADD(A, B : Integer) : Integer;
function ACT(X : Integer) : Integer;
function SAT16(X : LongInt) : Integer;

implementation

function FXMUL(A, B : Integer) : Integer;
var
  Prod, Scaled, Rem, AbsProd : LongInt;
  Sign : Integer;
  Q : Integer;
begin
  Prod := LongInt(A) * LongInt(B);
  if Prod = 0 then
  begin
    FXMUL := 0;
    Exit;
  end;

  if Prod < 0 then
  begin
    Sign := -1;
    AbsProd := -Prod;
  end
  else
  begin
    Sign := 1;
    AbsProd := Prod;
  end;

  Scaled := AbsProd div 256;
  Rem := AbsProd mod 256;

  if Rem >= 128 then
    Scaled := Scaled + 1;

  Scaled := Scaled * Sign;

  if Scaled > 255 then
    Q := 255
  else if Scaled < -256 then
    Q := -256
  else
    Q := Integer(Scaled);

  FXMUL := Q;
end;

function SATADD(A, B : Integer) : Integer;
var
  Sum : LongInt;
begin
  Sum := LongInt(A) + LongInt(B);
  if Sum > 32767 then
    SATADD := 32767
  else if Sum < -32768 then
    SATADD := -32768
  else
    SATADD := Integer(Sum);
end;

function ACT(X : Integer) : Integer;
begin
  if X > 255 then
    ACT := 255
  else if X < -256 then
    ACT := -256
  else
    ACT := X;
end;

function SAT16(X : LongInt) : Integer;
begin
  if X > 32767 then
    SAT16 := 32767
  else if X < -32768 then
    SAT16 := -32768
  else
    SAT16 := Integer(X);
end;

end.
