idf_component_register(
    SRCS
        "source/idf/esp_wifi/idf_esp_wifi_c_code.c"
        "source/idf/sys/socket/idf_sys_socket_c_code.c"
        "source/idfd/signalio/i2s_c_code.c"
    INCLUDE_DIRS "."
    PRIV_REQUIRES nvs_flash esp_wifi
)

# Code below is the same for every d component
add_custom_target(
    "${COMPONENT_NAME}_dcode" ALL
    dub build --deep --color=always --arch=xtensa-esp32
    WORKING_DIRECTORY "${COMPONENT_DIR}"
    BYPRODUCTS "${COMPONENT_DIR}/lib${COMPONENT_NAME}.a"
    USES_TERMINAL
)
target_link_libraries(${COMPONENT_LIB} PRIVATE "${COMPONENT_DIR}/lib${COMPONENT_NAME}.a")
target_link_options(${COMPONENT_LIB} INTERFACE "-Wl,--start-group") # Allow .a file order
