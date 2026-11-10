package zui.mobile;

import kha.graphics2.Graphics;
import zui.Zui;

enum abstract ButtonStyle(Int) from Int to Int {
	var Filled = 0;
	var Tonal = 1;
	var Outlined = 2;
	var Text = 3;
	var Danger = 4;
}

/**
	Touch friendly widgets. They work like Zui elements: call them inside a window or region,
	they follow Zui's layout (row(), indent(), ...) and keep their state in a Handle.
	Colors come from Mobile.theme.
**/
@:access(zui.Zui)
class Widgets {

	static inline function dp(ui: Zui, v: Float): Float return v * ui.SCALE();
	static inline function sp(ui: Zui, v: Float): Int return Std.int(v * ui.SCALE());

	/** Keep the current window redrawing (animations). **/
	public static function animate(ui: Zui) {
		if (ui.currentWindow != null) ui.currentWindow.redraws = 2;
	}

	// Hit tests for a rect in the current window/region coordinates

	static inline function inside(px: Float, py: Float, x: Float, y: Float, w: Float, h: Float): Bool {
		return px >= x && px < x + w && py >= y && py < y + h;
	}

	static function hit(ui: Zui, px: Float, py: Float, x: Float, y: Float, w: Float, h: Float): Bool {
		return ui.inputInWindow(px, py) && inside(px, py, ui._windowX + x, ui._windowY + y, w, h);
	}

	public static function tapped(ui: Zui, x: Float, y: Float, w: Float, h: Float): Bool {
		return ui.enabled && ui.inputEnabled && ui.inputReleased && hit(ui, ui.inputX, ui.inputY, x, y, w, h) &&
			hit(ui, ui.inputStartedX, ui.inputStartedY, x, y, w, h);
	}

	public static function pressed(ui: Zui, x: Float, y: Float, w: Float, h: Float): Bool {
		return ui.enabled && ui.inputEnabled && ui.inputDown && ui.touchScrollHandle == null &&
			hit(ui, ui.inputX, ui.inputY, x, y, w, h) && hit(ui, ui.inputStartedX, ui.inputStartedY, x, y, w, h);
	}

	static function started(ui: Zui, x: Float, y: Float, w: Float, h: Float): Bool {
		return ui.enabled && ui.inputEnabled && ui.inputStarted && hit(ui, ui.inputX, ui.inputY, x, y, w, h);
	}

	static inline function col(ui: Zui, c: Int): Int {
		return ui.enabled ? c : Draw.alpha(c, 0.38);
	}

	/** Horizontal margin in dp on both sides for the following elements. Undo with a negative value. **/
	public static function margin(ui: Zui, m: Float = 8) {
		var px = dp(ui, m);
		ui._x += px;
		ui._w -= Std.int(px * 2);
	}

	/** Vertical gap in dp. **/
	public static function space(ui: Zui, h: Float = 16) {
		ui._y += dp(ui, h);
	}

	/** Pill shaped button. **/
	public static function button(ui: Zui, text: String, style: ButtonStyle = Filled, icon: String = null): Bool {
		var eh = ui.ELEMENT_H();
		if (!ui.isVisible(eh)) {
			ui.endElement();
			return false;
		}
		var t = Mobile.theme;
		var g = ui.g;
		var pad = ui.buttonOffsetY;
		var x = ui._x + pad;
		var y = ui._y + pad;
		var w = ui._w - pad * 2;
		var h = ui.BUTTON_H();
		var released = tapped(ui, x, y, w, h);
		var down = pressed(ui, x, y, w, h);
		if (released) ui.changed = true;

		var bg = 0;
		var fg = 0;
		switch (style) {
			case Filled: bg = t.primary; fg = t.onPrimary;
			case Tonal: bg = t.primaryContainer; fg = t.onPrimaryContainer;
			case Danger: bg = t.error; fg = 0xffffffff;
			case Outlined | Text: bg = 0; fg = t.primary;
		}
		if (down) bg = bg == 0 ? Draw.alpha(fg, 0.12) : Draw.mix(bg, fg, 0.14);
		if (bg != 0) {
			g.color = col(ui, bg);
			Draw.fillRoundRect(g, x, y, w, h, h / 2);
		}
		if (style == Outlined) {
			g.color = col(ui, t.outline);
			Draw.strokeRoundRect(g, x, y, w, h, h / 2, Math.max(1, dp(ui, 1)));
		}
		var size = sp(ui, 15);
		var font = ui.ops.font;
		var iconSize = sp(ui, 18);
		var gap = icon != null ? dp(ui, 8) + iconSize : 0;
		var label = Draw.fit(font, size, text, w - dp(ui, 24) - gap);
		var cw = Draw.width(font, size, label) + gap;
		var cx = x + (w - cw) / 2;
		if (icon != null) Draw.icon(ui, g, icon, cx + iconSize / 2, y + h / 2, iconSize, col(ui, fg));
		Draw.textMid(ui, g, label, cx + gap, y + h / 2, size, fg);
		ui.endElement();
		return released;
	}

