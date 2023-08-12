#ifndef YUNI__MINIIO_H
#define YUNI__MINIIO_H

#ifdef __cplusplus
extern "C" {
#endif
/* } */

/* I/O Context (No NCCC export) */
typedef void (*miniio_wakeup_routine)(void* ctx, void* wakeup_ctx);
int miniio_ioctx_create(miniio_wakeup_routine wakeup, void* wakeup_ctx,
                        void** out_ctx);
int miniio_ioctx_process(void* ctx);
void miniio_ioctx_terminate(void* ctx);


/* Context, Eventqueue */
int miniio_get_events(void* ctx, uintptr_t* buf, uint32_t bufcount,
                      uint32_t* out_written, uint32_t* out_current);

/* Timer */
void* miniio_timer_create(void* ctx, void* userdata);
void miniio_timer_destroy(void* ctx, void* handle);
int miniio_timer_start(void* ctx, void* handle, uint64_t timeout, 
                       uint64_t interval);

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

/* { */
#ifdef __cplusplus
};
#endif

#endif /* YUNI__MINIIO_H */
