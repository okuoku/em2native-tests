
# INPUTs:
#   RIBBON_INTEG_BOOTSTRAP: Fullpath for build directory of ribbon-integ

if(NOT RIBBON_INTEG_BOOTSTRAP)
    message(FATAL_ERROR "RIBBON_INTEG_BOOTSTRAP required")
endif()

cmake_minimum_required(VERSION 3.12)
project(yuniframe-testhost)

include(${CMAKE_CURRENT_LIST_DIR}/../integ/proj/projwrap.cmake)
add_subdirectory(../proj/uv uv)

# Standalone Ribbon
set(NCCC_ROOT ${CMAKE_CURRENT_LIST_DIR}/../integ/nccc)
include(${NCCC_ROOT}/stubsupport/cmake/NcccStubMacros.cmake)
set(RIBBON_ROOT ${CMAKE_CURRENT_LIST_DIR}/../ribbon-integ/ribbon/c-proto)

add_definitions(-DRN_EMBEDDING)

set(WITH_YUNI ${CMAKE_CURRENT_LIST_DIR}/../ribbon-integ/yuni)
set(WITH_RUNTIME ${CMAKE_CURRENT_LIST_DIR}/../ribbon-integ/yuniribbit-proto)

include_directories(
    ${RIBBON_ROOT}
    ${CMAKE_CURRENT_LIST_DIR}/../miniio
    ${CMAKE_CURRENT_LIST_DIR}/../ext/platform/libuv/include)

# Bytecode generation
include(${RIBBON_INTEG_BOOTSTRAP}/deps.cmake) # => yunideps_srcs
include(${RIBBON_INTEG_BOOTSTRAP}/bootstrap_params.cmake) # WITH_RUNTIME etc

# NCCC stub generation
include(${CMAKE_CURRENT_LIST_DIR}/../miniio/stub_miniio.cmake)
include_directories(${CMAKE_CURRENT_BINARY_DIR} ${NCCC_ROOT}/stubsupport)

add_definitions(
    -DYUNIROOT=\"${WITH_YUNI}\"
    -DRUNTIMEROOT=\"${WITH_RUNTIME}\"
    -DBUILDROOT=\"${BUILDROOT}\")

add_executable(ribbon_miniio
    ribbon.c
    nccc_miniio.c
    nccc_embedded_libs.c
    ../miniio/miniio_uv.c
    ${RIBBON_ROOT}/c-proto.c)

target_link_libraries(ribbon_miniio uv_a)

if(CYGWIN)
    # WAR: Cygwin libc cannot use with gnu90
    set_property(TARGET uv_a PROPERTY C_STANDARD 11)
endif()
