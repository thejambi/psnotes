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
	psnotes.vala config.vapi FileUtility.vala Note.vala NoteEditor.vala UserData.vala UserSettingsManager.vala Zystem.vala

psnotes_VALAFLAGS =  --pkg glib-2.0 --pkg gee-1.0 --pkg gtk+-3.0  \
	--pkg gtk+-3.0

psnotes_LDFLAGS = \
	-Wl,--export-dynamic

psnotes_LDADD = $(PSNOTES_LIBS)


