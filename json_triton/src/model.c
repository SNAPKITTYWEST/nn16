/* ============================================================
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Copyright (c) 2026 SnapKittyWest
 * Ahmad Ali Parr / Bel Esprit D'Accord Irrevocable Trust
 * CLONE GATE: Any clone, fork, or derivative of this node
 * MUST be released under GPL-3.0-or-later. No closed-source use.
 * ============================================================ */
/* NN/16 JSON-Triton — Model binary load/save */
#include "nn16_jt.h"
#include <string.h>
#include <stdio.h>

static void put_u16(uint8_t *p, uint16_t v) {
    p[0] = (uint8_t)(v & 0xFF);
    p[1] = (uint8_t)((v >> 8) & 0xFF);
}

static uint16_t get_u16(const uint8_t *p) {
    return (uint16_t)p[0] | ((uint16_t)p[1] << 8);
}

static void put_i16(uint8_t *p, int16_t v) { put_u16(p, (uint16_t)v); }
static int16_t get_i16(const uint8_t *p) { return (int16_t)get_u16(p); }

jt_status_t jt_model_to_binary(const jt_model_t *m, uint8_t *img,
                                size_t imgsize, size_t *written) {
    if (!m || !img) return JT_ERR_NULL;
    size_t need = 20
        + (size_t)m->n_hidden * m->n_input * 2
        + (size_t)m->n_hidden * 2
        + (size_t)m->n_output * m->n_hidden * 2
        + (size_t)m->n_output * 2
        + 2;
    if (imgsize < need) return JT_ERR_OVERFLOW;

    size_t pos = 0;
    put_u16(img + pos, JT_MODEL_MAGIC); pos += 2;
    img[pos++] = 1;  /* version */
    img[pos++] = 0;  /* flags */
    img[pos++] = (uint8_t)m->n_input;
    img[pos++] = (uint8_t)m->n_hidden;
    img[pos++] = (uint8_t)m->n_output;
    img[pos++] = 0;  /* reserved */
    put_u16(img + pos, m->seed);   pos += 2;
    put_i16(img + pos, m->lr);     pos += 2;
    put_u16(img + pos, m->epoch);  pos += 2;
    put_u16(img + pos, 0);         pos += 2;  /* sample count */
    put_u16(img + pos, 0);         pos += 2;  /* reserved */
    put_u16(img + pos, 0);         pos += 2;  /* reserved */

    for (int i = 0; i < m->n_hidden; i++)
        for (int j = 0; j < m->n_input; j++) {
            put_i16(img + pos, m->w1[i][j]); pos += 2;
        }
    for (int i = 0; i < m->n_hidden; i++) {
        put_i16(img + pos, m->b1[i]); pos += 2;
    }
    for (int i = 0; i < m->n_output; i++)
        for (int j = 0; j < m->n_hidden; j++) {
            put_i16(img + pos, m->w2[i][j]); pos += 2;
        }
    for (int i = 0; i < m->n_output; i++) {
        put_i16(img + pos, m->b2[i]); pos += 2;
    }

    uint16_t cs = jt_fletcher16(img, pos);
    put_u16(img + pos, cs); pos += 2;
    if (written) *written = pos;
    return JT_OK;
}

jt_status_t jt_model_from_binary(const uint8_t *img, size_t len, jt_model_t *m) {
    if (!img || !m) return JT_ERR_NULL;
    if (len < 20) return JT_ERR_RANGE;

    size_t pos = 0;
    uint16_t magic = get_u16(img + pos); pos += 2;
    if (magic != JT_MODEL_MAGIC) return JT_ERR_SYNTAX;
    if (img[pos++] != 1) return JT_ERR_UNSUPPORTED;
    pos++; /* flags */
    int ni = img[pos++];
    int nh = img[pos++];
    int no = img[pos++];
    pos++; /* reserved */
    if (ni < 1 || ni > JT_MAX_DIM || nh < 1 || nh > JT_MAX_DIM || no < 1 || no > JT_MAX_DIM)
        return JT_ERR_DIM;

    jt_model_init(m, ni, nh, no);
    m->seed  = get_u16(img + pos); pos += 2;
    m->lr    = get_i16(img + pos); pos += 2;
    m->epoch = get_u16(img + pos); pos += 2;
    pos += 2; /* sample count */
    pos += 4; /* reserved */

    size_t need = pos
        + (size_t)nh * ni * 2 + (size_t)nh * 2
        + (size_t)no * nh * 2 + (size_t)no * 2 + 2;
    if (len < need) return JT_ERR_RANGE;

    for (int i = 0; i < nh; i++)
        for (int j = 0; j < ni; j++) {
            m->w1[i][j] = get_i16(img + pos); pos += 2;
        }
    for (int i = 0; i < nh; i++) {
        m->b1[i] = get_i16(img + pos); pos += 2;
    }
    for (int i = 0; i < no; i++)
        for (int j = 0; j < nh; j++) {
            m->w2[i][j] = get_i16(img + pos); pos += 2;
        }
    for (int i = 0; i < no; i++) {
        m->b2[i] = get_i16(img + pos); pos += 2;
    }

    uint16_t stored = get_u16(img + pos);
    uint16_t calc   = jt_fletcher16(img, pos);
    if (stored != calc) return JT_ERR_CHECKSUM;
    m->checksum = stored;
    return JT_OK;
}
