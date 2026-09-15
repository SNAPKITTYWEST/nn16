(* NN/16 Matrix Kernel *)

unit MatrixUnit;

interface

uses VectorUnit, DotProductUnit, FixedPoint;

const
  MAXDIM = 16;

type
  Matrix = array[1..MAXDIM, 1..MAXDIM] of Weight;

procedure MatClear(var M : Matrix; Rows, Cols : Integer);
procedure MatCopy(const Src : Matrix; var Dst : Matrix; Rows, Cols : Integer);
procedure MatTranspose(const Src : Matrix; var Dst : Matrix; Rows, Cols : Integer);
procedure MatVecMul(const M : Matrix; const V : Vector; var R : Vector; Rows, Cols : Integer);
procedure MatVecMulFX(const M : Matrix; const V : Vector; var R : Vector; Rows, Cols : Integer);
procedure MatAdd(const A, B : Matrix; var C : Matrix; Rows, Cols : Integer);
procedure MatScale(const A : Matrix; S : Integer; var C : Matrix; Rows, Cols : Integer);
procedure MatFill(var M : Matrix; Rows, Cols : Integer; Value : Integer);
procedure MatGetRow(const M : Matrix; Row, Cols : Integer; var V : Vector);
procedure MatSetRow(var M : Matrix; Row, Cols : Integer; const V : Vector);

implementation

procedure MatClear(var M : Matrix; Rows, Cols : Integer);
var I, J : Integer;
begin
  for I := 1 to Rows do for J := 1 to Cols do M[I, J] := 0;
end;

procedure MatCopy(const Src : Matrix; var Dst : Matrix; Rows, Cols : Integer);
var I, J : Integer;
begin
  for I := 1 to Rows do for J := 1 to Cols do Dst[I, J] := Src[I, J];
end;

procedure MatTranspose(const Src : Matrix; var Dst : Matrix; Rows, Cols : Integer);
var I, J : Integer;
begin
  for I := 1 to Rows do for J := 1 to Cols do Dst[J, I] := Src[I, J];
end;

procedure MatGetRow(const M : Matrix; Row, Cols : Integer; var V : Vector);
var J : Integer;
begin
  for J := 1 to Cols do V[J] := M[Row, J];
end;

procedure MatSetRow(var M : Matrix; Row, Cols : Integer; const V : Vector);
var J : Integer;
begin
  for J := 1 to Cols do M[Row, J] := V[J];
end;

procedure MatVecMul(const M : Matrix; const V : Vector; var R : Vector; Rows, Cols : Integer);
var I : Integer; RowV : Vector;
begin
  for I := 1 to Rows do
  begin
    MatGetRow(M, I, Cols, RowV);
    R[I] := DotProduct(RowV, V, Cols);
  end;
end;

procedure MatVecMulFX(const M : Matrix; const V : Vector; var R : Vector; Rows, Cols : Integer);
var I : Integer; RowV : Vector;
begin
  for I := 1 to Rows do
  begin
    MatGetRow(M, I, Cols, RowV);
    R[I] := DotProductFX(RowV, V, Cols);
  end;
end;

procedure MatAdd(const A, B : Matrix; var C : Matrix; Rows, Cols : Integer);
var I, J : Integer;
begin
  for I := 1 to Rows do
    for J := 1 to Cols do
      C[I, J] := SATADD(A[I, J], B[I, J]);
end;

procedure MatScale(const A : Matrix; S : Integer; var C : Matrix; Rows, Cols : Integer);
var I, J : Integer;
begin
  for I := 1 to Rows do
    for J := 1 to Cols do
      C[I, J] := FXMUL(A[I, J], S);
end;

procedure MatFill(var M : Matrix; Rows, Cols : Integer; Value : Integer);
var I, J : Integer;
begin
  for I := 1 to Rows do for J := 1 to Cols do M[I, J] := Value;
end;

end.
