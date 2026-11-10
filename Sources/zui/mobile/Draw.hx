package zui.mobile;

import kha.Font;
import kha.graphics2.Graphics;

/**
	Drawing helpers for the mobile widgets: rounded shapes, circles, text and icons.
	All coordinates and sizes are in pixels.
**/
@:access(zui.Zui)
class Draw {

	static inline var PI = 3.141592653589793;

	public static function fillRoundRect(g: Graphics, x: Float, y: Float, w: Float, h: Float, r: Float) {
		if (w <= 0 || h <= 0) return;
		if (r * 2 > h) r = h / 2;
		if (r * 2 > w) r = w / 2;
		if (r < 0.5) {
			g.fillRect(x, y, w, h);
			return;
		}
		g.fillRect(x + r, y, w - r * 2, h);
		g.fillRect(x, y + r, r, h - r * 2);
		g.fillRect(x + w - r, y + r, r, h - r * 2);
		fillCorner(g, x + r, y + r, r, PI, PI * 1.5);
		fillCorner(g, x + w - r, y + r, r, PI * 1.5, PI * 2);
		fillCorner(g, x + w - r, y + h - r, r, 0, PI * 0.5);
		fillCorner(g, x + r, y + h - r, r, PI * 0.5, PI);
	}

	/** Rounded rect with only the top corners rounded (sheets). **/
	public static function fillTopRoundRect(g: Graphics, x: Float, y: Float, w: Float, h: Float, r: Float) {
		if (r * 2 > w) r = w / 2;
		if (r > h) r = h;
		g.fillRect(x + r, y, w - r * 2, r);
		g.fillRect(x, y + r, w, h - r);
		fillCorner(g, x + r, y + r, r, PI, PI * 1.5);
		fillCorner(g, x + w - r, y + r, r, PI * 1.5, PI * 2);
	}

	public static function strokeRoundRect(g: Graphics, x: Float, y: Float, w: Float, h: Float, r: Float, strength: Float) {
		if (r * 2 > h) r = h / 2;
		if (r * 2 > w) r = w / 2;
		var s2 = strength / 2;
		x += s2; y += s2; w -= strength; h -= strength; r -= s2;
		if (r < 0) r = 0;
		g.drawLine(x + r, y, x + w - r, y, strength);
		g.drawLine(x + r, y + h, x + w - r, y + h, strength);
		g.drawLine(x, y + r, x, y + h - r, strength);
		g.drawLine(x + w, y + r, x + w, y + h - r, strength);
		if (r > 0) {
			strokeArc(g, x + r, y + r, r, PI, PI * 1.5, strength);
			strokeArc(g, x + w - r, y + r, r, PI * 1.5, PI * 2, strength);
			strokeArc(g, x + w - r, y + h - r, r, 0, PI * 0.5, strength);
			strokeArc(g, x + r, y + h - r, r, PI * 0.5, PI, strength);
		}
	}

	public static function fillCircle(g: Graphics, cx: Float, cy: Float, r: Float) {
		if (r <= 0) return;
		fillCorner(g, cx, cy, r, 0, PI * 2);
	}

	public static function strokeCircle(g: Graphics, cx: Float, cy: Float, r: Float, strength: Float) {
		strokeArc(g, cx, cy, r, 0, PI * 2, strength);
	}

	public static function strokeArc(g: Graphics, cx: Float, cy: Float, r: Float, a0: Float, a1: Float, strength: Float) {
		var n = segments(r, a1 - a0);
		var px = cx + Math.cos(a0) * r;
		var py = cy + Math.sin(a0) * r;
		for (i in 1...n + 1) {
			var a = a0 + (a1 - a0) * i / n;
			var nx = cx + Math.cos(a) * r;
			var ny = cy + Math.sin(a) * r;
			g.drawLine(px, py, nx, ny, strength);
			px = nx;
			py = ny;
		}
	}

	static function fillCorner(g: Graphics, cx: Float, cy: Float, r: Float, a0: Float, a1: Float) {
		var n = segments(r, a1 - a0);
		var px = cx + Math.cos(a0) * r;
		var py = cy + Math.sin(a0) * r;
		for (i in 1...n + 1) {
			var a = a0 + (a1 - a0) * i / n;
			var nx = cx + Math.cos(a) * r;
			var ny = cy + Math.sin(a) * r;
			g.fillTriangle(cx, cy, px, py, nx, ny);
			px = nx;
			py = ny;
		}
	}

	static inline function segments(r: Float, angle: Float): Int {
		var n = Std.int(Math.abs(angle) * Math.sqrt(r) * 0.9);
		return n < 3 ? 3 : n > 64 ? 64 : n;
	}

