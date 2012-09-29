## Process this file with automake to produce Makefile.in
## Created by Anjuta

SUBDIRS = src 

psnotesdocdir = ${prefix}/doc/psnotes
psnotesdoc_DATA = \
	README\
	COPYING\
	AUTHORS\
	ChangeLog\
	INSTALL\
	NEWS


EXTRA_DIST = $(psnotesdoc_DATA)


# Remove doc directory on uninstall
uninstall-local:
	-rm -r $(psnotesdocdir)