	/** Round icon button, e.g. inside a row. **/
	public static function iconButton(ui: Zui, icon: String, filled = false): Bool {
		var eh = ui.ELEMENT_H();
		if (!ui.isVisible(eh)) {
			ui.endElement();
			return false;
		}
		var t = Mobile.theme;
		var g = ui.g;
		var s = Math.min(eh, ui._w);
		var x = ui._x + (ui._w - s) / 2;
		var y = ui._y;
		var released = tapped(ui, x, y, s, s);
		var down = pressed(ui, x, y, s, s);
		var r = s / 2 - dp(ui, 2);
		if (filled || down) {
			g.color = col(ui, filled ? (down ? Draw.mix(t.primaryContainer, t.onPrimaryContainer, 0.14) : t.primaryContainer) : Draw.alpha(t.onSurface, 0.1));
			Draw.fillCircle(g, x + s / 2, y + s / 2, r);
		}
		Draw.icon(ui, g, icon, x + s / 2, y + s / 2, sp(ui, 24), col(ui, filled ? t.onPrimaryContainer : t.onSurfaceVariant));
		ui.endElement();
		return released;
	}

	/**
		On/off switch with a label. The whole row is tappable.
		State: handle.selected. handle.value is used for the knob animation.
	**/
	public static function toggle(ui: Zui, handle: Handle, text: String, subtitle: String = null): Bool {
		var h = subtitle != null ? dp(ui, 64) : ui.ELEMENT_H();
		if (!ui.isVisible(h)) {
			ui.endElement(h);
			return handle.selected;
		}
		var t = Mobile.theme;
		var g = ui.g;
		handle.changed = false;
		if (tapped(ui, ui._x, ui._y, ui._w, h)) {
			handle.selected = !handle.selected;
			handle.changed = ui.changed = true;
		}
		if (pressed(ui, ui._x, ui._y, ui._w, h)) {
			g.color = Draw.alpha(t.onSurface, 0.06);
			g.fillRect(ui._x, ui._y, ui._w, h);
		}
		// Knob animation
		var target = handle.selected ? 1.0 : 0.0;
		if (handle.value != target) {
			var step = 0.2;
			handle.value = handle.value < target ? Math.min(target, handle.value + step) : Math.max(target, handle.value - step);
			animate(ui);
		}
		var p = handle.value;
		var tw = dp(ui, 52);
		var th = dp(ui, 32);
		var pad = ui.TEXT_OFFSET();
		var tx = ui._x + ui._w - pad - tw;
		var ty = ui._y + (h - th) / 2;
		g.color = col(ui, Draw.mix(t.surfaceVariant, t.primary, p));
		Draw.fillRoundRect(g, tx, ty, tw, th, th / 2);
		if (p < 1) {
			g.color = col(ui, Draw.alpha(t.outline, 1 - p));
			Draw.strokeRoundRect(g, tx, ty, tw, th, th / 2, dp(ui, 2));
		}
		var kr = dp(ui, 8 + 4 * p);
		var kx = tx + th / 2 + (tw - th) * p;
		g.color = col(ui, Draw.mix(t.outline, t.onPrimary, p));
		Draw.fillCircle(g, kx, ty + th / 2, kr);
		if (p > 0.5) Draw.icon(ui, g, Icons.CHECK, kx, ty + th / 2, sp(ui, 16), Draw.alpha(t.primary, (p - 0.5) * 2));

		var font = ui.ops.font;
		var size = sp(ui, 16);
		var maxW = tx - ui._x - pad * 2;
		if (subtitle != null) {
			var ss = sp(ui, 13);
			var total = font.height(size) + font.height(ss);
			var y0 = ui._y + (h - total) / 2;
			Draw.text(ui, g, Draw.fit(font, size, text, maxW), ui._x + pad, y0, size, t.onSurface);
			Draw.text(ui, g, Draw.fit(font, ss, subtitle, maxW), ui._x + pad, y0 + font.height(size), ss, t.onSurfaceVariant);
		}
		else Draw.textMid(ui, g, Draw.fit(font, size, text, maxW), ui._x + pad, ui._y + h / 2, size, t.onSurface);
		ui.endElement(h);
		return handle.selected;
	}

