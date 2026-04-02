cmake_minimum_required(VERSION 3.23)
project(minibar LANGUAGES C CXX)

find_package(PkgConfig REQUIRED)
find_program(WAYLAND_SCANNER wayland-scanner REQUIRED)
pkg_check_modules(WAYLAND REQUIRED IMPORTED_TARGET wayland-client)
pkg_check_modules(CAIRO REQUIRED IMPORTED_TARGET cairo)
pkg_check_modules(PANGOCAIRO REQUIRED IMPORTED_TARGET pangocairo)

set(WLR_PROTO "/usr/share/wlr-protocols/unstable/wlr-layer-shell-unstable-v1.xml" CACHE FILEPATH "wlr layer shell protocol XML")
set(XDG_PROTO "/usr/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml" CACHE FILEPATH "xdg shell protocol XML")

set(WLR_HEADER "${CMAKE_CURRENT_BINARY_DIR}/wlr-layer-shell-unstable-v1-client-protocol.h")
set(WLR_CODE "${CMAKE_CURRENT_BINARY_DIR}/wlr-layer-shell-unstable-v1-protocol.c")
set(XDG_HEADER "${CMAKE_CURRENT_BINARY_DIR}/xdg-shell-client-protocol.h")
set(XDG_CODE "${CMAKE_CURRENT_BINARY_DIR}/xdg-shell-protocol.c")

add_custom_command(
    OUTPUT ${WLR_HEADER}
    COMMAND ${WAYLAND_SCANNER} client-header ${WLR_PROTO} ${WLR_HEADER}
    DEPENDS ${WLR_PROTO}
    VERBATIM
)

add_custom_command(
    OUTPUT ${WLR_CODE}
    COMMAND ${WAYLAND_SCANNER} private-code ${WLR_PROTO} ${WLR_CODE}
    DEPENDS ${WLR_PROTO}
    VERBATIM
)

add_custom_command(
    OUTPUT ${XDG_HEADER}
    COMMAND ${WAYLAND_SCANNER} client-header ${XDG_PROTO} ${XDG_HEADER}
    DEPENDS ${XDG_PROTO}
    VERBATIM
)

add_custom_command(
    OUTPUT ${XDG_CODE}
    COMMAND ${WAYLAND_SCANNER} private-code ${XDG_PROTO} ${XDG_CODE}
    DEPENDS ${XDG_PROTO}
    VERBATIM
)

add_custom_target(protocol_bindings DEPENDS ${WLR_HEADER} ${WLR_CODE} ${XDG_HEADER} ${XDG_CODE})

add_executable(minibar minibar.cpp ${WLR_CODE} ${XDG_CODE})
add_dependencies(minibar protocol_bindings)
set_source_files_properties(${WLR_CODE} ${XDG_CODE} PROPERTIES LANGUAGE C)

target_compile_features(minibar PRIVATE cxx_std_20)
target_compile_options(minibar PRIVATE -Wall -Wextra -Wpedantic)
target_include_directories(minibar PRIVATE ${CMAKE_CURRENT_BINARY_DIR})
target_link_libraries(minibar PRIVATE
    PkgConfig::WAYLAND
    PkgConfig::CAIRO
    PkgConfig::PANGOCAIRO
)
