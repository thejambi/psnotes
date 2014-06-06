/* -*- Mode: vala; tab-width: 4; intend-tabs-mode: t -*- */
/* PSNotes
 *
 * Copyright (C) Zach Burnham 2012 <thejambi@gmail.com>
 *
PSNotes is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * PSNotes is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

public class Note : GLib.Object {

	public string title { get; private set; }
	private string filePath;
	private File noteFile;

	// Constructor
	public Note(string title) {
		this.setNoteInfo(this.trimBadStuffFromTitle(title));
		Zystem.debug("Note path is: " + this.filePath);
	}

	public string trimBadStuffFromTitle(string title) {
		return title.replace("/", "_");
	}

	public void setNoteInfo(string newTitle) {
		this.title = newTitle;
		this.filePath = FileUtility.pathCombine(UserData.notesDirPath, this.title + ".txt");
		this.noteFile = File.new_for_path(this.filePath);
	}

	public string getContents() {
		try {
			string contents;
			FileUtils.get_contents(this.filePath, out contents);
			return contents;
		} catch(FileError e) {
			return "";
		}
	}

	public void rename(string noteTitle, string text) {
		// Don't let there be a filename that is too long
		string newTitle = this.trimBadStuffFromTitle(noteTitle);
		if (noteTitle.length > 200) {
			newTitle = noteTitle.substring(0, 200);
		}
		// Only rename file if no duplicate.
		if (!FileUtility.isDuplicateNoteTitle(newTitle)) {
			this.removeNoteFile();
			this.setNoteInfo(newTitle);
		}
		this.saveFileContents(text);
	}

	public async void saveAsync(string text) throws GLib.Error {
		if (text.strip() == "") {
			this.removeNoteFile();
		} else {
			yield this.saveFileContentsAsync(text);
		}
	}

	private async void saveFileContentsAsync(string text) throws GLib.Error {
		Zystem.debug("ACTUALLY SAVING FILE");
		yield this.noteFile.replace_contents_async(text.data, null, false, FileCreateFlags.NONE, null, null);
	}

	public void save(string text) {
		if (text.strip() == "") {
			this.removeNoteFile();
		} else {
			this.saveFileContents(text);
		}
	}

	private void saveFileContents(string text) {
		Zystem.debug("ACTUALLY SAVING FILE");
		// this.noteFile.replace_contents(text, text.length, null, false, FileCreateFlags.NONE, null, null);
		try {
			this.noteFile.replace_contents(text.data, null, false, FileCreateFlags.NONE, null, null);
		} catch (Error e) {
			// Problem saving, so give it another title
			this.rename(FileUtility.getTimestamp(), text);
		}
	}

	private void removeNoteFile() {
		var file = File.new_for_path(this.filePath);

		if (file.query_exists()) {
			try {
				try {
					file.trash();
				} catch (Error e) {
					Zystem.debug("There was an error moving entry file to trash. Just deleting it.");
					file.delete();
				}
			} catch (Error e) {
				Zystem.debug("There was an error removing the entry file");
			}
		}
	}

	/**
	 * Move note file to the archive directory.
	 */
	public void archive() {
		FileInfo fileInfo = this.noteFile.query_info(FileAttribute.STANDARD_NAME, FileQueryInfoFlags.NONE);
		FileUtility.moveFile(fileInfo, UserData.notesDirPath, UserData.getArchivedNotesDir());
	}

}
