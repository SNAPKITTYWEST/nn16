/* ============================================================
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Copyright (c) 2026 SnapKittyWest
 * Ahmad Ali Parr / Bel Esprit D'Accord Irrevocable Trust
 * CLONE GATE: Any clone, fork, or derivative of this node
 * MUST be released under GPL-3.0-or-later. No closed-source use.
 * ============================================================ */
/* NN/16 JSON-Triton — Numerical primitives + arena + LFSR + forward pass */
#include "nn16_jt.h"
#include <string.h>
#include <math.h>

const char *jt_status_str(jt_status_t s) {
    static const char *names[] = {
        "OK","NOMEM","SYNTAX","TYPE","RANGE","NOTFOUND",
        "CHECKSUM","DIM","NULL","OVERFLOW","IO","UNSUPPORTED"
    };
    if (s < 0 || s > JT_ERR_UNSUPPORTED) return "UNKNOWN";
    return names[s];
}

int16_t jt_fxmul(int16_t a, int16_t b) {
    int32_t prod = (int32_t)a * (int32_t)b;
    if (prod == 0) return 0;
    int sign = 1;
    int32_t absprod = prod;
    if (prod < 0) { sign = -1; absprod = -prod; }
    int32_t scaled = absprod / 256;
    int32_t rem    = absprod % 256;
    if (rem >= 128) scaled += 1;
    scaled *= sign;
    if (scaled > JT_ACT_MAX) return JT_ACT_MAX;
    if (scaled < JT_ACT_MIN) return JT_ACT_MIN;
    return (int16_t)scaled;
}

int16_t jt_satadd(int16_t a, int16_t b) {
    int32_t sum = (int32_t)a + (int32_t)b;
    if (sum > 32767)  return 32767;
    if (sum < -32768) return -32768;
    return (int16_t)sum;
}

int16_t jt_act(int16_t x) {
    if (x > JT_ACT_MAX) return JT_ACT_MAX;
    if (x < JT_ACT_MIN) return JT_ACT_MIN;
    return x;
}

int16_t jt_dotproduct(const int16_t *a, const int16_t *b, int n) {
    int32_t s = 0;
    for (int i = 0; i < n; i++) s += (int32_t)a[i] * (int32_t)b[i];
    if (s > 32767)  return 32767;
    if (s < -32768) return -32768;
    return (int16_t)s;
}

uint16_t jt_fletcher16(const uint8_t *data, size_t len) {
    uint32_t sum1 = 0, sum2 = 0;
    for (size_t i = 0; i < len; i++) {
        sum1 = (sum1 + data[i]) % 255;
        sum2 = (sum2 + sum1) % 255;
    }
    return (uint16_t)(sum1 | (sum2 << 8));
}

void jt_arena_init(jt_arena_t *a) { a->used = 0; memset(a->mem, 0, sizeof(a->mem)); }

void *jt_arena_alloc(jt_arena_t *a, size_t n, size_t align) {
    if (align == 0) align = 1;
    size_t pad = (align - (a->used % align)) % align;
    if (a->used + pad + n > JT_ARENA_SIZE) return NULL;
    a->used += pad;
    void *p = a->mem + a->used;
    a->used += n;
    return p;
}

void jt_arena_reset(jt_arena_t *a) { a->used = 0; }

static uint16_t lfsr_next(uint16_t *state) {
    if (*state & 1) *state = (*state >> 1) ^ 0xB400;
    else            *state = *state >> 1;
    if (*state == 0) *state = 1;
    return *state;
}

void jt_model_init_lfsr(jt_model_t *m, uint16_t seed) {
    if (seed == 0) seed = 1;
    uint16_t st = seed;
    m->seed = seed;
    for (int i = 0; i < m->n_hidden; i++) {
        for (int j = 0; j < m->n_input; j++) {
            lfsr_next(&st);
            m->w1[i][j] = (int16_t)((st & 0x1FF) - 256);
        }
        lfsr_next(&st);
        m->b1[i] = (int16_t)((st & 0x1FF) - 256);
    }
    for (int i = 0; i < m->n_output; i++) {
        for (int j = 0; j < m->n_hidden; j++) {
            lfsr_next(&st);
            m->w2[i][j] = (int16_t)((st & 0x1FF) - 256);
        }
        lfsr_next(&st);
        m->b2[i] = (int16_t)((st & 0x1FF) - 256);
    }
}

jt_status_t jt_model_validate(const jt_model_t *m) {
    if (!m) return JT_ERR_NULL;
    if (m->n_input  < 1 || m->n_input  > JT_MAX_DIM) return JT_ERR_DIM;
    if (m->n_hidden < 1 || m->n_hidden > JT_MAX_DIM) return JT_ERR_DIM;
    if (m->n_output < 1 || m->n_output > JT_MAX_DIM) return JT_ERR_DIM;
    return JT_OK;
}

void jt_forward(const jt_model_t *m, const int16_t *x, int16_t *h, int16_t *o) {
    for (int i = 0; i < m->n_hidden; i++) {
        int32_t sum = m->b1[i];
        for (int j = 0; j < m->n_input; j++)
            sum = jt_satadd((int16_t)sum, jt_fxmul(x[j], m->w1[i][j]));
        h[i] = jt_act((int16_t)sum);
    }
    for (int i = 0; i < m->n_output; i++) {
        int32_t sum = m->b2[i];
        for (int j = 0; j < m->n_hidden; j++)
            sum = jt_satadd((int16_t)sum, jt_fxmul(h[j], m->w2[i][j]));
        o[i] = jt_act((int16_t)sum);
    }
}
