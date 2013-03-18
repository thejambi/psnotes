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
		this.setNoteInfo(title);
		Zystem.debug("Note path is: " + this.filePath);
	}

	public void setNoteInfo(string title) {
		this.title = title;
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

	public void rename(string title, string text) {
		// Only rename file if no duplicate.
		if (!FileUtility.isDuplicateNoteTitle(title)) {
			this.removeNoteFile();
			this.setNoteInfo(title);
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

	public void save(string text) throws GLib.Error {
		if (text.strip() == "") {
			this.removeNoteFile();
		} else {
			this.saveFileContents(text);
		}
	}

	private void saveFileContents(string text) throws GLib.Error {
		Zystem.debug("ACTUALLY SAVING FILE");
		// this.noteFile.replace_contents(text, text.length, null, false, FileCreateFlags.NONE, null, null);
		this.noteFile.replace_contents(text.data, null, false, FileCreateFlags.NONE, null, null);
	}

	private void removeNoteFile() {
		var file = File.new_for_path(this.filePath);

		if (file.query_exists()) {
			try {
				file.delete();
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
