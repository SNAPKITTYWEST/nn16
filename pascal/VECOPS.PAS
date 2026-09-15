(* NN/16 Vector Kernel
   Weight = Integer
   Vector = array[1..16] of Weight
*)

unit VectorUnit;

interface

const
  MAXDIM = 16;

type
  Weight = Integer;
  Vector = array[1..MAXDIM] of Weight;

procedure VecClear(var V : Vector; N : Integer);
procedure VecCopy(const Src : Vector; var Dst : Vector; N : Integer);
procedure VecAdd(const A, B : Vector; var C : Vector; N : Integer);
procedure VecScale(const A : Vector; S : Integer; var C : Vector; N : Integer);
procedure VecSatAdd(const A, B : Vector; var C : Vector; N : Integer);
function VecNorm1(const V : Vector; N : Integer) : Integer;
function VecMaxAbs(const V : Vector; N : Integer) : Integer;
procedure VecFill(var V : Vector; N : Integer; Value : Integer);

implementation

uses FixedPoint;

procedure VecClear(var V : Vector; N : Integer);
var
  I : Integer;
begin
  for I := 1 to N do
    V[I] := 0;
end;

procedure VecCopy(const Src : Vector; var Dst : Vector; N : Integer);
var
  I : Integer;
begin
  for I := 1 to N do
    Dst[I] := Src[I];
end;

procedure VecAdd(const A, B : Vector; var C : Vector; N : Integer);
var
  I : Integer;
begin
  for I := 1 to N do
    C[I] := A[I] + B[I];
end;

procedure VecScale(const A : Vector; S : Integer; var C : Vector; N : Integer);
var
  I : Integer;
begin
  for I := 1 to N do
    C[I] := FXMUL(A[I], S);
end;

procedure VecSatAdd(const A, B : Vector; var C : Vector; N : Integer);
var
  I : Integer;
begin
  for I := 1 to N do
    C[I] := SATADD(A[I], B[I]);
end;

function VecNorm1(const V : Vector; N : Integer) : Integer;
var
  I, S, AbsV : Integer;
begin
  S := 0;
  for I := 1 to N do
  begin
    if V[I] < 0 then AbsV := -V[I] else AbsV := V[I];
    S := SATADD(S, AbsV);
  end;
  VecNorm1 := S;
end;

function VecMaxAbs(const V : Vector; N : Integer) : Integer;
var
  I, M, AbsV : Integer;
begin
  M := 0;
  for I := 1 to N do
  begin
    if V[I] < 0 then AbsV := -V[I] else AbsV := V[I];
    if AbsV > M then M := AbsV;
  end;
  VecMaxAbs := M;
end;

procedure VecFill(var V : Vector; N : Integer; Value : Integer);
var
  I : Integer;
begin
  for I := 1 to N do
    V[I] := Value;
end;

end.
