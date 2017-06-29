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
using Gtk;
using GLib;

public class NoteEditor : GLib.Object {

	// Variables
	public SourceBuffer buffer { get; private set; }

	//private ArrayList<string> highlightStrings;

	//private int undoMax;

	//private ArrayList<Action> undos;
	//private ArrayList<Action> redos;

	private ulong onInsertConnection;
	private ulong onDeleteConnection;

	/**
	 * Constructor for NoteEditor.
	 */
	public NoteEditor(DocumentView docView) {
		//
		this.buffer = docView.getBuffer();

		//this.undoMax = 1000;
		//this.highlightStrings = new ArrayList<string>();
		// foundTag??
		//


		//this.undos = new ArrayList<Action>();
		//this.redos = new ArrayList<Action>();

		this.connectSignals();
		

		/*
		 * gtk.TextView.__init__( self)
		self.set_wrap_mode(gtk.WRAP_WORD)
		self.undo_max = None
		self._highlight_strings = []
		found_tag = gtk.TextTag("highlight")
		found_tag.set_property("background","yellow")
		self.get_buffer().get_tag_table().add(found_tag)

		self.insert_event = self.get_buffer().connect("insert-text",self._on_insert)
		self.delete_event = self.get_buffer().connect("delete-range",self._on_delete)
		self.change_event = self.get_buffer().connect("changed",self._on_text_changed)
		self._auto_bullet = None
		self.auto_bullets = False
		self.clipboard = gtk.Clipboard()

		self.undos = []
		self.redos = []
		 */


		this.createBoldTitleTag();
	}

	private void createBoldTitleTag() {
		TextTag boldTag = this.buffer.create_tag("boldTitle");
		boldTag.set_property("weight", Pango.Weight.BOLD);
	}

	private void setTitleBold() {
		TextIter startIter;
		this.buffer.get_iter_at_line(out startIter, 0);
		TextIter endIter;
		this.buffer.get_iter_at_line(out endIter, 1);
		this.buffer.apply_tag_by_name("boldTitle", startIter, endIter);
	}

	private TextIter getStartIter() {
		TextIter startIter;
		this.buffer.get_start_iter(out startIter);
		return startIter;
	}

	public TextIter getEndIter() {
		TextIter endIter;
		this.buffer.get_end_iter(out endIter);
		return endIter;
	}

	public string getText() {
		return buffer.text;
	}

	public string firstLine() {
		TextIter startIter;
		buffer.get_iter_at_line(out startIter, 0);

		if (lineCount() == 1) {
			return buffer.get_text(startIter, getEndIter(), false);
		}

		TextIter endIter;
		buffer.get_iter_at_line(out endIter, 1);
		return buffer.get_text(startIter, endIter, false);
	}

	public int lineCount() {
		return buffer.get_line_count();
	}

	/*
	 * Start working on a new note. Sets the passed in text as the buffer text.
	 */
	public void startNewNote(string text) {
		//this.undos.clear();
		//this.redos.clear();

		this.disconnectSignals();
		
		this.buffer.set_text(text);

		this.connectSignals();

		this.setTitleBold();	// ZLB!!!!!!!!!!!!!!!!!!!!!!!!!!!!

		this.buffer.set_undo_manager(null);
	}

	private TextIter getIterAtOffset(int offset) {
		TextIter iter;
		this.buffer.get_iter_at_offset(out iter, offset);
		return iter;
	}

	public void append(string text) {
		TextIter iter = this.getEndIter();
		this.buffer.insert(ref iter, text, text.length);
	}

	public void prepend(string text) {
		TextIter startIter = this.getStartIter();
		this.buffer.insert(ref startIter, text, text.length);
	}

	public void prependDateToEntry(string dateHeading) {
		if (!this.buffer.text.has_prefix(dateHeading.strip())) {
			this.prepend(dateHeading);
		}
	}

	public void insertAtCursor(string text) {
		TextIter startIter = this.getCurrentIter();
		this.buffer.insert(ref startIter, text, text.length);
	}

