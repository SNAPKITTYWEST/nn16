/* ============================================================
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Copyright (c) 2026 SnapKittyWest
 * Ahmad Ali Parr / Bel Esprit D'Accord Irrevocable Trust
 * CLONE GATE: Any clone, fork, or derivative of this node
 * MUST be released under GPL-3.0-or-later. No closed-source use.
 * ============================================================ */
/* NN/16 JSON-Triton — Model repository + Triton-style inference */
#include "nn16_jt.h"
#include <string.h>
#include <stdio.h>

void jt_repo_init(jt_repo_t *repo) {
    memset(repo, 0, sizeof(*repo));
    jt_arena_init(&repo->arena);
}

static jt_model_entry_t *repo_slot(jt_repo_t *repo, const char *name) {
    for (int i = 0; i < repo->count; i++)
        if (strcmp(repo->entries[i].name, name) == 0)
            return &repo->entries[i];
    if (repo->count >= JT_REPO_MAX_MODELS) return NULL;
    jt_model_entry_t *e = &repo->entries[repo->count++];
    memset(e, 0, sizeof(*e));
    strncpy(e->name, name, JT_NAME_LEN - 1);
    return e;
}

jt_model_entry_t *jt_repo_find(jt_repo_t *repo, const char *name) {
    for (int i = 0; i < repo->count; i++)
        if (repo->entries[i].loaded && strcmp(repo->entries[i].name, name) == 0)
            return &repo->entries[i];
    return NULL;
}

jt_status_t jt_repo_load_json(jt_repo_t *repo, const char *name,
                               const char *json, size_t len) {
    if (!repo || !name || !json) return JT_ERR_NULL;
    jt_model_entry_t *e = repo_slot(repo, name);
    if (!e) return JT_ERR_OVERFLOW;
    jt_arena_reset(&repo->arena);
    jt_status_t st = jt_model_from_json(&repo->arena, json, len, &e->model);
    if (st != JT_OK) return st;
    st = jt_model_validate(&e->model);
    if (st != JT_OK) return st;
    e->loaded = true;
    return JT_OK;
}

jt_status_t jt_repo_load_binary(jt_repo_t *repo, const char *name,
                                 const uint8_t *img, size_t len) {
    if (!repo || !name || !img) return JT_ERR_NULL;
    jt_model_entry_t *e = repo_slot(repo, name);
    if (!e) return JT_ERR_OVERFLOW;
    jt_status_t st = jt_model_from_binary(img, len, &e->model);
    if (st != JT_OK) return st;
    e->loaded = true;
    return JT_OK;
}

jt_status_t jt_repo_unload(jt_repo_t *repo, const char *name) {
    for (int i = 0; i < repo->count; i++)
        if (strcmp(repo->entries[i].name, name) == 0) {
            repo->entries[i].loaded = false;
            return JT_OK;
        }
    return JT_ERR_NOTFOUND;
}

jt_status_t jt_infer(jt_repo_t *repo, const jt_infer_request_t *req,
                      jt_infer_response_t *resp) {
    if (!repo || !req || !resp) return JT_ERR_NULL;
    memset(resp, 0, sizeof(*resp));

    jt_model_entry_t *e = jt_repo_find(repo, req->model_name);
    if (!e) { resp->status = JT_ERR_NOTFOUND; return JT_ERR_NOTFOUND; }

    const jt_model_t *m = &e->model;
    if (req->n_inputs < 1) { resp->status = JT_ERR_DIM; return JT_ERR_DIM; }
    const jt_tensor_t *tin = &req->inputs[0];
    if (tin->dim != m->n_input) { resp->status = JT_ERR_DIM; return JT_ERR_DIM; }

    int16_t h[JT_MAX_DIM];
    int16_t o[JT_MAX_DIM];
    jt_forward(m, tin->data, h, o);

    resp->n_outputs = 1;
    strncpy(resp->outputs[0].name, "OUTPUT", JT_NAME_LEN - 1);
    resp->outputs[0].dim = m->n_output;
    for (int i = 0; i < m->n_output; i++)
        resp->outputs[0].data[i] = o[i];

    resp->status = JT_OK;
    return JT_OK;
}

jt_status_t jt_infer_simple(const jt_model_t *m, const int16_t x[4], int16_t *out) {
    if (!m || !x || !out) return JT_ERR_NULL;
    if (m->n_input != 4) return JT_ERR_DIM;
    int16_t h[JT_MAX_DIM];
    int16_t o[JT_MAX_DIM];
    jt_forward(m, x, h, o);
    *out = o[0];
    return JT_OK;
}
