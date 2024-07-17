idf_component_register(
    SRCS
        "../../../source/idfd/signalio/idfd_signalio_i2s_c_code.c"
    INCLUDE_DIRS "."
)
target_link_libraries("${COMPONENT_LIB}" "${PROJECT_DIR}/dcode.a")
target_link_options("${COMPONENT_LIB}" INTERFACE "-Wl,--start-group") # Allow forward references during linkage
