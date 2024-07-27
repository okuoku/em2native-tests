cmake_minimum_required(VERSION 3.20)
project(yfrm-uv NONE)

set(root ../..)
set(LIBUV_BUILD_SHARED OFF CACHE BOOL "" FORCE)

yfrm_add_subproject(UV ${root}/ext/platform/libuv uv
    # Exported library
    uv_a)


