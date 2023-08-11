
#include <stdlib.h>
#include <uv.h>
#include "miniio.h"

/* Context */
struct miniio_uv_event_s {
    struct miniio_uv_event_s* prev; /* (C + E) */
    struct miniio_uv_event_s* next; /* (C + E) */
};

static void
freeevent(struct miniio_uv_event_s* ev){
    if(ev->prev){
        ev->prev->next = ev->next;
    }
    if(ev->next){
        ev->next->prev = ev->prev;
    }
    free(ev);
}

struct miniio_uv_ctx_s {
    uv_loop_t loop;
    /* C: Context lock */
    uv_mutex_t mtx_ctx;

    /* Wakeup handler */
    miniio_wakeup_routine wakeup;
    void* wakeup_ctx;

    /* Termination flag */
    int terminating; /* (C) */

    /* Event chain */
    struct miniio_uv_event* first; /* (C) */
    struct miniio_uv_event* last; /* (C) */
};

/* I/O Context (No NCCC export) */
int 
miniio_ioctx_create(miniio_wakeup_routine wakeup, void* wakeup_ctx, 
                    void** out_ctx){
    int r;
    struct miniio_uv_ctx_s* ctx;
    ctx = malloc(sizeof(struct miniio_uv_ctx_s));
    if(! ctx){
        goto fail0;
    }
    r = uv_loop_init(&ctx->loop);
    if(r){
        goto fail1;
    }
    r = uv_mutex_init(&ctx->mtx_ctx);
    if(r){
        goto fail2;
    }

    ctx->wakeup = wakeup;
    ctx->wakeup_ctx = wakeup_ctx;
    ctx->terminating = 0;
    ctx->first = ctx->last = 0;

    *out_ctx = ctx;
    return 0;

fail2:
    r = uv_loop_close(&ctx->loop);
    if(r){
        abort(); /* Should never happen */
    }
fail1:
    free(ctx);
fail0:
    return 1;
}

int 
miniio_ioctx_process(void* pctx){
    int r;
    struct miniio_uv_ctx_s* ctx = (struct miniio_uv_ctx_s*)pctx;
    r = uv_run(ctx->loop, UV_RUN_DEFAULT);
    if(r){
        /* We still have some active handles */
        return 1;
    }
    return 0;
}

void 
miniio_ioctx_lock(void* pctx){
    struct miniio_uv_ctx_s* ctx = (struct miniio_uv_ctx_s*)pctx;
    uv_mutex_lock(&ctx->mtx_ctx);
}

void 
miniio_ioctx_unlock(void* pctx){
    struct miniio_uv_ctx_s* ctx = (struct miniio_uv_ctx_s*)pctx;
    uv_mutex_unlock(&ctx->mtx_ctx);
}

void 
miniio_ioctx_terminate(void* pctx){
    int r;
    struct miniio_uv_ctx_s* ctx = (struct miniio_uv_ctx_s*)pctx;
    struct miniio_uv_event_s* ev;
    uv_mutex_lock(&ctx->mtx_ctx);
    ctx->terminating = 1;
    uv_mutex_unlock(&ctx->mtx_ctx);

    r = uv_loop_close(&ctx->loop);
    if(r){
        /* FIXME: Wait for in-flight callbacks exit */
        abort();
    }
    uv_mutex_lock(&ctx->mtx_ctx);
    /* So we made sure noone will enqueue/dequeue events now */
    while(ctx->first){
        ev = ctx->first->next;
        freeevent(ctx->first);
        ctx->first = ev;
    }
    uv_mutex_unlock(&ctx->mtx_ctx);
    uv_mutex_destroy(&ctx->mtx_ctx);
    free(ctx);
}


/* Context, Eventqueue */
int miniio_get_events(void* ctx, uint64_t* buf, int bufcount);

/* Sleep */
int miniio_timeout(void* ctx, uint32_t ms);

/* TCP(Network stream) */
void* miniio_net_param_create(void* ctx, void* userdata);
void miniio_net_param_destroy(void* ctx, void* param);
int miniio_net_param_hostname(void* ctx, void* param, const char* hostname);
int miniio_net_param_port(void* ctx, void* param, int port);
void* miniio_tcp_listen(void* ctx, void* param);
void* miniio_tcp_connect(void* ctx, void* param);

/* Process */
void* miniio_process_param_create(void* ctx, const char* execpath,
                                  void* userdata);
void miniio_process_param_destroy(void* ctx, void* param);
int miniio_process_param_workdir(void* ctx, void* param, const char* dir);
int miniio_process_param_args(void* ctx, void* argv, int argc);
int miniio_process_param_stdin(void* ctx, void* pipe);
int miniio_process_param_stdout(void* ctx, void* pipe);
int miniio_process_param_stderr(void* ctx, void* pipe);
void* miniio_process_spawn(void* ctx, void* param);
int miniio_process_abort(void* ctx, void* handle);
void* miniio_pipe_new(void* ctx, void* userdata);
void miniio_pipe_destroy(void* ctx, void* pipe);

/* Stream I/O */
void miniio_close(void* ctx, void* stream);
void* miniio_buffer_create(void* ctx, uintptr_t size, void* userdata);
void miniio_buffer_destroy(void* ctx, void* handle);
void* miniio_buffer_lock(void* ctx, void* handle);
void miniio_buffer_unlock(void* ctx, void* handle);
int miniio_write(void* ctx, void* stream, void* buffer, uintptr_t offset,
                 uintptr_t len);
int miniio_read(void* ctx, void* stream);


