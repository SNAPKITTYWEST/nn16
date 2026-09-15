(* NN/16 Inference Kernel *)

unit InferenceUnit;

interface

uses VectorUnit, NetworkUnit;

function Infer(var Net : Network; const InVec : Vector) : Integer;
procedure InferBatch(var Net : Network;
                     const Samples : array of Vector;
                     var Outputs : array of Integer;
                     Count : Integer);

implementation

function Infer(var Net : Network; const InVec : Vector) : Integer;
begin
  SetInput(Net, InVec);
  Forward(Net);
  Infer := GetOutput(Net);
end;

procedure InferBatch(var Net : Network;
                     const Samples : array of Vector;
                     var Outputs : array of Integer;
                     Count : Integer);
var K : Integer;
begin
  for K := 0 to Count - 1 do
    Outputs[K] := Infer(Net, Samples[K]);
end;

end.
