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

using GLib;

public class NotesMonitor : GLib.Object {

	private File monitoredFile;
	
	public NotesMonitor(string filePath) {
		monitoredFile = File.new_for_path(filePath);
		Zystem.debug("Created the Monitor for " + filePath);
	}

	public FileMonitor getFileMonitor() {
		return monitoredFile.monitor_directory(GLib.FileMonitorFlags.NONE);
	}

}

