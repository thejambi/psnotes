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

/**
 * File Utility class.
 */
class FileUtility : GLib.Object {

	/**
	 * Create a folder (or make sure it exists).
	 */
	public static void createFolder(string dirPath){
		// Create the directory. This method doesn't care if it exists already or not.
		GLib.DirUtils.create_with_parents(dirPath, 0775);
	}

	/**
	 * Return the file extension from the given fileInfo.
	 */
	public static string getFileExtension(FileInfo file){
		string fileName = file.get_name();
		return fileName.substring(fileName.last_index_of("."));
	}

	/**
	 * 
	 */
	public static string getFileNameWithoutExtension(FileInfo file) {
		return file.get_name().replace(getFileExtension(file), "");
	}

	/**
	 * Return correctly combined path.
	 */
	public static string pathCombine(string pathStart, string pathEnd) {
		return Path.build_path(Path.DIR_SEPARATOR_S, pathStart, pathEnd);
	}

	/**
	 * 
	 */
	// public static bool isDirectoryEmpty(string dirPath) {
	// 	try {
	// 		var directory = File.new_for_path(dirPath);

	// 		var enumerator = directory.enumerate_children(FILE_ATTRIBUTE_STANDARD_NAME, 0);

	// 		FileInfo file_info;
	// 		while ((file_info = enumerator.next_file ()) != null) {
	// 			Zystem.debug("Directory is not empty");
	// 			return false;
	// 		}

	// 		Zystem.debug("Directory is empty");
	// 		return true;

	// 	} catch (Error e) {
	// 		stderr.printf ("Error: %s\n", e.message);
	// 		return false;
	// 	}
	// }
	
}
