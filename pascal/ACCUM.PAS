{ ============================================================
  SPDX-License-Identifier: GPL-3.0-or-later
  Copyright (c) 2026 SnapKittyWest
  Ahmad Ali Parr / Bel Esprit D'Accord Irrevocable Trust
  CLONE GATE: Any clone, fork, or derivative of this node
  MUST be released under GPL-3.0-or-later. No closed-source use.
  ============================================================ }
(* NN/16 Accumulator Kernel
   Signed extended integer: N0 (sign) + L2:L1 with BASE = 32768
   Apple Pascal / UCSD Pascal style
*)

unit Accumulator;

interface

const
  BASE = 32768;
  MAXLIMB = 32767;

type
  AccRec = record
    N0 : Integer; (* 0 = positive, 1 = negative *)
    L1 : Integer; (* low limb 0..32767 *)
    L2 : Integer; (* high limb 0..32767 *)
  end;

procedure ACCCLR(var A : AccRec);
procedure LADDL(var A : AccRec; Sign, Low, High : Integer);
procedure ACCADDW(var A : AccRec; W : Integer);
procedure MULADD(var A : AccRec; X, Y : Integer);
procedure ADDP(var Dest : AccRec; const Src : AccRec);
procedure ACCSAT(var A : AccRec; var Result : Integer);
procedure ACCSHIFT(var A : AccRec; Bits : Integer);
function AccToLong(const A : AccRec) : LongInt;
procedure LongToAcc(var A : AccRec; V : LongInt);

implementation

procedure ACCCLR(var A : AccRec);
begin
  A.N0 := 0;
  A.L1 := 0;
  A.L2 := 0;
end;

procedure LADDL(var A : AccRec; Sign, Low, High : Integer);
begin
  A.N0 := Sign;
  if Low < 0 then Low := 0;
  if Low > MAXLIMB then Low := MAXLIMB;
  if High < 0 then High := 0;
  if High > MAXLIMB then High := MAXLIMB;
  A.L1 := Low;
  A.L2 := High;
end;

function AccToLong(const A : AccRec) : LongInt;
var
  Mag : LongInt;
begin
  Mag := LongInt(A.L2) * BASE + LongInt(A.L1);
  if A.N0 = 0 then
    AccToLong := Mag
  else
    AccToLong := -Mag;
end;

procedure LongToAcc(var A : AccRec; V : LongInt);
var
  Mag : LongInt;
begin
  if V < 0 then
  begin
    A.N0 := 1;
    Mag := -V;
  end
  else
  begin
    A.N0 := 0;
    Mag := V;
  end;
  if Mag > LongInt(MAXLIMB) * BASE + MAXLIMB then
    Mag := LongInt(MAXLIMB) * BASE + MAXLIMB;
  A.L2 := Mag div BASE;
  A.L1 := Mag mod BASE;
end;

procedure ACCADDW(var A : AccRec; W : Integer);
var
  V : LongInt;
begin
  V := AccToLong(A) + LongInt(W);
  LongToAcc(A, V);
end;

procedure MULADD(var A : AccRec; X, Y : Integer);
var
  Prod : LongInt;
begin
  Prod := LongInt(X) * LongInt(Y);
  LongToAcc(A, AccToLong(A) + Prod);
end;

procedure ADDP(var Dest : AccRec; const Src : AccRec);
begin
  LongToAcc(Dest, AccToLong(Dest) + AccToLong(Src));
end;

procedure ACCSAT(var A : AccRec; var Result : Integer);
var
  V : LongInt;
begin
  V := AccToLong(A);
  if V > 32767 then
    Result := 32767
  else if V < -32768 then
    Result := -32768
  else
    Result := Integer(V);
  LongToAcc(A, LongInt(Result));
end;

procedure ACCSHIFT(var A : AccRec; Bits : Integer);
var
  V : LongInt;
  I : Integer;
begin
  V := AccToLong(A);
  if Bits > 0 then
  begin
    for I := 1 to Bits do
    begin
      if V >= 0 then
        V := V div 2
      else
        V := (V - 1) div 2;
    end;
  end
  else if Bits < 0 then
  begin
    for I := 1 to -Bits do
      V := V * 2;
  end;
  LongToAcc(A, V);
end;

end.
