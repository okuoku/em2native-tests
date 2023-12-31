set(mysubmodules
    integ # => https://github.com/okuoku/em2native-integ
    integ/coal
    integ/cwgl
    integ/ext/legacygl/tinygl-cmake
    integ/ext/cwgl/angle-static-cmake
    integ/nccc
    integ/yuniframe
    ribbon-integ
    ribbon-integ/ribbon
    ribbon-integ/yuni
    ribbon-integ/yuniribbit-proto
    )

foreach(e ${mysubmodules})
    if(e STREQUAL integ)
        set(url "git@github.com:okuoku/em2native-integ")
    else()
        get_filename_component(nam "${e}" NAME)
        set(url "git@github.com:okuoku/${nam}")
    endif()
    message(STATUS "${e} = ${url}")
    execute_process(COMMAND
        git remote set-url --push origin ${url}
        WORKING_DIRECTORY ${CMAKE_CURRENT_LIST_DIR}/../${e})
endforeach()
