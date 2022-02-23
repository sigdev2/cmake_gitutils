# cmake_gitutils
CMake git utils for work with git repositories dependencies

# Using

CMakeLists.txt of libA:

    ...
    
    list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/cmake_gitutils")
    include(GitUtils)
    
    ...
    
    GitUtils_Define(libB https://github.com/libdev/libB)
    GitUtils_Define(libC https://github.com/libdev/libC)
    GitUtils_Depends(libA DEPENDS libB libC)


CMakeLists.txt of Application:

    ...
    
    list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/cmake_gitutils")
    include(GitUtils)
    
    ...
    
    GitUtils_Define(libA https://github.com/libdev/libA)
    
    ...
    
    add_executable(Application main.cpp)
    GitUtils_TargetInclude(Application DEPENDS libA)
