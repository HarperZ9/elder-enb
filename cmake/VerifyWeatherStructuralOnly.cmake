cmake_minimum_required(VERSION 3.25)

foreach(required IN ITEMS COMPILER SOURCE_ROOT OUTPUT_ROOT)
    if(NOT DEFINED ${required} OR "${${required}}" STREQUAL "")
        message(FATAL_ERROR "${required} is required")
    endif()
endforeach()

file(REMOVE_RECURSE "${OUTPUT_ROOT}")
execute_process(
    COMMAND "${COMPILER}"
        --overlay-root "${SOURCE_ROOT}"
        --preset-root "${SOURCE_ROOT}"
        --catalog "${SOURCE_ROOT}/config/legacy-kreate-bindings.csv"
        --improvement-manifest "${SOURCE_ROOT}/config/first-five-improvements.csv"
        --theme-config "${SOURCE_ROOT}/config/five-profile-weather-themes.csv"
        --semantic-registry "${SOURCE_ROOT}/config/shader-semantic-registry.csv"
        --output-root "${OUTPUT_ROOT}"
        --expect-semantic-verified 15
        --expect-semantic-unresolved 1
    RESULT_VARIABLE result
    OUTPUT_VARIABLE output
    ERROR_VARIABLE error
)
if(NOT result EQUAL 0)
    message(FATAL_ERROR
        "structural-only validation failed (${result})\nstdout:\n${output}\nstderr:\n${error}"
    )
endif()
if(EXISTS "${OUTPUT_ROOT}")
    message(FATAL_ERROR "structural-only validation published output")
endif()
if(NOT output MATCHES
    "mode=structural-only semantic_verified=15 semantic_unresolved=1 output=not-published"
)
    message(FATAL_ERROR "unexpected structural-only report: ${output}")
endif()
