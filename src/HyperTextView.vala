/* -*- Mode: vala; tab-width: 4; intend-tabs-mode: t -*- */
/* psnotes
 *
 * Copyright (C) Zach Burnham 2013 <thejambi@gmail.com>
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

/**
 * HyperTextView is adapted from code found online.
 */


using Gtk;
using Pango;

public class HyperTextView : Gtk.SourceView {

	private Gdk.Cursor hand_cursor;
	private Gdk.Cursor regular_cursor;
	private bool cursor_over_link = false;

	private uint undo_timeout = 0;
	private int undo_cursor_pos;
	private string undo_text = "";
	private string redo_text = "";

	private uint tag_timeout = 0;
	private Gtk.TextTag tag_link;

	private Gtk.SourceBuffer code_buffer;

	construct {
		// need to setup language
        var manager = Gtk.SourceLanguageManager.get_default ();
        var language = manager.guess_language (null, "text/x-markdown");
        code_buffer = new Gtk.SourceBuffer.with_language (language);

		this.buffer = code_buffer;
		
		Gtk.TextIter iter;

		this.hand_cursor = new Gdk.Cursor (Gdk.CursorType.HAND2);
		this.regular_cursor = new Gdk.Cursor (Gdk.CursorType.XTERM);

		this.button_release_event += button_release_event_cb;
		this.motion_notify_event += motion_notify_event_cb;
		this.move_cursor += move_cursor_cb;
		this.buffer.changed += buffer_changed_cb;
		this.buffer.insert_text += insert_text_cb;
		this.buffer.delete_range += delete_range_cb;

		this.buffer.get_iter_at_offset (out iter, 0);
		this.buffer.create_mark ("undo-pos", iter, false);

		this.tag_link = this.buffer.create_tag ("link",
		                                        "foreground", "blue", // TODO use __gdk_color_constrast function
		                                        "underline", Pango.Underline.SINGLE,
		                                        null);
	}

	/*
	 * Signal callbacks
	 */

	/**
	 * button_release_event_cb:
	 *
	 * Event to open links.
	 */
	private bool button_release_event_cb (HyperTextView hypertextview, Gdk.EventButton event) {
		Gtk.TextIter start, end, iter;
		string link;
		int x, y;

		if (event.button != 1)
			return false;

		this.buffer.get_selection_bounds (out start, out end);
		if (start.get_offset () != end.get_offset ())
			return false;

		window_to_buffer_coords (Gtk.TextWindowType.WIDGET, (int)event.x, (int)event.y, out x, out y);
		get_iter_at_location (out iter, x, y);

		if (iter.has_tag (this.tag_link)) {
			start = end = iter;

			if (!start.begins_tag (this.tag_link)) {
				start.backward_to_tag_toggle (this.tag_link);
			}

			end.forward_to_tag_toggle (this.tag_link);

			link = start.get_text (end);

			try {
				GLib.AppInfo.launch_default_for_uri (link, null);
			} catch (Error ex) {
				warning ("Unable to open link `%s': %s", link, ex.message);

				/*if (Gdk.spawn_command_line_on_screen (Gdk.Screen.get_default (), "xdg-open "+link)) {
					return false;
				}

				if (Gdk.spawn_command_line_on_screen (Gdk.Screen.get_default (), "firefox "+link)) {
					return false;
				}*/

				critical ("Impossible to find an appropriate fallback to open the link");
			}
		}

		return false;
	}

	/**
	 * motion_notify_event_cb:
	 *
	 * Event to update the cursor of the pointer.
	 */
	private bool motion_notify_event_cb (HyperTextView hypertextview, Gdk.EventMotion event) {
		Gtk.TextIter iter;
		Gdk.Window win;
		bool over_link;
		int x, y;

		window_to_buffer_coords (Gtk.TextWindowType.WIDGET, (int)event.x, (int)event.y, out x, out y);
		get_iter_at_location (out iter, x, y);
		over_link = iter.has_tag (this.tag_link);

		if (over_link != this.cursor_over_link) {
			this.cursor_over_link = over_link;
			win = get_window (Gtk.TextWindowType.TEXT);
			win.set_cursor (over_link ? this.hand_cursor : this.regular_cursor);
		}

		return false;
	}

	/**
	 * move_cursor_cb:
	 *
	 * Destroys existing timeouts and executes the actions immediately.
	 */
	private void move_cursor_cb (HyperTextView hypertextview, Gtk.MovementStep step, int count, bool extend_selection) {
		if (this.undo_timeout > 0) {
			/* Make an undo snapshot and save cursor_position before it really moves */
			Source.remove (this.undo_timeout);
			undo_snapshot ();
			this.undo_cursor_pos = this.buffer.cursor_position;
		}

		if (this.tag_timeout > 0) {
			Source.remove (this.tag_timeout);
			update_tags ();
		}
	}

