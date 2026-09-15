# NN/16 — Apple II Integer Neural Computing Stack
# Top-level build coordination

.PHONY: all c sim test clean count

all: c

# JSON-Triton C kernel
c:
	$(MAKE) -C json_triton

test: c
	cd json_triton && ./nn16_jt

# Python reference simulation (golden vectors)
sim:
	python3 sim/reference.py

# Line count across all layers
count:
	@find . -name "*.bas" -o -name "*.lgo" -o -name "*.pas" \
	        -o -name "*.asm" -o -name "*.c" -o -name "*.h" \
	        -o -name "*.py" | grep -v ".git" | xargs wc -l 2>/dev/null | tail -1

clean:
	$(MAKE) -C json_triton clean
