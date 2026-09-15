{ ============================================================
  SPDX-License-Identifier: GPL-3.0-or-later
  Copyright (c) 2026 SnapKittyWest
  Ahmad Ali Parr / Bel Esprit D'Accord Irrevocable Trust
  CLONE GATE: Any clone, fork, or derivative of this node
  MUST be released under GPL-3.0-or-later. No closed-source use.
  ============================================================ }
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
