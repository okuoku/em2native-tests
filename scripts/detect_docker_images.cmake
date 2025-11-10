
function(detect_docker_images prefix)
    execute_process(COMMAND
        docker images
        OUTPUT_VARIABLE out
        ERROR_VARIABLE bogus
        RESULT_VARIABLE rr)
    if(rr)
        message(STATUS "Failed to run Docker. (${rr})")
    endif()
    string(REPLACE "\n" ";" lines "${out}")
    set(types)
    foreach(l IN LISTS lines)
        if("${l}" MATCHES "yunibuild-([^ ]*)[ ]*[^ ]*[ ]*([^ ]*)")
            set(imgtype "${CMAKE_MATCH_1}")
            set(ident "${CMAKE_MATCH_2}")
            message(STATUS "yunibuild: ${imgtype} ${ident}")
            list(APPEND types ${imgtype})
            set(${prefix}_${imgtype} ${ident} PARENT_SCOPE)
        endif()
    endforeach()
    set(${prefix}_images ${types} PARENT_SCOPE)
endfunction()
