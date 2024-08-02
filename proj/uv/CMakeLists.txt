cmake_minimum_required(VERSION 3.20)
project(yfrm-uv NONE)

set(root ../..)
set(LIBUV_BUILD_SHARED OFF CACHE BOOL "" FORCE)

if(WIN32)
    set(YFRM_PREBUILT_DEPS_uv_a
        ws2_32
        iphlpapi
        dbghelp
        userenv)
endif()

yfrm_add_subproject(UV ${root}/ext/platform/libuv uv
    # Exported library
    uv_a)


