cmake_minimum_required(VERSION 3.12)
project(tinygltest C)

set(SDL_SHARED OFF CACHE BOOL "" FORCE)
set(SDL_STATIC ON CACHE BOOL "" FORCE)
set(LIBC ON CACHE BOOL "" FORCE)

set(tinygl ../integ/ext/legacygl/tinygl-cmake)
add_subdirectory(${tinygl} tinygl)
add_subdirectory(../integ/ext/platform/SDL2 sdl2)

# GL part

add_library(gears STATIC
    ${tinygl}/gears-sdl2/gears.c
    ${tinygl}/shim/tglshim.c
    )

target_link_libraries(gears
    PRIVATE
    TinyGL)

target_include_directories(gears
    PRIVATE
    ${tinygl}/shim
    ${tinygl}/TinyGL/include
    ${tinygl}/TinyGL/src
    )

# SDL part

add_executable(tinygltest ${tinygl}/gears-sdl2/main.c)
target_include_directories(tinygltest PRIVATE ${tinygl}/shim)
target_link_libraries(tinygltest SDL2::SDL2 SDL2::SDL2main gears)
