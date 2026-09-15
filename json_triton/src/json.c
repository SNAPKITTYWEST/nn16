/* ============================================================
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Copyright (c) 2026 SnapKittyWest
 * Ahmad Ali Parr / Bel Esprit D'Accord Irrevocable Trust
 * CLONE GATE: Any clone, fork, or derivative of this node
 * MUST be released under GPL-3.0-or-later. No closed-source use.
 * ============================================================ */
/* NN/16 JSON-Triton — Hand-rolled JSON tokenizer + recursive descent parser */
#include "nn16_jt.h"
#include <ctype.h>
#include <string.h>
#include <stdio.h>

static void skip_ws(jt_parser_t *p) {
    while (p->pos < p->len) {
        char c = p->src[p->pos];
        if (c == ' ' || c == '\t' || c == '\n' || c == '\r') p->pos++;
        else break;
    }
}

static int match_kw(jt_parser_t *p, const char *kw, size_t klen) {
    if (p->pos + klen > p->len) return 0;
    if (memcmp(p->src + p->pos, kw, klen) != 0) return 0;
    if (p->pos + klen < p->len) {
        char n = p->src[p->pos + klen];
        if (isalnum((unsigned char)n) || n == '_') return 0;
    }
    return 1;
}

jt_status_t jt_parser_next(jt_parser_t *p) {
    skip_ws(p);
    if (p->pos >= p->len) {
        p->tok.kind = JT_TOK_EOF;
        p->tok.start = p->src + p->pos;
        p->tok.len = 0;
        return JT_OK;
    }

    const char *s = p->src + p->pos;
    char c = *s;

    if (c=='{'){p->tok.kind=JT_TOK_LBRACE;  p->tok.start=s;p->tok.len=1;p->pos++;return JT_OK;}
    if (c=='}'){p->tok.kind=JT_TOK_RBRACE;  p->tok.start=s;p->tok.len=1;p->pos++;return JT_OK;}
    if (c=='['){p->tok.kind=JT_TOK_LBRACKET;p->tok.start=s;p->tok.len=1;p->pos++;return JT_OK;}
    if (c==']'){p->tok.kind=JT_TOK_RBRACKET;p->tok.start=s;p->tok.len=1;p->pos++;return JT_OK;}
    if (c==':'){p->tok.kind=JT_TOK_COLON;   p->tok.start=s;p->tok.len=1;p->pos++;return JT_OK;}
    if (c==','){p->tok.kind=JT_TOK_COMMA;   p->tok.start=s;p->tok.len=1;p->pos++;return JT_OK;}

    if (c == '"') {
        p->pos++;
        size_t start = p->pos;
        while (p->pos < p->len) {
            char ch = p->src[p->pos];
            if (ch == '\\') { p->pos += 2; if (p->pos > p->len) return JT_ERR_SYNTAX; continue; }
            if (ch == '"') break;
            p->pos++;
        }
        if (p->pos >= p->len) return JT_ERR_SYNTAX;
        p->tok.kind = JT_TOK_STRING;
        p->tok.start = p->src + start;
        p->tok.len = p->pos - start;
        p->pos++;
        return JT_OK;
    }

    if (c == '-' || isdigit((unsigned char)c)) {
        size_t start = p->pos;
        int neg = 0;
        if (c == '-') { neg = 1; p->pos++; }
        if (p->pos >= p->len || !isdigit((unsigned char)p->src[p->pos])) return JT_ERR_SYNTAX;
        int64_t val = 0;
        while (p->pos < p->len && isdigit((unsigned char)p->src[p->pos])) {
            int d = p->src[p->pos] - '0';
            if (val > (9007199254740991 - d) / 10) return JT_ERR_OVERFLOW;
            val = val * 10 + d;
            p->pos++;
        }
        if (neg) val = -val;
        p->tok.kind = JT_TOK_NUMBER;
        p->tok.start = p->src + start;
        p->tok.len = p->pos - start;
        p->tok.number = val;
        return JT_OK;
    }

    if (match_kw(p,"true",4)) { p->tok.kind=JT_TOK_TRUE; p->tok.start=s;p->tok.len=4;p->pos+=4;return JT_OK; }
    if (match_kw(p,"false",5)){p->tok.kind=JT_TOK_FALSE;p->tok.start=s;p->tok.len=5;p->pos+=5;return JT_OK; }
    if (match_kw(p,"null",4)) { p->tok.kind=JT_TOK_NULL; p->tok.start=s;p->tok.len=4;p->pos+=4;return JT_OK; }

    p->tok.kind = JT_TOK_ERROR;
    return JT_ERR_SYNTAX;
}

