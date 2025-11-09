#
# INPUTs: ONLY (image name)
find_program(CYGPATH cygpath) # Detect Cygwin
include(${CMAKE_CURRENT_LIST_DIR}/detect_docker_images.cmake)

if(ONLY)
    set(images ${ONLY}) 
else()
    set(images)
    set(types 
        # Win32/Win64
        mingw-x64 
        # Web
        emscripten
        # Linux envs
        steamruntime3 linuxmusl linuxglibc
        # Platforms
        android)
    detect_docker_images(yunibuild_image)
    if(NOT CYGPATH)
        list(APPEND images __LOCAL__)
    endif()
    foreach(t IN LISTS types)
        if(yunibuild_image_${t})
            list(APPEND images yunibuild-${t})
            message(STATUS "Build: ${t}")
        endif()
    endforeach()
endif()

if(CYGPATH OR WIN32)
    # Always use process isolation for faster build
    set(isolation --isolation process)
else()
    set(isolation)
endif()

cmake_path(SET root0 NORMALIZE ${CMAKE_CURRENT_LIST_DIR}/..)
if(CYGPATH)
    # Convert repository root into native path
    execute_process(COMMAND cygpath -w ${root0} 
        OUTPUT_STRIP_TRAILING_WHITESPACE
        OUTPUT_VARIABLE root)
    message(STATUS "${root0} => ${root}")
    set(container_work c:\\yuniframe)
else()
    # Use CMake path as is
    set(root "${root0}")
    set(container_work /yuniframe)
endif()

set(docker_run
    docker run
    -v${root}:${container_work}
    ${isolation})

foreach(img IN LISTS images)
    if(${img} STREQUAL __LOCAL__)
        execute_process(
            COMMAND ${CMAKE_COMMAND} 
            -P ${CMAKE_CURRENT_LIST_DIR}/_localbuild.cmake
            RESULT_VARIABLE rr)

        if(rr)
            message(FATAL_ERROR "Failed to run generation (on Local)")
        endif()

        execute_process(
            COMMAND ${CMAKE_COMMAND} -DPHASE=cycle -P 
            ${CMAKE_CURRENT_LIST_DIR}/_localbuild.cmake
            RESULT_VARIABLE rr)

        if(rr)
            message(FATAL_ERROR "Failed to run build (on Local)")
        endif()

    else()
        execute_process(
            COMMAND ${docker_run} --rm
            ${img} cmake -P /yuniframe/scripts/_localbuild.cmake
            RESULT_VARIABLE rr)
        if(rr)
            message(FATAL_ERROR "Failed to run generation (on ${img})")
        endif()

        execute_process(
            COMMAND 
            ${docker_run} --rm
            ${img}
            cmake
            -DPHASE=cycle -P 
            /yuniframe/scripts/_localbuild.cmake
            RESULT_VARIABLE rr)

        if(rr)
            message(FATAL_ERROR "Failed to run build (on ${img})")
        endif()
    endif()
endforeach()