	/** Segmented button / tab switcher. Returns handle.position. **/
	public static function segmented(ui: Zui, handle: Handle, items: Array<String>): Int {
		var eh = ui.ELEMENT_H();
		if (!ui.isVisible(eh)) {
			ui.endElement();
			return handle.position;
		}
		var t = Mobile.theme;
		var g = ui.g;
		var pad = ui.buttonOffsetY;
		var x = ui._x + pad;
		var y = ui._y + pad;
		var w = ui._w - pad * 2;
		var h = ui.BUTTON_H();
		var sw = w / items.length;
		handle.changed = false;
		var line = Math.max(1, dp(ui, 1));
		g.color = col(ui, t.surfaceVariant);
		Draw.fillRoundRect(g, x, y, w, h, h / 2);
		var font = ui.ops.font;
		var size = sp(ui, 14);
		for (i in 0...items.length) {
			var sx = x + sw * i;
			if (tapped(ui, sx, y, sw, h) && handle.position != i) {
				handle.position = i;
				handle.changed = ui.changed = true;
			}
			var sel = handle.position == i;
			var inset = dp(ui, 3);
			if (sel) {
				g.color = col(ui, t.primary);
				Draw.fillRoundRect(g, sx + inset, y + inset, sw - inset * 2, h - inset * 2, (h - inset * 2) / 2);
			}
			else if (pressed(ui, sx, y, sw, h)) {
				g.color = Draw.alpha(t.onSurface, 0.08);
				Draw.fillRoundRect(g, sx + inset, y + inset, sw - inset * 2, h - inset * 2, (h - inset * 2) / 2);
			}
			var label = Draw.fit(font, size, items[i], sw - dp(ui, 12));
			Draw.textMid(ui, g, label, sx + sw / 2, y + h / 2, size, sel ? t.onPrimary : t.onSurface, 1);
		}
		ui.endElement();
		return handle.position;
	}

	/** Label with - value + buttons. Returns handle.value. **/
	public static function stepper(ui: Zui, handle: Handle, text: String, min = 0.0, max = 100.0, step = 1.0, precision = 0): Float {
		var eh = ui.ELEMENT_H();
		if (!ui.isVisible(eh)) {
			ui.endElement();
			return handle.value;
		}
		var t = Mobile.theme;
		var g = ui.g;
		var pad = ui.TEXT_OFFSET();
		var b = dp(ui, 36);
		var valueW = dp(ui, 56);
		var right = ui._x + ui._w - pad;
		var plusX = right - b;
		var minusX = plusX - valueW - b;
		var by = ui._y + (eh - b) / 2;
		handle.changed = false;
		var slop = dp(ui, 6); // Slightly larger touch targets than the drawn circles
		if (tapped(ui, minusX - slop, ui._y, b + slop * 2, eh) && handle.value > min) {
			handle.value = Math.max(min, handle.value - step);
			handle.changed = ui.changed = true;
		}
		if (tapped(ui, plusX - slop, ui._y, b + slop * 2, eh) && handle.value < max) {
			handle.value = Math.min(max, handle.value + step);
			handle.changed = ui.changed = true;
		}
		var m = Math.pow(10, precision);
		handle.value = Math.round(handle.value * m) / m;
		for (i in 0...2) {
			var bx = i == 0 ? minusX : plusX;
			var enabled = i == 0 ? handle.value > min : handle.value < max;
			var down = pressed(ui, bx - slop, ui._y, b + slop * 2, eh) && enabled;
			g.color = col(ui, down ? Draw.mix(t.primaryContainer, t.onPrimaryContainer, 0.14) : enabled ? t.primaryContainer : t.surfaceVariant);
			Draw.fillCircle(g, bx + b / 2, by + b / 2, b / 2);
			Draw.icon(ui, g, i == 0 ? Icons.REMOVE : Icons.ADD, bx + b / 2, by + b / 2, sp(ui, 20),
				col(ui, enabled ? t.onPrimaryContainer : t.outline));
		}
		var size = sp(ui, 16);
		var vs = precision > 0 ? formatFixed(handle.value, precision) : "" + Std.int(handle.value);
		Draw.textMid(ui, g, vs, minusX + b + valueW / 2, ui._y + eh / 2, size, t.onSurface, 1);
		Draw.textMid(ui, g, Draw.fit(ui.ops.font, size, text, minusX - ui._x - pad * 2), ui._x + pad, ui._y + eh / 2, size, t.onSurface);
		ui.endElement();
		return handle.value;
	}

	public static function formatFixed(v: Float, precision: Int): String {
		var m = Math.pow(10, precision);
		var neg = v < 0;
		var n = Math.round(Math.abs(v) * m);
		var ip = Std.int(n / m);
		var fp = "" + Std.int(n - ip * m);
		while (fp.length < precision) fp = "0" + fp;
		return (neg ? "-" : "") + ip + (precision > 0 ? "." + fp : "");
	}

