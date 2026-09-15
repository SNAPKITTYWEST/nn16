{ ============================================================
  SPDX-License-Identifier: GPL-3.0-or-later
  Copyright (c) 2026 SnapKittyWest
  Ahmad Ali Parr / Bel Esprit D'Accord Irrevocable Trust
  CLONE GATE: Any clone, fork, or derivative of this node
  MUST be released under GPL-3.0-or-later. No closed-source use.
  ============================================================ }
(* NN/16 DotProduct Kernel
   Fundamental operation of NN/16
*)

unit DotProductUnit;

interface

uses VectorUnit, Accumulator, FixedPoint;

function DotProduct(const A, B : Vector; N : Integer) : Integer;
function DotProductSat(const A, B : Vector; N : Integer) : Integer;
function DotProductFX(const A, B : Vector; N : Integer) : Integer;

implementation

function DotProduct(const A, B : Vector; N : Integer) : Integer;
var
  I : Integer;
  S : LongInt;
begin
  S := 0;
  for I := 1 to N do
    S := S + LongInt(A[I]) * LongInt(B[I]);
  if S > 32767 then
    DotProduct := 32767
  else if S < -32768 then
    DotProduct := -32768
  else
    DotProduct := Integer(S);
end;

function DotProductSat(const A, B : Vector; N : Integer) : Integer;
var
  Acc : AccRec;
  I : Integer;
  R : Integer;
begin
  ACCCLR(Acc);
  for I := 1 to N do
    MULADD(Acc, A[I], B[I]);
  ACCSAT(Acc, R);
  DotProductSat := R;
end;

function DotProductFX(const A, B : Vector; N : Integer) : Integer;
var
  I, S, Term : Integer;
begin
  S := 0;
  for I := 1 to N do
  begin
    Term := FXMUL(A[I], B[I]);
    S := SATADD(S, Term);
  end;
  DotProductFX := ACT(S);
end;

end.
