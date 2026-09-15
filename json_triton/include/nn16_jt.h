/* NN/16 JSON-Triton — public header
 * Hand-rolled JSON tokenizer + parser + serializer
 * Triton-inspired inference interface
 * No external libraries beyond libc
 */
#ifndef NN16_JT_H
#define NN16_JT_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

/* ------------------------------------------------------------------ */
/* Status codes */
/* ------------------------------------------------------------------ */
typedef enum {
    JT_OK               = 0,
    JT_ERR_NOMEM        = 1,
    JT_ERR_SYNTAX       = 2,
    JT_ERR_TYPE         = 3,
    JT_ERR_RANGE        = 4,
    JT_ERR_NOTFOUND     = 5,
    JT_ERR_CHECKSUM     = 6,
    JT_ERR_DIM          = 7,
    JT_ERR_NULL         = 8,
    JT_ERR_OVERFLOW     = 9,
    JT_ERR_IO           = 10,
    JT_ERR_UNSUPPORTED  = 11
} jt_status_t;

const char *jt_status_str(jt_status_t s);

/* ------------------------------------------------------------------ */
/* Constants */
/* ------------------------------------------------------------------ */
#define JT_ARENA_SIZE       (128 * 1024)
#define JT_MAX_DIM          16
#define JT_ACT_MAX          255
#define JT_ACT_MIN          (-256)
#define JT_MODEL_MAGIC      0x314E   /* 'N','1' little-endian */
#define JT_REPO_MAX_MODELS  8
#define JT_NAME_LEN         64

/* ------------------------------------------------------------------ */
/* Arena allocator */
/* ------------------------------------------------------------------ */
typedef struct {
    uint8_t mem[JT_ARENA_SIZE];
    size_t  used;
} jt_arena_t;

void  jt_arena_init(jt_arena_t *a);
void *jt_arena_alloc(jt_arena_t *a, size_t n, size_t align);
void  jt_arena_reset(jt_arena_t *a);

/* ------------------------------------------------------------------ */
/* Model */
/* ------------------------------------------------------------------ */
typedef struct {
    int n_input;
    int n_hidden;
    int n_output;
    int16_t w1[JT_MAX_DIM][JT_MAX_DIM]; /* hidden x input */
    int16_t b1[JT_MAX_DIM];
    int16_t w2[JT_MAX_DIM][JT_MAX_DIM]; /* output x hidden */
    int16_t b2[JT_MAX_DIM];
    uint16_t seed;
    int16_t  lr;
    uint16_t epoch;
    uint16_t checksum;
} jt_model_t;

static inline void jt_model_init(jt_model_t *m, int ni, int nh, int no) {
    int i, j;
    m->n_input = ni; m->n_hidden = nh; m->n_output = no;
    m->seed = 1; m->lr = 16; m->epoch = 0; m->checksum = 0;
    for (i = 0; i < nh; i++) {
        for (j = 0; j < ni; j++) m->w1[i][j] = 0;
        m->b1[i] = 0;
    }
    for (i = 0; i < no; i++) {
        for (j = 0; j < nh; j++) m->w2[i][j] = 0;
        m->b2[i] = 0;
    }
}

jt_status_t jt_model_validate(const jt_model_t *m);
void        jt_model_init_lfsr(jt_model_t *m, uint16_t seed);
void        jt_forward(const jt_model_t *m, const int16_t *x,
                       int16_t *h, int16_t *o);

/* ------------------------------------------------------------------ */
/* Numerical primitives */
/* ------------------------------------------------------------------ */
int16_t  jt_fxmul(int16_t a, int16_t b);
int16_t  jt_satadd(int16_t a, int16_t b);
int16_t  jt_act(int16_t x);
int16_t  jt_dotproduct(const int16_t *a, const int16_t *b, int n);
uint16_t jt_fletcher16(const uint8_t *data, size_t len);

/* ------------------------------------------------------------------ */
/* JSON tokenizer */
/* ------------------------------------------------------------------ */
typedef enum {
    JT_TOK_LBRACE, JT_TOK_RBRACE,
    JT_TOK_LBRACKET, JT_TOK_RBRACKET,
    JT_TOK_COLON, JT_TOK_COMMA,
    JT_TOK_STRING, JT_TOK_NUMBER,
    JT_TOK_TRUE, JT_TOK_FALSE, JT_TOK_NULL,
    JT_TOK_EOF, JT_TOK_ERROR
} jt_tok_kind_t;

typedef struct {
    jt_tok_kind_t kind;
    const char   *start;
    size_t        len;
    int64_t       number;
} jt_tok_t;

typedef struct {
    const char *src;
    size_t      len;
    size_t      pos;
    jt_tok_t    tok;
    jt_arena_t *arena;
} jt_parser_t;

void        jt_parser_init(jt_parser_t *p, const char *src, size_t len, jt_arena_t *arena);
jt_status_t jt_parser_next(jt_parser_t *p);

/* ------------------------------------------------------------------ */
/* Model JSON serialization */
/* ------------------------------------------------------------------ */
jt_status_t jt_model_to_json(jt_arena_t *arena, const jt_model_t *m,
                              char *buf, size_t bufsize, size_t *written);
jt_status_t jt_model_from_json(jt_arena_t *arena, const char *json,
                                size_t len, jt_model_t *m);

/* ------------------------------------------------------------------ */
/* Model binary serialization */
/* ------------------------------------------------------------------ */
jt_status_t jt_model_to_binary(const jt_model_t *m, uint8_t *img,
                                size_t imgsize, size_t *written);
jt_status_t jt_model_from_binary(const uint8_t *img, size_t len,
                                  jt_model_t *m);

/* ------------------------------------------------------------------ */
/* Triton-style inference */
/* ------------------------------------------------------------------ */
typedef struct {
    char     name[JT_NAME_LEN];
    int      dim;
    int16_t  data[JT_MAX_DIM];
} jt_tensor_t;

typedef struct {
    char        model_name[JT_NAME_LEN];
    jt_tensor_t inputs[4];
    int         n_inputs;
} jt_infer_request_t;

typedef struct {
    jt_tensor_t  outputs[4];
    int          n_outputs;
    jt_status_t  status;
} jt_infer_response_t;

typedef struct {
    jt_model_t model;
    char       name[JT_NAME_LEN];
    bool       loaded;
} jt_model_entry_t;

typedef struct {
    jt_model_entry_t entries[JT_REPO_MAX_MODELS];
    int              count;
    jt_arena_t       arena;
} jt_repo_t;

void        jt_repo_init(jt_repo_t *repo);
jt_status_t jt_repo_load_json(jt_repo_t *repo, const char *name,
                               const char *json, size_t len);
jt_status_t jt_repo_load_binary(jt_repo_t *repo, const char *name,
                                 const uint8_t *img, size_t len);
jt_status_t jt_repo_unload(jt_repo_t *repo, const char *name);
jt_model_entry_t *jt_repo_find(jt_repo_t *repo, const char *name);

jt_status_t jt_infer(jt_repo_t *repo, const jt_infer_request_t *req,
                      jt_infer_response_t *resp);
jt_status_t jt_infer_simple(const jt_model_t *m, const int16_t x[4],
                              int16_t *out);

/* ------------------------------------------------------------------ */
/* Golden tests */
/* ------------------------------------------------------------------ */
bool jt_test_fxmul(void);
bool jt_test_satadd(void);
bool jt_test_act(void);
bool jt_test_dotproduct(void);
bool jt_test_forward(void);
bool jt_test_json_roundtrip(void);
bool jt_test_binary_roundtrip(void);
bool jt_run_all_golden(void);

#endif /* NN16_JT_H */
