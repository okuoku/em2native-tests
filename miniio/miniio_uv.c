#include <stdlib.h>
#include <string.h>
#include <uv.h>
#include "miniio.h"

/* Context */
struct miniio_uv_event_s {
    struct miniio_uv_event_s* prev;
    struct miniio_uv_event_s* next;
    uintptr_t* event;
    size_t eventlen;
};

struct miniio_uv_ctx_s {
    uv_loop_t loop;
    /* Wakeup handler */
    miniio_wakeup_routine wakeup;
    void* wakeup_ctx;

    /* Termination flag */
    int terminating;

    /* Event chain */
    struct miniio_uv_event_s* first;
    struct miniio_uv_event_s* last;
    size_t total_queued_event_len;
};


static void
addevent(struct miniio_uv_ctx_s* ctx, uintptr_t* event){
    /* Add to `last */
    struct miniio_uv_event_s* ev;
    uintptr_t* msg;
    uintptr_t len;
    len = msg[0];
    ev = malloc(sizeof(struct miniio_uv_event_s));
    if(! ev){
        abort();
    }
    msg = malloc(sizeof(uintptr_t) * len);
    if(! msg){
        abort();
    }
    memcpy(msg, event, sizeof(uintptr_t) * len);
    ev->event = msg;
    ev->eventlen = len;
    ev->prev = ctx->last;
    ev->next = 0;
    ctx->total_queued_event_len += len;
    ctx->last = ev;
    if(! ctx->first){
        ctx->first = ev;
    }
}

static void
delevent(struct miniio_uv_ctx_s* ctx){
    struct miniio_uv_event_s* ev;
    /* Remove from `first` */
    if(ctx->first){
        ev = ctx->first;
        ctx->first = ev->next;
        if(ctx->last == ev){
            ctx->last = 0;
        }
        if(ev->prev){
            abort();
        }
        if(ev->next){
            ev->next->prev = 0;
        }
        ctx->total_queued_event_len -= ev->eventlen;
        free(ev->event);
        free(ev);
    }else{
        abort();
    }
}



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

    ctx->wakeup = wakeup;
    ctx->wakeup_ctx = wakeup_ctx;
    ctx->terminating = 0;
    ctx->first = ctx->last = 0;
    ctx->total_queued_event_len = 0;

    *out_ctx = ctx;
    return 0;

fail1:
    free(ctx);
fail0:
    return 1;
}

int 
miniio_ioctx_process(void* pctx){
    int r;
    struct miniio_uv_ctx_s* ctx = (struct miniio_uv_ctx_s*)pctx;
    r = uv_run(&ctx->loop, UV_RUN_DEFAULT);
    if(r){
        /* We still have some active handles */
        return 1;
    }
    return 0;
}

void 
miniio_ioctx_terminate(void* pctx){
    int r;
    struct miniio_uv_ctx_s* ctx = (struct miniio_uv_ctx_s*)pctx;
    struct miniio_uv_event_s* ev;
    ctx->terminating = 1;

    r = uv_loop_close(&ctx->loop);
    if(r){
        /* FIXME: Wait for in-flight callbacks exit */
        abort();
    }
    /* So we made sure noone will enqueue/dequeue events now */
    while(ctx->first){
        delevent(ctx);
    }
    free(ctx);
}


/* Context, Eventqueue */
int 
miniio_get_events(void* pctx, uintptr_t* buf, uint32_t bufcount, 
                  uint32_t* out_written,
                  uint32_t* out_current){
    struct miniio_uv_ctx_s* ctx = (struct miniio_uv_ctx_s*)pctx;
    uint32_t cur = 0;
    uint32_t res;
    uintptr_t len;
    while(ctx->first){
        len = ctx->first->event[0];
        if(cur + len > bufcount){
            break;
        }
        memcpy(&buf[cur], ctx->first->event, sizeof(uintptr_t)*len);
        cur += len;
        delevent(ctx);
    }
    *out_written = cur;
    *out_current = ctx->total_queued_event_len;
    return 0;
}

/* Timer */
struct miniio_uv_timer_s { /* for libuv userdata */
    struct miniio_uv_ctx_s* ctx;
    void* userdata;
    uv_timer_t timer;
};

void* 
miniio_timer_create(void* pctx, void* userdata){
    struct miniio_uv_ctx_s* ctx = (struct miniio_uv_ctx_s*)pctx;
    struct miniio_uv_timer_s* h;
    int r;
    h = malloc(sizeof(struct miniio_uv_timer_s));
    if(! h){
        return 0;
    }
    r = uv_timer_init(&ctx->loop, &h->timer);
    if(r){
        free(h);
        return 0;
    }
    h->timer.data = h;
    h->userdata = userdata;
    h->ctx = ctx;
    return h;
}

static void
cb_timer_close(uv_handle_t* uhandle){
    struct miniio_uv_timer_s* h = (struct miniio_uv_timer_s*)uhandle->data;
    uintptr_t ev[4];
    /* [4 0(handle-close) handle userdata] */
    ev[0] = 4;
    ev[1] = 0;
    ev[2] = (uintptr_t)h;
    ev[3] = (uintptr_t)h->userdata;
    addevent(h->ctx, ev);

    free(h);
}

void 
miniio_timer_destroy(void* pctx, void* phandle){
    int r;
    struct miniio_uv_ctx_s* ctx = (struct miniio_uv_ctx_s*)pctx;
    struct miniio_uv_timer_s* h = (struct miniio_uv_timer_s*)phandle;

    uv_close((uv_handle_t*)&h->timer, cb_timer_close);
}

static void 
cb_timer_event(uv_timer_t* uhandle){
    struct miniio_uv_timer_s* h = (struct miniio_uv_timer_s*)uhandle->data;
    struct miniio_uv_ctx_s* ctx = h->ctx;
    uintptr_t ev[4];

    /* [4 1(timer) handle userdata] */
    ev[0] = 4;
    ev[1] = 1;
    ev[2] = (uintptr_t)h;
    ev[3] = (uintptr_t)h->userdata;
    addevent(ctx, ev);
}

int 
miniio_timer_start(void* pctx, void* phandle, uint64_t timeout,
                       uint64_t interval){
    int r;
    struct miniio_uv_timer_s* h = (struct miniio_uv_timer_s*)phandle;

    /* Request timeout */
    r = uv_timer_start(&h->timer, cb_timer_event, timeout, interval);
    if(r){
        return r;
    }
    return 0;
}

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
int miniio_start_read(void* ctx, void* stream);


