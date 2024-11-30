set(mysubmodules
    integ # => https://github.com/okuoku/em2native-integ
    integ/coal
    integ/cwgl
    integ/ext/legacygl/tinygl-cmake
    integ/ext/cwgl/angle-static-cmake
    integ/ext/nccc/napi-sdkfiles
    integ/nccc
    integ/yuniframe
    ribbon-integ
    ribbon-integ/ribbon
    ribbon-integ/yuni
    ribbon-integ/yuniribbit-proto
    miniio
    mediatools
    )

set(rename_integ em2native-integ)
set(rename_mediatools nccc_mediatools)

foreach(e ${mysubmodules})
    if(rename_${e})
        set(url "git@github.com:okuoku/${rename_${e}}")
    else()
        get_filename_component(nam "${e}" NAME)
        set(url "git@github.com:okuoku/${nam}")
    endif()
    message(STATUS "${e} = ${url}")
    execute_process(COMMAND
        git remote set-url --push origin ${url}
        WORKING_DIRECTORY ${CMAKE_CURRENT_LIST_DIR}/../${e})
endforeach()
