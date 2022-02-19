cmake_minimum_required(VERSION 3.3)


get_property(HAS_GIT_UTILS_REPOSITORY GLOBAL PROPERTY GLOBAL_GIT_UTILS_PROJECTS_LIST DEFINED)
if (NOT ${HAS_GIT_UTILS_REPOSITORY})
    define_property(GLOBAL PROPERTY GLOBAL_GIT_UTILS_PROJECTS_LIST BRIEF_DOCS "Initialized git repositories list" FULL_DOCS "List of already initialized git repositories")
    set_property(GLOBAL PROPERTY GLOBAL_GIT_UTILS_PROJECTS_LIST "")
endif()


function(__GitUtils_DefineIncludeMapItem PROJECT)
    get_property(HAS_PROJECT_INCLUDE GLOBAL PROPERTY GLOBAL_GIT_UTILS_PROJECT_INCLUDE_MAP_${PROJECT} DEFINED)
    if (NOT ${HAS_PROJECT_INCLUDE})
        define_property(GLOBAL PROPERTY GLOBAL_GIT_UTILS_PROJECT_INCLUDE_MAP_${PROJECT}
                        BRIEF_DOCS "Project ${PROJECT} git repository include property"
                        FULL_DOCS "Project ${PROJECT} git repository property with include paths list")
        set_property(GLOBAL PROPERTY GLOBAL_GIT_UTILS_PROJECT_INCLUDE_MAP_${PROJECT} "")
    endif()
endfunction()


function(__GitUtils_AppendIncludeMapItem PROJECT PATH)
    __GitUtils_DefineIncludeMapItem(PROJECT)
    get_property(PROJECT_INCLUDE_LIST GLOBAL PROPERTY GLOBAL_GIT_UTILS_PROJECT_INCLUDE_MAP_${PROJECT})
    if (NOT (${PATH} IN_LIST PROJECT_INCLUDE_LIST))
        list(APPEND PROJECT_INCLUDE_LIST ${PATH})
        set_property(GLOBAL PROPERTY GLOBAL_GIT_UTILS_PROJECT_INCLUDE_MAP_${PROJECT} PROJECT_INCLUDE_LIST)
    endif()
endfunction()


function(__GitUtils_ResetIncludeMapItem PROJECT)
    __GitUtils_DefineIncludeMapItem(PROJECT)
    set_property(GLOBAL PROPERTY GLOBAL_GIT_UTILS_PROJECT_INCLUDE_MAP_${PROJECT} "")
endfunction()


function(__GitUtils_DefineDependencyMapItem PROJECT)
    get_property(HAS_PROJECT_DEPENDS GLOBAL PROPERTY GLOBAL_GIT_UTILS_PROJECT_DEPENDENCY_MAP_${PROJECT} DEFINED)
    if (NOT ${HAS_PROJECT_DEPENDS})
        define_property(GLOBAL PROPERTY GLOBAL_GIT_UTILS_PROJECT_DEPENDENCY_MAP_${PROJECT}
                        BRIEF_DOCS "Project ${PROJECT} git repository dependencies property"
                        FULL_DOCS "Project ${PROJECT} git repository property with dependencies list")
        set_property(GLOBAL PROPERTY GLOBAL_GIT_UTILS_PROJECT_DEPENDENCY_MAP_${PROJECT} "")
    endif()
endfunction()


function(__GitUtils_AppendDependencyMapItem PROJECT DEPEND)
    __GitUtils_DefineDependencyMapItem(PROJECT)
    get_property(PROJECT_DEPENDS_LIST GLOBAL PROPERTY GLOBAL_GIT_UTILS_PROJECT_DEPENDENCY_MAP_${PROJECT})
    if (NOT (${DEPEND} IN_LIST PROJECT_DEPENDS_LIST))
        list(APPEND PROJECT_DEPENDS_LIST ${DEPEND})
        set_property(GLOBAL PROPERTY GLOBAL_GIT_UTILS_PROJECT_DEPENDENCY_MAP_${PROJECT} PROJECT_DEPENDS_LIST)
    endif()
