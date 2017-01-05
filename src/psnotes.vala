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
			"Ctrl+W: Toggle Write Mode\n" +
			"Ctrl+O: Choose notes folder\n" + 
			"Ctrl+=: Increase font size\n" + 
			"Ctrl+-: Decrease font size\n" + 
			"Ctrl+0: Reset font size";

	private int width;
	private int height;
	
	private Note note;

	private string lastKeyName;

	private bool needsSave = false;
	private bool isOpening = false;
	private bool loadingNotes = false;

	private Entry txtFilter;
	private TreeView notesView;
	private DocumentView noteTextView;
	private Paned paned;
	private NoteEditor editor;
	private NotesFilter filter;
	
	private Gtk.MenuToolButton openButton;
	private Gtk.Menu openNotebooksMenu;
	private Gtk.Box notesVBox;
	private Gtk.HeaderBar headerBar;
	private Gtk.CheckMenuItem menuWriteMode;

	private NotesMonitor notesMonitor;
	private FileMonitor fileMon;

	private bool saveRequested;
	private uint timerId;

	private string firstLine;

	private Gtk.Label wordCountLabel;

	/** 
	 * Constructor for main P.S. Notes window.
	 */
	public Main() {
		Zystem.debugOn = !isInstalled;
		UserData.initializeUserData();

		this.lastKeyName = "";
		this.firstLine = "";

		this.title = "P.S. Notes.";
		this.headerBar = new Gtk.HeaderBar();
		headerBar.set_title("P.S. Notes.");
		headerBar.set_show_close_button(true);
		this.set_titlebar(headerBar);
		this.window_position = WindowPosition.CENTER;
		set_default_size(UserData.windowWidth, UserData.windowHeight);

		this.configure_event.connect(() => {
			// Record window size if not maximized
			if (!(Gdk.WindowState.MAXIMIZED in this.get_window().get_state())) {
				this.get_size(out this.width, out this.height);
			} else {
				Zystem.debug("Window maximized, no save window size!");
				this.scaleEditorForMaximize();
			}
			return false;
		});

		this.saveRequested = false;

		/*this.window_state_event.connect((event) => {
			if (event.new_window_state == Gdk.WindowState.MAXIMIZED) {
				Zystem.debug("EL MAXIMOZED");
				//this.scaleEditorForMaximize();
			} else if (event.new_window_state == Gdk.WindowState.FOCUSED) {
				Zystem.debug("UNNNNNNNNNNNNnnnnnnnnn MAXIMOZED");
			}
			return false;
		});*/



		// Do I create toolbar or menu?
		var textBgColor = new TextView().get_style_context().get_background_color(StateFlags.NORMAL);
		var winBgColor = this.get_style_context().get_background_color(StateFlags.NORMAL);
		
		if (textBgColor.to_string() == winBgColor.to_string()) {
			textBgColor = Gdk.RGBA();
			textBgColor.parse("#FFFFFF");
		} else {
			Zystem.debug(textBgColor.to_string());
			Zystem.debug(winBgColor.to_string());
		}
		
		var toolbar = new Toolbar();
		var menubar = new MenuBar();
		
			// Create toolbar
			toolbar.set_style(ToolbarStyle.ICONS);
			var context = toolbar.get_style_context();
			context.add_class(Gtk.STYLE_CLASS_PRIMARY_TOOLBAR);

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

			var archiveButton = new ToolButton.from_stock(Stock.JUMP_TO);
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

			var menuKeyboardShortcutsToolbar = new Gtk.MenuItem.with_label("Keyboard Shortcuts");
			menuKeyboardShortcutsToolbar.activate.connect(() => {
				this.showKeyboardShortcuts();
			});

			var menuAboutToolbar = new Gtk.MenuItem.with_label("About P.S. Notes.");
			menuAboutToolbar.activate.connect(() => {
				this.menuAboutClicked();
			});

			var menuWordCount = new Gtk.CheckMenuItem.with_label("Word Count");
			menuWordCount.active = UserData.showWordCount;
			menuWordCount.toggled.connect(() => {
				this.menuWordCountToggled(menuWordCount);
			});

			var menuChooseFont = new Gtk.MenuItem.with_label("Set Font...");
			menuChooseFont.activate.connect(() => {
				this.chooseFont();
			});

			var menuSortLastModified = new Gtk.CheckMenuItem.with_label("Sort by recently modified");
			menuSortLastModified.active = UserData.useAltSortType;
			menuSortLastModified.activate.connect(() => {
				this.sortToggled(menuSortLastModified);
			});

		this.menuWriteMode = new Gtk.CheckMenuItem.with_label("Write Mode");
			menuWriteMode.activate.connect(() => {
				this.toggleWriteMode();
			});

		var menuUseFileExtTxt = new Gtk.RadioMenuItem.with_label(null, "Work with .txt");
		unowned SList<Gtk.RadioMenuItem> group = menuUseFileExtTxt.get_group();
		menuUseFileExtTxt.active = (UserData.fileExtension == UserData.fileExtTxt);
		menuUseFileExtTxt.activate.connect(() => {
			if (menuUseFileExtTxt.active) {
				this.createNewNote();
				UserData.setFileExtension(UserData.fileExtTxt);
				this.loadNotesList("File extension set.");
			}
		});

		var menuUseFileExtMd = new Gtk.RadioMenuItem.with_label(group, "Work with .md");
		menuUseFileExtMd.active = (UserData.fileExtension == UserData.fileExtMd);
		menuUseFileExtMd.activate.connect(() => {
			if (menuUseFileExtMd.active) {
				this.createNewNote();
				UserData.setFileExtension(UserData.fileExtMd);
				this.loadNotesList("File extension set.");
			}
		});
			
		settingsMenu.append(menuChooseFont);
		settingsMenu.append(menuWordCount);
		settingsMenu.append(menuSortLastModified);
		settingsMenu.append(menuWriteMode);
		settingsMenu.append(new SeparatorMenuItem());
		settingsMenu.append(menuUseFileExtTxt);
		settingsMenu.append(menuUseFileExtMd);
		settingsMenu.append(new SeparatorMenuItem());
		settingsMenu.append(menuKeyboardShortcutsToolbar);
		settingsMenu.append(menuAboutToolbar);

			settingsMenuButton.set_menu(settingsMenu);

			settingsMenu.show_all();

			settingsMenuButton.clicked.connect(() => {
				this.menuAboutClicked();
			});

			// Word Count
			var wordCountItem = new ToolItem();
			this.wordCountLabel = new Gtk.Label("");
			wordCountLabel.set_width_chars(18);
			wordCountItem.add(wordCountLabel);
			this.updateWordCount();

		headerBar.pack_start(openButton);
		headerBar.pack_start(newButton);
		headerBar.pack_start(archiveButton);
		
		headerBar.pack_end(settingsMenuButton);
		headerBar.pack_end(wordCountItem);

		

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

		//this.noteTextView = new HyperTextView();	// used to be TextView
		this.noteTextView = new DocumentView();

		/*this.noteTextView.buffer.changed.connect(() => {
			onTextChanged(this.noteTextView.buffer);
		});*/
		this.noteTextView.changed.connect(() => {
			onTextChanged(this.noteTextView);
		});
		//this.editor = new NoteEditor(this.noteTextView.buffer);
		this.editor = new NoteEditor(this.noteTextView);
		/*
		 this.noteTextView.pixels_above_lines = 2;
		this.noteTextView.pixels_below_lines = 2;
		this.noteTextView.pixels_inside_wrap = 4;
		this.noteTextView.wrap_mode = WrapMode.WORD_CHAR;
		this.noteTextView.left_margin = 4;
		this.noteTextView.right_margin = 4;
		this.noteTextView.accepts_tab = true;
		 */

		var scroll1 = new ScrolledWindow (null, null);
		// scroll1.shadow_type = ShadowType.ETCHED_OUT;
		scroll1.set_policy (PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
		scroll1.min_content_width = 160;
		// scroll1.min_content_height = 280;
		scroll1.add (this.notesView);
		scroll1.expand = true;

		this.notesVBox = new Box(Orientation.VERTICAL, 2);
		this.notesVBox.pack_start(txtFilter, false, true, 2);
		this.notesVBox.pack_start(this.notesView, true, true, 2);
		this.notesVBox.pack_start(scroll1, true, true, 2);

		var scroll = new ScrolledWindow (null, null);
		scroll.shadow_type = ShadowType.ETCHED_OUT;
		scroll.set_policy (PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
		scroll.min_content_width = 251;
		scroll.min_content_height = 280;
		scroll.add (this.noteTextView);
		scroll.expand = true;

		this.paned = new Paned(Orientation.HORIZONTAL);
		paned.add1(this.notesVBox);
		paned.add2(scroll);
		paned.position = UserData.panePosition;

		var vbox1 = new Box (Orientation.VERTICAL, 0);
		vbox1.pack_start (paned, true, true, 0);

		add (vbox1);

		this.noteTextView.grab_focus();

//		this.startingFontSize = 10;
//		this.fontSize = startingFontSize;
//		this.resetFontSize();

		var font = Pango.FontDescription.from_string(UserData.fontString);
		this.noteTextView.override_font(font);
		/*this.fontSize = font.get_size() / Pango.SCALE;
		if (this.fontSize == 0) {
			this.fontSize = 10;
		}

		Zystem.debug("\n\n\n\n\nFONT SIZE IS " + this.fontSize.to_string() + "\n\n\n\n");*/

		// Connect keypress signal
		this.key_press_event.connect((window,event) => { 
			return this.onKeyPress(event); 
		});
		

		this.monitorNotesDir();
		
		
		// Connect on_destroy
		this.destroy.connect(() => { this.on_destroy(); });
	}

	private void addImageNow() {
		/* Images! */
		Image img = new Image.from_file("/home/zach/Dropbox/Pictures/Lego_avatar.png");
		var anchor = this.editor.buffer.create_child_anchor(this.editor.getCurrentIter());
		//this.noteTextView.add_child_at_anchor(img, anchor);
		img.show_now();
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
		
		var forgetNotebook = new Gtk.MenuItem.with_label("Forget current notebook");
		forgetNotebook.activate.connect(() => { this.forgetCurrentNotebook(); });

		var viewNotebookFiles = new Gtk.MenuItem.with_label("View current notebook files");
		viewNotebookFiles.activate.connect(() => { this.openNotesLocation(); });

		this.openNotebooksMenu.append(new Gtk.SeparatorMenuItem());
		this.openNotebooksMenu.append(forgetNotebook);
		this.openNotebooksMenu.append(viewNotebookFiles);

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
		this.notesMonitor = new NotesMonitor(UserData.notesDirPath);
		this.fileMon = notesMonitor.getFileMonitor();
		this.fileMon.changed.connect((one, two, fileEvent) => {
			if (fileEvent == FileMonitorEvent.DELETED || fileEvent == FileMonitorEvent.ATTRIBUTE_CHANGED) {
//				this.loadNotesList("FileMonitor was changed! " + fileMon.get_type().to_string());
				this.filter.setToLoad(LoadRequestType.fileMonitorEvent);
			}
		});
	}

	private void setupNotesView() {
		var listmodel = new Gtk.ListStore (1, typeof (string));
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

	private void resetNotesView() {
		var listmodel = new Gtk.ListStore (1, typeof (string));
		this.notesView.set_model (listmodel);

		//this.notesView.insert_column_with_attributes (-1, "Notes", new CellRendererText (), "text", 0);

		var treeSelection = this.notesView.get_selection();
		
		this.filter = new NotesFilter(listmodel, treeSelection);

		this.loadNotesList("Just setting up notes view.");

		//treeSelection.set_mode(SelectionMode.SINGLE);
		//treeSelection.changed.connect(() => {
		//	noteSelected(treeSelection);
		//});
	}

	private async void loadNotesList(string reason) {		
		Zystem.debug("Loading Notes List: " + reason);
		this.loadingNotes = true;

		yield this.filter.filter();

		this.loadingNotes = false;
	}

	 private bool isNotebook(string dirPath) {
		 foreach (string s in UserData.getNotebookList()) {
			if (dirPath == s) {
				return true;
			}
		}
		 return false;
	 }

	private void noteSelected(TreeSelection treeSelection) {
		if (this.loadingNotes) {
			return;
		}

		TreeModel model;
		TreeIter iter;
		treeSelection.get_selected(out model, out iter);
		Value val;
		model.get_value(iter, 0, out val);
		Zystem.debug("SELECTION IS: " + val.get_string());

		string noteTitle = val.get_string();

		if (noteTitle == UserData.upToBook) {
			Zystem.debug("Return to Book Root selected");

			/* Create the chapter compiled file */
			var chappyCompy = new ChapterCompiler();
			var chapterTitle = FileUtility.getNameFromPath(UserData.notesDirPath);
			var chapterText = chappyCompy.compileChapterText();
			
			this.setNotesDir(UserData.bookRoot);
			
			chappyCompy.saveChapterText(chapterTitle, chapterText);
			
		} else if (noteTitle == UserData.upToFolder) {
			Zystem.debug("Return to parent folder");
			var parentFolderPath = FileUtility.getParentFolderPath(UserData.notesDirPath);
			this.setNotesDirToFolder(parentFolderPath);
		} else if (noteTitle.has_prefix(UserData.chapterKey)) {
			Zystem.debug("Chapter selected");
			this.setNotesDirToChapter(FileUtility.pathCombine(UserData.notesDirPath, noteTitle.replace(UserData.chapterKey, "")));
		} else if (noteTitle.has_prefix(UserData.folderKey)) {
			this.setNotesDirToFolder(FileUtility.pathCombine (UserData.notesDirPath, noteTitle.replace(UserData.folderKey, "")));
		} else {
			this.isOpening = true;

			this.note = new Note(noteTitle);
			this.editor.startNewNote(this.note.getContents());
			this.needsSave = false;

			this.isOpening = false;
		}
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

		if (ctrl && shift) { // Ctrl+Shift+?
			Zystem.debug("Ctrl+Shift+" + keyName);
			switch (keyName) {
				case "Z":
					//this.editor.redo();
					break;
				default:
					Zystem.debug("What should Ctrl+Shift+" + keyName + " do?");
					break;
			}
		}
		else if (ctrl) { // Ctrl+?
			switch (keyName) {
				case "z":
					//this.editor.undo();
					break;
				case "y":
					//this.editor.redo();
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
					this.clearFontPrefs();
					break;
				case "p":
					this.addImageNow();
					break;
				case "w":
					this.menuWriteMode.active = !this.menuWriteMode.active;
					this.toggleWriteMode();
					break;
				case "q":
					if (UserData.inBook) {
						var chappyCompy = new ChapterCompiler();
						chappyCompy.compileEPub();
					}
					break;
				case "2":
					if (!this.menuWriteMode.active) {
						UserData.defaultMargins += 1;
						if (UserData.defaultMargins > (this.noteTextView.get_allocated_width() - 2) / 2) {
							UserData.defaultMargins = (this.noteTextView.get_allocated_width() - 2) / 2;
						}
						this.noteTextView.setMargins(UserData.defaultMargins);
						this.wordCountLabel.set_text(UserData.defaultMargins.to_string());
					}
					break;
				case "1":
					if (!this.menuWriteMode.active) {
						UserData.defaultMargins -= 1;
						if (UserData.defaultMargins < 0) {
							UserData.defaultMargins = 0;
						}
						this.noteTextView.setMargins(UserData.defaultMargins);
						this.wordCountLabel.set_text(UserData.defaultMargins.to_string());
					}
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

	public void toggleWriteMode() {
		if (this.menuWriteMode.active) {
			var width = this.paned.position + 1 + (UserData.defaultMargins * 2);
			var margins = width % 2 == 0 ? width / 2 : (width - 1) / 2;
			this.notesVBox.hide();
			this.noteTextView.setMargins(margins);
			if (width % 2 == 1) {
				this.noteTextView.beefUpAMargin();
			}
		} else {
			this.notesVBox.show();
			this.noteTextView.setDefaultMargins();
		}
	}

	public void scaleEditorForMaximize() {
		// Check size. 
		int nowWidth;
		int nowHeight;
		this.get_size(out nowWidth, out nowHeight);
		
		if (this.width == nowWidth && this.height == nowHeight) {
			Zystem.debug("THE UNNNNN maximizedBOOOOOGABOOGA");
		} else if (Gdk.WindowState.MAXIMIZED in this.get_window().get_state()) {
			Zystem.debug("EL MAXIMIZEDDD");
		}
	}

	//public void onTextChanged(TextBuffer buffer) {
	public void onTextChanged(DocumentView docView) {
		this.updateWordCount();
		
		if (this.isOpening) {
			return;
		}

		this.needsSave = true;

		if (this.note == null && this.editor.getText() != "") {
			// If creating a new note
			Zystem.debug("NOTE IS NULL, thank you very much!");
			Zystem.debug("Note title should be: " + this.editor.firstLine());
			this.note = new Note(this.editor.firstLine().strip());
			this.loadNotesList("Creating a new note!");
		} else if (this.editor.getText().strip() == "") {
			// Note text is empty; need to delete
			this.autoSave();
		} else if (this.editor.lineCount() > 0 && this.editor.firstLine().strip() != ""
				&& this.noteTitleChanged()) {
			// If note title changed
			Source.remove(this.timerId);	// TRY THAT! (This should fix the duplicate file issue)
			Zystem.debug("Oh boy, the note title changed. Let's rename that sucker.");
			this.note.rename(this.editor.firstLine().strip(), this.editor.getText());
			this.loadNotesList("Note title changed!");
			this.filter.notifyAutoSave();
			this.firstLine = this.editor.firstLine();
			Zystem.debug("I REPEAT - NOTE TITLE HAS BEEN CHANGED!!!");
		} else {
			Zystem.debug("ZLB NEW - CALLING REQUEST SAVE");
			this.requestSave();
		}
	}

	private void updateWordCount() {
		if (!UserData.showWordCount) {
			this.wordCountLabel.set_text("");
			return;
		}
		var wc = this.editor.getWordCount();
		this.wordCountLabel.set_text("Words: " + wc.words.to_string());
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

		Zystem.debug("\n\n" + this.editor.firstLine() + " VS \n" + this.firstLine + "\n");
		
		return this.editor.firstLine() != this.firstLine;   //this.note.title;
	}

	private void createNewNote() {
		this.note = new Note("");
		this.needsSave = false;
		this.isOpening = true;
		this.editor.startNewNote(this.note.title);
		this.isOpening = false;
	}

	/**
	 * Font size methods
	 */
	private void increaseFontSize() {
		this.changeFontSize(1);
	}
	private void decreaseFontSize() {
		this.changeFontSize(-1);
	}

	private int getFontSize() {
		//int size = Pango.FontDescription.from_string(UserData.fontString).get_size() / Pango.SCALE;
		//return size == 0 ? 10 : size;

		return this.noteTextView.get_style_context().get_font(StateFlags.NORMAL).get_size() / Pango.SCALE;
	}

	private void changeFontSize(int byThisMuch) {
		int fontSize = this.getFontSize();
		
		// If font would be too small or too big, no way man
		if (fontSize + byThisMuch < 6 || fontSize + byThisMuch > 50) {
			Zystem.debug("Not changing font size, because it would be: " + fontSize.to_string());
			return;
		}

		fontSize += byThisMuch;
		Zystem.debug("Changing font size to: " + fontSize.to_string());

		Pango.FontDescription font = this.noteTextView.style.context.get_font(StateFlags.NORMAL);
		double newFontSize = (fontSize) * Pango.SCALE;
		font.set_size((int)newFontSize);
		this.noteTextView.override_font(font);
		UserData.setFont(font.to_string());
	}

	private void clearFontPrefs() {
		UserData.setFont("");
		this.noteTextView.override_font(null);
		this.changeFontSize(10 - this.getFontSize());
	}

	private void chooseFont() {
		Gtk.FontChooserDialog dialog = new Gtk.FontChooserDialog ("Pick your favourite font", this);
		if (dialog.run () == Gtk.ResponseType.OK) {
			/*stdout.printf (" font: %s\n", dialog.get_font ().to_string ());
			stdout.printf (" desc: %s\n", dialog.get_font_desc ().to_string ());
			stdout.printf (" face: %s\n", dialog.get_font_face ().get_face_name ());
			stdout.printf (" size: %d\n", dialog.get_font_size ());
			stdout.printf (" family: %s\n", dialog.get_font_family ().get_name ());
			stdout.printf (" monospace: %s\n", dialog.get_font_family ().is_monospace ().to_string ());*/

			UserData.setFont(dialog.font);
			
			this.noteTextView.override_font(dialog.font_desc);
		}

		// Close the FontChooserDialog
		dialog.close ();
	}

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
		UserData.inChapter = false;
		this.loadNotesList("Just setting notes dir path.");
		this.monitorNotesDir();
		this.rememberCurrentNotebook();
	}

	private void setNotesDirToChapter(string dirPath) {
		this.createNewNote();
		UserData.setNotesDir(dirPath);
		UserData.inChapter = true;
		this.loadNotesList("Opened a Chapter.");
		this.monitorNotesDir();
	}

	 private void setNotesDirToFolder(string dirPath) {
		 this.createNewNote();
		 UserData.setNotesDir(dirPath);
		 UserData.inFolder = true;
		 if (this.isNotebook(dirPath)) {
			UserData.inFolder = false;
		 }
		 this.loadNotesList("Opened a folder.");
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

	private void menuWordCountToggled(CheckMenuItem menu) {
		UserData.setShowWordCount(menu.active);
		this.updateWordCount();
	}

	private void sortToggled(CheckMenuItem menu) {
		UserData.setUseAltSortType(menu.active);
		this.loadNotesList("Sort type was toggled to: " + menu.active.to_string());
		//this.setupNotesView();
		this.resetNotesView();
	}

	/**
	 * Quit P.S. Notes.
	 */
	public void on_destroy () {

		if (this.saveRequested && this.timerId != 0) {
			Source.remove(this.timerId);
			
			this.note.save(this.editor.getText());
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
