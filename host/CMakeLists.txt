cmake_minimum_required(VERSION 3.12)
project(yuniframe-testhost)

include(${CMAKE_CURRENT_LIST_DIR}/../integ/proj/projwrap.cmake)
add_subdirectory(../proj/uv uv)

# Standalone Ribbon
set(RIBBON_ROOT ${CMAKE_CURRENT_LIST_DIR}/../ribbon-integ/ribbon/c-proto)

add_definitions(-DRN_EMBEDDING)

set(WITH_YUNI ${CMAKE_CURRENT_LIST_DIR}/../ribbon-integ/yuni)
set(WITH_RUNTIME ${CMAKE_CURRENT_LIST_DIR}/../ribbon-integ/yuniribbit-proto)

add_definitions(
    -DYUNIROOT=\"${WITH_YUNI}\"
    -DRUNTIMEROOT=\"${WITH_RUNTIME}\"
    -DBUILDROOT=\"${CMAKE_CURRENT_BINARY_DIR}\")

include_directories(
    ${RIBBON_ROOT}
    ${CMAKE_CURRENT_LIST_DIR}/../ext/platform/libuv/include)

add_executable(ribbon_miniio
    ribbon.c
    ../miniio/miniio_uv.c
    ${RIBBON_ROOT}/c-proto.c)

target_link_libraries(ribbon_miniio uv_a)

if(CYGWIN)
    # WAR: Cygwin libc cannot use with c90
    set_property(TARGET uv_a PROPERTY C_STANDARD 11)
endif()