	/**
		Slider with a thumb that follows the finger. step > 0 snaps the value.
		Returns handle.value.
	**/
	public static function slider(ui: Zui, handle: Handle, text: String = null, from = 0.0, to = 1.0, step = 0.0, showValue = true, precision = 0): Float {
		var labelH = text != null ? dp(ui, 22) : 0;
		var h = labelH + ui.ELEMENT_H();
		if (!ui.isVisible(h)) {
			ui.endElement(h);
			return handle.value;
		}
		var t = Mobile.theme;
		var g = ui.g;
		var pad = ui.TEXT_OFFSET();
		var tx = ui._x + pad + dp(ui, 8);
		var tw = ui._w - pad * 2 - dp(ui, 16);
		var cy = ui._y + labelH + ui.ELEMENT_H() / 2;
		handle.changed = false;

		if (started(ui, ui._x, ui._y, ui._w, h)) { // Capture the finger, window scrolling stays off
			ui.scrollHandle = handle;
			ui.isScrolling = true;
		}
		var dragging = ui.scrollHandle == handle;
		if (dragging) {
			var v = from + (ui.inputX - ui._windowX - tx) / tw * (to - from);
			if (step > 0) v = from + Math.round((v - from) / step) * step;
			v = Math.max(Math.min(v, Math.max(from, to)), Math.min(from, to));
			if (v != handle.value) {
				handle.value = v;
				handle.changed = ui.changed = true;
			}
		}
		var p = (handle.value - from) / (to - from);
		p = p < 0 ? 0 : p > 1 ? 1 : p;
		var size = sp(ui, 15);
		if (text != null) {
			Draw.text(ui, g, text, ui._x + pad, ui._y + dp(ui, 4), size, t.onSurface);
			if (showValue) Draw.text(ui, g, formatFixed(handle.value, precision), ui._x + ui._w - pad, ui._y + dp(ui, 4), size, t.primary, 2);
		}
		var trackH = dp(ui, 4);
		g.color = col(ui, t.surfaceVariant);
		Draw.fillRoundRect(g, tx, cy - trackH / 2, tw, trackH, trackH / 2);
		g.color = col(ui, t.primary);
		Draw.fillRoundRect(g, tx, cy - trackH / 2, tw * p, trackH, trackH / 2);
		if (step > 0 && (to - from) / step <= 20) { // Tick marks
			var n = Std.int(Math.round((to - from) / step));
			for (i in 0...n + 1) {
				var px = tx + tw * i / n;
				g.color = col(ui, px <= tx + tw * p ? t.onPrimary : t.outline);
				Draw.fillCircle(g, px, cy, dp(ui, 1.5));
			}
		}
		var kx = tx + tw * p;
		if (dragging) {
			g.color = Draw.alpha(t.primary, 0.16);
			Draw.fillCircle(g, kx, cy, dp(ui, 20));
			if (text == null && showValue) { // Value bubble while dragging
				var vs = formatFixed(handle.value, precision);
				var bw = Math.max(dp(ui, 36), Draw.width(ui.ops.font, size, vs) + dp(ui, 16));
				var bh = dp(ui, 26);
				g.color = t.inverseSurface;
				Draw.fillRoundRect(g, kx - bw / 2, cy - dp(ui, 26) - bh, bw, bh, bh / 2);
				Draw.textMid(ui, g, vs, kx, cy - dp(ui, 26) - bh / 2, size, t.onInverseSurface, 1);
			}
		}
		g.color = col(ui, t.primary);
		Draw.fillCircle(g, kx, cy, dp(ui, dragging ? 12 : 10));
		ui.endElement(h);
		return handle.value;
	}

	/** Progress bar. value < 0 draws an indeterminate (animated) bar. **/
	public static function progress(ui: Zui, value: Float, text: String = null) {
		var labelH = text != null ? dp(ui, 22) : 0;
		var h = labelH + dp(ui, 20);
		if (!ui.isVisible(h)) {
			ui.endElement(h);
			return;
		}
		var t = Mobile.theme;
		var g = ui.g;
		var pad = ui.TEXT_OFFSET();
		var x = ui._x + pad;
		var w = ui._w - pad * 2;
		var size = sp(ui, 14);
		if (text != null) {
			Draw.text(ui, g, text, x, ui._y + dp(ui, 2), size, t.onSurfaceVariant);
			if (value >= 0) Draw.text(ui, g, Std.int(value * 100) + "%", x + w, ui._y + dp(ui, 2), size, t.onSurfaceVariant, 2);
		}
		var bh = dp(ui, 6);
		var y = ui._y + labelH + (dp(ui, 20) - bh) / 2;
		g.color = col(ui, t.surfaceVariant);
		Draw.fillRoundRect(g, x, y, w, bh, bh / 2);
		g.color = col(ui, t.primary);
		if (value >= 0) {
			var v = value > 1 ? 1 : value;
			if (v > 0) Draw.fillRoundRect(g, x, y, Math.max(bh, w * v), bh, bh / 2);
		}
		else {
			var tm = kha.Scheduler.realTime();
			var phase = (tm * 0.8) % 1.0;
			var segW = w * 0.35;
			var sx = x - segW + (w + segW) * phase;
			var s0 = Math.max(x, sx);
			var s1 = Math.min(x + w, sx + segW);
			if (s1 > s0) Draw.fillRoundRect(g, s0, y, s1 - s0, bh, bh / 2);
			animate(ui);
		}
		ui.endElement(h);
	}

