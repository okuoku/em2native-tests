nccc_stub_begin(miniio)

# Context
nccc_api(miniio_ioctx_create
    IN OUT ptr)
nccc_api(miniio_ioctx_process
    IN ptr OUT s32)
nccc_api(miniio_ioctx_destroy
    IN ptr OUT)
nccc_api(miniio_get_events
    IN ptr ptr u32 ptr ptr OUT s32)

# Timer
nccc_api(miniio_timer_create
    IN ptr ptr OUT ptr)
nccc_api(miniio_timer_destroy
    IN ptr ptr OUT)
nccc_api(miniio_timer_start
    IN ptr ptr u64 u64 OUT s32)

# TCP(Network stream)
nccc_api(miniio_net_param_create
    IN ptr ptr OUT ptr)
nccc_api(miniio_net_param_destroy
    IN ptr ptr OUT)
nccc_api(miniio_net_param_hostname
    IN ptr ptr ptr OUT s32)
nccc_api(miniio_net_param_port
    IN ptr ptr s32 OUT s32)
nccc_api(miniio_net_param_name_resolve
    IN ptr ptr OUT s32)
nccc_api(miniio_net_param_name_fetch
    IN ptr ptr u32 ptr ptr ptr OUT s32)

nccc_api(miniio_tcp_create
    IN ptr ptr u32 ptr OUT ptr)
nccc_api(miniio_tcp_listen
    IN ptr ptr OUT s32)
nccc_api(miniio_tcp_connect
    IN ptr ptr ptr u32 OUT s32)
nccc_api(miniio_tcp_accept
    IN ptr ptr ptr OUT ptr)
nccc_api(miniio_tcp_shutdown
    IN ptr ptr OUT s32)

# Stream I/O
nccc_api(miniio_close
    IN ptr ptr OUT)
nccc_api(miniio_buffer_create
    IN ptr u32 ptr OUT ptr)
nccc_api(miniio_buffer_destroy
    IN ptr ptr OUT)
nccc_api(miniio_buffer_lock
    IN ptr ptr u32 u32 OUT ptr)
nccc_api(miniio_buffer_unlock
    IN ptr ptr OUT)
nccc_api(miniio_write
    IN ptr ptr ptr u32 u32 OUT s32)
nccc_api(miniio_start_read
    IN ptr ptr ptr OUT s32)


nccc_stub_end(miniio)
