# ============================================================
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (c) 2026 SnapKittyWest
# Ahmad Ali Parr / Bel Esprit D'Accord Irrevocable Trust
# CLONE GATE: Any clone, fork, or derivative of this node
# MUST be released under GPL-3.0-or-later. No closed-source use.
# ============================================================
# NN/16 JSON-Triton hand-rolled kernel
CC = cc
CFLAGS = -std=c99 -Wall -Wextra -O2 -Iinclude
SRCS = src/numerics.c src/json.c src/model.c src/infer.c src/tests.c src/main.c
OBJS = $(SRCS:.c=.o)
BIN = nn16_jt

.PHONY: all clean test lines

all: $(BIN)

$(BIN): $(OBJS)
	$(CC) $(CFLAGS) -o $@ $(OBJS)

src/%.o: src/%.c include/nn16_jt.h
	$(CC) $(CFLAGS) -c -o $@ $<

test: $(BIN)
	./$(BIN)

clean:
	rm -f $(OBJS) $(BIN)

lines:
	@wc -l include/*.h src/*.c Makefile
