cmake_minimum_required(VERSION 3.21)

project(DockHub LANGUAGES CXX)

find_package(ECM REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH} ${CMAKE_MODULE_PATH})

find_package(Plasma REQUIRED)
find_package(Qt6 REQUIRED COMPONENTS Core Qml Network)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

qt_standard_project_setup()

set(KDE_INSTALL_USE_QT_SYS_PATHS TRUE)
include(KDEInstallDirs6)

# Keep the existing Qt resource behavior for the QML module.
qt_policy(SET QTP0001 OLD)

# ---------------------------------------------------------------------------
# Plasma package
# ---------------------------------------------------------------------------

set(DOCKHUB_PACKAGE_ID "com.opensquares.dockhub")
set(DOCKHUB_PACKAGE_DIR "${CMAKE_CURRENT_BINARY_DIR}/package")

# Recreate the staging package to prevent stale files.
file(REMOVE_RECURSE "${DOCKHUB_PACKAGE_DIR}")
file(MAKE_DIRECTORY "${DOCKHUB_PACKAGE_DIR}")

configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/metadata.json"
    "${DOCKHUB_PACKAGE_DIR}/metadata.json"
    COPYONLY
)

# Copy the complete contents directory, excluding the generated QML module.
# The generated module is built separately below.
file(COPY
    "${CMAKE_CURRENT_SOURCE_DIR}/contents/"
    DESTINATION "${DOCKHUB_PACKAGE_DIR}/contents"
    PATTERN "screenshots" EXCLUDE
    PATTERN "OpenSquares" EXCLUDE
)

plasma_install_package(
    "${DOCKHUB_PACKAGE_DIR}"
    "${DOCKHUB_PACKAGE_ID}"
)

# ---------------------------------------------------------------------------
# Native QML module
# ---------------------------------------------------------------------------

set(DOCKHUB_QML_MODULE_DIR
    "${CMAKE_CURRENT_BINARY_DIR}/contents/ui/OpenSquares/DockHub"
)

qt_add_qml_module(dockhub
    URI OpenSquares.DockHub
    VERSION 1.0
    OUTPUT_DIRECTORY "${DOCKHUB_QML_MODULE_DIR}"

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
        Qt6::Network
)

# The plugin and its backing library are installed side by side.
set_target_properties(dockhubplugin PROPERTIES
    INSTALL_RPATH "$ORIGIN"
)

# Install both libraries into the Qt QML import directory.
install(
    TARGETS dockhub dockhubplugin
    LIBRARY DESTINATION "${KDE_INSTALL_QMLDIR}/OpenSquares/DockHub"
)

# Install the generated QML module metadata.
install(
    DIRECTORY "${DOCKHUB_QML_MODULE_DIR}/"
    DESTINATION "${KDE_INSTALL_QMLDIR}/OpenSquares/DockHub"
    FILES_MATCHING
        PATTERN "qmldir"
        PATTERN "*.qmltypes"
)
