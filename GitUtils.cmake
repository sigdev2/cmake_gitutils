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


function(GitUtils_Define PROJECT GIT_URL)
    set(ARGS_OPT FREEZE PULL LOCAL OVERRIDE)
    set(ARGS_ONE TAG FOLDER INCLUDE BUILD)
    set(ARGS_LIST "")
    cmake_parse_arguments(GIT_ARGS "${ARGS_OPT}" "${ARGS_ONE}" "${ARGS_LIST}" ${ARGV})

    set(FULL_PROJECT_NAME ${PROJECT})
    if (DEFINED GIT_ARGS_TAG)
        set(FULL_PROJECT_NAME ${FULL_PROJECT_NAME}_${GIT_ARGS_TAG})
    endif()
    
    get_property(PROJECTS_LIST GLOBAL PROPERTY GLOBAL_GIT_UTILS_PROJECTS_LIST)
    if (NOT (${FULL_PROJECT_NAME} IN_LIST PROJECTS_LIST))
        if (DEFINED GIT_ARGS_OVERRIDE)
            message("[OVERRIDE GIT] repository project ${PROJECT} to ${FULL_PROJECT_NAME}")
        else()
            message("[DEFINE GIT] repository project ${PROJECT} and append as ${FULL_PROJECT_NAME}")
        endif()
    
        if (NOT DEFINED GIT_ARGS_FOLDER)
            set(GIT_ARGS_FOLDER "external")
        endif()

        if (DEFINED GIT_ARGS_LOCAL)
            set(INTERNAL_CMAKE_SOURCE ${CMAKE_CURRENT_SOURCE_DIR})
        else()
            set(INTERNAL_CMAKE_SOURCE ${CMAKE_SOURCE_DIR})
        endif()
        
        if (DEFINED GIT_ARGS_OVERRIDE)
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


# TODO: Just map dependencies for project
function(GitRepositoryDependencies PROJECT)
    set(ARGS_OPT "")
    set(ARGS_ONE TAG)
    set(ARGS_LIST DEPENDS)
    cmake_parse_arguments(GIT_ARGS "${ARGS_OPT}" "${ARGS_ONE}" "${ARGS_LIST}" ${ARGV})
    
    set(FULL_PROJECT_NAME ${PROJECT})
    if (DEFINED GIT_ARGS_TAG)
        set(FULL_PROJECT_NAME ${FULL_PROJECT_NAME}_${GIT_ARGS_TAG})
    endif()
    
    _GitUtils_DefineIncludeMapItem(${PROJECT})
    get_property(TARGET_PROJECT_INCLUDE_LIST GLOBAL PROPERTY GLOBAL_GIT_REPOSITORY_PROJECT_INCLUDE_MAP_${FULL_PROJECT_NAME})

    foreach(DEPEND ${GIT_ARGS_DEPENDS})
        get_property(HAS_DEPEND_INCLUDE GLOBAL PROPERTY GLOBAL_GIT_REPOSITORY_PROJECT_INCLUDE_MAP_${DEPEND} DEFINED)
        if (NOT ${HAS_DEPEND_INCLUDE})
            message(FATAL_ERROR "Git repository project ${DEPEND} must be defined before set as depend")
        endif()
        get_property(DEPEND_PROJECT_INCLUDE_LIST GLOBAL PROPERTY GLOBAL_GIT_REPOSITORY_PROJECT_INCLUDE_MAP_${DEPEND})
        
        foreach(DEPEND_INCLUDE ${DEPEND_PROJECT_INCLUDE_LIST})
            if (NOT (${DEPEND} IN_LIST TARGET_PROJECT_INCLUDE_LIST))
                list(PREPEND TARGET_PROJECT_INCLUDE_LIST ${DEPEND})
            endif()
        endforeach()
    endforeach()
    set_property(GLOBAL PROPERTY GLOBAL_GIT_REPOSITORY_PROJECT_INCLUDE_MAP_${FULL_PROJECT_NAME} TARGET_PROJECT_INCLUDE_LIST)
endfunction()


# TODO: Collect all includes for dependencies map
function(GitRepositoryTargetDependencies TARGET)
    set(ARGS_OPT "")
    set(ARGS_ONE "")
    set(ARGS_LIST DEPENDS)
    cmake_parse_arguments(GIT_ARGS "${ARGS_OPT}" "${ARGS_ONE}" "${ARGS_LIST}" ${ARGV})
    
    set(TARGET_DEPENDS "")
    foreach(DEPEND ${GIT_ARGS_DEPENDS})
        get_property(HAS_DEPEND_INCLUDE GLOBAL PROPERTY GLOBAL_GIT_REPOSITORY_PROJECT_INCLUDE_MAP_${DEPEND} DEFINED)
        if (NOT ${HAS_DEPEND_INCLUDE})
            message(FATAL_ERROR "Git repository project ${DEPEND} must be defined before set as depend for target")
        endif()
        get_property(DEPEND_PROJECT_INCLUDE_LIST GLOBAL PROPERTY GLOBAL_GIT_REPOSITORY_PROJECT_INCLUDE_MAP_${DEPEND})
        
        foreach(DEPEND_INCLUDE ${DEPEND_PROJECT_INCLUDE_LIST})
            if (NOT (${DEPEND_INCLUDE} IN_LIST TARGET_DEPENDS))
                list(APPEND TARGET_DEPENDS ${DEPEND_INCLUDE})
            endif()
        endforeach()
    endforeach()
    
    foreach(DEPEND ${TARGET_DEPENDS})
        target_include_directories(${TARGET} PRIVATE ${DEPEND})
    endforeach()
endfunction()