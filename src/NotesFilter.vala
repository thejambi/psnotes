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

public enum LoadRequestType {
	autoSaved,
	fileMonitorEvent,
	filterTextChanged,
	otherType;
}

public class NotesFilter : GLib.Object {

	private weak ListStore listmodel;
	private weak TreeSelection treeSelection;

	private int reloadCount;

	private bool loadRequested;
	private bool noLoad;

	private string filterText;
	
	// Constructor
	public NotesFilter(ListStore listmodel, TreeSelection treeSelection) {
		this.listmodel = listmodel;
		this.treeSelection = treeSelection;
		this.loadRequested = false;
		this.reloadCount = 0;
		this.noLoad = false;
		this.filterText = "";
	}

	public async void filter() {

		Zystem.debug("Filter Text:" + this.filterText + "|");
		
		this.reloadCount++;
		Zystem.debug("********************   Reload count is: " + this.reloadCount.to_string());
		if (this.reloadCount < 0) {
			return;
		}

//		this.treeSelection.unselect_all();
		this.treeSelection.mode = SelectionMode.NONE;
		
		try {
			Gee.Set<string> results = new Gee.HashSet<string>();
			
			listmodel.clear();
			listmodel.set_sort_column_id(0, SortType.ASCENDING);
			// var notesList = new GLib.List<string>();
			TreeIter iter;

			File notesDir = File.new_for_path(UserData.notesDirPath);
			FileEnumerator enumerator = notesDir.enumerate_children(FileAttribute.STANDARD_NAME, 0);
			FileInfo fileInfo;

			// Go through the files to check for note titles (file names) that match filter text
			while((fileInfo = enumerator.next_file()) != null) {
				// string filename = fileInfo.get_name();
				if (FileUtility.getFileExtension(fileInfo) == ".txt") {
					// Check if name contains filter text
					// Zystem.debug(FileUtility.getFileNameWithoutExtension(fileInfo));
					string name = FileUtility.getFileNameWithoutExtension(fileInfo);
					if (filterText.down() in name.down()) {
						listmodel.append(out iter);
						listmodel.set(iter, 0, name);
						results.add(name);
					}
				}
			}

			enumerator = notesDir.enumerate_children(FileAttribute.STANDARD_NAME, 0);
			// Go through the files to search contents of notes for filter text
			while((fileInfo = enumerator.next_file()) != null) {
				// string filename = fileInfo.get_name();
				if (FileUtility.getFileExtension(fileInfo) == ".txt") {
					string name = FileUtility.getFileNameWithoutExtension(fileInfo);
					if (!results.contains(name)) {
						Note note = new Note(name);
						string noteText = note.getContents();
						if (filterText.down() in noteText.down()) {
							listmodel.append(out iter);
							listmodel.set(iter, 0, name);
						}
					}
				}
			}
			
		} catch(Error e) {
			stderr.printf ("Error loading notes list: %s\n", e.message);
		}

		this.treeSelection.mode = SelectionMode.SINGLE;
	}
	
	public bool onTimerEvent() {
		this.loadRequested = false;
		
		if (this.noLoad) {
			Zystem.debug("------------------------------> NoLoad! <------------------------");
			this.noLoad = false;
			
			return false;
		}
		
		Zystem.debug("Timer event. Calling filter.");
		this.filter();
		
		return false;
	}


	public void setToLoad(LoadRequestType requestType) {
//		Zystem.debug(requestType.to_string());
		if (!this.loadRequested && requestType != LoadRequestType.autoSaved) {
			var timerId = Timeout.add(1000, onTimerEvent);
			Zystem.debug("Set timer!");
		} else {
			Zystem.debug("No Timer Set! Take THAT!");
		}

		this.loadRequested = true;
	}

	public void notifyAutoSave() {
		this.noLoad = true;
	}

	public void setFilterText(string text) {
		this.filterText = text;
	}
	

}