	/**
	 * buffer_changed_cb:
	 *
	 * Initializes timeouts to postpone actions.
	 */
	private void buffer_changed_cb () {
		/* Initialize undo_timeout */
		if (this.undo_timeout > 0) {
			Source.remove (this.undo_timeout);
		}
		this.undo_timeout = Timeout.add_seconds_full (Priority.DEFAULT, 1,  // ZLB
		                                              undo_snapshot);

		/* Reinit tag_timeout as long as the buffer is under constant changes */
		if (this.tag_timeout > 0) {
			Source.remove (this.tag_timeout);
			this.tag_timeout = Timeout.add_seconds_full (Priority.DEFAULT, 1,   // ZLB
			                                             tag_timeout_cb);
		}
	}

	/**
	 * insert_text_cb:
	 *
	 * Event to create and update existing tags within the buffer.
	 */
	private void insert_text_cb (Gtk.TextBuffer buffer, Gtk.TextIter location, string text, int len) {
		Gtk.TextIter start, end;

		/* Text is inserted inside a tag */
		if (location.has_tag (this.tag_link) && !location.begins_tag (this.tag_link)) {
			start = location;
			start.backward_to_tag_toggle (this.tag_link);

			if (location.get_offset () - start.get_offset () < 7) {
				end = start;
				end.forward_to_tag_toggle (this.tag_link);

				this.buffer.remove_tag (this.tag_link, start, end);

				if (len > 1 && (text.contains (" ") || text.contains ("\n"))) {
					/* We are here because there is a chance in a million that the
					 * user pasted a text that ends with " ht" in front of "tp://"
					 */
					tag_timeout_init ();
				}
			}
			else if (text.contains (" ") || text.contains ("\n")) {
				end = location;
				end.forward_to_tag_toggle (this.tag_link);

				this.buffer.remove_tag (this.tag_link, start, end);

				tag_timeout_init ();
			}
		}

		/* Text is inserted at the end of a tag */
		else if (location.ends_tag (this.tag_link)) {
			start = location;
			start.backward_to_tag_toggle (this.tag_link);

			this.buffer.remove_tag (this.tag_link, start, location);

			tag_timeout_init ();
		}

		/* Check if the word being typed is "http://" */
		 else if (len == 1 && text[0] == '/') {
			 start = location;

			 if (!start.backward_chars (6) || (start.get_text(location).down () != "http:/" && start.get_text(location).down () != "https:/"))
				 return;

			 tag_timeout_init ();
		 }
		 
		 /* Text contains links */
		 else if (len > 1 && (text.contains ("http://") || text.contains ("https://"))) {
			 tag_timeout_init ();
		 }
	}

	/**
	 * delete_range_cb:
	 *
	 * Event to delete and update existing tags within the buffer.
	 */
	private void delete_range_cb (Gtk.TextBuffer buffer, Gtk.TextIter start, Gtk.TextIter end) {
		Gtk.TextIter iter;

		if (!start.has_tag (this.tag_link) && !end.has_tag (this.tag_link))
			return;

		if (start.has_tag (this.tag_link)) {
			iter = start;
			iter.backward_to_tag_toggle (this.tag_link);
			this.buffer.remove_tag (this.tag_link, iter, start);
		}

		if (end.has_tag (this.tag_link)) {
			iter = end;
			iter.forward_to_tag_toggle (this.tag_link);
			this.buffer.remove_tag (this.tag_link, end, iter);
		}

		tag_timeout_init ();
	}

	/*
	 * Undo
	 */

	/**
	 * undo_snapshot:
	 *
	 * Makes a snapshot of the current buffer and swaps undo/redo texts.
	 */
	private bool undo_snapshot () {
		Gtk.TextIter start, end;

		this.undo_cursor_pos = this.buffer.cursor_position;

		this.buffer.get_iter_at_offset (out start, 0);
		this.buffer.get_iter_at_offset (out end, -1);

		this.undo_text = this.redo_text;
		this.redo_text = this.buffer.get_text (start, end, false);

		return false;
	}

	private void undo_timeout_destroy () {
		this.undo_timeout = 0;
	}

	/**
	 * undo:
	 *
	 * Revert the buffer to the undo text and swaps undo/redo texts.
	 */
	public void undo () {
		Gtk.TextIter iter;
		Gtk.TextMark mark;
		string tmp;

		if (this.undo_timeout > 0) {
			/* Make an undo snaphot */
			Source.remove (this.undo_timeout);
			undo_snapshot ();
		}

		this.buffer.set_text (this.undo_text, -1);
		this.buffer.get_iter_at_offset (out iter, this.undo_cursor_pos);
		this.buffer.place_cursor (iter);

		/* Scroll to the cursor position */
		mark = this.buffer.get_mark ("undo-pos");
		this.buffer.move_mark (mark, iter);
		this.scroll_to_mark (mark, 0.0, false, 0.5, 0.5);

		tmp = this.undo_text;
		this.undo_text = this.redo_text;
		this.redo_text = tmp;

		Source.remove (this.undo_timeout);
	}