endfunction()


function(__GitUtils_RecurciveDependency PROJECT DEPENDENCY_INCLUDE_LIST)
    if (NOT DEFINED ${DEPENDENCY_INCLUDE_LIST})
        set(${DEPENDENCY_INCLUDE_LIST} "" PARENT_SCOPE)
    endif()

    get_property(HAS_DEPEND GLOBAL PROPERTY GLOBAL_GIT_UTILS_PROJECT_DEPENDENCY_MAP_${PROJECT} DEFINED)
    if (${HAS_DEPEND})
        get_property(DEPEND_PROJECTS_LIST GLOBAL PROPERTY GLOBAL_GIT_UTILS_PROJECT_DEPENDENCY_MAP_${PROJECT})
        foreach(DEPEND ${DEPEND_PROJECTS_LIST})
            __GitUtils_RecurciveDependency(${DEPEND} ${DEPENDENCY_INCLUDE_LIST})
            set(${DEPENDENCY_INCLUDE_LIST} ${${DEPENDENCY_INCLUDE_LIST}} PARENT_SCOPE)
        endforeach()
    endif()

    get_property(HAS_DEPEND_INCLUDE GLOBAL PROPERTY GLOBAL_GIT_UTILS_PROJECT_INCLUDE_MAP_${DEPEND} DEFINED)
    if (NOT ${HAS_DEPEND_INCLUDE})
        message(FATAL_ERROR "[ERROR GIT] repository project ${DEPEND} must be defined before set as depend for target")
    endif()
    get_property(DEPEND_PROJECT_INCLUDE_LIST GLOBAL PROPERTY GLOBAL_GIT_UTILS_PROJECT_INCLUDE_MAP_${DEPEND})
    foreach(DEPEND_INCLUDE ${DEPEND_PROJECT_INCLUDE_LIST})
        if (NOT (${DEPEND_INCLUDE} IN_LIST ${DEPENDENCY_INCLUDE_LIST}))
            list(APPEND ${DEPENDENCY_INCLUDE_LIST} ${DEPEND_INCLUDE})
            set(${DEPENDENCY_INCLUDE_LIST} ${${DEPENDENCY_INCLUDE_LIST}} PARENT_SCOPE)
        endif()
    endforeach()
endfunction()


