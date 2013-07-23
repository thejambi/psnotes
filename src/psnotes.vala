/* -*- Mode: C; indent-tabs-mode: t; c-basic-offset: 4; tab-width: 4 -*- */
/*
 * main.c
 * Copyright (C) 2012 Zach Burnham <thejambi@gmail.com>
 * 
 * P.S.Notes is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * P.S.Notes is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

using Gtk;

public class Main : Window {

	// SET THIS TO TRUE BEFORE BUILDING TARBALL
	private const bool isInstalled = true;

	private const string shortcutsText = 
			"Ctrl+N: Create a new note\n" + 
			"Ctrl+F: Jump to filter box to search note titles\n" + 
			"Escape: Jump to filter box / clear filter box\n" +
			"Ctrl+O: Choose notes folder\n" + 
			"Ctrl+=: Increase font size\n" + 
			"Ctrl+-: Decrease font size\n" + 
			"Ctrl+0: Reset font size";

	private int width;
	private int height;
	
	private Note note;

	private int startingFontSize;
	private int fontSize;

	private string lastKeyName;

	private bool needsSave = false;
	private bool isOpening = false;
	private bool loadingNotes = false;

	private Entry txtFilter;
	private TreeView notesView;
//	private TextView noteTextView;
	private HyperTextView noteTextView;
	private Paned paned;
	private NoteEditor editor;
	private NotesFilter filter;
	
	private Gtk.MenuToolButton openButton;
	private Gtk.Menu openNotebooksMenu;

	private NotesMonitor notesMonitor;
	private FileMonitor fileMon;

	private bool saveRequested;
	private uint timerId;

	/** 
	 * Constructor for main P.S. Notes window.
	 */
	public Main() {

		Zystem.debugOn = !isInstalled;

		UserData.initializeUserData();

		this.lastKeyName = "";

		this.title = "P.S. Notes.";
		this.window_position = WindowPosition.CENTER;
		set_default_size(UserData.windowWidth, UserData.windowHeight);

		this.configure_event.connect(() => {
			// Record window size if not maximized
			if (!(Gdk.WindowState.MAXIMIZED in this.get_window().get_state())) {
				this.get_size(out this.width, out this.height);
			} else {
				Zystem.debug("Window maximized, no save window size!");
			}
			return false;
		});

		this.saveRequested = false;



		// Do I create toolbar or menu?
		var textBgColor = new TextView().get_style_context().get_background_color(StateFlags.NORMAL);
		var winBgColor = this.get_style_context().get_background_color(StateFlags.NORMAL);

		bool elementaryHackTime = false;
		
		if (textBgColor.to_string() == winBgColor.to_string()) {
			textBgColor = Gdk.RGBA();
			textBgColor.parse("#FFFFFF");
			Zystem.debug("Hi. Your theme was wrong so I am just using white for you to write on.");
			elementaryHackTime = true;
		} else {
			Zystem.debug(textBgColor.to_string());
			Zystem.debug(winBgColor.to_string());
		}
		
		var toolbar = new Toolbar();
		var menubar = new MenuBar();
		
//		if (elementaryHackTime) {   // Let's do this all the time
			// Create toolbar
			toolbar.set_style(ToolbarStyle.ICONS);
			var context = toolbar.get_style_context();
			context.add_class(Gtk.STYLE_CLASS_PRIMARY_TOOLBAR);

//			var openButton = new ToolButton.from_stock(Stock.OPEN);
			this.openButton = new MenuToolButton.from_stock(Stock.OPEN);
			openButton.tooltip_text = "Change notes folder";
			openButton.clicked.connect(() => {
				this.openNotesDir();
			});

			// Set up Open Notebooks menu
			this.setOpenNotebooksMenuItems();

			var newButton = new ToolButton.from_stock(Stock.NEW);
			newButton.tooltip_text = "New note";
			newButton.clicked.connect(() => {
				this.createNewNote();
			});

//			var archiveButton = new ToolButton.from_stock(Stock.HARDDISK);
			var archiveButton = new ToolButton.from_stock(Stock.JUMP_TO);
//			var archiveButton = new ToolButton.from_stock(Stock.REVERT_TO_SAVED);
//			var archiveButton = new ToolButton.from_stock(Stock.CONVERT);
			archiveButton.tooltip_text = "Archive note";
			archiveButton.clicked.connect(() => {
				this.archiveActiveNote();
			});

			var decreaseFontSizeButton = new ToolButton.from_stock(Stock.ZOOM_OUT);
			decreaseFontSizeButton.tooltip_text = "Decrease font size";
			decreaseFontSizeButton.clicked.connect(() => {
				this.decreaseFontSize();
			});

			var increaseFontSizeButton = new ToolButton.from_stock(Stock.ZOOM_IN);
			increaseFontSizeButton.tooltip_text = "Increase font size";
			increaseFontSizeButton.clicked.connect(() => {
				this.increaseFontSize();
			});

			var settingsMenuButton = new MenuToolButton.from_stock(Stock.INFO);

			// Set up Settings menu
			var settingsMenu = new Gtk.Menu();
			
			/*menuIncreaseFontSize = new Gtk.MenuItem.with_label("Increase font size");
			menuIncreaseFontSize.activate.connect(() => { 
				this.increaseFontSize(); 
			});
			menuDecreaseFontSize = new Gtk.MenuItem.with_label("Decrease font size");
			menuDecreaseFontSize.activate.connect(() => { 
				this.decreaseFontSize(); 
			});*/

			var menuKeyboardShortcutsToolbar = new Gtk.MenuItem.with_label("Keyboard Shortcuts");
			menuKeyboardShortcutsToolbar.activate.connect(() => {
				this.showKeyboardShortcuts();
			});
			var menuAboutToolbar = new Gtk.MenuItem.with_label("About P.S. Notes.");
			menuAboutToolbar.activate.connect(() => {
				this.menuAboutClicked();
			});

			
//			settingsMenu.append(new SeparatorMenuItem());
			settingsMenu.append(menuKeyboardShortcutsToolbar);
			settingsMenu.append(menuAboutToolbar);

			settingsMenuButton.set_menu(settingsMenu);

			settingsMenu.show_all();

			settingsMenuButton.clicked.connect(() => {
				this.menuAboutClicked();
			});

			toolbar.insert(openButton, -1);
			toolbar.insert(new SeparatorToolItem(), -1);
			toolbar.insert(newButton, -1);
			toolbar.insert(new SeparatorToolItem(), -1);
			toolbar.insert(archiveButton, -1);
			toolbar.insert(new SeparatorToolItem(), -1);
			toolbar.insert(decreaseFontSizeButton, -1);
			toolbar.insert(increaseFontSizeButton, -1);
//			toolbar.insert(this.completeButton, -1);
//			toolbar.insert(this.deleteButton, -1);
			//		toolbar.insert(new Gtk.SeparatorToolItem(), -1);
			var separator = new SeparatorToolItem();
			toolbar.add(separator);
			toolbar.child_set_property(separator, "expand", true);
			separator.draw = false;
			toolbar.insert(separator, -1);
			toolbar.insert(settingsMenuButton, -1);
//		} else {

		if (!elementaryHackTime) {
			// Create menu

			// Set up Notes menu
			var notesMenu = new Gtk.Menu();
			var menuNewNote = new Gtk.MenuItem.with_label("New Note");
			menuNewNote.activate.connect(() => {
				this.createNewNote();
			});
			var menuArchiveNote = new Gtk.MenuItem.with_label("Archive Note");
			menuArchiveNote.activate.connect(() => {
				this.archiveActiveNote();
			});
			var menuChangeNotesDir = new Gtk.MenuItem.with_label("Change Notes Folder");
			menuChangeNotesDir.activate.connect(() => {
				this.openNotesDir();
			});
			var menuOpenNotesLocation = new Gtk.MenuItem.with_label("View Notes Files");
			menuOpenNotesLocation.activate.connect(() => {
				openNotesLocation();
			});
			var menuClose = new Gtk.MenuItem.with_label("Close P.S. Notes.");
			menuClose.activate.connect(() => {
				this.on_destroy();
			});
			notesMenu.append(menuNewNote);
			notesMenu.append(menuArchiveNote);
			notesMenu.append(new SeparatorMenuItem());
			notesMenu.append(menuChangeNotesDir);
			notesMenu.append(menuOpenNotesLocation);
			notesMenu.append(new SeparatorMenuItem());
			notesMenu.append(menuClose);

			Gtk.MenuItem notesMenuItem = new Gtk.MenuItem.with_label("Notes");
			notesMenuItem.set_submenu(notesMenu);
			menubar.append(notesMenuItem);

			// Set up Settings menu
			var settingsMenu2 = new Gtk.Menu();
			var menuIncreaseFontSize = new Gtk.MenuItem.with_label("Increase font size");
			menuIncreaseFontSize.activate.connect(() => {
				this.increaseFontSize();
			});
			var menuDecreaseFontSize = new Gtk.MenuItem.with_label("Decrease font size");
			menuDecreaseFontSize.activate.connect(() => {
				this.decreaseFontSize();
			});
			settingsMenu2.append(menuIncreaseFontSize);
			settingsMenu2.append(menuDecreaseFontSize);

			Gtk.MenuItem settingsMenuItem = new Gtk.MenuItem.with_label("Settings");
			settingsMenuItem.set_submenu(settingsMenu);
			menubar.append(settingsMenuItem);

			// Set up Help menu
			var helpMenu = new Gtk.Menu();
			var menuKeyboardShortcuts = new Gtk.MenuItem.with_label("Keyboard Shortcuts");
			menuKeyboardShortcuts.activate.connect(() => {
				showKeyboardShortcuts();
			});
			var menuAbout = new Gtk.MenuItem.with_label("About P.S. Notes.");
			menuAbout.activate.connect(() => {
				this.menuAboutClicked();
			});
			helpMenu.append(menuKeyboardShortcuts);
			helpMenu.append(menuAbout);

			var helpMenuItem = new Gtk.MenuItem.with_label("Help");
			helpMenuItem.set_submenu(helpMenu);
			menubar.append(helpMenuItem);

		}

		

		this.txtFilter = new Entry();

		this.txtFilter.buffer.deleted_text.connect(() => {
			this.filter.setFilterText(this.txtFilter.text);
			this.loadNotesList("txtFilter text was deleted!");
//			this.filter.setToLoad(LoadRequestType.filterTextChanged);
		});
		this.txtFilter.buffer.inserted_text.connect(() => {
			this.filter.setFilterText(this.txtFilter.text);
			this.loadNotesList("txtFilter text was inserted!");
//			this.filter.setToLoad(LoadRequestType.filterTextChanged);
		});

		this.notesView = new TreeView();
		this.setupNotesView();

		this.noteTextView = new HyperTextView();	// used to be TextView

		this.noteTextView.buffer.changed.connect(() => {
			onTextChanged(this.noteTextView.buffer);
		});
		this.editor = new NoteEditor(this.noteTextView.buffer);
		this.noteTextView.pixels_above_lines = 2;
		this.noteTextView.pixels_below_lines = 2;
		this.noteTextView.pixels_inside_wrap = 4;
		this.noteTextView.wrap_mode = WrapMode.WORD_CHAR;
		this.noteTextView.left_margin = 4;
		this.noteTextView.right_margin = 4;
		this.noteTextView.accepts_tab = true;

		var scroll1 = new ScrolledWindow (null, null);
		// scroll1.shadow_type = ShadowType.ETCHED_OUT;
		scroll1.set_policy (PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
		scroll1.min_content_width = 160;
		// scroll1.min_content_height = 280;
		scroll1.add (this.notesView);
		scroll1.expand = true;

		var vbox = new Box(Orientation.VERTICAL, 2);
		vbox.pack_start(txtFilter, false, true, 2);
		vbox.pack_start(this.notesView, true, true, 2);
		vbox.pack_start(scroll1, true, true, 2);

		var scroll = new ScrolledWindow (null, null);
		scroll.shadow_type = ShadowType.ETCHED_OUT;
		scroll.set_policy (PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
		scroll.min_content_width = 251;
		scroll.min_content_height = 280;
		scroll.add (this.noteTextView);
		scroll.expand = true;

		this.paned = new Paned(Orientation.HORIZONTAL);
		paned.add1(vbox);
		paned.add2(scroll);
		paned.position = UserData.panePosition;

		var vbox1 = new Box (Orientation.VERTICAL, 0);
		if (!elementaryHackTime) {
			vbox1.pack_start(menubar, false, true, 0);
		}
		vbox1.pack_start(toolbar, false, true, 0);
		vbox1.pack_start (paned, true, true, 0);

		add (vbox1);

		this.noteTextView.grab_focus();

		this.startingFontSize = 10;
		this.fontSize = startingFontSize;
		this.resetFontSize();

		// Connect keypress signal
		this.key_press_event.connect((window,event) => { 
			return this.onKeyPress(event); 
		});
		

		this.monitorNotesDir();
		
		
		// Connect on_destroy
		this.destroy.connect(() => { this.on_destroy(); });
	}

	private void setOpenNotebooksMenuItems() {
		this.openNotebooksMenu = new Gtk.Menu();
		
		// Add list of user's notebooks to menu
		foreach (string s in UserData.getNotebookList()) {
			var menuItem = new Gtk.MenuItem.with_label(s);
			menuItem.activate.connect(() => {
				this.setNotesDir(s);
			});
			
			this.openNotebooksMenu.append(menuItem);
		}

		// Then, add the "Add" and "Remove" options
		var rememberNotebook = new Gtk.MenuItem.with_label("Remember current notebook");
		rememberNotebook.activate.connect(() => { this.rememberCurrentNotebook(); });
		
		var forgetNotebook = new Gtk.MenuItem.with_label("Forget current notebook");
		forgetNotebook.activate.connect(() => { this.forgetCurrentNotebook(); });

		this.openNotebooksMenu.append(new Gtk.SeparatorMenuItem());
		this.openNotebooksMenu.append(rememberNotebook);
		this.openNotebooksMenu.append(forgetNotebook);

		this.openButton.set_menu(openNotebooksMenu);
		this.openNotebooksMenu.show_all();
	}

	private void rememberCurrentNotebook() {
		UserData.rememberCurrentNotebook();
		this.setOpenNotebooksMenuItems();
	}

	private void forgetCurrentNotebook() {
		UserData.forgetCurrentNotebook();
		this.setOpenNotebooksMenuItems();
	}

	/**
	 * Monitor the notes directory so we can auto-refresh notes list.
	 */
	private void monitorNotesDir() {
		//this.notesMonitor = new NotesMonitor("/home/zach/Dropbox/epistle");
		this.notesMonitor = new NotesMonitor(UserData.notesDirPath);
		this.fileMon = notesMonitor.getFileMonitor();
		this.fileMon.changed.connect((one, two, fileEvent) => {
//			Zystem.debug(fileEvent.to_string());

			/*if (this.currentEventType == 1) {
				Zystem.debug("neener neener!");
				if (fileEvent == FileMonitorEvent.CHANGES_DONE_HINT) {
					this.currentEventType = 0;
				}
				return;
			}*/
			
			if (fileEvent == FileMonitorEvent.DELETED || fileEvent == FileMonitorEvent.ATTRIBUTE_CHANGED) {
//				this.loadNotesList("FileMonitor was changed! " + fileMon.get_type().to_string());
				this.filter.setToLoad(LoadRequestType.fileMonitorEvent);
			}
		});
	}

	private void setupNotesView() {
		var listmodel = new ListStore (1, typeof (string));
		this.notesView.set_model (listmodel);

		this.notesView.insert_column_with_attributes (-1, "Notes", new CellRendererText (), "text", 0);

		var treeSelection = this.notesView.get_selection();
		
		this.filter = new NotesFilter(listmodel, treeSelection);

		this.loadNotesList("Just setting up notes view.");

		treeSelection.set_mode(SelectionMode.SINGLE);
		treeSelection.changed.connect(() => {
			noteSelected(treeSelection);
		});
	}

	private async void loadNotesList(string reason) {		
		Zystem.debug("Loading Notes List!");
		Zystem.debug(reason);
		this.loadingNotes = true;

		yield this.filter.filter();

		this.loadingNotes = false;
	}

	private void noteSelected(TreeSelection treeSelection) {
		if (this.loadingNotes) {
			return;
		}

		TreeModel model;
		TreeIter iter;
		treeSelection.get_selected(out model, out iter);
		Value value;
		model.get_value(iter, 0, out value);
		Zystem.debug("SELECTION IS: " + value.get_string());

		string noteTitle = value.get_string();
		
		this.isOpening = true;

		this.note = new Note(noteTitle);
		this.editor.startNewNote(this.note.getContents());
		this.needsSave = false;

		this.isOpening = false;
	}

	public bool onKeyPress(Gdk.EventKey key) {
		uint keyval;
        keyval = key.keyval;
		Gdk.ModifierType state;
		state = key.state;
		bool ctrl = (state & Gdk.ModifierType.CONTROL_MASK) != 0;
		bool shift = (state & Gdk.ModifierType.SHIFT_MASK) != 0;
		/*bool release = (state & Gdk.ModifierType.RELEASE_MASK) != 0;
		bool hyper = (state & Gdk.ModifierType.HYPER_MASK) != 0;

		Zystem.debug("RELEASE: " + release.to_string());
		Zystem.debug("HYPER:   " + hyper.to_string());*/

		string keyName = Gdk.keyval_name(keyval);
		
		// Zystem.debug("Key:\t" + keyName);

		if (ctrl && shift) { // Ctrl+Shift+?
			Zystem.debug("Ctrl+Shift+" + keyName);
			switch (keyName) {
				case "Z":
					this.editor.redo();
					Zystem.debug("Y'all hit Ctrl+Shift+Z");
					break;
				default:
					Zystem.debug("What should Ctrl+Shift+" + keyName + " do?");
					break;
			}
		}
		else if (ctrl) { // Ctrl+?
			switch (keyName) {
				case "z":
					this.editor.undo();
					break;
				case "y":
					this.editor.redo();
					break;
				case "d":
					// this.editor.prependDateToEntry(this.entry.getEntryDateHeading());
					break;
				case "f":
					this.txtFilter.grab_focus();
					break;
				case "n":
					this.createNewNote();
					break;
				case "o":
					this.openNotesDir();
					break;
				case "equal":
					this.increaseFontSize();
					break;
				case "minus":
					this.decreaseFontSize();
					break;
				case "0":
					this.resetFontSize();
					break;
				default:
					Zystem.debug("What should Ctrl+" + keyName + " do?");
					break;
			}
		}
		else if (!(ctrl || shift || keyName == this.lastKeyName)) { // Just the one key
			switch (keyName) {
				case "period":
				case "Return":
				case "space":
					//this.seldomSave();
					break;
				default:
					break;
			}
		}

		// Handle escape key
		if (!(ctrl || shift) && keyName == "Escape") {
			if (this.txtFilter.has_focus) {
				this.txtFilter.text = "";
			} else {
				this.txtFilter.grab_focus();
			}
		}

		this.lastKeyName = keyName;
		
		// Return false or the entry does not get updated.
		return false;
	}

	public void onTextChanged(TextBuffer buffer) {
		if (this.isOpening) {
			return;
		}

		this.needsSave = true;

		// If creating a new note
		if (this.note == null && this.editor.getText() != "") {
			Zystem.debug("NOTE IS NULL, thank you very much!");
			Zystem.debug("Note title should be: " + this.editor.firstLine());
			this.note = new Note(this.editor.firstLine().strip());
			this.loadNotesList("Creating a new note!");
		}

		// If note title changed
		if (this.editor.lineCount() > 0 && this.editor.firstLine().strip() != ""
				&& this.noteTitleChanged()) {
			Zystem.debug("Oh boy, the note title changed. Let's rename that sucker.");
			this.note.rename(this.editor.firstLine().strip(), this.editor.getText());
			this.loadNotesList("Note title changed!");
			this.filter.notifyAutoSave();
		} else {
			//this.autoSave();
			this.requestSave();
		}
	}

	private void requestSave() {
		if (!this.saveRequested) {
			this.timerId = Timeout.add(200, onTimerEvent);
			Zystem.debug("Set timer for SAVE!");
		}

		this.saveRequested = true;
	}

	private bool onTimerEvent() {
		this.saveRequested = false;
		
		this.autoSave();
		
		return false;
	}

	private bool noteTitleChanged() {
		if (this.editor.lineCount() == 0) {
			return false;
		}

		return this.editor.firstLine().strip() != this.note.title;
	}

	private void createNewNote() {
		/*this.seldomSave();*/
		this.note = new Note("");
		//this.loadNotesList();
//		this.needsSave = true;
		this.needsSave = false;

		this.isOpening = true;
		this.editor.startNewNote(this.note.title);
		this.isOpening = false;
//		this.noteTextView.select_all(true);
	}

	/**
	 * Font size methods
	 */
	private void resetFontSize() {
		this.changeFontSize(this.startingFontSize - this.fontSize);
	}

	private void increaseFontSize() {
		this.changeFontSize(1);
	}
	private void decreaseFontSize() {
		this.changeFontSize(-1);
	}

	private void changeFontSize(int byThisMuch) {
		// If font would be too small or too big, no way man
		if (this.fontSize + byThisMuch < 6 || this.fontSize + byThisMuch > 50) {
			Zystem.debug("Not changing font size, because it would be: " + this.fontSize.to_string());
			return;
		}

		this.fontSize += byThisMuch;
		Zystem.debug("Changing font size to: " + this.fontSize.to_string());

		Pango.FontDescription font = this.noteTextView.style.context.get_font(StateFlags.NORMAL);
		double newFontSize = (this.fontSize) * Pango.SCALE;
		font.set_size((int)newFontSize);
		this.noteTextView.modify_font(font);
	}

	/*private async void seldomSave() {
		Zystem.debug("THIS IS A SELDOM SAVE POINT AND needsSave is " + this.needsSave.to_string());
		if (UserData.seldomSave && this.needsSave) {
			this.callSave();
		}
	}*/

	private void autoSave() {

		this.filter.notifyAutoSave();

		bool load = this.editor.lineCount() == 0 || this.editor.firstLine().strip() == "";
		
		this.callSave();

		if (load) {
			this.loadNotesList("Note deleted, need to reload.");
		}
	}

	private async void callSave() {
		try {
			yield this.note.saveAsync(this.editor.getText());
			this.needsSave = false;
		} catch (Error e) {
			Zystem.debug("There was an error saving the file.");
		}
	}

	/*private async void callSave() {
		try {
			this.note.save(this.editor.getText());
			this.needsSave = false;
		} catch (Error e) {
			Zystem.debug("There was an error saving the file.");
		}
	}*/

	public void openNotesDir() {
		var fileChooser = new FileChooserDialog("Choose Notes Folder", this,
												FileChooserAction.SELECT_FOLDER,
												Stock.CANCEL, ResponseType.CANCEL,
												Stock.OPEN, ResponseType.ACCEPT);
		if (fileChooser.run() == ResponseType.ACCEPT) {
			string dirPath = fileChooser.get_filename();
			this.setNotesDir(dirPath);
		}
		fileChooser.destroy();
	}

	private void setNotesDir(string dirPath) {
		this.createNewNote();
		UserData.setNotesDir(dirPath);
		this.loadNotesList("Just settings notes dir path.");
		this.monitorNotesDir();
	}

	private void openNotesLocation() {
		Gtk.show_uri(null, "file://" + UserData.notesDirPath, Gdk.CURRENT_TIME);
	}

	private void showKeyboardShortcuts() {
		var dialog = new Gtk.MessageDialog(null,Gtk.DialogFlags.MODAL,Gtk.MessageType.INFO, 
						Gtk.ButtonsType.OK, this.shortcutsText);
		dialog.set_title("Message Dialog");
		dialog.run();
		dialog.destroy();
	}

	private void menuAboutClicked() {
		var about = new AboutDialog();
		about.set_program_name("P.S. Notes.");
		about.comments = "Notes, plain and simple.";
		about.website = "http://burnsoftware.wordpress.com/p-s-notes";
		about.logo_icon_name = "psnotes";
		about.set_copyright("by Zach Burnham");
		about.run();
		about.hide();
	}

	private void archiveActiveNote() {
		/*this.seldomSave();*/
		if (this.note != null && this.editor.getText() != "") {
			this.note.archive();
		}
		this.createNewNote();
	}

	/**
	 * Quit P.S. Notes.
	 */
	public void on_destroy () {

		if (this.saveRequested && this.timerId != 0) {
			Source.remove(this.timerId);
			try {
				this.note.save(this.editor.getText());
			} catch (Error e) {
				Zystem.debug("There was an error saving the file.");
			}
		}

		// Save window size
		Zystem.debug("Width and height: " + this.width.to_string() + " and " + this.height.to_string());
		UserData.saveWindowSize(this.width, this.height);

		// Save pane position
		Zystem.debug("Pane position: " + this.paned.position.to_string());
		UserData.savePanePosition(this.paned.position);
		
		Gtk.main_quit();
	}

	public static int main(string[] args) {
		Gtk.init(ref args);

		var window = new Main();
		window.show_all();

		Gtk.main();
		return 0;
	}
}