void jt_parser_init(jt_parser_t *p, const char *src, size_t len, jt_arena_t *arena) {
    p->src = src;
    p->len = len;
    p->pos = 0;
    p->arena = arena;
    memset(&p->tok, 0, sizeof(p->tok));
}

/* ---- key match helper ---- */
static int key_eq(const jt_tok_t *t, const char *key) {
    size_t kl = strlen(key);
    return t->len == kl && memcmp(t->start, key, kl) == 0;
}

/* ---- parse a JSON integer array into buf[max] ---- */
static jt_status_t parse_int_array(jt_parser_t *p, int16_t *buf, int max, int *count) {
    jt_status_t st;
    if ((st = jt_parser_next(p)) != JT_OK) return st;
    if (p->tok.kind != JT_TOK_LBRACKET) return JT_ERR_SYNTAX;
    *count = 0;
    for (;;) {
        if ((st = jt_parser_next(p)) != JT_OK) return st;
        if (p->tok.kind == JT_TOK_RBRACKET) break;
        if (p->tok.kind != JT_TOK_NUMBER) return JT_ERR_TYPE;
        if (*count >= max) return JT_ERR_OVERFLOW;
        buf[(*count)++] = (int16_t)p->tok.number;
        if ((st = jt_parser_next(p)) != JT_OK) return st;
        if (p->tok.kind == JT_TOK_RBRACKET) break;
        if (p->tok.kind != JT_TOK_COMMA) return JT_ERR_SYNTAX;
    }
    return JT_OK;
}

/* ---- parse model from JSON ---- */
jt_status_t jt_model_from_json(jt_arena_t *arena, const char *json, size_t len, jt_model_t *m) {
    (void)arena;
    jt_parser_t p;
    jt_parser_init(&p, json, len, arena);
    jt_status_t st;

    if ((st = jt_parser_next(&p)) != JT_OK) return st;
    if (p.tok.kind != JT_TOK_LBRACE) return JT_ERR_SYNTAX;

    int ni = 0, nh = 0, no = 0;
    jt_model_t tmp; memset(&tmp, 0, sizeof(tmp));

    for (;;) {
        if ((st = jt_parser_next(&p)) != JT_OK) return st;
        if (p.tok.kind == JT_TOK_RBRACE) break;
        if (p.tok.kind != JT_TOK_STRING) return JT_ERR_SYNTAX;

        jt_tok_t key = p.tok;
        if ((st = jt_parser_next(&p)) != JT_OK) return st;
        if (p.tok.kind != JT_TOK_COLON) return JT_ERR_SYNTAX;

        if (key_eq(&key, "n_input")) {
            if ((st = jt_parser_next(&p)) != JT_OK) return st;
            ni = (int)p.tok.number; tmp.n_input = ni;
        } else if (key_eq(&key, "n_hidden")) {
            if ((st = jt_parser_next(&p)) != JT_OK) return st;
            nh = (int)p.tok.number; tmp.n_hidden = nh;
        } else if (key_eq(&key, "n_output")) {
            if ((st = jt_parser_next(&p)) != JT_OK) return st;
            no = (int)p.tok.number; tmp.n_output = no;
        } else if (key_eq(&key, "seed")) {
            if ((st = jt_parser_next(&p)) != JT_OK) return st;
            tmp.seed = (uint16_t)p.tok.number;
        } else if (key_eq(&key, "lr")) {
            if ((st = jt_parser_next(&p)) != JT_OK) return st;
            tmp.lr = (int16_t)p.tok.number;
        } else if (key_eq(&key, "epoch")) {
            if ((st = jt_parser_next(&p)) != JT_OK) return st;
            tmp.epoch = (uint16_t)p.tok.number;
        } else if (key_eq(&key, "w1")) {
            /* 2D array: [[row0], [row1], ...] */
            if ((st = jt_parser_next(&p)) != JT_OK) return st;
            if (p.tok.kind != JT_TOK_LBRACKET) return JT_ERR_SYNTAX;
            for (int i = 0; i < nh; i++) {
                int cnt = 0;
                if ((st = jt_parser_next(&p)) != JT_OK) return st;
                if (p.tok.kind == JT_TOK_RBRACKET) break;
                /* expect '[' already consumed as start of row from comma or opening */
                if (p.tok.kind == JT_TOK_LBRACKET) {
                    /* read row */
                    for (int j = 0; j < ni; j++) {
                        if ((st = jt_parser_next(&p)) != JT_OK) return st;
                        if (p.tok.kind != JT_TOK_NUMBER) return JT_ERR_SYNTAX;
                        tmp.w1[i][j] = (int16_t)p.tok.number;
                        if ((st = jt_parser_next(&p)) != JT_OK) return st;
                        if (p.tok.kind == JT_TOK_RBRACKET) break;
                        if (p.tok.kind != JT_TOK_COMMA) return JT_ERR_SYNTAX;
                    }
                    if ((st = jt_parser_next(&p)) != JT_OK) return st;
                    if (p.tok.kind == JT_TOK_RBRACKET) break;
                    if (p.tok.kind != JT_TOK_COMMA) return JT_ERR_SYNTAX;
                } else if (p.tok.kind == JT_TOK_COMMA) i--;
                else return JT_ERR_SYNTAX;
                (void)cnt;
            }
        } else if (key_eq(&key, "b1")) {
            int cnt = 0;
            if ((st = parse_int_array(&p, tmp.b1, JT_MAX_DIM, &cnt)) != JT_OK) return st;
        } else if (key_eq(&key, "b2")) {
            int cnt = 0;
            if ((st = parse_int_array(&p, tmp.b2, JT_MAX_DIM, &cnt)) != JT_OK) return st;
        } else {
            /* skip unknown value */
            if ((st = jt_parser_next(&p)) != JT_OK) return st;
        }

        if ((st = jt_parser_next(&p)) != JT_OK) return st;
        if (p.tok.kind == JT_TOK_RBRACE) break;
        if (p.tok.kind != JT_TOK_COMMA) return JT_ERR_SYNTAX;
    }

    *m = tmp;
    return JT_OK;
}

