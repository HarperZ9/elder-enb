cmake_minimum_required(VERSION 4.0)

cmake_policy(SET CMP0091 NEW)
set(CMAKE_VS_GLOBALS "VcpkgEnabled=false")

project(ElderENB VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

add_library(elder_profiles STATIC
    src/profiles/TransactionalProfile.cpp
)

target_include_directories(elder_profiles
    PUBLIC
        "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>"
)

target_compile_features(elder_profiles PUBLIC cxx_std_23)

if(MSVC)
    target_compile_options(elder_profiles PRIVATE /W4 /WX /permissive-)
endif()

include(CTest)

if(BUILD_TESTING)
    add_executable(elder_profile_tests
        tests/TransactionalProfileTests.cpp
    )

    target_link_libraries(elder_profile_tests PRIVATE elder_profiles)

    if(MSVC)
        target_compile_options(elder_profile_tests PRIVATE /W4 /WX /permissive-)
    endif()

    add_test(NAME transactional_profile_tests COMMAND elder_profile_tests)
    set_tests_properties(transactional_profile_tests PROPERTIES TIMEOUT 30)
endif()
