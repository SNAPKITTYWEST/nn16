(* NN/16 Pascal Golden Test Driver
   Compile and run under Apple Pascal / a compatible dialect
*)

program GoldenTests;

uses FixedPoint, DotProductUnit, VectorUnit, NetworkUnit,
     SerializationUnit, ValidationUnit, MemoryUnit, TrainingUnit,
     InferenceUnit;

var
  Ok  : Boolean;
  Net : Network;
  InV : Vector;
  OutV: Integer;
begin
  WriteLn('NN/16 Pascal Golden Tests');
  WriteLn('-------------------------');

  Ok := RunAllGolden;
  if Ok then
    WriteLn('ALL GOLDEN TESTS PASSED')
  else
    WriteLn('SOME TESTS FAILED');

  NetInit(Net, 4, 3, 1);
  InitWeightsLFSR(Net, 1);
  InV[1] := 100; InV[2] := 50; InV[3] := -30; InV[4] := 10;
  OutV := Infer(Net, InV);
  WriteLn('Sample inference output = ', OutV);
  WriteLn('Epoch = ', Net.Epoch);
end.
