(* NN/16 Activation Kernel *)

unit ActivationUnit;

interface

uses VectorUnit, FixedPoint;

procedure ActVector(const X : Vector; var Y : Vector; N : Integer);
procedure ActIdentity(const X : Vector; var Y : Vector; N : Integer);
function ActScalar(X : Integer) : Integer;

implementation

function ActScalar(X : Integer) : Integer;
begin
  ActScalar := ACT(X);
end;

procedure ActVector(const X : Vector; var Y : Vector; N : Integer);
var I : Integer;
begin
  for I := 1 to N do Y[I] := ACT(X[I]);
end;

procedure ActIdentity(const X : Vector; var Y : Vector; N : Integer);
var I : Integer;
begin
  for I := 1 to N do Y[I] := X[I];
end;

end.