	public void insertAfterCursor(string text) {
		TextIter startIter = this.getCurrentIter();
		this.buffer.insert(ref startIter, text, text.length);
		startIter.backward_chars(text.length);
		this.buffer.place_cursor(startIter);
	}

	public void cursorToEnd() {
		this.buffer.place_cursor(this.getEndIter());
	}

	public void cursorToStart() {
		this.buffer.place_cursor(this.getStartIter());
	}

	public TextIter getCurrentIter() {
		TextIter iter;
		this.buffer.get_iter_at_offset(out iter, this.buffer.cursor_position);
		return iter;
	}

	public void insertAtIter(TextIter iter, string text) {
		this.buffer.insert(ref iter, text, text.length);
	}

	public void insertAfterIter(TextIter iter, string text) {
		this.buffer.insert(ref iter, text, text.length);
		iter.backward_chars(text.length);
		this.buffer.place_cursor(iter);
	}

	/************** Markdown **************/
	public void simpleMarkdownSurround(string str) {
		if (this.buffer.has_selection) {
			// Surrounding selected text
			TextIter beginIter;
			TextIter endIter;
			this.buffer.get_selection_bounds(out beginIter, out endIter);
			this.insertAtIter(beginIter, str);
			// Need to recalculate endIter...
			this.buffer.get_selection_bounds(out beginIter, out endIter);
			this.insertAtIter(endIter, str);
		} else {
			// No selection, just surround cursor position
			// Ideally, grab current word and surround that?
			this.insertAtCursor(str);
			this.insertAfterCursor(str);
		}
	}
	
	public void toggleMarkdownSurround(string str) {
		if (this.cursorSurrounded(str)) {
			Zystem.debug("Need to un-surround!");
			this.unsurround(str);
		} else {
			this.simpleMarkdownSurround(str);
		}
	}

	private void unsurround(string str) {
		// Remove "str" from front of selection or just before selection
		// Remove "str" from end of selection or just after selection

		if (this.buffer.has_selection) {
			TextIter beginIter1;
			TextIter beginIter2;
			TextIter endIter1;
			TextIter endIter2;
			this.buffer.get_selection_bounds(out beginIter1, out endIter1);
			this.buffer.get_selection_bounds(out beginIter2, out endIter2);

			// Remove from end first
			// Is 'str' after selection?
			endIter2.forward_chars(str.length);
			string txt = this.buffer.get_text(endIter1, endIter2, false);
			if (txt == str) {
				this.buffer.@delete(ref endIter1, ref endIter2);
			} else {
				// 'str' must be at end of selection
				endIter2.backward_chars(str.length);
				endIter1.backward_chars(str.length);
				txt = this.buffer.get_text(endIter1, endIter2, false);
				if (txt == str) {
					this.buffer.@delete(ref endIter1, ref endIter2);
				}
			}

			// Recalculate after text change:
			this.buffer.get_selection_bounds(out beginIter1, out endIter1);
			this.buffer.get_selection_bounds(out beginIter2, out endIter2);

			// Remove from beginning
			// Is 'str' at beginning of selection?
			beginIter2.forward_chars(str.length);
			txt = this.buffer.get_text(beginIter1, beginIter2, false);
			if (txt == str) {
				this.buffer.@delete(ref beginIter1, ref beginIter2);
			} else {
				// 'str' must be before selection
				beginIter1.backward_chars(str.length);
				beginIter2.backward_chars(str.length);
				txt = this.buffer.get_text(beginIter1, beginIter2, false);
				if (txt == str) {
					this.buffer.@delete(ref beginIter1, ref beginIter2);
				}
			}
		} else {
			// No selection. Remove 'str' from just before cursor and just after
		}
	}

