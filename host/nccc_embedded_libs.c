#include <stdint.h>

void lib_miniio_dispatch(const uint64_t* in, uint64_t* out);

uintptr_t
ncccinteg_get_dispatch(uintptr_t idx){
    switch(idx){
        case 0:
            return (uintptr_t)lib_miniio_dispatch;
        default:
            return 0;
    }
}