function(GitUtils_Define PROJECT GIT_URL)
    set(ARGS_OPT FREEZE PULL LOCAL OVERRIDE)
    set(ARGS_ONE TAG FOLDER INCLUDE BUILD)
    set(ARGS_LIST "")
    cmake_parse_arguments(GIT_ARGS "${ARGS_OPT}" "${ARGS_ONE}" "${ARGS_LIST}" ${ARGN})

    set(FULL_PROJECT_NAME ${PROJECT})
    if (DEFINED GIT_ARGS_TAG)
        set(FULL_PROJECT_NAME ${FULL_PROJECT_NAME}_${GIT_ARGS_TAG})
    endif()
    
    get_property(PROJECTS_LIST GLOBAL PROPERTY GLOBAL_GIT_UTILS_PROJECTS_LIST)
    if (NOT (${FULL_PROJECT_NAME} IN_LIST PROJECTS_LIST))
        if ((DEFINED GIT_ARGS_OVERRIDE) AND (${GIT_ARGS_OVERRIDE}))
            message("[OVERRIDE GIT] repository project ${PROJECT} to ${FULL_PROJECT_NAME}")
        else()
            message("[DEFINE GIT] repository project ${PROJECT} and append as ${FULL_PROJECT_NAME}")
        endif()
    
        if (NOT DEFINED GIT_ARGS_FOLDER)
            set(GIT_ARGS_FOLDER "external")
        endif()

        if ((DEFINED GIT_ARGS_LOCAL) AND (${GIT_ARGS_LOCAL}))
            set(INTERNAL_CMAKE_SOURCE ${CMAKE_CURRENT_SOURCE_DIR})
        else()
            set(INTERNAL_CMAKE_SOURCE ${CMAKE_SOURCE_DIR})
        endif()
        
        if ((DEFINED GIT_ARGS_OVERRIDE) AND (${GIT_ARGS_OVERRIDE}))
            __GitUtils_ResetIncludeMapItem(${PROJECT})
        endif()
        
        __GitUtils_AppendIncludeMapItem(${PROJECT} ${INTERNAL_CMAKE_SOURCE}/${GIT_ARGS_FOLDER}/)

        set(GIT_FOLDER ${INTERNAL_CMAKE_SOURCE}/${GIT_ARGS_FOLDER}/${FULL_PROJECT_NAME})

        if(NOT EXISTS ${GIT_FOLDER})
            execute_process(COMMAND git clone ${GIT_URL} ${GIT_FOLDER}/)
            if (DEFINED GIT_ARGS_TAG)
                execute_process(COMMAND git checkout ${GIT_ARGS_TAG} WORKING_DIRECTORY ${GIT_FOLDER}/)
            endif()
        else()
            if ((NOT DEFINED GIT_ARGS_FREEZE) OR (NOT ${GIT_ARGS_FREEZE}))
                execute_process(COMMAND git push WORKING_DIRECTORY ${GIT_FOLDER}/)
                if ((DEFINED GIT_ARGS_PULL) AND (${GIT_ARGS_PULL}))
                    execute_process(COMMAND git pull WORKING_DIRECTORY ${GIT_FOLDER}/)
                endif()
            endif()
        endif()

        if (EXISTS ${GIT_FOLDER}/CMakeLists.txt)
            if (DEFINED GIT_ARGS_BUILD)
                add_subdirectory(${GIT_FOLDER}/ ${GIT_ARGS_BUILD})
            else()
                add_subdirectory(${GIT_FOLDER}/ ${GIT_FOLDER}/build)
            endif()
        endif()
        
        set(SEARCH_INCLUDE "")
        if (DEFINED GIT_ARGS_INCLUDE)
            list(APPEND SEARCH_INCLUDE ${GIT_ARGS_INCLUDE})
        endif()
        list(APPEND SEARCH_INCLUDE include src source Src Source)
        foreach(INCLUDE_DIR ${SEARCH_INCLUDE})
            if (EXISTS ${GIT_FOLDER}/${INCLUDE_DIR}/)
                __GitUtils_AppendIncludeMapItem(${PROJECT} ${GIT_FOLDER}/${INCLUDE_DIR}/)
                break()
            endif()
        endforeach()

        set_property(GLOBAL APPEND PROPERTY GLOBAL_GIT_UTILS_PROJECTS_LIST ${FULL_PROJECT_NAME})
    endif()

endfunction()


function(GitUtils_Depends PROJECT)
    set(ARGS_OPT "")
    set(ARGS_ONE "")
    set(ARGS_LIST DEPENDS)
    cmake_parse_arguments(GIT_ARGS "${ARGS_OPT}" "${ARGS_ONE}" "${ARGS_LIST}" ${ARGN})

    message("[DEPENDENCY GIT] ${PROJECT}: ${GIT_ARGS_DEPENDS}")

    foreach(DEPEND ${GIT_ARGS_DEPENDS})
        __GitUtils_AppendDependencyMapItem(PROJECT ${DEPEND})
    endforeach()
endfunction()


function(GitUtils_TargetInclude TARGET)
    set(ARGS_OPT "")
    set(ARGS_ONE "")
    set(ARGS_LIST DEPENDS)
    cmake_parse_arguments(GIT_ARGS "${ARGS_OPT}" "${ARGS_ONE}" "${ARGS_LIST}" ${ARGN})
    
    set(TARGET_DEPENDS "")
    foreach(DEPEND ${GIT_ARGS_DEPENDS})
        __GitUtils_RecurciveDependency(DEPEND TARGET_DEPENDS)
    endforeach()
    
    message("[TARGET GIT INCLUDES] ${Target}")

    foreach(DEPEND ${TARGET_DEPENDS})
        message("    ${DEPEND}")
        target_include_directories(${TARGET} PRIVATE ${DEPEND})
    endforeach()
    message("[END] ${Target}")
endfunction()