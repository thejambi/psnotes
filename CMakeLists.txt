project (com.github.thejambi.psnotes)

cmake_minimum_required (VERSION 2.6)

list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)
list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake/src)

set (DATADIR "${CMAKE_INSTALL_PREFIX}/share")

set (PKGDATADIR "${DATADIR}/com.github.thejambi.psnotes")

set (EXEC_NAME "com.github.thejambi.psnotes")
set (RELEASE_NAME "PSNotes")
set (VERSION "0.16.0")
set (VERSION_INFO "Initial release")

find_package(PkgConfig)

pkg_check_modules(DEPS REQUIRED 
    gtk+-3.0
    gdk-3.0
    gee-0.8
    gio-2.0
    glib-2.0
    gtksourceview-3.0)

add_definitions(${DEPS_CFLAGS})
link_libraries(${DEPS_LIBRARIES})
link_directories(${DEPS_LIBRARY_DIRS})

find_package(Vala REQUIRED)
include(ValaVersion)
ensure_vala_version("0.16" MINIMUM)

include(ValaPrecompile)
vala_precompile(VALA_C ${EXEC_NAME}
    src/psnotes.vala
    src/FileUtility.vala
    src/HyperTextView.vala
    src/Note.vala
    src/NoteEditor.vala
    src/NotesFilter.vala
    src/NotesMonitor.vala
    src/UserData.vala
    src/UserSettingsManager.vala
    src/Zystem.vala

PACKAGES
    gtk+-3.0
    gdk-3.0
    gee-0.8
    gio-2.0
    glib-2.0
    gtksourceview-3.0
)

add_executable(${EXEC_NAME} ${VALA_C})

install (TARGETS ${EXEC_NAME} RUNTIME DESTINATION bin)

install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/com.github.thejambi.psnotes.desktop DESTINATION ${DATADIR}/applications/)

install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/com.github.thejambi.psnotes.appdata.xml DESTINATION ${DATADIR}/metainfo/)

install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/icons/16/com.github.thejambi.psnotes.png DESTINATION share/icons/hicolor/16x16/apps)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/icons/24/com.github.thejambi.psnotes.png DESTINATION share/icons/hicolor/24x24/apps)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/icons/32/com.github.thejambi.psnotes.png DESTINATION share/icons/hicolor/32x32/apps)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/icons/48/com.github.thejambi.psnotes.png DESTINATION share/icons/hicolor/48x48/apps)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/icons/64/com.github.thejambi.psnotes.png DESTINATION share/icons/hicolor/64x64/apps)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/icons/128/com.github.thejambi.psnotes.png DESTINATION share/icons/hicolor/128x128/apps)

# Translation files
#set (GETTEXT_PACKAGE "${CMAKE_PROJECT_NAME}")
#add_definitions (-DGETTEXT_PACKAGE=\"${GETTEXT_PACKAGE}\")
#add_subdirectory (po)

option (ICON_UPDATE "Run gtk-update-icon-cache after the install." ON)
if (ICON_UPDATE)
  install (CODE "message(\"-- Updating icon cache...\")")
  install (CODE "execute_process(COMMAND gtk-update-icon-cache -f -t ${CMAKE_INSTALL_PREFIX}/share/icons/hicolor)")
endif (ICON_UPDATE)

# end
