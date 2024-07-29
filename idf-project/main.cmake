idf_component_register(
    SRCS
        "/dev/null"
    INCLUDE_DIRS "."
)
target_link_libraries("${COMPONENT_LIB}" "${PROJECT_DIR}/dcode.a")
target_link_options("${COMPONENT_LIB}" INTERFACE "-Wl,--start-group") # Allow forward references during linkage
#target_link_options("${COMPONENT_LIB}" INTERFACE "-Wl,--print-gc-sections")
