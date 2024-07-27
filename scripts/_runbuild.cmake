cmake_minimum_required(VERSION 3.12)

if(NOT PHASE)
    set(PHASE cycle)
endif()

# Since we cannot depend on CYGWIN variable here, find cygpath instead
find_program(CYGPATH cygpath)

if(CYGPATH OR WIN32)
    # Run _localbuild.cmake with Visual Studio Command Prompt
    # First, locate vsroot
    set(vsroot_pre "C:\\Program Files\\Microsoft Visual Studio\\2022\\")
    if(IS_DIRECTORY "${vsroot_pre}Professional")
        set(vsroot_edition Professional)
    elseif(IS_DIRECTORY "${vsroot_pre}BuildTools")
        set(vsroot_edition BuildTools)
    elseif(IS_DIRECTORY "${vsroot_pre}Community")
        set(vsroot_edition Community)
    elseif(IS_DIRECTORY "${vsroot_pre}Enterprise")
        set(vsroot_edition Enterprise)
    else()
        set(vsroot_edition)
    endif()
    message(STATUS "VS Edition = ${vsroot_edition}")

    set(vsroot "${vsroot_pre}${vsroot_edition}")
    set(vcvars64 "${vsroot}\\VC\\Auxiliary\\Build\\vcvars64.bat")

    if(CYGPATH)
        # FIXME: Do some second-chance with Windows registry
        set(cmake_path "${vsroot}\\Common7\\IDE\\CommonExtensions\\Microsoft\\CMake\\CMake\\bin\\cmake.exe")
    else()
        set(cmake_path "${CMAKE_COMMAND}")
    endif()

    if(CYGPATH)
        # Override PATH
        # FIXME: We can mask Git but not for Python
        set(ENV{PATH} /cygdrive/c/Windows/System32:/cygdrive/c/Windows)
    endif()

    execute_process(
        COMMAND cmd /c chcp 65001 &&
        ${vcvars64} && ${cmake_path} -DPHASE=${PHASE} 
        -P scripts/_localbuild.cmake
        WORKING_DIRECTORY ${CMAKE_CURRENT_LIST_DIR}/..
        RESULT_VARIABLE rr
        )
else()
    execute_process(
        COMMAND 
        ${CMAKE_COMMAND} -DPHASE=${PHASE} -P scripts/_localbuild.cmake
        WORKING_DIRECTORY ${CMAKE_CURRENT_LIST_DIR}/..
        RESULT_VARIABLE rr
        )
endif()

message(STATUS "Result = ${rr}")
if(rr)
    message(FATAL_ERROR "Failed to build some module(s)")
endif()
