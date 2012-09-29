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

	/*
	 * Actually move the file to where it's supposed to go.
	 */
	/*public static void moveFile(FileInfo file, string destDir, bool isFileExtRule = false) {
		string fileDestPath = destDir + "/" + file.get_name();
		var destFile = File.new_for_path(fileDestPath);

		// If file already exists, add timestamp to file name
		if (destFile.query_exists()) {
			fileDestPath = addTimestampToFilePath(fileDestPath, isFileExtRule);
			destFile = File.new_for_path(fileDestPath);
		}

		// Only move the file if destination file does not exist. We don't want to write over any files.
		if (!destFile.query_exists()) {
			GLib.FileUtils.rename(monDir.sourcePath + "/" + file.get_name(), fileDestPath);
		}
	}*/

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
	 * Get the file path with the unique timestamp inserted at end of 
	 * filename before file extension.
	 */
	/*private static string addTimestampToFilePath(string filePath, bool isFileExtRule) {
		DateTime dateTime = new GLib.DateTime.now_local();

		string pathPrefix = filePath.substring(0, filePath.last_index_of("."));
		string fileExt = filePath.substring(filePath.last_index_of("."));
		string timestamp = "_";

		if (isFileExtRule) {
			timestamp = dateTime.format("_%Y%m%d_%H%M%S");
		} else if (UserData.isDailyDfType()) {
			timestamp = dateTime.format("_%H%M%S");
		} else if (UserData.isWeeklyDfType() || UserData.isMonthlyDfType()) {
			timestamp = dateTime.format("_%d_%H%M%S");
		}

		return pathPrefix + timestamp + fileExt;
	}*/

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

	
	// public static void convertToNewJournalStructure() {
	// 	//
	// 	// Loop through directory. 4 digit folders are okay, change 1 digit folders to two digits w/ leading zero
	// 	Zystem.debug("Converting journal directory");

	// 	try {
	// 		File djDir = File.new_for_path(UserData.djDirPath);
	// 		FileEnumerator enumerator = djDir.enumerate_children(FILE_ATTRIBUTE_STANDARD_NAME, 0);
	// 		FileInfo fileInfo;

	// 		// Go through the files
	// 		while((fileInfo = enumerator.next_file()) != null) {
	// 			if (fileInfo.get_file_type() == FileType.DIRECTORY) {
	// 				//Zystem.debug("Recursing dir: " + fileInfo.get_name());
	// 				recurseDirForNaming(pathCombine(UserData.djDirPath, fileInfo.get_name()), fileInfo);
	// 			}
	// 		}
	// 	} catch(Error e) {
	// 		stderr.printf ("Error in DayFolder.cleanDesktop(): %s\n", e.message);
	// 	}
	// }

	// private static void recurseDirForNaming(string path, FileInfo dir) throws GLib.Error {
	// 	//string dirPath = pathCombine(path, dir.get_name());
	// 	Zystem.debug("Recursing dir: " + path);
	// 	File fileObject = File.new_for_path(path);
	// 	FileEnumerator enumerator = fileObject.enumerate_children(FILE_ATTRIBUTE_STANDARD_NAME, 0);
	// 	FileInfo file;
		
	// 	// Go through the files
	// 	while((file = enumerator.next_file()) != null) {
	// 		if (file.get_file_type() == FileType.DIRECTORY) {
	// 			// Check file name
	// 			if (file.get_name().length == 4) {
	// 				// This is cool, go one more level
	// 				recurseDirForNaming(pathCombine(path, file.get_name()), file);
	// 			} else if (file.get_name().length == 1) {
	// 				// Rename if 1
	// 				string filePath = pathCombine(path, file.get_name());
	// 				Zystem.debug("Should rename : " + filePath);
	// 				Zystem.debug("::::       to : " + pathCombine(path, "0" + file.get_name()));
	// 				GLib.FileUtils.rename(filePath, pathCombine(path, "0" + file.get_name()));
	// 				recurseDirForNaming(pathCombine(path, "0" + file.get_name()), file);
	// 			} else if(file.get_name().length == 2) {
	// 				recurseDirForNaming(pathCombine(path, file.get_name()), file);
	// 			}
	// 		} else if (file.get_file_type() == FileType.REGULAR && file.get_name().length == 5 && getFileExtension(file) == ".txt") {
	// 			// Rename if 1
	// 			string filePath = pathCombine(path, file.get_name());
	// 			Zystem.debug("Should rename : " + filePath);
	// 			Zystem.debug("::::       to : " + pathCombine(path, "0" + file.get_name().substring(0, file.get_name().last_index_of("."))) + ".txt");
	// 			GLib.FileUtils.rename(filePath, pathCombine(path, "0" + file.get_name().substring(0, file.get_name().last_index_of("."))) + ".txt");
	// 		}
	// 	}
	// }
	
}
