(* NN/16 Memory Kernel
   Static allocation helpers and LFSR weight initialisation
*)

unit MemoryUnit;

interface

uses NetworkUnit, VectorUnit, MatrixUnit;

function LFSRNext(var State : Integer) : Integer;
procedure InitWeightsLFSR(var Net : Network; Seed : Integer);

implementation

const
  LFSR_TAP = $B400;

function LFSRNext(var State : Integer) : Integer;
begin
  if (State and 1) <> 0 then
    State := ((State shr 1) and $7FFF) xor LFSR_TAP
  else
    State := (State shr 1) and $7FFF;
  if State = 0 then State := 1;
  LFSRNext := State;
end;

procedure InitWeightsLFSR(var Net : Network; Seed : Integer);
var
  State, I, J, W : Integer;
begin
  if Seed = 0 then Seed := 1;
  State := Seed;
  Net.Seed := Seed;

  for I := 1 to Net.NHidden do
  begin
    for J := 1 to Net.NInput do
    begin
      LFSRNext(State);
      W := (State and $1FF) - 256;
      Net.W1[I, J] := W;
    end;
    LFSRNext(State);
    Net.B1[I] := (State and $1FF) - 256;
  end;

  for I := 1 to Net.NOutput do
  begin
    for J := 1 to Net.NHidden do
    begin
      LFSRNext(State);
      W := (State and $1FF) - 256;
      Net.W2[I, J] := W;
    end;
    LFSRNext(State);
    Net.B2[I] := (State and $1FF) - 256;
  end;
end;

end.