	/** Activity indicator (spinning dots). **/
	public static function spinner(ui: Zui, size = 32.0) {
		var h = Math.max(ui.ELEMENT_H(), dp(ui, size + 8));
		if (!ui.isVisible(h)) {
			ui.endElement(h);
			return;
		}
		var t = Mobile.theme;
		var g = ui.g;
		var cx = ui._x + ui._w / 2;
		var cy = ui._y + h / 2;
		var r = dp(ui, size) / 2;
		var n = 12;
		var head = Std.int(kha.Scheduler.realTime() * 12) % n;
		for (i in 0...n) {
			var a = i / n * Math.PI * 2 - Math.PI / 2;
			var age = (head - i + n) % n;
			g.color = Draw.alpha(t.primary, 1 - age / n * 0.85);
			Draw.fillCircle(g, cx + Math.cos(a) * r * 0.75, cy + Math.sin(a) * r * 0.75, r * 0.13);
		}
		animate(ui);
		ui.endElement(h);
	}

	/** Small colored section title for grouping list items. **/
	public static function sectionHeader(ui: Zui, text: String) {
		var h = dp(ui, 40);
		if (!ui.isVisible(h)) {
			ui.endElement(h);
			return;
		}
		var t = Mobile.theme;
		Draw.text(ui, ui.g, text, ui._x + ui.TEXT_OFFSET(), ui._y + dp(ui, 18), sp(ui, 13), t.primary);
		ui.endElement(h);
	}

	/** Plain text that wraps to the element width. **/
	public static function paragraph(ui: Zui, text: String, size = 15.0, color: Null<Int> = null) {
		var font = ui.ops.font;
		var fs = sp(ui, size);
		var pad = ui.TEXT_OFFSET();
		var lines = Draw.wrap(font, fs, text, ui._w - pad * 2);
		var lh = font.height(fs) * 1.35;
		var h = lines.length * lh + dp(ui, 8);
		if (ui.isVisible(h)) {
			var c = color == null ? Mobile.theme.onSurfaceVariant : color;
			for (i in 0...lines.length) Draw.text(ui, ui.g, lines[i], ui._x + pad, ui._y + dp(ui, 4) + i * lh, fs, c);
		}
		ui.endElement(h);
	}

	/**
		List row with optional leading icon, subtitle and trailing text / chevron.
		Returns true when tapped.
	**/
	public static function listItem(ui: Zui, title: String, subtitle: String = null, icon: String = null, trailing: String = null,
			chevron = true, iconColor: Null<Int> = null, divider = true): Bool {
		var h = dp(ui, subtitle != null ? 72 : 56);
		if (!ui.isVisible(h)) {
			ui.endElement(h);
			return false;
		}
		var t = Mobile.theme;
		var g = ui.g;
		var released = tapped(ui, ui._x, ui._y, ui._w, h);
		if (released) ui.changed = true;
		if (pressed(ui, ui._x, ui._y, ui._w, h)) {
			g.color = Draw.alpha(t.onSurface, 0.08);
			g.fillRect(ui._x, ui._y, ui._w, h);
		}
		var pad = dp(ui, 16);
		var x = ui._x + pad;
		var cy = ui._y + h / 2;
		if (icon != null) {
			var r = dp(ui, 20);
			var bg = iconColor != null ? iconColor : t.primaryContainer;
			g.color = col(ui, bg);
			Draw.fillCircle(g, x + r, cy, r);
			Draw.icon(ui, g, icon, x + r, cy, sp(ui, 22), col(ui, iconColor != null ? 0xffffffff : t.onPrimaryContainer));
			x += r * 2 + pad;
		}
		var right = ui._x + ui._w - pad;
		if (chevron) {
			Draw.icon(ui, g, Icons.CHEVRON_RIGHT, right - dp(ui, 10), cy, sp(ui, 22), col(ui, t.onSurfaceVariant));
			right -= dp(ui, 28);
		}
		var font = ui.ops.font;
		if (trailing != null) {
			var ts = sp(ui, 14);
			var tw = Math.min(Draw.width(font, ts, trailing), (right - x) * 0.45);
			Draw.textMid(ui, g, Draw.fit(font, ts, trailing, tw + 1), right, cy, ts, t.onSurfaceVariant, 2);
			right -= tw + dp(ui, 12);
		}
		var size = sp(ui, 16);
		if (subtitle != null) {
			var ss = sp(ui, 14);
			var total = font.height(size) + font.height(ss) + dp(ui, 2);
			var y0 = cy - total / 2;
			Draw.text(ui, g, Draw.fit(font, size, title, right - x), x, y0, size, t.onSurface);
			Draw.text(ui, g, Draw.fit(font, ss, subtitle, right - x), x, y0 + font.height(size) + dp(ui, 2), ss, t.onSurfaceVariant);
		}
		else Draw.textMid(ui, g, Draw.fit(font, size, title, right - x), x, cy, size, t.onSurface);
		if (divider) {
			g.color = t.divider;
			g.fillRect(x, ui._y + h - Math.max(1, dp(ui, 0.5)), ui._x + ui._w - x, Math.max(1, dp(ui, 0.5)));
		}
		ui.endElement(h);
		return released;
	}

