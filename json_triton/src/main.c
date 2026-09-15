/* ============================================================
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Copyright (c) 2026 SnapKittyWest
 * Ahmad Ali Parr / Bel Esprit D'Accord Irrevocable Trust
 * CLONE GATE: Any clone, fork, or derivative of this node
 * MUST be released under GPL-3.0-or-later. No closed-source use.
 * ============================================================ */
/* NN/16 JSON-Triton — standalone driver
 * Build: cc -O2 -Iinclude src/numerics.c src/json.c src/model.c src/infer.c src/tests.c src/main.c -o nn16_jt
 */
#include "nn16_jt.h"
#include <stdio.h>
#include <string.h>

static void demo_infer(void) {
    jt_repo_t repo;
    jt_repo_init(&repo);

    jt_model_t m;
    jt_model_init(&m, 4, 3, 1);
    jt_model_init_lfsr(&m, 1);

    jt_arena_t arena;
    jt_arena_init(&arena);
    char json[8192];
    size_t jlen = 0;
    if (jt_model_to_json(&arena, &m, json, sizeof(json), &jlen) != JT_OK) {
        printf("demo: stringify failed\n");
        return;
    }
    printf("Model JSON (%zu bytes):\n%.200s...\n\n", jlen, json);

    if (jt_repo_load_json(&repo, "nn16_demo", json, jlen) != JT_OK) {
        printf("demo: load failed\n");
        return;
    }

    jt_infer_request_t req;
    memset(&req, 0, sizeof(req));
    strncpy(req.model_name, "nn16_demo", JT_NAME_LEN - 1);
    req.n_inputs = 1;
    strncpy(req.inputs[0].name, "INPUT", JT_NAME_LEN - 1);
    req.inputs[0].dim = 4;
    req.inputs[0].data[0] = 100;
    req.inputs[0].data[1] = 50;
    req.inputs[0].data[2] = -30;
    req.inputs[0].data[3] = 10;

    jt_infer_response_t resp;
    if (jt_infer(&repo, &req, &resp) != JT_OK) {
        printf("demo: infer failed (%s)\n", jt_status_str(resp.status));
        return;
    }
    printf("Infer OUTPUT = %d\n", resp.outputs[0].data[0]);
}

int main(int argc, char **argv) {
    (void)argc; (void)argv;
    bool ok = jt_run_all_golden();
    printf("\n");
    demo_infer();
    return ok ? 0 : 1;
}
