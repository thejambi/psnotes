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
	noteRename,
	otherType;
}

public class NotesFilter : GLib.Object {

	/* 300 tested to be good. */
	private const int LOAD_AFTER_THIS_MANY_MILLISECONDS = 300;

	private weak Gtk.ListStore listmodel;
	private weak TreeSelection treeSelection;

	private int reloadCount;

	public LoadRequestType lastLoadRequestType { get; private set; }
	private bool loadRequested;
	private bool noLoad;

	private string filterText;

	private uint timerId;
	
	// Constructor
	public NotesFilter(Gtk.ListStore listmodel, TreeSelection treeSelection) {
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

		this.treeSelection.mode = SelectionMode.NONE;
		
		try {
			Gee.Set<string> results = new Gee.HashSet<string>();
			
			listmodel.clear();

			listmodel.set_sort_column_id(0, SortType.ASCENDING);
			
			if (UserData.useAltSortType) {
				Zystem.debug("Sorting list");
				listmodel.set_sort_func(0, (model, iterA, iterB) => {
					Value value;
					model.get_value(iterA, 0, out value);
					string noteTitleA = value.get_string();
					var noteA = new Note(noteTitleA);
					//Zystem.debug("Note A: " + noteTitleA);

					model.get_value(iterB, 0, out value);
					string noteTitleB = value.get_string();
					var noteB = new Note(noteTitleB);
					//Zystem.debug("Note B: " + noteTitleB);

					long compare = noteB.getModifiedTime() - noteA.getModifiedTime();
					//Zystem.debug(compare.to_string());

					if (compare > 0) {
						return 1;
					} else if (compare < 0) {
						return -1;
					} else {
						return 0;
					}
				});
			}
			
			TreeIter iter;

			File notesDir = File.new_for_path(UserData.notesDirPath);
			FileEnumerator enumerator = notesDir.enumerate_children(FileAttribute.STANDARD_NAME, 0);
			FileInfo fileInfo;
			
			UserData.inBook = false;

			if (UserData.inChapter) {
				listmodel.append(out iter);
				listmodel.set(iter, 0, UserData.upToBook);
			} else if (UserData.inFolder) {
				listmodel.append(out iter);
				listmodel.set(iter, 0, UserData.upToFolder);
			}
			
			// Go through the files to check for note titles (file names) that match filter text
			while((fileInfo = enumerator.next_file()) != null) {
				if (FileUtility.getFileExtension(fileInfo) == UserData.fileExtension) {
					if (fileInfo.get_name() == UserData.bookDirMagicFilename) {
						var note = new Note("title");
						if (note.getContents().has_prefix("---")) {
							UserData.inBook = true;
							UserData.bookRoot = UserData.notesDirPath;
							Zystem.debug("--- IN BOOK ---");
						}
					}
					// Check if name contains filter text
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
				if (FileUtility.getFileExtension(fileInfo) == UserData.fileExtension) {
					string name = FileUtility.getFileNameWithoutExtension(fileInfo);
					if (!results.contains(name)) {
						Note note = new Note(name);
						string noteText = note.getContents();
						if (filterText.down() in noteText.down()) {
							listmodel.append(out iter);
							listmodel.set(iter, 0, name);
						}
					}
				} else if (UserData.inBook) {
					if (FileUtility.isDirectory(FileUtility.pathCombine(UserData.notesDirPath, fileInfo.get_name()))) {
						listmodel.append(out iter);
						listmodel.set(iter, 0, UserData.chapterKey + fileInfo.get_name());
					}
				} else {
					if (FileUtility.isDirectory(FileUtility.pathCombine(UserData.notesDirPath, fileInfo.get_name()))) {
						listmodel.append(out iter);
						listmodel.set(iter, 0, UserData.folderKey + fileInfo.get_name());
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
		if (!this.loadRequested && requestType != LoadRequestType.autoSaved) {
			this.lastLoadRequestType = requestType;
			this.timerId = Timeout.add(LOAD_AFTER_THIS_MANY_MILLISECONDS, onTimerEvent);
			Zystem.debug("Set Load timer! " + requestType.to_string());
		} else if (requestType != LoadRequestType.autoSaved) {
			// Reset timer
			Zystem.debug("Resetting Load timer!");
			Source.remove(this.timerId);
			this.loadRequested = false;
			this.setToLoad(requestType);
		}

		this.loadRequested = true;
	}

	public void notifyAutoSave() {
		this.noLoad = true;
	}

	public void setFilterText(string text) {
		this.filterText = text;
	}

	/*private string getNoteTitle(string text) {
		var newText = text;
		if (UserData.inBook || UserData.inChapter) {
			newText = text.replace(UserData.chapterKey, "00000");
			newText = text.replace(UserData.upToBook, "00000");
			return newText;
		} else {
			return text;
		}
	}*/

}

