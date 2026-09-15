<!--
  SPDX-License-Identifier: GPL-3.0-or-later
  Copyright (c) 2026 SnapKittyWest
  Ahmad Ali Parr / Bel Esprit D'Accord Irrevocable Trust
  CLONE GATE: Any clone, fork, or derivative of this node
  MUST be released under GPL-3.0-or-later. No closed-source use.
-->
# NN/16 — Apple II-Era Integer Neural Computing Stack

NN/16 is a small, deterministic neural-network runtime reconstructed from first
principles for the Apple II generation of machines. No floating point, no modern
frameworks, no external ML libraries.

## The Stack

```
+------------------+
| Integer BASIC    |  interactive REPL, dataset entry, training control
+--------+---------+
         |
         v
+------------------+
| Apple Logo       |  symbolic topology, recursive graph traversal
+--------+---------+
         |
         v
+------------------+
| Apple Pascal     |  deterministic neural runtime, 14 kernel units
+--------+---------+
         |
         v
+------------------+
| 6502 Assembly    |  integer kernels, shift-add multiply, SATADD
+------------------+
```

Plus a standalone **JSON-Triton C kernel** (`json_triton/`) that provides:
- Hand-rolled JSON tokenizer + parser + serializer
- Triton-style model repository + inference API
- Same numerical contract as all other layers
- Golden test suite — all 9 tests pass

## Numerical Contract

16-bit two's-complement integers. Weights are Q8.8 fixed point.
Products computed exactly (magnitudes clamped to 32767).
Accumulation in saturating 32-bit accumulator.
Writeback: divide by 256, round-half-away-from-zero, saturate to [-32768,32767].
Activation clips to [-256, 255].

Identical inputs + weights + parameters → identical outputs. Always.

## Golden Vectors (from `sim/reference.py`)

| Test | Value |
|------|-------|
| dot([1,2,3,4],[5,6,7,8]) | 70 |
| fxmul(300,200) | 234 |
| fxmul(-300,200) | -234 |
| act(300) | 255 |
| act(-300) | -256 |
| LFSR from 12345 → | 24691, 16614, 461, 922... |
| bank0 Fletcher-16 | 24226 |
| Trained outputs (8 samples) | [-256,-191,-193,213,-210,196,195,255] |
| bankF Fletcher-16 | 27489 |
| Correct classifications | 8/8 |

## Repository Layout

```
basic/          Integer BASIC — REPL, dataset, trainer, inference
logo/           Apple Logo — topology, graph, symbolic, recursion
pascal/         Apple Pascal — 14 kernel units + golden test driver
asm6502/        6502 assembly — ADD, MUL, FXMUL (KERNEL.I equates)
json_triton/    C kernel — JSON + Triton-style inference
sim/            Python reference simulation (golden vectors)
tests/          XTEST.TXT cross-language golden vector file
docs/           Architecture, memory, numerics, math, interfaces, build
```

## Quick Start

**Pascal**: Compile `pascal/GOLDEN.PAS` (includes all kernel units via uses).
Expected output: `ALL GOLDEN TESTS PASSED`

**C (JSON-Triton)**:
```bash
cd json_triton
make
./nn16_jt
```
Expected: `ALL GOLDEN TESTS PASSED` + demo inference output

**Python reference**:
```bash
python3 sim/reference.py
```
Reproduces all golden vectors.

**Integer BASIC**: Load `basic/REPL.bas` on Apple II or emulator. Type `H` for help.

## Training Demo (Majority of Three)

4 inputs (±64), 3 hidden, 1 output. Target ±224 when 2+ of x0..x2 are positive.
Seed 12345, LR=32 (0.125), 2000 epochs. 8/8 correct classifications at convergence.

## License

FSL-1.1. Converts to Apache 2.0 after two years.
Copyright (c) 2026 SnapKittyWest. Ahmad Ali Parr, Bel Esprit D'Accord Irrevocable Trust.
