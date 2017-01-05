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

	public static bool isDirectory(string dirPath) {
		var file = File.new_for_path(dirPath);
		return file.query_file_type (0) == FileType.DIRECTORY;
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

	public static string getNameFromPath(string path) {
		var file = File.new_for_path(path);
		var fileInfo = file.query_info(FileAttribute.STANDARD_NAME, FileQueryInfoFlags.NONE);
		return fileInfo.get_name();
	}

	/**
	 * Return correctly combined path.
	 */
	public static string pathCombine(string pathStart, string pathEnd) {
		return Path.build_path(Path.DIR_SEPARATOR_S, pathStart, pathEnd);
	}

	public static bool isDuplicateNoteTitle(string title) {
		try {
			File notesDir = File.new_for_path(UserData.notesDirPath);
			FileEnumerator enumerator = notesDir.enumerate_children(FILE_ATTRIBUTE_STANDARD_NAME, 0);
			FileInfo fileInfo;

			// Go through the files
			while((fileInfo = enumerator.next_file()) != null) {
				if (FileUtility.getFileExtension(fileInfo) == UserData.fileExtension
						&& FileUtility.getFileNameWithoutExtension(fileInfo) == title) {
					return true;
				}
			}
		} catch(Error e) {
			stderr.printf ("Error reading note titles: %s\n", e.message);
			return true;
		}

		return false;
	}

	/**
	 * Move the given file somewhere else.
	 */
	public static void moveFile(FileInfo file, string fromThisDir, string toThisPath) {
		Zystem.debug("Moving file " + file.get_name());

//		string fileDestPath = "";

		string fileDestPath = pathCombine(toThisPath, file.get_name());
		
		var destFile = File.new_for_path(fileDestPath);

		// If file already exists, add timestamp to file name
		if (destFile.query_exists()) {
			fileDestPath = addTimestampToFilePath(fileDestPath);
			destFile = File.new_for_path(fileDestPath);
		}

		// Only move the file if destination file does not exist. We don't want to write over any files.
		if (!destFile.query_exists()) {
			GLib.FileUtils.rename(pathCombine(fromThisDir, file.get_name()), fileDestPath);
		}
	}

	/**
	 * Get the file path with the unique timestamp inserted at end of 
	 * filename before file extension.
	 */
	private static string addTimestampToFilePath(string filePath) {
		DateTime dateTime = new GLib.DateTime.now_local();

		string pathPrefix = filePath.substring(0, filePath.last_index_of("."));
		string fileExt = filePath.substring(filePath.last_index_of("."));
		string timestamp = dateTime.format("_%Y%m%d_%H%M%S");

		return pathPrefix + timestamp + fileExt;
	}

	public static string getTimestamp() {
		DateTime dateTime = new GLib.DateTime.now_local();
		return dateTime.format("_%Y%m%d_%H%M%S");
	}

	 public static string getParentFolderPath(string dirPath) {
		 Zystem.debug(dirPath);
		 var parentPath = dirPath.slice(0, dirPath.last_index_of("/"));
		 Zystem.debug(parentPath);
		 return parentPath;
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
