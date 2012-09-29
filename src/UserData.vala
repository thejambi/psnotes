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
	
	public static string defaultNotesDirName { get; private set; }
	
	public static string notesDirPath { get; set; }
	
	public static string homeDirPath { get; private set; }

	public static bool seldomSave { get; set; default = true; }

	private static UserSettingsManager settings;

	public static void initializeUserData() {
		
		homeDirPath = Environment.get_home_dir();

		defaultNotesDirName = "PS Notes";

		settings = new UserSettingsManager();

		// Create Notes Directory
		FileUtility.createFolder(notesDirPath);
	}

	public static void setNotesDir(string path) {
		//
		Zystem.debug("Setting Notes directory");
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

	

	
}