	/**
		Chips that wrap onto several lines.
		Single choice: handle.position. Multiple choice: handle.nest(i).selected.
		Returns the tapped index or -1.
	**/
	public static function chips(ui: Zui, handle: Handle, items: Array<String>, multi = false): Int {
		var t = Mobile.theme;
		var font = ui.ops.font;
		var size = sp(ui, 14);
		var ch = dp(ui, 34);
		var gapX = dp(ui, 8);
		var gapY = dp(ui, 8);
		var padX = dp(ui, 14);
		// Selected chips get a leading check icon: 8dp | 18dp icon | 8dp | text | padX
		var iconPadL = dp(ui, 8);
		var iconSize = sp(ui, 18);
		var check = iconPadL + iconSize + dp(ui, 8) - padX;
		var left = ui._x + ui.TEXT_OFFSET();
		var maxX = ui._x + ui._w - ui.TEXT_OFFSET();
		// Layout pass
		var xs: Array<Float> = [];
		var ys: Array<Float> = [];
		var ws: Array<Float> = [];
		var cx = left;
		var cy = 0.0;
		for (i in 0...items.length) {
			var sel = multi ? handle.nest(i).selected : handle.position == i;
			var w = Draw.width(font, size, items[i]) + padX * 2 + (sel ? check : 0);
			if (cx + w > maxX && cx > left) {
				cx = left;
				cy += ch + gapY;
			}
			xs.push(cx);
			ys.push(cy);
			ws.push(w);
			cx += w + gapX;
		}
		var h = cy + ch + dp(ui, 8);
		var result = -1;
		if (ui.isVisible(h)) {
			var g = ui.g;
			handle.changed = false;
			for (i in 0...items.length) {
				var x = xs[i];
				var y = ui._y + dp(ui, 4) + ys[i];
				if (tapped(ui, x, y, ws[i], ch)) {
					result = i;
					if (multi) handle.nest(i).selected = !handle.nest(i).selected;
					else handle.position = i;
					handle.changed = ui.changed = true;
					animate(ui);
				}
				var sel = multi ? handle.nest(i).selected : handle.position == i;
				var down = pressed(ui, x, y, ws[i], ch);
				if (sel) {
					g.color = col(ui, down ? Draw.mix(t.primaryContainer, t.onPrimaryContainer, 0.14) : t.primaryContainer);
					Draw.fillRoundRect(g, x, y, ws[i], ch, dp(ui, 8));
					Draw.icon(ui, g, Icons.CHECK, x + iconPadL + iconSize / 2, y + ch / 2, iconSize, col(ui, t.onPrimaryContainer));
					Draw.textMid(ui, g, items[i], x + padX + check, y + ch / 2, size, t.onPrimaryContainer);
				}
				else {
					if (down) {
						g.color = Draw.alpha(t.onSurface, 0.08);
						Draw.fillRoundRect(g, x, y, ws[i], ch, dp(ui, 8));
					}
					g.color = col(ui, t.outline);
					Draw.strokeRoundRect(g, x, y, ws[i], ch, dp(ui, 8), Math.max(1, dp(ui, 1)));
					Draw.textMid(ui, g, items[i], x + padX, y + ch / 2, size, t.onSurfaceVariant);
				}
			}
		}
		ui.endElement(h);
		return result;
	}

	/** Dots showing the current page of a pager. **/
	public static function pageDots(ui: Zui, count: Int, index: Int) {
		var h = dp(ui, 20);
		if (ui.isVisible(h)) {
			var t = Mobile.theme;
			var g = ui.g;
			var gap = dp(ui, 14);
			var x0 = ui._x + ui._w / 2 - gap * (count - 1) / 2;
			for (i in 0...count) {
				g.color = i == index ? t.primary : t.outline;
				Draw.fillCircle(g, x0 + gap * i, ui._y + h / 2, dp(ui, i == index ? 4 : 3));
			}
		}
		ui.endElement(h);
	}

	// Text fields

	static function fieldText(ui: Zui, handle: Handle, x: Float, w: Float, liveUpdate: Bool): String {
		// Run Zui's textInput (editing, caret, keyboard) inside a custom frame
		var t = ui.t;
		var ac = t.ACCENT_COL;
		var ah = t.ACCENT_HOVER_COL;
		t.ACCENT_COL = t.ACCENT_HOVER_COL = 0x00000000;
		var ox = ui._x;
		var ow = ui._w;
		ui._x = x;
		ui._w = Std.int(w);
		var s = ui.textInput(handle, "", Left, true, liveUpdate);
		ui._x = ox;
		ui._w = ow;
		t.ACCENT_COL = ac;
		t.ACCENT_HOVER_COL = ah;
		return s;
	}