/* ---- stringify model to JSON ---- */
jt_status_t jt_model_to_json(jt_arena_t *arena, const jt_model_t *m,
                              char *buf, size_t bufsize, size_t *written) {
    (void)arena;
    if (!m || !buf) return JT_ERR_NULL;

    int pos = 0;
    int rem = (int)bufsize - 1;

#define JAPPEND(...) do { \
    int n = snprintf(buf + pos, (size_t)(rem - pos + 1), __VA_ARGS__); \
    if (n < 0 || n > rem - pos) return JT_ERR_OVERFLOW; \
    pos += n; \
} while(0)

    JAPPEND("{\"n_input\":%d,\"n_hidden\":%d,\"n_output\":%d",
            m->n_input, m->n_hidden, m->n_output);
    JAPPEND(",\"seed\":%u,\"lr\":%d,\"epoch\":%u",
            m->seed, m->lr, m->epoch);

    JAPPEND(",\"w1\":[");
    for (int i = 0; i < m->n_hidden; i++) {
        if (i) JAPPEND(",");
        JAPPEND("[");
        for (int j = 0; j < m->n_input; j++) {
            if (j) JAPPEND(",");
            JAPPEND("%d", m->w1[i][j]);
        }
        JAPPEND("]");
    }
    JAPPEND("]");

    JAPPEND(",\"b1\":[");
    for (int i = 0; i < m->n_hidden; i++) {
        if (i) JAPPEND(",");
        JAPPEND("%d", m->b1[i]);
    }
    JAPPEND("]");

    JAPPEND(",\"w2\":[");
    for (int i = 0; i < m->n_output; i++) {
        if (i) JAPPEND(",");
        JAPPEND("[");
        for (int j = 0; j < m->n_hidden; j++) {
            if (j) JAPPEND(",");
            JAPPEND("%d", m->w2[i][j]);
        }
        JAPPEND("]");
    }
    JAPPEND("]");

    JAPPEND(",\"b2\":[");
    for (int i = 0; i < m->n_output; i++) {
        if (i) JAPPEND(",");
        JAPPEND("%d", m->b2[i]);
    }
    JAPPEND("]}");
#undef JAPPEND

    buf[pos] = '\0';
    if (written) *written = (size_t)pos;
    return JT_OK;
}
