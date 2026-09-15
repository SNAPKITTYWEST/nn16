/* NN/16 JSON-Triton — Golden tests matching Pascal / BASIC / 6502 */
#include "nn16_jt.h"
#include <stdio.h>
#include <string.h>

bool jt_test_fxmul(void) {
    bool ok = true;
    if (jt_fxmul( 300, 200) !=  234) { printf("FAIL FXMUL(300,200) got %d\n",  jt_fxmul( 300, 200)); ok=false; }
    if (jt_fxmul(-300, 200) != -234) { printf("FAIL FXMUL(-300,200) got %d\n", jt_fxmul(-300, 200)); ok=false; }
    if (jt_fxmul( 100, 100) !=   39) { printf("FAIL FXMUL(100,100) got %d\n",  jt_fxmul( 100, 100)); ok=false; }
    if (jt_fxmul(   0, 999) !=    0) { printf("FAIL FXMUL(0,999)\n"); ok=false; }
    if (jt_fxmul( 256, 256) !=  256) { printf("FAIL FXMUL(256,256) got %d\n",  jt_fxmul( 256, 256)); ok=false; }
    if (ok) printf("FXMUL OK\n");
    return ok;
}

bool jt_test_satadd(void) {
    bool ok = true;
    if (jt_satadd( 30000, 5000)   !=  32767) { printf("FAIL SATADD overflow\n"); ok=false; }
    if (jt_satadd(-30000,-5000)   != -32768) { printf("FAIL SATADD underflow\n"); ok=false; }
    if (jt_satadd( 20000, 10000)  !=  30000) { printf("FAIL SATADD normal\n"); ok=false; }
    if (jt_satadd(-20000,-10000)  != -30000) { printf("FAIL SATADD neg\n"); ok=false; }
    if (ok) printf("SATADD OK\n");
    return ok;
}

bool jt_test_act(void) {
    bool ok = true;
    if (jt_act( 200) !=  200) { printf("FAIL ACT 200\n"); ok=false; }
    if (jt_act( 300) !=  255) { printf("FAIL ACT 300\n"); ok=false; }
    if (jt_act(-300) != -256) { printf("FAIL ACT -300\n"); ok=false; }
    if (jt_act(   0) !=    0) { printf("FAIL ACT 0\n"); ok=false; }
    if (jt_act( 255) !=  255) { printf("FAIL ACT 255\n"); ok=false; }
    if (jt_act(-256) != -256) { printf("FAIL ACT -256\n"); ok=false; }
    if (jt_act( 256) !=  255) { printf("FAIL ACT 256\n"); ok=false; }
    if (jt_act(-257) != -256) { printf("FAIL ACT -257\n"); ok=false; }
    if (ok) printf("ACT OK\n");
    return ok;
}

bool jt_test_dotproduct(void) {
    int16_t a[4] = {1,2,3,4};
    int16_t b[4] = {5,6,7,8};
    int16_t r = jt_dotproduct(a, b, 4);
    if (r != 70) { printf("FAIL DotProduct got %d expect 70\n", r); return false; }
    printf("DotProduct OK\n");
    return true;
}

bool jt_test_forward(void) {
    jt_model_t m;
    jt_model_init(&m, 4, 3, 1);
    m.w1[0][0]=100; m.w1[1][1]=100; m.w1[2][2]=100;
    m.w2[0][0]=100; m.w2[0][1]=100; m.w2[0][2]=100;
    int16_t x[4] = {128, 128, 128, 0};
    int16_t h[3], o[1];
    jt_forward(&m, x, h, o);
    if (h[0]!=50 || h[1]!=50 || h[2]!=50 || o[0]!=57) {
        printf("FAIL Forward H=%d,%d,%d O=%d\n", h[0],h[1],h[2],o[0]);
        return false;
    }
    printf("Forward OK\n");
    return true;
}

bool jt_test_json_roundtrip(void) {
    jt_arena_t arena;
    jt_arena_init(&arena);
    jt_model_t m1, m2;
    jt_model_init(&m1, 4, 3, 1);
    m1.w1[0][0] = 42;
    m1.b2[0]    = -7;
    char buf[4096];
    size_t written = 0;
    if (jt_model_to_json(&arena, &m1, buf, sizeof(buf), &written) != JT_OK) {
        printf("FAIL json stringify\n"); return false;
    }
    jt_arena_reset(&arena);
    if (jt_model_from_json(&arena, buf, written, &m2) != JT_OK) {
        printf("FAIL json parse\n"); return false;
    }
    if (m2.w1[0][0]!=42 || m2.b2[0]!=-7 || m2.n_input!=4) {
        printf("FAIL json roundtrip values\n"); return false;
    }
    printf("JSON RT OK\n");
    return true;
}

bool jt_test_binary_roundtrip(void) {
    jt_model_t m1, m2;
    jt_model_init(&m1, 4, 3, 1);
    m1.w1[1][2] = 1234;
    m1.b1[2]    = -99;
    uint8_t img[128];
    size_t written = 0;
    if (jt_model_to_binary(&m1, img, sizeof(img), &written) != JT_OK) {
        printf("FAIL binary serialize\n"); return false;
    }
    if (jt_model_from_binary(img, written, &m2) != JT_OK) {
        printf("FAIL binary deserialize\n"); return false;
    }
    if (m2.w1[1][2] != 1234 || m2.b1[2] != -99) {
        printf("FAIL binary roundtrip values\n"); return false;
    }
    printf("Binary RT OK\n");
    return true;
}

static bool test_infer(void) {
    jt_repo_t repo;
    jt_repo_init(&repo);
    jt_model_t m;
    jt_model_init(&m, 4, 3, 1);
    jt_model_init_lfsr(&m, 1);
    jt_arena_t arena; jt_arena_init(&arena);
    char json[4096]; size_t jlen = 0;
    if (jt_model_to_json(&arena, &m, json, sizeof(json), &jlen) != JT_OK) {
        printf("FAIL infer json\n"); return false;
    }
    if (jt_repo_load_json(&repo, "m", json, jlen) != JT_OK) {
        printf("FAIL infer load\n"); return false;
    }
    jt_infer_request_t req; memset(&req, 0, sizeof(req));
    strncpy(req.model_name, "m", JT_NAME_LEN-1);
    req.n_inputs = 1;
    req.inputs[0].dim = 4;
    req.inputs[0].data[0]=64; req.inputs[0].data[1]=64;
    req.inputs[0].data[2]=64; req.inputs[0].data[3]=0;
    jt_infer_response_t resp;
    if (jt_infer(&repo, &req, &resp) != JT_OK) {
        printf("FAIL infer dispatch\n"); return false;
    }
    printf("Infer OK (output=%d)\n", resp.outputs[0].data[0]);
    return true;
}

bool jt_test_json_roundtrip(void);
bool jt_test_binary_roundtrip(void);

bool jt_run_all_golden(void) {
    bool ok = true;
    ok &= jt_test_fxmul();
    ok &= jt_test_satadd();
    ok &= jt_test_act();
    ok &= jt_test_dotproduct();
    ok &= jt_test_forward();
    ok &= jt_test_json_roundtrip();
    ok &= jt_test_binary_roundtrip();
    ok &= test_infer();
    if (ok) printf("ALL GOLDEN TESTS PASSED\n");
    else    printf("SOME TESTS FAILED\n");
    return ok;
}
