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
    len = event[0];
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
void*
miniio_ioctx_create(void){
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

    ctx->terminating = 0;
    ctx->first = ctx->last = 0;
    ctx->total_queued_event_len = 0;

    return ctx;

fail1:
    free(ctx);
fail0:
    return 0;
}

int 
miniio_ioctx_process(void* pctx){
    int r;
    struct miniio_uv_ctx_s* ctx = (struct miniio_uv_ctx_s*)pctx;
    r = uv_run(&ctx->loop, UV_RUN_ONCE);
    if(r){
        /* We still have some active handles */
        return 1;
    }
    /* No handles left */
    return 0;
}

void 
miniio_ioctx_destroy(void* pctx){
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
struct miniio_uv_netparam_s {
    struct miniio_uv_ctx_s* ctx;
    void* userdata;
    const char* hostname;
    int port;
    int has_addrinfo;
    union {
        uv_getaddrinfo_t gai;
        uv_req_t req;
    } as;
};

void* 
miniio_net_param_create(void* ctx, void* userdata){
    struct miniio_uv_netparam_s* np;

    np = malloc(sizeof(struct miniio_uv_netparam_s));
    if(! np){
        return 0;
    }

    np->ctx = (struct miniio_uv_ctx_s *)ctx;
    np->hostname = 0;
    np->port = 0;
    np->userdata = userdata;
    np->has_addrinfo = 0;
}

void 
miniio_net_param_destroy(void* ctx, void* param){
    struct miniio_uv_netparam_s* np = (struct miniio_uv_netparam_s *)param;
    (void) ctx;

    if(np->has_addrinfo){
        uv_freeaddrinfo(np->as.gai.addrinfo);
    }

    if(np->hostname){
        free((void*)np->hostname);
    }
    free(np);
}

int 
miniio_net_param_hostname(void* ctx, void* param, const char* hostname){
    size_t namelen;
    char* p;
    struct miniio_uv_netparam_s* np = (struct miniio_uv_netparam_s *)param;
    (void) ctx;

    if(np->hostname){
        free((void*)np->hostname);
        np->hostname = 0;
    }

    namelen = strnlen(hostname, 4096);
    p = malloc(namelen + 1);
    if(!p){
        return -1;
    }
    memcpy(p, hostname, namelen + 1);
    np->hostname = (const char*)p;
    return 0;
}

int 
miniio_net_param_port(void* ctx, void* param, int port){
    struct miniio_uv_netparam_s* np = (struct miniio_uv_netparam_s *)param;
    (void) ctx;
    np->port = port;
    return 0;
}

static void
cb_getaddrinfo(uv_getaddrinfo_t* req, int status, struct addrinfo *res){
    struct miniio_uv_netparam_s* np = (struct miniio_uv_netparam_s *)req->data;
    struct miniio_uv_ctx_s* ctx = np->ctx;
    uintptr_t ev[5];

    if(status == 0){
        np->has_addrinfo = 0;
    }

    /* [5 2(netresolve) handle userdata result] */
    ev[0] = 5;
    ev[1] = 2;
    ev[2] = (uintptr_t)np;
    ev[3] = (uintptr_t)np->userdata;
    ev[4] = status;

    addevent(ctx, ev);
}

int
miniio_net_param_name_resolve(void* pctx, void* param){
    struct miniio_uv_ctx_s* ctx = (struct miniio_uv_ctx_s*)pctx;
    struct miniio_uv_netparam_s* np = (struct miniio_uv_netparam_s *)param;
    int r;

    if(np->has_addrinfo){
        uv_freeaddrinfo(np->as.gai.addrinfo);
        np->has_addrinfo = 0;
    }

    np->as.req.data = param;
    r = uv_getaddrinfo(&ctx->loop, &np->as.gai, cb_getaddrinfo,
                       np->hostname, 0, 0);

    if(r){
        return r;
    }
    return 0;
}

static struct addrinfo*
select_addrinfo(struct miniio_uv_netparam_s* np, uint32_t idx){
    uint32_t r;
    struct addrinfo* cur;
    if(np->has_addrinfo){
        cur = np->as.gai.addrinfo;
        if(! cur){
            abort();
        }
        for(r = 0; r != idx; r++){
            if(! cur){
                return 0;
            }
            cur = cur->ai_next;
        }
        return cur;
    }else{
        return 0;
    }
}

int 
miniio_net_param_name_fetch(void* pctx, void* param, uint32_t idx,
                            uint32_t* ipversion,
                            uint8_t** addr, uint32_t* addrlen){
    struct miniio_uv_ctx_s* ctx = (struct miniio_uv_ctx_s*)pctx;
    struct miniio_uv_netparam_s* np = (struct miniio_uv_netparam_s *)param;
    struct addrinfo* ai;

    ai = select_addrinfo(np, idx);
    if(! ai){
        return 1;
    }

    switch(ai->ai_family){
        case AF_INET:
            *ipversion = 4;
            break;
        case AF_INET6:
            *ipversion = 6;
            break;
        default:
            *ipversion = 0;
            break;
    }

    *addr = (uint8_t *)&ai->ai_addr->sa_data;
    *addrlen = ai->ai_addrlen;

    return 0;
}


enum miniio_uv_objtype_e {
    OBJTYPE_TCP,
    OBJTYPE_PIPE,
};

struct miniio_uv_buffer_s;
struct miniio_uv_obj_s {
    struct miniio_uv_ctx_s* ctx;
    struct miniio_uv_buffer_s* readbuf;
    void* userdata;
    union {
        uv_tcp_t tcp;
        uv_stream_t stream;
        uv_handle_t handle;
    } as;
    union {
        uv_connect_t connect;
        uv_shutdown_t shutdown;
    }req;
    enum miniio_uv_objtype_e objtype;
};

void* 
miniio_tcp_create(void* pctx, void* param, uint32_t idx, void* userdata){
    int r;
    struct miniio_uv_ctx_s* ctx = (struct miniio_uv_ctx_s*)pctx;
    struct miniio_uv_netparam_s* np = (struct miniio_uv_netparam_s *)param;
    struct miniio_uv_obj_s* obj;
    struct addrinfo* ai = 0;

    if(param){
        ai = select_addrinfo(np, idx);
        if(!ai){
            return 0;
        }

    }

    obj = malloc(sizeof(struct miniio_uv_obj_s));
    if(! obj){
        return 0;
    }

    r = uv_tcp_init(&ctx->loop, &obj->as.tcp);
    if(r){
        free(obj);
        return 0;
    }

    /* Bind */
    if(ai){
        r = uv_tcp_bind(&obj->as.tcp, ai->ai_addr, 0);
        if(r){
            free(obj);
            return 0;
        }
    }

    obj->ctx = ctx;
    obj->readbuf = 0;
    obj->userdata = userdata;
    obj->objtype = OBJTYPE_TCP;
    obj->as.stream.data = obj;

    return obj;

}

static void
cb_connection(uv_stream_t* server, int status){
    uintptr_t ev[5];
    struct miniio_uv_obj_s* obj = (struct miniio_uv_obj_s*)server->data;
    struct miniio_uv_ctx_s* ctx = obj->ctx;

    /* [5 3(incomming) handle userdata result] */
    ev[0] = 5;
    ev[1] = 3;
    ev[2] = (uintptr_t)obj;
    ev[3] = (uintptr_t)obj->userdata;
    ev[4] = status;

    addevent(ctx, ev);

}

int
miniio_tcp_listen(void* pctx, void* handle){
    int r;
    struct miniio_uv_ctx_s* ctx = (struct miniio_uv_ctx_s*)pctx;
    struct miniio_uv_obj_s* obj = (struct miniio_uv_obj_s*)handle;

    /* Start listen */
    r = uv_listen(&obj->as.stream, 99, cb_connection);
    if(r){
        return r;
    }
    return 0;
}

static void
cb_connect(uv_connect_t* req, int status){
    uintptr_t ev[5];
    struct miniio_uv_obj_s* obj = (struct miniio_uv_obj_s*)req->data;
    struct miniio_uv_ctx_s* ctx = obj->ctx;
    /* [5 4(outgoing) handle userdata result] */
    ev[0] = 5;
    ev[1] = 4;
    ev[2] = (uintptr_t)obj;
    ev[3] = (uintptr_t)obj->userdata;
    ev[4] = status;

    addevent(ctx, ev);
}

int
miniio_tcp_connect(void* pctx, void* handle, void* param, uint32_t idx){
    int r;
    struct miniio_uv_ctx_s* ctx = (struct miniio_uv_ctx_s*)pctx;
    struct miniio_uv_netparam_s* np = (struct miniio_uv_netparam_s *)param;
    struct miniio_uv_obj_s* obj;
    struct addrinfo* ai = 0;

    if(! np){
        return 1;
    }else{
        ai = select_addrinfo(np, idx);
        if(! ai){
            return 1;
        }
    }

    obj->req.connect.data = handle;
    r = uv_tcp_connect(&obj->req.connect, &obj->as.tcp, ai->ai_addr, 
                       cb_connect);
    if(r){
        return r;
    }

    return 0;
}

void*
miniio_tcp_accept(void* pctx, void* handle, void* new_userdata){
    int r;
    struct miniio_uv_ctx_s* ctx = (struct miniio_uv_ctx_s*)pctx;
    struct miniio_uv_obj_s* obj = (struct miniio_uv_obj_s*)handle;
    struct miniio_uv_obj_s* newobj;

    newobj = malloc(sizeof(struct miniio_uv_obj_s));
    if(! newobj){
        return 0;
    }

    r = uv_tcp_init(&ctx->loop, &newobj->as.tcp);
    if(r){
        free(newobj);
        return 0;
    }

    newobj->ctx = ctx;
    newobj->userdata = new_userdata;
    newobj->objtype = OBJTYPE_TCP;
    newobj->as.stream.data = newobj;

    r = uv_accept(&obj->as.stream, &newobj->as.stream);
    if(r){
        free(newobj);
        return 0;
    }

    return newobj;
}

static void
cb_shutdown(uv_shutdown_t* req, int status){
    uintptr_t ev[5];
    struct miniio_uv_obj_s* obj = (struct miniio_uv_obj_s*)req->data;
    struct miniio_uv_ctx_s* ctx = obj->ctx;
    /* [5 5(shutdown) handle userdata result] */
    ev[0] = 5;
    ev[1] = 5;
    ev[2] = (uintptr_t)obj;
    ev[3] = (uintptr_t)obj->userdata;
    ev[4] = status;

    addevent(ctx, ev);
}

int
miniio_tcp_shutdown(void* pctx, void* handle){
    int r;
    struct miniio_uv_ctx_s* ctx = (struct miniio_uv_ctx_s*)pctx;
    struct miniio_uv_obj_s* obj = (struct miniio_uv_obj_s*)handle;

    obj->req.shutdown.data = handle;
    r = uv_shutdown(&obj->req.shutdown, &obj->as.stream, cb_shutdown);
    if(r){
        return r;
    }
    return 0;
}

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
static void
cb_close(uv_handle_t* uhandle){
    struct miniio_uv_obj_s* obj = (struct miniio_uv_obj_s*)uhandle->data;
    uintptr_t ev[4];
    /* [4 0(handle-close) handle userdata] */
    ev[0] = 4;
    ev[1] = 0;
    ev[2] = (uintptr_t)obj;
    ev[3] = (uintptr_t)obj->userdata;
    addevent(obj->ctx, ev);

    free(obj);
}

void 
miniio_close(void* ctx, void* stream){
    struct miniio_uv_obj_s* obj = (struct miniio_uv_obj_s*)stream;
    (void)ctx;
    uv_close(&obj->as.handle, cb_close);
}

struct miniio_uv_buffer_s {
    struct miniio_uv_ctx_s* ctx;
    uint8_t* buffer;
    uintptr_t buflen;
    uintptr_t readptr;
    uintptr_t writeptr;
    void* userdata;
    union {
        uv_req_t req;
        uv_write_t write;
    } req;
};

void* 
miniio_buffer_create(void* ctx, uintptr_t size, void* userdata){
    void* bufdata;
    struct miniio_uv_buffer_s* buf;
    buf = malloc(sizeof(struct miniio_uv_buffer_s));
    if(! buf){
        return 0;
    }
    bufdata = malloc(size);
    if(! bufdata){
        free(buf);
        return 0;
    }

    buf->ctx = (struct miniio_uv_ctx_s*) ctx;
    buf->userdata = userdata;
    buf->buflen = size;
    buf->readptr = 0;
    buf->writeptr = 0;
    (void)uv_req_set_data(&buf->req.req, buf);
    
    return buf;
}

void 
miniio_buffer_destroy(void* ctx, void* handle){
    struct miniio_uv_buffer_s* buf = (struct miniio_uv_buffer_s*)handle;

    free(buf->buffer);
    free(buf);
}

void* 
miniio_buffer_lock(void* ctx, void* handle, uintptr_t offset, uintptr_t len){
    (void)ctx;
    struct miniio_uv_buffer_s* buf = (struct miniio_uv_buffer_s*)handle;

    return buf->buffer + offset;
}

void 
miniio_buffer_unlock(void* ctx, void* handle){
    /* Do nothing */
    (void)ctx;
    (void)handle;
}

void
miniio_buffer_consume(void* ctx, void* handle, uintptr_t len){
    (void)ctx;
    struct miniio_uv_buffer_s* buf = (struct miniio_uv_buffer_s*)handle;

    uintptr_t newlen;

    if(len == 0){
        /* Do nothing */
        return;
    }

    newlen = buf->readptr + len;
    if(newlen > buf->buflen){
        /* Should not happen */
        abort();
    }
    if(buf->writeptr == newlen){
        /* Buffer is empty */
        buf->writeptr = 0;
        buf->readptr = 0;
    }else if(buf->buflen == newlen){
        /* Rollover */
        buf->readptr = 0;
    }else{
        buf->readptr = newlen;
    }
}


static void
cb_write(uv_write_t* req, int status){
    uintptr_t ev[5];
    struct miniio_uv_buffer_s* buf;

    buf = (struct miniio_uv_buffer_s*) uv_req_get_data((uv_req_t*)(void*)req);

    /* [5 5(write-complete) buffer-handle buffer-userdata result] */
    ev[0] = 5;
    ev[1] = 6;
    ev[2] = (uintptr_t)buf;
    ev[3] = (uintptr_t)buf->userdata;
    ev[4] = status;

    addevent(buf->ctx, ev);
}

int 
miniio_write(void* ctx, void* stream, void* buffer, uintptr_t offset,
                 uintptr_t len){
    int r;
    struct miniio_uv_obj_s* obj = (struct miniio_uv_obj_s*)stream;
    struct miniio_uv_buffer_s* buf = (struct miniio_uv_buffer_s*)buffer;
    uint8_t* target;
    uv_buf_t reqbuf;


    target = buf->buffer + offset;
    reqbuf = uv_buf_init(target, len);

    r = uv_write(&buf->req.write, &obj->as.stream, &reqbuf, 1, cb_write);
    if(r){
        return r;
    }
    return 0;
}

static void
cb_alloc_read(uv_handle_t* handle, size_t suggested_size, uv_buf_t* out){
    struct miniio_uv_obj_s* obj = (struct miniio_uv_obj_s*)handle->data;
    struct miniio_uv_buffer_s* buf = obj->readbuf;

    uintptr_t res;

    if(suggested_size == 0){
        /* Algorithm cannot handle zero allocation */
        abort();
    }

    if(buf->writeptr == buf->buflen){
        res = buf->buflen - buf->readptr;
        res = res > suggested_size ? suggested_size : res;
        *out = uv_buf_init(buf->buffer, res);
        buf->writeptr = res;
    }else if(buf->readptr < buf->writeptr){
        res = buf->buflen - buf->writeptr;
        res = res > suggested_size ? suggested_size : res;
        *out = uv_buf_init(buf->buffer + buf->writeptr, res);
        buf->writeptr += res;
    }else if(buf->readptr > buf->writeptr){
        res = buf->readptr - buf->writeptr;
        res = res > suggested_size ? suggested_size : res;
        *out = uv_buf_init(buf->buffer + buf->writeptr, res);
        buf->writeptr += res;
    }else if(buf->readptr == 0){
        /* readptr == writeptr == 0 */
        res = buf->buflen;
        res = res > suggested_size ? suggested_size : res;
        *out = uv_buf_init(buf->buffer, res);
        buf->writeptr = res;
    }else{
        /* Buffer full */
        *out = uv_buf_init(0, 0);
    }
}

static void
cb_read(uv_stream_t* stream, ssize_t nread, const uv_buf_t* buf){
    uintptr_t ev[9];
    struct miniio_uv_obj_s* obj = (struct miniio_uv_obj_s*)stream->data;
    struct miniio_uv_ctx_s* ctx = obj->ctx;
    uint8_t* bufstart = buf->base;
    uintptr_t buflen, buftop, bufend;

    if(nread == UV_EOF){
        /* [4 7(read-eof) stm-handle stm-userdata] */
        ev[0] = 4;
        ev[1] = 7;
        ev[2] = (uintptr_t)obj;
        ev[3] = (uintptr_t)obj->userdata;
    }else if(nread == UV_ENOBUFS){
        /* [5 8(read-stop) stm-handle stm-userdata bufend?] */
        ev[0] = 5;
        ev[1] = 8;
        ev[2] = (uintptr_t)obj;
        ev[3] = (uintptr_t)obj->userdata;
        ev[4] = 1;
    }else if(nread < 0){
        /* [5 9(read-error) stm-handle stm-userdata err] */
        ev[0] = 5;
        ev[1] = 9;
        ev[2] = (uintptr_t)obj;
        ev[3] = (uintptr_t)obj->userdata;
        ev[4] = (uintptr_t)nread;
    }else{
        buflen = buf->len;
        buftop = bufstart - obj->readbuf->buffer;
        bufend = buftop + buf->len;

        /* [9 6(read-complete) stm-handle stm-userdata 
         *  buf-handle buf-userdata start end n] */
        ev[0] = 9;
        ev[1] = 6;
        ev[2] = (uintptr_t)obj;
        ev[3] = (uintptr_t)obj->userdata;
        ev[4] = (uintptr_t)obj->readbuf;
        ev[5] = (uintptr_t)obj->readbuf->userdata;
        ev[6] = buftop;
        ev[7] = bufend;
        ev[8] = nread;
    }

    addevent(ctx, ev);
}

int 
miniio_start_read(void* ctx, void* stream, void* buffer){
    int r;
    struct miniio_uv_obj_s* obj = (struct miniio_uv_obj_s*)stream;
    struct miniio_uv_buffer_s* buf = (struct miniio_uv_buffer_s*)buffer;

    obj->readbuf = buf;
    r = uv_read_start(&obj->as.stream, cb_alloc_read, cb_read);

    return r;
}