	/*
	 * Tags
	 */

	private bool tag_timeout_cb () {
		update_tags ();
		return false;
	}

	private void tag_timeout_init () {
		if (this.tag_timeout > 0) {
			Source.remove (this.tag_timeout);
		}

		this.tag_timeout = Timeout.add_seconds_full (Priority.DEFAULT, 1,   // ZLB
		                                             tag_timeout_cb);
	}

	private void tag_timeout_destroy () {
		this.tag_timeout = 0;
	}

	/**
	 * update_tags:
	 *
	 * Goes through the entire document to search for untagged HTTP links and tag them.
	 */
	public void update_tags () {
		Gtk.TextIter iter, start, end, tmp;

		if (this.tag_timeout > 0)
			Source.remove (this.tag_timeout);

		this.buffer.get_iter_at_offset (out iter, 0);

		while (iter.forward_search ("http", Gtk.TextSearchFlags.TEXT_ONLY, out start, out end, null)) {
			iter = end;

			if (start.begins_tag (this.tag_link))
				continue;

			if (!iter.forward_search  (" ", Gtk.TextSearchFlags.TEXT_ONLY, out end, null, null)) {
				if (!iter.forward_search ("\n", Gtk.TextSearchFlags.TEXT_ONLY, out end, null, null)) {
					this.buffer.get_iter_at_offset (out end, -1);
				}
			}
			else if (iter.forward_search  ("\n", Gtk.TextSearchFlags.TEXT_ONLY, out tmp, null, null)) {
				if (tmp.get_offset () < end.get_offset ()) {
					end = tmp;
				}
			}

			if (end.get_offset () - start.get_offset () >= 7)
				this.buffer.apply_tag (this.tag_link, start, end);
		}
	}

	public Gtk.SourceBuffer getBuffer() {
		return code_buffer;
	}

}



public class DocumentView : Gtk.ScrolledWindow {
    private HyperTextView code_view;
    //private Gtk.SourceBuffer code_buffer;

    public signal void changed ();

    public DocumentView () {
        setup_code_view ();
    }
	
	public Gtk.SourceBuffer getBuffer() {
		//return code_buffer;
		return code_view.getBuffer();
	}

    public void set_text (string text, bool new_file = false) {
        if (new_file) {
            getBuffer().changed.disconnect (trigger_changed);
        }

        getBuffer().text = text;

        if (new_file) {
            getBuffer().changed.connect (trigger_changed);
        }
    }

    public void reset () {
        getBuffer().text = "";
    }

    public string get_text () {
        return code_view.buffer.text;
    }

    public string get_selected_text () {
        var start = Gtk.TextIter();
        var end = Gtk.TextIter();
        code_view.buffer.get_selection_bounds(out start, out end);
        return code_view.buffer.get_text(start, end, true);
    }

    public void give_focus () {
        code_view.grab_focus ();
    }

    public void set_font (string name) {
        var font = Pango.FontDescription.from_string (name);
        code_view.override_font (font);
    }

    public void set_scheme (string id) {
        var style_manager = Gtk.SourceStyleSchemeManager.get_default ();
        var style = style_manager.get_scheme (id);
        //code_buffer.set_style_scheme (style);
    }

    private string get_default_scheme () {
        var style_manager = Gtk.SourceStyleSchemeManager.get_default ();
        if ("solarized-light" in style_manager.scheme_ids) { // In Gnome
            return "solarized-light";
        } else { // In Elementary
            return "solarizedlight";
        }
    }

    private void trigger_changed () {
        changed ();
    }

    private void setup_code_view () {
        code_view = new HyperTextView();

        getBuffer().changed.connect (trigger_changed);
        
        // make it look pretty
        this.setDefaultMargins();
        code_view.pixels_above_lines = 5;
        // wrap text between words
        code_view.wrap_mode = Gtk.WrapMode.WORD;
        code_view.show_line_numbers = false;

        this.set_scheme (this.get_default_scheme ());

		code_view.pixels_inside_wrap = UserData.lineHeight;

        add (code_view);
    }

	public void setDefaultMargins() {
		this.setMargins(UserData.defaultMargins);
	}

	public void setMargins(int margin) {
		code_view.left_margin = margin;
		code_view.right_margin = margin;
	}

	public void beefUpAMargin() {
		code_view.left_margin = code_view.left_margin + 1;
	}
}



