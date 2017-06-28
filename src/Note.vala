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
	public string filePath { get; private set; }
	private File noteFile;
	//private string loadedContents = "";

	// Constructor
	public Note(string title) {
		this.setNoteInfo(title);
	}

	public string trimBadStuffFromTitle(string title) {
		var newTitle = title;
		if (newTitle.has_prefix("#")) {
			newTitle = newTitle.substring(1).strip();
		}
		if (newTitle == "---") {
			newTitle = "title";
		}
		return newTitle.replace("/", "_");
	}

	public void setNoteInfo(string newTitle) {
		this.title = newTitle;
		this.filePath = FileUtility.pathCombine(UserData.notesDirPath, this.title + UserData.fileExtension);
		this.noteFile = File.new_for_path(this.filePath);
	}

	public string getContents() {
		/*if (this.hasLoadedContents()) {
			return this.loadedContents;
		}*/
		
		try {
			string contents;
			FileUtils.get_contents(this.filePath, out contents);
			//this.loadedContents = contents;
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
		//this.loadedContents = text;
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
		
		try {
			this.noteFile.replace_contents(text.data, null, false, FileCreateFlags.NONE, null, null);
			//this.loadedContents = text;
		} catch (Error e) {
			try {
				// Problem saving, so give it another title
				this.rename(FileUtility.getTimestamp(), text);
			} catch (Error e) {
				this.rename("__Save_failed", text);
			}
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

	public long getModifiedTime() {
		if (UserData.inBook || UserData.inChapter) {
			var tv = new TimeVal();
			tv.get_current_time();
			if (this.title == UserData.bookDirMagicFilename) {
				tv.tv_sec = tv.tv_sec + (long)999999999999;
			}
			return tv.tv_sec;
		} else {
			FileInfo fileInfo = this.noteFile.query_info(FileAttribute.TIME_MODIFIED, FileQueryInfoFlags.NONE);
			var timeVal = fileInfo.get_modification_time();
			return timeVal.tv_sec;
		}
	}

	/*private void notLoaded() {
		this.loadedContents = "";
	}

	private bool hasLoadedContents() {
		return this.loadedContents != "";
	}*/

}

/*
public class NoteFileExtensions {
	private static Gee.Set<string> allowedFileExtensions = new Gee.HashSet<string>();

	public static void initialize() {
		allowedFileExtensions.add(".txt");
		allowedFileExtensions.add(".text");
		allowedFileExtensions.add(".md");
		allowedFileExtensions.add(".markdown");
		allowedFileExtensions.add(".fountain");
	}

	public static bool isAllowed(string ext) {
		return ext in allowedFileExtensions;
	}
}
*/

public class ChapterCompiler : GLib.Object {

	private static const string SCENE_SEPARATOR = "÷÷÷§÷÷÷";

	private string bookDir;
	private string chapDir;

	// Constructor
	public ChapterCompiler() {
		this.bookDir = UserData.bookRoot;
		this.chapDir = UserData.notesDirPath;
	}

	public string compileChapterText() {
		Zystem.debug("--- IN COMPILE CHAPTER ---");

		Gee.SortedSet<string> results = new Gee.TreeSet<string>(null);
		
		File notesDir = File.new_for_path(UserData.notesDirPath);
		FileEnumerator enumerator = notesDir.enumerate_children(FileAttribute.STANDARD_NAME, 0);
		FileInfo fileInfo;
		
		while((fileInfo = enumerator.next_file()) != null) {
			if (FileUtility.getFileExtension(fileInfo) == UserData.fileExtension) {
				string name = FileUtility.getFileNameWithoutExtension(fileInfo);
				results.add(name);
			}
		}

		var chapterText = "";
		
		foreach (string name in results) {
			Zystem.debug(name);
			var note = new Note(name);
			var noteText = note.getContents().strip();

			// Remove HTML comments
			try {
				Regex regex = new Regex ("<!--([\\s\\S]*?)-->");  // Regex for HTML comments
				noteText = regex.replace (noteText, noteText.length, 0, "");
			} catch (RegexError e) {
				stdout.printf ("Regex Error: %s\n", e.message);
			}
			
			chapterText += noteText + "\n\n";
		}

		return chapterText;
	}

	public void saveChapterText(string title, string text) {
		// Fix up title?
		var chapterTitle = title;
		Zystem.debug("Chapter Title: " + chapterTitle);
		if (chapterTitle.has_prefix("#")) {
			chapterTitle = chapterTitle.replace("#", "").strip();
			Zystem.debug("Chapter Title: " + chapterTitle);
		}

		// If title has a dash and it's a number before it, just use the number as the title
		if (chapterTitle.contains("-")) {
			var chNum = chapterTitle.slice(0, chapterTitle.index_of("-")).strip();
			Zystem.debug("CHAPTER NUMBER: " + chNum);
			//if (int64.try_parse(chNum.get_char().to_string())) {	// Weird because chapter 08 wasn't working?
			chapterTitle = "Chapter " + chNum;
		}

		var h2 = "\n## ";

		var chapterText = "# " + chapterTitle + "\n" + text;
		chapterText = chapterText.strip().replace("\n# ", h2);
		var first = true;
		while (chapterText.contains(h2)) {
			var startIndex = chapterText.index_of(h2);
			var endIndex = chapterText.index_of("\n", startIndex + 1);
			var replacement = first ? "" : "\n\n" + SCENE_SEPARATOR + "\n"; // ¤ § · ÷
			chapterText = chapterText.splice(startIndex, endIndex, replacement);
			Zystem.debug("Replaced h2 at " + startIndex.to_string() + " to " + endIndex.to_string());
			first = false;
		}
		
		var note = new Note(chapterTitle);
		note.save(chapterText);
	}

	public void compileEPub() {
		Zystem.debug("IN COMPILE EPUB");

		var cmdStart = "pandoc -S -f commonmark ";

		// Need to know filename, path to title, paths to chapter files

		var filename = FileUtility.pathCombine(UserData.bookRoot, FileUtility.getNameFromPath(this.bookDir));


		Gee.SortedSet<string> chapters = new Gee.TreeSet<string>();
		
		File notesDir = File.new_for_path(UserData.notesDirPath);
		FileEnumerator enumerator = notesDir.enumerate_children(FileAttribute.STANDARD_NAME, 0);
		FileInfo fileInfo;

		Note titleNote = new Note("title");
		
		while((fileInfo = enumerator.next_file()) != null) {
			if (fileInfo.get_name() == UserData.bookDirMagicFilename) {
				titleNote = new Note(FileUtility.getFileNameWithoutExtension(fileInfo));
			} else if (FileUtility.getFileExtension(fileInfo) == UserData.fileExtension) {
				string name = FileUtility.getFileNameWithoutExtension(fileInfo);
				chapters.add(name);

				// Generate odt for chapter
				var note = new Note(name);
				var cmd = cmdStart + "-t odt -o " + FileUtility.pathCombine(UserData.bookRoot, name.replace(" ", "\\ ")) + ".odt " + note.filePath.replace(" ", "\\ ");
				Zystem.debug(cmd);
				GLib.Process.spawn_command_line_sync(cmd);
			}
		}

		var cmd = cmdStart;
		
		cmd += "-t odt -o " + filename + ".odt " + titleNote.filePath;

		foreach (string name in chapters) {
			Zystem.debug(name);
			var note = new Note(name);
			cmd += " \\\n" + note.filePath.replace(" ", "\\ ");
		}

		Zystem.debug(cmd);
		
		GLib.Process.spawn_command_line_sync(cmd);

		cmd = cmdStart;
		cmd += "-t epub --epub-cover-image=" + UserData.notesDirPath + "/cover.jpg -o " + filename + ".epub " + titleNote.filePath;

		//cmd = "pandoc -S -o " + filename + ".epub " + titleNote.filePath;

		foreach (string name in chapters) {
			Zystem.debug(name);
			var note = new Note(name);
			cmd += " \\\n" + note.filePath.replace(" ", "\\ ");
		}

		Zystem.debug(cmd);
		
		GLib.Process.spawn_command_line_sync(cmd);
	}

}