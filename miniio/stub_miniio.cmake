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

nccc_stub_end(miniio)
