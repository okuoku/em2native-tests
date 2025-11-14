set(moltenvk_url "https://github.com/KhronosGroup/MoltenVK/releases/download/v1.4.0/MoltenVK-all.tar")

function(detect_moltenvk) # => moltenvk_prefix
    set(prefix
        ${CMAKE_CURRENT_LIST_DIR}/../_build/_MoltenVk
    )
    if(APPLE)
        if(NOT EXISTS ${prefix}/archive.tar)
            file(MAKE_DIRECTORY "${prefix}")
            file(DOWNLOAD 
                ${moltenvk_url}
                ${prefix}/archive.tar SHOW_PROGRESS)
            file(ARCHIVE_EXTRACT
                INPUT ${prefix}/archive.tar
                DESTINATION ${prefix})
        endif()
        set(moltenvk_prefix ${prefix}/MoltenVk PARENT_SCOPE)
    endif()
endfunction()
