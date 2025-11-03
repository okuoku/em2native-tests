#
# INPUTs: ONLY (image name)
if(ONLY)
    set(images ${ONLY}) 
else()
    set(images local 
        yunibuild-mingw-x64 
        yunibuild-android
        yunibuild-emscripten
    )
endif()


foreach(img IN LISTS images)
    if(${img} STREQUAL local)
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
            COMMAND docker run --rm -t 
            -v${CMAKE_CURRENT_LIST_DIR}/..:/yuniframe
            ${img} cmake -P /yuniframe/scripts/_localbuild.cmake
            RESULT_VARIABLE rr)
        if(rr)
            message(FATAL_ERROR "Failed to run generation (on ${img})")
        endif()

        execute_process(
            COMMAND 
            docker run --rm -t 
            -v${CMAKE_CURRENT_LIST_DIR}/..:/yuniframe
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