	/** Linear blend between two ARGB colors. **/
	public static function mix(a: Int, b: Int, t: Float): Int {
		if (t <= 0) return a;
		if (t >= 1) return b;
		inline function ch(c: Int, s: Int) return (c >>> s) & 0xff;
		inline function lerp(s: Int) return Std.int(ch(a, s) + (ch(b, s) - ch(a, s)) * t) & 0xff;
		return (lerp(24) << 24) | (lerp(16) << 16) | (lerp(8) << 8) | lerp(0);
	}

	/** Multiply the alpha of an ARGB color. **/
	public static function alpha(c: Int, a: Float): Int {
		var ca = (c >>> 24) & 0xff;
		var na = Std.int(ca * (a < 0 ? 0 : a > 1 ? 1 : a));
		return (na << 24) | (c & 0xffffff);
	}

	/** Register glyphs so the font atlas contains them (needed for non ASCII text and icons). **/
	public static function registerGlyphs(text: String) {
		var added = false;
		for (i in 0...text.length) {
			var c = text.charCodeAt(i);
			if (c > 126 && Graphics.fontGlyphs.indexOf(c) == -1) {
				if (!added) Graphics.fontGlyphs = Graphics.fontGlyphs.copy(); // New array triggers an atlas rebuild
				Graphics.fontGlyphs.push(c);
				added = true;
			}
		}
		if (added) Graphics.fontGlyphs.sort(function(a, b) return a - b);
	}

	/**
		Text width in pixels. Registers the glyphs first: Kha measures with the current font atlas,
		so characters that are not in it yet (CJK, icons) would be measured wrong on the first frame.
	**/
	public static function width(font: Font, size: Int, s: String): Float {
		if (s == null || s == "") return 0;
		if (Zui.dynamicGlyphLoad) registerGlyphs(s);
		return font.width(size, s);
	}

	/**
		Draw text with its top-left at x, y (align 0 = left, 1 = center on x, 2 = right ending at x).
		Uses the Zui text pipeline so text renders correctly into window textures.
	**/
	public static function text(ui: Zui, g: Graphics, s: String, x: Float, y: Float, size: Int, color: Int, align = 0, font: Font = null) {
		if (s == null || s == "") return;
		if (font == null) font = ui.ops.font;
		if (Zui.dynamicGlyphLoad) registerGlyphs(s);
		if (align == 1) x -= width(font, size, s) / 2;
		else if (align == 2) x -= width(font, size, s);
		g.font = font;
		g.fontSize = size;
		g.color = ui.enabled ? color : alpha(color, 0.38);
		g.pipeline = ui.rtTextPipeline;
		g.drawString(s, x, y);
		g.pipeline = null;
	}

	/** Same as text() but vertically centered on cy. **/
	public static function textMid(ui: Zui, g: Graphics, s: String, x: Float, cy: Float, size: Int, color: Int, align = 0, font: Font = null) {
		if (font == null) font = ui.ops.font;
		text(ui, g, s, x, cy - font.height(size) / 2, size, color, align, font);
	}

	/** Draw an icon (see Icons) centered on cx, cy. Does nothing without Mobile.iconFont. **/
	public static function icon(ui: Zui, g: Graphics, icon: String, cx: Float, cy: Float, size: Int, color: Int) {
		var font = Mobile.iconFont;
		if (font == null || icon == null || icon == "") return;
		text(ui, g, icon, cx - width(font, size, icon) / 2, cy - font.height(size) / 2, size, color, 0, font);
	}

	/** Shorten text with an ellipsis so it fits into maxW. **/
	public static function fit(font: Font, size: Int, s: String, maxW: Float): String {
		if (s == null || width(font, size, s) <= maxW) return s;
		var end = s.length;
		while (end > 0 && width(font, size, s.substr(0, end) + "…") > maxW) end--;
		return s.substr(0, end) + "…";
	}

	/**
		Break text into lines no wider than maxW.
		Latin words are kept together, CJK text may break between any two characters.
	**/
	public static function wrap(font: Font, size: Int, s: String, maxW: Float): Array<String> {
		var lines: Array<String> = [];
		for (para in s.split("\n")) {
			var line = "";
			var i = 0;
			while (i < para.length) {
				// Take one token: a run of Latin letters/digits, or a single other character
				var j = i + 1;
				if (isWordChar(para.charCodeAt(i))) while (j < para.length && isWordChar(para.charCodeAt(j))) j++;
				var token = para.substring(i, j);
				if (line != "" && width(font, size, line + token) > maxW) {
					lines.push(StringTools.rtrim(line));
					line = token == " " ? "" : token;
				}
				else line += token;
				i = j;
			}
			lines.push(line);
		}
		return lines;
	}

	static inline function isWordChar(c: Int): Bool {
		return (c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 39 || c == 45;
	}
}
