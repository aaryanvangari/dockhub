cmake_minimum_required(VERSION 3.21)

project(DockHub LANGUAGES CXX)

find_package(ECM REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH} ${CMAKE_MODULE_PATH})

find_package(Plasma REQUIRED)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Core Qml)

qt_standard_project_setup()

set(KDE_INSTALL_USE_QT_SYS_PATHS TRUE)
include(KDEInstallDirs6)

if(CMAKE_INSTALL_PREFIX STREQUAL "/usr")
    set(DOCKHUB_QML_INSTALL_DIR "${KDE_INSTALL_QMLDIR}")
else()
    set(DOCKHUB_QML_INSTALL_DIR "${CMAKE_INSTALL_PREFIX}${KDE_INSTALL_QMLDIR}")
endif()

set(DOCKHUB_PACKAGE_DIR "${CMAKE_CURRENT_BINARY_DIR}/package")

file(MAKE_DIRECTORY "${DOCKHUB_PACKAGE_DIR}/contents")


configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/metadata.json"
    "${DOCKHUB_PACKAGE_DIR}/metadata.json"
    COPYONLY
)

file(GLOB DOCKHUB_UI_FILES
    "${CMAKE_CURRENT_SOURCE_DIR}/contents/ui/*.qml"
    "${CMAKE_CURRENT_SOURCE_DIR}/contents/ui/*.js"
)

file(COPY ${DOCKHUB_UI_FILES}
    DESTINATION "${DOCKHUB_PACKAGE_DIR}/contents/ui"
)

configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/contents/screenshot.png"
    "${DOCKHUB_PACKAGE_DIR}/contents/screenshot.png"
    COPYONLY
)

file(COPY
    "${CMAKE_CURRENT_SOURCE_DIR}/contents/screenshots"
    DESTINATION "${DOCKHUB_PACKAGE_DIR}/contents"
)

file(COPY
    "${CMAKE_CURRENT_SOURCE_DIR}/contents/config"
    DESTINATION "${DOCKHUB_PACKAGE_DIR}/contents"
)

plasma_install_package(
    "${DOCKHUB_PACKAGE_DIR}"
    "com.opensquares.dockhub"
)

qt_policy(SET QTP0001 OLD)


qt_add_qml_module(dockhub
    URI OpenSquares.DockHub
    VERSION 1.0
    OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/contents/ui/OpenSquares/DockHub"
    SOURCES
        src/UnixSocketBridge.h
        src/UnixSocketBridge.cpp
)

target_include_directories(dockhub
    PRIVATE
        "${CMAKE_CURRENT_SOURCE_DIR}/src"
)

target_link_libraries(dockhub
    PRIVATE
        Qt6::Core
        Qt6::Qml
)

set_target_properties(dockhubplugin PROPERTIES
    INSTALL_RPATH "$ORIGIN"
)

install(
    TARGETS dockhub
    LIBRARY DESTINATION "${DOCKHUB_QML_INSTALL_DIR}/OpenSquares/DockHub"
)

install(
    TARGETS dockhubplugin
    LIBRARY DESTINATION "${DOCKHUB_QML_INSTALL_DIR}/OpenSquares/DockHub"
)

install(
    DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/contents/ui/OpenSquares/DockHub/"
    DESTINATION "${DOCKHUB_QML_INSTALL_DIR}/OpenSquares/DockHub"
    FILES_MATCHING
        PATTERN "qmldir"
        PATTERN "*.qmltypes"
)
