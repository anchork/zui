package zui.mobile;

#if kha_html5
import js.Browser;
import js.html.Event;
import js.html.InputElement;
import js.html.KeyboardEvent;
import kha.input.KeyCode;

/**
	On-screen keyboard and IME support for HTML5.

	Kha's HTML5 backend has no virtual keyboard, so a hidden <input> element is focused while a
	Zui text field is edited. The browser edits the text (soft keyboard, IME composition, autocorrect,
	native caret) and the result is mirrored into Zui with Zui.setTextEdit().

	Mobile browsers only show the keyboard when focus() happens inside a user input event, which is
	why Zui calls prime() from its mouse-up handler when a text field is tapped.
**/
class HtmlSoftKeyboard implements Zui.SoftKeyboard {

	var input: InputElement;
	var ui: Zui = null;
	var active = false; // Zui is editing a field
	var primed = false; // Focused from an input event, waiting for Zui to start editing
	var primeFrames = 0;
	var blurring = false;

	public function new() {
		var doc = Browser.document;
		input = cast doc.createElement("input");
		input.type = "text";
		input.setAttribute("autocomplete", "off");
		input.setAttribute("autocorrect", "off");
		input.setAttribute("autocapitalize", "off");
		input.setAttribute("spellcheck", "false");
		input.setAttribute("enterkeyhint", "done");
		input.setAttribute("aria-hidden", "true");
		var s = input.style;
		s.position = "fixed";
		s.left = "0px";
		s.top = "0px";
		s.width = "1px";
		s.height = "1px";
		s.opacity = "0";
		s.border = "0";
		s.padding = "0";
		s.margin = "0";
		s.outline = "none";
		s.fontSize = "16px"; // Smaller fonts make iOS zoom into the page on focus
		s.color = "transparent";
		s.background = "transparent";
		s.setProperty("caret-color", "transparent");
		s.pointerEvents = "none";
		s.zIndex = "-1";
		doc.body.appendChild(input);

		input.addEventListener("input", function(_) sync());
		input.addEventListener("keyup", function(e: KeyboardEvent) {
			e.stopPropagation();
			sync();
		});
		input.addEventListener("keydown", onKeyDown);
		input.addEventListener("keypress", function(e: Event) e.stopPropagation());
		input.addEventListener("compositionend", function(_) sync());
		// Kha listens for clipboard events on the document and would paste a second time
		for (type in ["paste", "copy", "cut"]) input.addEventListener(type, function(e: Event) e.stopPropagation());
		input.addEventListener("blur", function(_) {
			if (blurring || !active || ui == null) return;
			active = false;
			ui.deselectTextEdit(); // Keyboard closed by the user (e.g. "Done" on iOS)
		});
		doc.addEventListener("selectionchange", function(_) {
			if (doc.activeElement == input) sync();
		});
	}

	function onKeyDown(e: KeyboardEvent) {
		e.stopPropagation(); // Keep Kha's canvas handlers out of it
		if (ui == null || !active) return;
		if (untyped e.isComposing || e.keyCode == 229) return; // IME is converting, Enter confirms the candidate
		var code: Null<KeyCode> = switch (e.key) {
			case "Enter": KeyCode.Return;
			case "Escape": KeyCode.Escape;
			case "Tab": KeyCode.Tab;
			default: null;
		}
		if (code == null) return;
		e.preventDefault();
		sync();
		ui.onKeyDown(code);
		ui.onKeyUp(code);
	}

	function sync() {
		if (!active || ui == null) return;
		var start = input.selectionStart;
		var end = input.selectionEnd;
		if (start == null) start = input.value.length;
		if (end == null) end = start;
		var backward = input.selectionDirection == "backward";
		ui.setTextEdit(input.value, backward ? start : end, backward ? end : start);
	}

	function place(x: Float, y: Float, w: Float, h: Float) {
		// Put the element over the text field so the browser scrolls the right spot into view
		var canvas = kha.SystemImpl.khanvas;
		var rect = canvas.getBoundingClientRect();
		var sx = canvas.width > 0 ? rect.width / canvas.width : 1;
		var sy = canvas.height > 0 ? rect.height / canvas.height : 1;
		input.style.left = (rect.left + x * sx) + "px";
		input.style.top = (rect.top + y * sy) + "px";
		input.style.width = Math.max(1, w * sx) + "px";
		input.style.height = Math.max(1, h * sy) + "px";
	}

	function focus() {
		if (Browser.document.activeElement != input) (untyped input).focus({preventScroll: true});
	}

	public function prime(x: Float, y: Float, w: Float, h: Float) {
		place(x, y, w, h);
		primed = true;
		primeFrames = 0;
		focus();
	}

	public function show(ui: Zui, text: String, cursor: Int, anchor: Int, x: Float, y: Float, w: Float, h: Float) {
		this.ui = ui;
		active = true;
		primed = false;
		place(x, y, w, h);
		input.value = text;
		focus();
		var a = anchor < cursor ? anchor : cursor;
		var b = anchor < cursor ? cursor : anchor;
		try (untyped input).setSelectionRange(a, b, anchor > cursor ? "backward" : "forward") catch (_: Dynamic) {}
	}

	public function hide() {
		active = false;
		primed = false;
		blur();
	}

	public function update(ui: Zui) {
		// Focused for a tap that did not start editing (e.g. field disappeared): close the keyboard again
		if (primed && !active && ++primeFrames > 3) {
			primed = false;
			blur();
		}
	}

	function blur() {
		if (Browser.document.activeElement != input) return;
		blurring = true;
		input.blur();
		blurring = false;
	}
}
#end