	/**
		Text field with a floating label above it and an optional leading icon.
		Tapping it opens the on-screen keyboard (see HtmlSoftKeyboard).
	**/
	public static function textField(ui: Zui, handle: Handle, label: String, placeholder: String = "", icon: String = null, liveUpdate = false): String {
		var t = Mobile.theme;
		var font = ui.ops.font;
		var labelH = label != null && label != "" ? dp(ui, 22) : 0;
		var eh = ui.ELEMENT_H();
		var editing = ui.textSelectedHandle == handle;
		var pad = ui.TEXT_OFFSET();
		if (labelH > 0 && ui.isVisible(labelH)) {
			Draw.text(ui, ui.g, label, ui._x + pad, ui._y + dp(ui, 2), sp(ui, 13), editing ? t.primary : t.onSurfaceVariant);
		}
		ui._y += labelH;
		if (!ui.isVisible(eh)) {
			ui.endElement();
			return handle.text;
		}
		var g = ui.g;
		var x = ui._x + pad;
		var w = ui._w - pad * 2;
		var y = ui._y + ui.buttonOffsetY;
		var h = ui.BUTTON_H() + dp(ui, 4);
		y -= dp(ui, 2);
		g.color = col(ui, t.surfaceVariant);
		Draw.fillRoundRect(g, x, y, w, h, dp(ui, 10));
		if (editing) {
			g.color = t.primary;
			Draw.strokeRoundRect(g, x, y, w, h, dp(ui, 10), dp(ui, 2));
		}
		var tx = x;
		if (icon != null) {
			Draw.icon(ui, g, icon, x + dp(ui, 20), y + h / 2, sp(ui, 20), col(ui, editing ? t.primary : t.onSurfaceVariant));
			tx += dp(ui, 32);
		}
		if (handle.text == "" && !editing && placeholder != "") {
			Draw.textMid(ui, g, Draw.fit(font, ui.fontSize, placeholder, w - (tx - x) - pad * 2), tx + ui.TEXT_OFFSET(), y + h / 2,
				ui.fontSize, Draw.alpha(t.onSurfaceVariant, 0.7));
		}
		return fieldText(ui, handle, tx, w - (tx - x), liveUpdate);
	}

	/** Rounded search field with a clear button. Updates handle.text while typing. **/
	public static function searchBar(ui: Zui, handle: Handle, placeholder = "検索"): String {
		var eh = ui.ELEMENT_H();
		if (!ui.isVisible(eh)) {
			ui.endElement();
			return handle.text;
		}
		var t = Mobile.theme;
		var g = ui.g;
		var font = ui.ops.font;
		var pad = ui.buttonOffsetY;
		var x = ui._x + ui.TEXT_OFFSET() * 0.5;
		var w = ui._w - ui.TEXT_OFFSET();
		var h = ui.BUTTON_H();
		var y = ui._y + pad;
		var editing = ui.textSelectedHandle == handle;
		var text = editing ? ui.textSelected : handle.text;
		g.color = col(ui, t.surfaceVariant);
		Draw.fillRoundRect(g, x, y, w, h, h / 2);
		Draw.icon(ui, g, Icons.SEARCH, x + dp(ui, 22), y + h / 2, sp(ui, 22), col(ui, t.onSurfaceVariant));
		var clearW = dp(ui, 40);
		var tx = x + dp(ui, 36);
		var tw = w - (tx - x) - clearW;
		if (text != "") {
			var cx = x + w - clearW / 2 - dp(ui, 4);
			if (pressed(ui, x + w - clearW, y, clearW, h)) {
				g.color = Draw.alpha(t.onSurface, 0.1);
				Draw.fillCircle(g, cx, y + h / 2, h / 2 - dp(ui, 2));
			}
			Draw.icon(ui, g, Icons.CLOSE, cx, y + h / 2, sp(ui, 20), col(ui, t.onSurfaceVariant));
			if (tapped(ui, x + w - clearW, y, clearW, h)) {
				handle.text = "";
				handle.changed = ui.changed = true;
				if (editing) {
					ui.setTextEdit("", 0, 0);
					if (Zui.softKeyboard != null) Zui.softKeyboard.show(ui, "", 0, 0, ui._windowX + tx, ui._windowY + ui._y, tw, eh);
				}
			}
		}
		else if (!editing) {
			Draw.textMid(ui, g, placeholder, tx + ui.TEXT_OFFSET(), y + h / 2, ui.fontSize, Draw.alpha(t.onSurfaceVariant, 0.8));
		}
		var before = handle.text;
		var s = fieldText(ui, handle, tx, tw, true);
		if (s != before) handle.changed = true;
		return s;
	}

	// Cards

	static var cardStack: Array<{handle: Handle, y: Float, x: Float, w: Int, pad: Float}> = [];

	/**
		Start a card: a rounded surface around the following elements. Close it with endCard().
		The card height is measured each redraw and stored in handle.value.
	**/
	public static function card(ui: Zui, handle: Handle, padding = 8.0) {
		var t = Mobile.theme;
		var g = ui.g;
		var m = dp(ui, 8); // Outer margin
		var x = ui._x + m;
		var w = ui._w - m * 2;
		if (handle.value > 0) {
			g.color = Draw.alpha(0xff000000, t.dark ? 0.3 : 0.06);
			Draw.fillRoundRect(g, x, ui._y + dp(ui, 1.5), w, handle.value, dp(ui, t.radius)); // Soft shadow
			g.color = t.surface;
			Draw.fillRoundRect(g, x, ui._y, w, handle.value, dp(ui, t.radius));
		}
		var pad = dp(ui, padding);
		cardStack.push({handle: handle, y: ui._y, x: ui._x, w: ui._w, pad: pad});
		ui._x = x + pad;
		ui._w = Std.int(w - pad * 2);
		ui._y += pad;
	}

