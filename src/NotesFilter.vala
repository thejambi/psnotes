/* -*- Mode: vala; indent-tabs-mode: t; c-basic-offset: 4; tab-width: 4 -*-  */
/* psnotes
 *
 * Copyright (C) 2012 Zach Burnham <thejambi@gmail.com>
 *
psnotes is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * psnotes is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

using Gtk;

public class NotesFilter : GLib.Object {

	private ListStore listmodel;
	
	// Constructor
	public NotesFilter(ListStore listmodel) {
		this.listmodel = listmodel;
	}

	public void filter(string filterText) {
		try {
			listmodel.clear();
			listmodel.set_sort_column_id(0, SortType.ASCENDING);
			// var notesList = new GLib.List<string>();
			TreeIter iter;

			File notesDir = File.new_for_path(UserData.notesDirPath);
			FileEnumerator enumerator = notesDir.enumerate_children(FileAttribute.STANDARD_NAME, 0);
			FileInfo fileInfo;

			// Go through the files
			while((fileInfo = enumerator.next_file()) != null) {
				// string filename = fileInfo.get_name();
				if (FileUtility.getFileExtension(fileInfo) == ".txt") {
					// Zystem.debug(FileUtility.getFileNameWithoutExtension(fileInfo));
					string name = FileUtility.getFileNameWithoutExtension(fileInfo);
					if (filterText.down() in name.down()) {
						listmodel.append(out iter);
						listmodel.set(iter, 0, name);
					}
				}
			}
		} catch(Error e) {
			stderr.printf ("Error loading notes list: %s\n", e.message);
		}
	}

}

