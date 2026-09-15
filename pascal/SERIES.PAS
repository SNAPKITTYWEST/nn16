{ ============================================================
  SPDX-License-Identifier: GPL-3.0-or-later
  Copyright (c) 2026 SnapKittyWest
  Ahmad Ali Parr / Bel Esprit D'Accord Irrevocable Trust
  CLONE GATE: Any clone, fork, or derivative of this node
  MUST be released under GPL-3.0-or-later. No closed-source use.
  ============================================================ }
(* NN/16 Serialization & Fletcher-16 Kernel *)

unit SerializationUnit;

interface

uses NetworkUnit, VectorUnit, MatrixUnit;

const
  MODEL_MAGIC = $314E; (* 'N','1' little-endian *)
  MODEL_SIZE  = 60;    (* default 4-3-1 *)

type
  ByteArray = array[0..255] of Byte;

procedure Serialize(const Net : Network; var Buf : ByteArray; var Len : Integer);
function Deserialize(var Net : Network; const Buf : ByteArray; Len : Integer) : Boolean;
function Fletcher16(const Buf : ByteArray; Len : Integer) : Integer;
procedure PutInt16(var Buf : ByteArray; var Pos : Integer; V : Integer);
function GetInt16(const Buf : ByteArray; var Pos : Integer) : Integer;

implementation

procedure PutInt16(var Buf : ByteArray; var Pos : Integer; V : Integer);
begin
  Buf[Pos]   := V and $FF;
  Buf[Pos+1] := (V shr 8) and $FF;
  Pos := Pos + 2;
end;

function GetInt16(const Buf : ByteArray; var Pos : Integer) : Integer;
var
  Lo, Hi : Integer;
begin
  Lo := Buf[Pos];
  Hi := Buf[Pos+1];
  Pos := Pos + 2;
  GetInt16 := Lo + (Hi * 256);
  if (Hi and $80) <> 0 then
    GetInt16 := GetInt16 - 65536;
end;

function Fletcher16(const Buf : ByteArray; Len : Integer) : Integer;
var
  Sum1, Sum2, I : Integer;
begin
  Sum1 := 0;
  Sum2 := 0;
  for I := 0 to Len - 1 do
  begin
    Sum1 := (Sum1 + Buf[I]) mod 255;
    Sum2 := (Sum2 + Sum1) mod 255;
  end;
  Fletcher16 := Sum1 + (Sum2 * 256);
end;

procedure Serialize(const Net : Network; var Buf : ByteArray; var Len : Integer);
var
  Pos, I, J, CSum : Integer;
begin
  Pos := 0;
  PutInt16(Buf, Pos, MODEL_MAGIC);
  Buf[Pos] := 1; Pos := Pos + 1;  (* version *)
  Buf[Pos] := 0; Pos := Pos + 1;  (* flags *)
  Buf[Pos] := Net.NInput;  Pos := Pos + 1;
  Buf[Pos] := Net.NHidden; Pos := Pos + 1;
  Buf[Pos] := Net.NOutput; Pos := Pos + 1;
  Buf[Pos] := 0; Pos := Pos + 1;  (* reserved *)
  PutInt16(Buf, Pos, Net.Seed);
  PutInt16(Buf, Pos, Net.LR);
  PutInt16(Buf, Pos, Net.Epoch);
  PutInt16(Buf, Pos, 0);  (* sample count placeholder *)
  PutInt16(Buf, Pos, 0);  (* reserved *)
  PutInt16(Buf, Pos, 0);  (* reserved *)

  for I := 1 to Net.NHidden do
    for J := 1 to Net.NInput do
      PutInt16(Buf, Pos, Net.W1[I, J]);
  for I := 1 to Net.NHidden do
    PutInt16(Buf, Pos, Net.B1[I]);
  for I := 1 to Net.NOutput do
    for J := 1 to Net.NHidden do
      PutInt16(Buf, Pos, Net.W2[I, J]);
  for I := 1 to Net.NOutput do
    PutInt16(Buf, Pos, Net.B2[I]);

  CSum := Fletcher16(Buf, Pos);
  PutInt16(Buf, Pos, CSum);
  Len := Pos;
end;

function Deserialize(var Net : Network; const Buf : ByteArray; Len : Integer) : Boolean;
var
  Pos, Magic, I, J, StoredCS, CalcCS : Integer;
begin
  Deserialize := False;
  if Len < 20 then Exit;
  Pos := 0;
  Magic := GetInt16(Buf, Pos);
  if Magic <> MODEL_MAGIC then Exit;
  if Buf[Pos] <> 1 then Exit;
  Pos := Pos + 1;
  Pos := Pos + 1; (* flags *)
  Net.NInput  := Buf[Pos]; Pos := Pos + 1;
  Net.NHidden := Buf[Pos]; Pos := Pos + 1;
  Net.NOutput := Buf[Pos]; Pos := Pos + 1;
  Pos := Pos + 1; (* reserved *)
  Net.Seed  := GetInt16(Buf, Pos);
  Net.LR    := GetInt16(Buf, Pos);
  Net.Epoch := GetInt16(Buf, Pos);
  Pos := Pos + 2; (* sample count *)
  Pos := Pos + 4; (* reserved *)

  for I := 1 to Net.NHidden do
    for J := 1 to Net.NInput do
      Net.W1[I, J] := GetInt16(Buf, Pos);
  for I := 1 to Net.NHidden do
    Net.B1[I] := GetInt16(Buf, Pos);
  for I := 1 to Net.NOutput do
    for J := 1 to Net.NHidden do
      Net.W2[I, J] := GetInt16(Buf, Pos);
  for I := 1 to Net.NOutput do
    Net.B2[I] := GetInt16(Buf, Pos);

  StoredCS := GetInt16(Buf, Pos);
  CalcCS   := Fletcher16(Buf, Pos - 2);
  if StoredCS <> CalcCS then Exit;

  Deserialize := True;
end;

end.