	private bool cursorSurrounded(string str) {
		if (this.buffer.has_selection) {
			// Check surrounding selected text
			TextIter beginIter;
			TextIter endIter;
			this.buffer.get_selection_bounds(out beginIter, out endIter);
			// Get text from iters?
			string txt = this.buffer.get_text(beginIter, endIter, false);
			
			// Does txt contain surroundness?
			bool left1 = txt.has_prefix(str);
			bool right1 = txt.has_suffix(str);
			
			if (left1 && right1) {
				return true;
			} else {
				// Expand iters, maybe just "word" is selected in "**word**" for example
				beginIter.backward_chars(str.length);
				endIter.forward_chars(str.length);
				txt = this.buffer.get_text(beginIter, endIter, false);
				bool left2 = txt.has_prefix(str);
				bool right2 = txt.has_suffix(str);
				return (left1 || left2) && (right1 || right2);
			}
		} else {
			// No selection, just check if cursor position surrounded
			// return this.textAtCursorIs(str) && this.textBeforeCursorIs(str);
		}
		
		return false;
	}

	public void surroundWithOpenAndClose(string open, string close) {
		if (this.buffer.has_selection) {
			// Surrounding selected text
			TextIter beginIter;
			TextIter endIter;
			this.buffer.get_selection_bounds(out beginIter, out endIter);
			this.insertAtIter(beginIter, open);
			// Need to recalculate endIter...
			this.buffer.get_selection_bounds(out beginIter, out endIter);
			this.insertAtIter(endIter, close);
		} else {
			// No selection, just surround cursor position
			this.insertAtCursor(open);
			this.insertAfterCursor(close);
		}
	}

	private string getHeadingStr(int level, bool includeSpace = true) {
		var headingStr = "";
		for (var i = 0; i < level; i++) {
			headingStr += "#";
		}
		if (includeSpace && level != 0) {
			headingStr += " ";
		}
		return headingStr;
	}

	private int getMarkdownHeadingLevel() {
		TextIter currentIter = this.getCurrentIter();
		
		TextIter lineStartIter = this.getCurrentIter();
		lineStartIter.set_line(currentIter.get_line());

		TextIter lineEndIter = this.getCurrentIter();
		lineEndIter.set_line(currentIter.get_line());
		lineEndIter.forward_to_line_end();

		var lineText = this.buffer.get_text(lineStartIter, lineEndIter, true);
		Zystem.debug(lineText);

		var hasHeading = false;
		hasHeading = Regex.match_simple("^#+ [\\s\\S]*", lineText);
		Zystem.debug(hasHeading.to_string());

		// Get heading level number
		var existingLevel = 0;
		if (hasHeading) {
			for (int i=0; i < lineText.char_count(); i++) {
				string ch = lineText.get_char(lineText.index_of_nth_char(i)).to_string();
				if (ch == "#") {
					existingLevel++;
				} else {
					break;
				}
			}
			Zystem.debug(existingLevel.to_string());
		}
		return existingLevel;
	}

	public void insertMarkdownHeading(int level) {
		// get heading string
		var headingStr = this.getHeadingStr(level);

		// Does line contain a heading already?
		var existingLevel = this.getMarkdownHeadingLevel();

		if (level == existingLevel) {
			level = 0;
			headingStr = this.getHeadingStr(0);
		}

		TextIter currentIter = this.getCurrentIter();
		
		TextIter lineStartIter = this.getCurrentIter();
		lineStartIter.set_line(currentIter.get_line());

		// If has heading, change it, else insert it

		if (existingLevel > 0) {
			var levelsToAdd = level - existingLevel;
			if (levelsToAdd > 0) {
				// Insert
				this.insertAtIter(lineStartIter, this.getHeadingStr(levelsToAdd, false));
			} else if (levelsToAdd < 0) {
				// Delete
				TextIter deleteToHereIter = this.getCurrentIter();
				deleteToHereIter.set_line(currentIter.get_line());
				deleteToHereIter.forward_chars(levelsToAdd*-1);
				if (levelsToAdd*-1 == existingLevel) {
					deleteToHereIter.forward_chars(1);
				}
				this.buffer.@delete(ref lineStartIter, ref deleteToHereIter);
			}
		} else {
			this.insertAtIter(lineStartIter, headingStr);
		}

		// Cursor keeps position, no cursor edit needed.
	}

	public void adjustMarkdownHeading(int levels) {
		var existingLevel = this.getMarkdownHeadingLevel();
		var targetHeadingLevel = existingLevel + levels;
		if (targetHeadingLevel >= 0) {
			this.insertMarkdownHeading(targetHeadingLevel);
		}
	}
	/**************  **************/