	public static function endCard(ui: Zui) {
		var c = cardStack.pop();
		if (c == null) return;
		ui._y += c.pad;
		var h = ui._y - c.y;
		if (Math.abs(h - c.handle.value) > 0.5) {
			c.handle.value = h;
			animate(ui); // Draw the background again with the measured height
		}
		ui._x = c.x;
		ui._w = c.w;
		ui._y += dp(ui, 12);
	}

	/**
		Wheel picker (iOS style). Drag or flick to choose, tap a row to jump to it.
		Returns handle.position.
	**/
	public static function wheelPicker(ui: Zui, handle: Handle, items: Array<String>, rows = 5): Int {
		var itemH = dp(ui, 40);
		if (rows % 2 == 0) rows++;
		var h = itemH * rows;
		var st = handle.nest(0); // Scroll state: scrollOffset, scrollVelocity, selected = dragging
		if (!st.dragEnabled) { // First use: start at handle.position
			st.dragEnabled = true;
			st.scrollOffset = -handle.position * itemH;
		}
		if (!ui.isVisible(h)) {
			ui.endElement(h);
			return handle.position;
		}
		var t = Mobile.theme;
		var g = ui.g;
		var n = items.length;
		var minOff = -(n - 1) * itemH;
		var x = ui._x + ui.buttonOffsetY;
		var w = ui._w - ui.buttonOffsetY * 2;
		var top = ui._y;
		var mid = top + h / 2;
		handle.changed = false;
		var moving = false;

		if (started(ui, x, top, w, h)) {
			ui.scrollHandle = st;
			ui.isScrolling = true;
			st.selected = true;
			st.scrollVelocity = 0;
		}
		if (st.selected) {
			if (ui.scrollHandle == st) {
				st.scrollOffset += ui.inputDY;
				st.scrollVelocity = st.scrollVelocity * 0.4 + ui.inputDY * 0.6;
				moving = true;
			}
			else { // Released
				st.selected = false;
				if (ui.inputReleased && !ui.touchDragging) { // Tap on a row
					var rowOff = Math.round((ui.inputY - ui._windowY - mid) / itemH);
					var target = Math.round(-st.scrollOffset / itemH) + rowOff;
					target = target < 0 ? 0 : target > n - 1 ? n - 1 : target;
					st.scrollOffset = -target * itemH + 0.01; // Snap animation takes it from here
					st.scrollVelocity = 0;
				}
				moving = true;
			}
		}
		else if (st.scrollVelocity != 0) {
			st.scrollOffset += st.scrollVelocity;
			st.scrollVelocity *= 0.92;
			if (Math.abs(st.scrollVelocity) < dp(ui, 0.6)) st.scrollVelocity = 0;
			moving = true;
		}
		else { // Snap to the nearest row
			var target = Math.round(st.scrollOffset / itemH) * itemH;
			var d = target - st.scrollOffset;
			if (Math.abs(d) > 0.5) {
				st.scrollOffset += d * 0.35;
				moving = true;
			}
			else st.scrollOffset = target;
		}
		if (st.scrollOffset > 0) {
			st.scrollOffset = 0;
			st.scrollVelocity = 0;
		}
		else if (st.scrollOffset < minOff) {
			st.scrollOffset = minOff;
			st.scrollVelocity = 0;
		}
		var pos = Std.int(Math.round(-st.scrollOffset / itemH));
		pos = pos < 0 ? 0 : pos > n - 1 ? n - 1 : pos;
		if (pos != handle.position) {
			handle.position = pos;
			handle.changed = ui.changed = true;
		}
		if (moving) animate(ui);

		// Selection band
		g.color = col(ui, t.surfaceVariant);
		Draw.fillRoundRect(g, x, mid - itemH / 2, w, itemH, dp(ui, 10));
		var font = ui.ops.font;
		var size = sp(ui, 18);
		var maxD = h / 2 - itemH / 2;
		var first = Std.int(Math.max(0, Math.floor((-st.scrollOffset - maxD) / itemH)));
		var last = Std.int(Math.min(n - 1, Math.ceil((-st.scrollOffset + maxD) / itemH)));
		for (i in first...last + 1) {
			var cy = mid + st.scrollOffset + i * itemH;
			var d = Math.abs(cy - mid);
			if (d > maxD + 0.5) continue;
			var k = 1 - d / (maxD + itemH);
			var c = Draw.mix(t.onSurfaceVariant, t.onSurface, d < itemH / 2 ? 1 - d / (itemH / 2) : 0);
			// One font size only: every size gets its own glyph atlas
			Draw.textMid(ui, g, Draw.fit(font, size, items[i], w - dp(ui, 8)), x + w / 2, cy, size, Draw.alpha(c, 0.25 + 0.75 * k), 1);
		}
		ui.endElement(h);
		return handle.position;
	}
}
