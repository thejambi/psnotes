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

using Gee;

class UserData : Object {

	public static const string bookDirMagicFilename = "title.txt";
	public static const string chapterKey = "/# ";
	public static const string upToBook = "/# ...";
	public static string bookRoot { get; set; }

	 public static const string folderKey = "/ ";
	 public static const string upToFolder = "/ ...";
	 public static bool inFolder { get; set; }
	
	public static string defaultNotesDirName { get; private set; }
	
	public static string notesDirPath { get; set; }
	public static bool inBook { get; set; }
	public static bool inChapter { get; set; }
	
	public static string homeDirPath { get; private set; }

	public static bool seldomSave { get; set; default = true; }

	public static bool showWordCount { get; set; default = true; }
	public static string fontString { get; set; default = ""; }
	public static bool useAltSortType { get; set; default = true; }

	public static int windowWidth { get; set; default = 530; }
	public static int windowHeight { get; set; default = 400; }
	public static int panePosition { get; set; default = 166; }

	public static string fileExtension { get; set; default = ".txt"; }

	public static int defaultMargins { get; set; default = 6; }
	public static int lineHeight { get; set; default = 6; }

	public static const string fileExtTxt = ".txt";
	public static const string fileExtMd = ".md";

	private static UserSettingsManager settings;

	public static void initializeUserData() {
		
		homeDirPath = Environment.get_home_dir();

		defaultNotesDirName = "PS Notes";

		settings = new UserSettingsManager();

		Zystem.debug("Width is: " + windowWidth.to_string());
		

		// Create Notes Directory
		FileUtility.createFolder(notesDirPath);
	}

	public static void setNotesDir(string path) {
		notesDirPath = path;
		settings.setNotesDir(path);
	}

	public static string getDefaultNotesDir() {
		return FileUtility.pathCombine(homeDirPath, defaultNotesDirName);
	}

	public static string getNewEntrySectionText() {
		string newSectionText = "\n\n-----\n\n";

		return newSectionText;
	}

	public static void saveWindowSize(int width, int height) {
		Zystem.debug(width.to_string() + " and the height: " + height.to_string());
		settings.setInt(UserSettingsManager.windowWidthKey, width);
		settings.setInt(UserSettingsManager.windowHeightKey, height);
	}

	public static void savePanePosition(int position) {
		settings.setInt(UserSettingsManager.panePositionKey, position);
	}

	public static string getArchivedNotesDir() {
		// Check if exists, if not, create
		string path = FileUtility.pathCombine(notesDirPath, "Archive");
		
		var file = File.new_for_path(path);

		if (!file.query_exists()) {
			FileUtility.createFolder(path);
		}
		
		return path;
	}

	public static void rememberCurrentNotebook() {
		settings.addNotebook(notesDirPath, notesDirPath);
	}

	public static void forgetCurrentNotebook() {
		settings.removeNotebook(notesDirPath);
	}

	public static ArrayList<string> getNotebookList() {
		return settings.getNotebookList();
	}

	public static void setShowWordCount(bool show) {
		settings.setBool(UserSettingsManager.showWordCountKey, show);
		showWordCount = show;
	}

	public static void setFont(string fontStr) {
		settings.setString(UserSettingsManager.fontKey, fontStr);
		fontString = fontStr;
	}

	public static void setUseAltSortType(bool altSort) {
		settings.setBool(UserSettingsManager.altSortTypeKey, altSort);
		useAltSortType = altSort;
		Zystem.debug("Use alt sort: " + altSort.to_string());
		if (UserData.inBook || UserData.inChapter) {
			useAltSortType = false;
		}
	}

	public static void setFileExtension(string ext) {
		fileExtension = ext;
		settings.setString(UserSettingsManager.fileExtKey, ext);
	}

	
}
