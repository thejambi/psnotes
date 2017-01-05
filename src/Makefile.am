## Process this file with automake to produce Makefile.in

## Created by Anjuta



AM_CPPFLAGS = \
	-DPACKAGE_LOCALE_DIR=\""$(localedir)"\" \
	-DPACKAGE_SRC_DIR=\""$(srcdir)"\" \
	-DPACKAGE_DATA_DIR=\""$(pkgdatadir)"\" \
	$(PSNOTES_CFLAGS)

AM_CFLAGS =\
	 -Wall\
	 -g

bin_PROGRAMS = psnotes

psnotes_SOURCES = \
	psnotes.vala config.vapi FileUtility.vala Note.vala NoteEditor.vala NotesFilter.vala NotesMonitor.vala UserData.vala UserSettingsManager.vala Zystem.vala HyperTextView.vala

psnotes_VALAFLAGS =  --pkg gio-2.0 --pkg glib-2.0 --pkg gee-0.8 --pkg gtk+-3.0 --pkg gdk-3.0 --pkg gtksourceview-3.0  \
	--pkg gtk+-3.0  

psnotes_LDFLAGS = \
	-Wl,--export-dynamic

psnotes_LDADD = $(PSNOTES_LIBS)