	/*public void undo() {
		Zystem.debug("IN UNDO");
		//
		if (this.undos.size == 0) {
			Zystem.debug("Nothing to undo");
			return;
		}

		this.disconnectSignals();

		Action undo = this.undos.last();
		Action redo = this.doAction(undo);
		this.redos.add(redo);
		this.undos.remove(undo);

		this.connectSignals();
		//this.insertEvent = this.buffer.connect("insert-text", this.onInsert);
		//this.deleteEvent = this.buffer.connect("delete-range", this.onDelete);
	}*/
	
	public Action doAction(Action action) {
		Zystem.debug("IN doAction");
		//
		if (action.action == "delete") {
			TextIter start = this.getIterAtOffset(action.offset);
			TextIter end = this.getIterAtOffset(action.offset + action.text.length);
			this.buffer.delete(ref start, ref end);
			action.action = "insert";
		} else if (action.action == "insert") {
			TextIter start = this.getIterAtOffset(action.offset);
			TextIter end = this.getIterAtOffset(action.offset + action.text.length);
			this.buffer.insert(ref start, action.text, action.text.length);
			action.action = "delete";
		}

		return action;
	}

	/*public void redo() {
		//

		if (this.redos.size == 0) {
			Zystem.debug("Nothing to redo");
			return;
		}

		this.disconnectSignals();

		Action redo = this.redos.last();
		Action undo = this.doAction(redo);
		this.undos.add(undo);
		this.redos.remove(redo);

		this.connectSignals();

		// this.highlight();
	}*/

	private void onInsertText(TextIter iter, string text, int length) {

		// this.highlight();

		Action cmd = new Action("delete", iter.get_offset(), text);
		//this.undos.add(cmd);
		//this.redos.clear();

		// Auto-bullets support
		//if (text == "\n" && UserData.autoBulletsOn) {
			//
		//}
	}

	private void onDeleteRange(TextIter startIter, TextIter endIter) {
		Zystem.debug("In onDeleteRange()");

		// this.highlight();

		string text = this.buffer.get_text(startIter, endIter, false);
		Zystem.debug("Text was: " + text);
		Action cmd = new Action("insert", startIter.get_offset(), text);
		//this.addUndo(cmd);
	}

	/*private void addUndo(Action cmd) {

		if (this.undos.size >= this.undoMax) {
			// remove first? self.undos.
		}

		this.undos.add(cmd);
	}*/

	private void connectSignals() {
		//
		this.onInsertConnection = 
			this.buffer.insert_text.connect((ref iter,text,length) => { this.onInsertText(iter, text, length); });
		this.onDeleteConnection =
			this.buffer.delete_range.connect((startIter,endIter) => { this.onDeleteRange(startIter, endIter); });
	}

	private void disconnectSignals() {
		//
		this.buffer.disconnect(this.onInsertConnection);
		this.buffer.disconnect(this.onDeleteConnection);
		//foo.disconnect (handler_id);
	}

	public WordCount getWordCount() {
		try {
			var reg = new Regex("[\\s\\W]+", RegexCompileFlags.OPTIMIZE);//new Regex(" +");
			string text = this.getText();//.replace("\n", " ");
			string result = reg.replace (text, text.length, 0, " ");
		
			return new WordCount(result.strip().split(" ").length, result.length);
		} catch (Error e) {
			return new WordCount(0, 0);
		}
	}
	
}

public class WordCount {
	public int words { get; private set; }
	public int chars { get; private set; }

	public WordCount(int words, int chars) {
		this.words = words;
		this.chars = chars;
	}
}

public class Action {

	public string action { get; set; }
	public string text { get; set; }
	public int offset { get; set; }

	public Action(string action, int offset, string text) {
		this.action = action;
		this.text = text;
		this.offset = offset;
	}

}

public class MarkdownStrings {
	public const string BOLD = "**";
	public const string ITALICS = "_";
	public const string CODE_TICK = "`";
	public const string HTML_COMMENT_OPEN = "<!--";
	public const string HTML_COMMENT_CLOSE = "-->";
}
