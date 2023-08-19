#ifndef YUNI__MINIIO_H
#define YUNI__MINIIO_H

#ifdef __cplusplus
extern "C" {
#endif
/* } */

#include <stdint.h>

/* I/O Context */
void* miniio_ioctx_create(void);
int miniio_ioctx_process(void* ctx);
void miniio_ioctx_destroy(void* ctx);

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
int miniio_net_param_name_resolve(void* ctx, void* param);
int miniio_net_param_name_fetch(void* ctx, void* param, uint32_t idx, 
                                uint32_t* ipversion,
                                uint8_t** addr, uint32_t* addrlen);
void* miniio_tcp_create(void* ctx, void* param, uint32_t idx, void* userdata);
int miniio_tcp_listen(void* ctx, void* handle);
int miniio_tcp_connect(void* ctx, void* handle, void* param, uint32_t idx);
void* miniio_tcp_accept(void* ctx, void* handle, void* userdata);
int miniio_tcp_shutdown(void* ctx, void* handle);

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
void* miniio_buffer_lock(void* ctx, void* handle, uintptr_t offset,
                         uintptr_t len);
void miniio_buffer_unlock(void* ctx, void* handle);
void miniio_buffer_consume(void* ctx, void* handle, uintptr_t len);
int miniio_write(void* ctx, void* stream, void* buffer, uintptr_t offset, 
                 uintptr_t len);
int miniio_start_read(void* ctx, void* stream, void* buffer);

/* { */
#ifdef __cplusplus
};
#endif

#endif /* YUNI__MINIIO_H */
