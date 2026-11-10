package zui.mobile;

import kha.graphics2.Graphics;
import zui.Zui;
import zui.mobile.MobileTheme;

typedef MobileOptions = {
	?theme: MobileTheme,
	?iconFont: kha.Font,
	?userScale: Float, // Extra UI scale on top of the device pixel ratio
	?softKeyboard: Bool, // HTML5: hidden <input> for on-screen keyboard / IME (default true)
	?fitCanvas: Bool, // HTML5: keep the canvas at full window size and device resolution (default true)
}

typedef TabItem = {
	var icon: String;
	var label: String;
	@:optional var badge: Int; // > 0 shows a counter, -1 shows a dot
}

/**
	Mobile setup and screen layout for Zui.

	```haxe
	Mobile.init(ui, {iconFont: Assets.fonts.icons});
	// In render():
	Mobile.begin(ui, g);
	Mobile.appBar(ui, "Title");
	var tab = Mobile.tabBar(ui, hTabs, items);
	if (Mobile.content(ui, hContent)) { ... Widgets / Zui elements ... }
	Mobile.end(ui);
	```

	Layout: appBar() and tabBar() take space from the top and bottom of the screen
	(including safe area insets), content() fills the rest with a touch scrolling window.
**/
@:access(zui.Zui)
class Mobile {

	public static var theme(default, null): MobileTheme;
	public static var iconFont: kha.Font = null;
	public static var dpr(default, null) = 1.0; // Device pixel ratio
	public static var userScale(default, null) = 1.0;
	public static var safeTop(default, null) = 0.0; // Safe area insets in pixels (notch, home indicator)
	public static var safeBottom(default, null) = 0.0;
	public static var safeLeft(default, null) = 0.0;
	public static var safeRight(default, null) = 0.0;
	public static var screenW(default, null) = 0;
	public static var screenH(default, null) = 0;
	public static var frame(default, null) = 0;

	// Free area of the current frame, shrinks with appBar() / tabBar()
	public static var areaTop(default, null) = 0.0;
	public static var areaBottom(default, null) = 0.0;

	static var globalG: Graphics;
	static var modalBlocked = false;
	static var redrawAll = 0;

	public static function init(ui: Zui, options: MobileOptions = null) {
		if (options == null) options = {};
		if (options.iconFont != null) iconFont = options.iconFont;
		if (options.userScale != null) userScale = options.userScale;
		Zui.touchScroll = true;
		Zui.touchHold = false;
		ui.highlightOnSelect = false; // Place the caret where the finger taps
		ui.tabSwitchEnabled = false;
		#if kha_html5
		initHtml5(options);
		#elseif (kha_android || kha_ios)
		Zui.touchInput = true;
		dpr = kha.System.screenDpi() / 160;
		if (dpr < 1) dpr = 1;
		#end
		setTheme(ui, options.theme != null ? options.theme : MobileThemes.light);
		if (iconFont != null) Draw.registerGlyphs(Icons.all());
	}

	public static function setTheme(ui: Zui, t: MobileTheme) {
		theme = t;
		ui.t = t.zui;
		ui.ops.theme = t.zui;
		ui.setScale(dpr * userScale); // Rebakes elements with the new colors
		requestRedraw();
	}

	public static function setUserScale(ui: Zui, s: Float) {
		userScale = s;
		ui.setScale(dpr * userScale);
		requestRedraw();
	}

	/** Redraw every cached window on the next frames (after theme or scale changes). **/
	public static function requestRedraw() {
		redrawAll = 2;
	}

	public static inline function dp(ui: Zui, v: Float): Float {
		return v * ui.SCALE();
	}

	/** Font size in pixels for a size in dp. **/
	public static inline function sp(ui: Zui, v: Float): Int {
		return Std.int(v * ui.SCALE());
	}

	#if kha_html5
	static function initHtml5(options: MobileOptions) {
		var win = js.Browser.window;
		var doc = js.Browser.document;
		var canvas = kha.SystemImpl.khanvas;

		var coarse = win.matchMedia("(pointer: coarse)").matches;
		Zui.touchInput = coarse;
		// Pointer events arrive before the touch/mouse events Kha turns into Zui input
		win.addEventListener("pointerdown", function(e: js.html.PointerEvent) Zui.touchInput = e.pointerType != "mouse", true);
		win.addEventListener("touchstart", function(_) Zui.touchInput = true, {capture: true, passive: true});
		win.addEventListener("pointermove", function(e: js.html.PointerEvent) {
			if (e.pointerType == "mouse" && Zui.touchInput && e.buttons == 0) Zui.touchInput = false;
		}, true);

		if (options.fitCanvas != false) {
			var meta: js.html.MetaElement = cast doc.querySelector("meta[name=viewport]");
			if (meta == null) {
				meta = cast doc.createElement("meta");
				meta.name = "viewport";
				doc.head.appendChild(meta);
			}
			meta.content = "width=device-width, initial-scale=1, maximum-scale=1, minimum-scale=1, user-scalable=no, viewport-fit=cover";
			var bs = doc.body.style;
			bs.margin = "0";
			bs.overflow = "hidden";
			bs.setProperty("overscroll-behavior", "none");
			bs.setProperty("-webkit-user-select", "none");
			bs.setProperty("user-select", "none");
			bs.setProperty("-webkit-touch-callout", "none");
			bs.setProperty("-webkit-tap-highlight-color", "transparent");
			var cs = canvas.style;
			cs.position = "fixed";
			cs.left = "0px";
			cs.top = "0px";
			cs.setProperty("touch-action", "none");
			cs.outline = "none";
			win.addEventListener("resize", fitCanvas);
			win.addEventListener("orientationchange", fitCanvas);
			var vv: Dynamic = untyped win.visualViewport;
			if (vv != null) vv.addEventListener("resize", fitCanvas);
			fitCanvas();
		}
		else {
			dpr = win.devicePixelRatio;
		}

		if (options.softKeyboard != false) Zui.softKeyboard = new HtmlSoftKeyboard();
	}

	static var safeProbe: js.html.DivElement = null;

	static function fitCanvas() {
		var win = js.Browser.window;
		var canvas = kha.SystemImpl.khanvas;
		var newDpr = win.devicePixelRatio;
		var w = win.innerWidth;
		var h = win.innerHeight;
		#if kha_html5_disable_automatic_size_adjust
		canvas.width = Math.round(w * newDpr);
		canvas.height = Math.round(h * newDpr);
		canvas.style.width = w + "px";
		canvas.style.height = h + "px";
		#else
		// Kha resizes the backbuffer to the css size and then divides the css size by devicePixelRatio
		canvas.style.width = Math.round(w * newDpr) + "px";
		canvas.style.height = Math.round(h * newDpr) + "px";
		#end

		if (safeProbe == null) {
			safeProbe = cast js.Browser.document.createElement("div");
			var s = safeProbe.style;
			s.position = "fixed";
			s.visibility = "hidden";
			s.pointerEvents = "none";
			s.setProperty("padding", "env(safe-area-inset-top) env(safe-area-inset-right) env(safe-area-inset-bottom) env(safe-area-inset-left)");
			js.Browser.document.body.appendChild(safeProbe);
		}
		var cs = win.getComputedStyle(safeProbe);
		safeTop = parse(cs.paddingTop) * newDpr;
		safeRight = parse(cs.paddingRight) * newDpr;
		safeBottom = parse(cs.paddingBottom) * newDpr;
		safeLeft = parse(cs.paddingLeft) * newDpr;

		if (newDpr != dpr) {
			dpr = newDpr;
			if (Zui.current != null) Zui.current.setScale(dpr * userScale);
		}
		requestRedraw();
	}

	static function parse(v: String): Float {
		var f = Std.parseFloat(v);
		return Math.isNaN(f) ? 0 : f;
	}
	#end

	/** Start a frame: clears the screen and begins Zui. **/
	public static function begin(ui: Zui, g: Graphics) {
		frame++;
		globalG = g;
		screenW = kha.System.windowWidth();
		screenH = kha.System.windowHeight();
		areaTop = safeTop;
		areaBottom = screenH - safeBottom;
		g.begin(true, theme.background);
		g.end();
		ui.alwaysRedraw = redrawAll > 0;
		if (redrawAll > 0) redrawAll--;
		ui.begin(g);
		// Modal overlays swallow input meant for the screen below
		modalBlocked = Overlay.isModal();
		if (modalBlocked) ui.inputEnabled = false;
	}

	/** End a frame: draws overlays (dialogs, sheets, toasts) and ends Zui. **/
	public static function end(ui: Zui) {
		if (!ui.windowEnded) ui.endWindow();
		if (modalBlocked) ui.inputEnabled = ui.comboSelectedHandle == null;
		globalG.begin(false);
		Overlay.draw(ui, globalG);
		globalG.end();
		ui.alwaysRedraw = false;
		ui.end();
	}

	// Run immediate drawing on the screen (outside of windows) at x, y with width w
	static function beginScreen(ui: Zui, x: Float, y: Float, w: Float): Graphics {
		if (!ui.windowEnded) ui.endWindow();
		globalG.begin(false);
		ui.beginRegion(globalG, Std.int(x), Std.int(y), Std.int(w));
		return globalG;
	}

	static function endScreen(ui: Zui) {
		ui.endRegion(false);
		globalG.end();
	}

	/**
		Top app bar. leading / actions are icons (see Icons).
		Returns 0 when the leading icon was tapped, 1.. for actions, -1 otherwise.
	**/
	public static function appBar(ui: Zui, title: String, leading: String = null, actions: Array<String> = null, subtitle: String = null): Int {
		var h = dp(ui, 56);
		var y = areaTop;
		var g = beginScreen(ui, 0, y, screenW);
		var t = theme;
		g.color = t.appBar;
		g.fillRect(0, 0, screenW, y + h);
		g.color = t.divider;
		g.fillRect(0, y + h - Math.max(1, dp(ui, 0.5)), screenW, Math.max(1, dp(ui, 0.5)));

		var result = -1;
		var btn = dp(ui, 48);
		var x = safeLeft + dp(ui, 4);
		var cy = y + h / 2;
		if (leading != null) {
			if (iconButton(ui, g, leading, x, y + (h - btn) / 2, btn, t.onAppBar)) result = 0;
			x += btn + dp(ui, 4);
		}
		else x += dp(ui, 12);

		var right = screenW - safeRight - dp(ui, 4);
		if (actions != null) {
			var i = actions.length;
			while (--i >= 0) {
				right -= btn;
				if (iconButton(ui, g, actions[i], right, y + (h - btn) / 2, btn, t.onAppBar)) result = i + 1;
			}
		}

		var font = ui.ops.font;
		var size = sp(ui, 20);
		if (subtitle != null) {
			var ss = sp(ui, 13);
			var th = font.height(size) + font.height(ss);
			var ty = cy - th / 2;
			Draw.text(ui, g, Draw.fit(font, size, title, right - x), x, ty, size, t.onAppBar);
			Draw.text(ui, g, Draw.fit(font, ss, subtitle, right - x), x, ty + font.height(size), ss, t.onSurfaceVariant);
		}
		else Draw.textMid(ui, g, Draw.fit(font, size, title, right - x), x, cy, size, t.onAppBar);

		endScreen(ui);
		areaTop = y + h;
		return result;
	}

	/** Bottom navigation bar. Returns the selected index (handle.position), handle.changed is set on taps. **/
	public static function tabBar(ui: Zui, handle: Handle, items: Array<TabItem>): Int {
		var h = dp(ui, 64);
		var y = areaBottom - h;
		var g = beginScreen(ui, 0, y, screenW);
		var t = theme;
		g.color = t.tabBar;
		g.fillRect(0, y, screenW, screenH - y);
		g.color = t.divider;
		g.fillRect(0, y, screenW, Math.max(1, dp(ui, 0.5)));

		handle.changed = false;
		var left = safeLeft;
		var w = (screenW - safeLeft - safeRight) / items.length;
		var font = ui.ops.font;
		var labelSize = sp(ui, 12);
		for (i in 0...items.length) {
			var it = items[i];
			var x = left + w * i;
			if (tapped(ui, x, y, w, h) && handle.position != i) {
				handle.position = i;
				handle.changed = ui.changed = true;
			}
			var selected = handle.position == i;
			var cx = x + w / 2;
			var iconCy = y + dp(ui, 22);
			var pillW = dp(ui, 56);
			var pillH = dp(ui, 30);
			if (selected || pressed(ui, x, y, w, h)) {
				g.color = selected ? t.primaryContainer : Draw.alpha(t.onSurface, 0.08);
				Draw.fillRoundRect(g, cx - pillW / 2, iconCy - pillH / 2, pillW, pillH, pillH / 2);
			}
			var col = selected ? t.onPrimaryContainer : t.onSurfaceVariant;
			Draw.icon(ui, g, it.icon, cx, iconCy, sp(ui, 22), col);
			Draw.text(ui, g, Draw.fit(font, labelSize, it.label, w - dp(ui, 4)), cx, y + dp(ui, 42), labelSize,
				selected ? t.onSurface : t.onSurfaceVariant, 1);
			if (it.badge != null && it.badge != 0) {
				var bx = cx + dp(ui, 10);
				var by = iconCy - dp(ui, 10);
				g.color = t.error;
				if (it.badge < 0) Draw.fillCircle(g, bx + dp(ui, 3), by + dp(ui, 2), dp(ui, 4));
				else {
					var s = it.badge > 99 ? "99+" : "" + it.badge;
					var bs = sp(ui, 11);
					var bw = Math.max(dp(ui, 16), Draw.width(font, bs, s) + dp(ui, 8));
					Draw.fillRoundRect(g, bx, by - dp(ui, 6), bw, dp(ui, 16), dp(ui, 8));
					Draw.textMid(ui, g, s, bx + bw / 2, by + dp(ui, 2), bs, 0xffffffff, 1);
				}
			}
		}
		endScreen(ui);
		areaBottom = y;
		return handle.position;
	}

	/**
		Scrolling content window filling the space left by appBar() / tabBar().
		Returns true if the window needs to be redrawn (like Zui.window()).
	**/
	public static function content(ui: Zui, handle: Handle): Bool {
		var x = Std.int(safeLeft);
		var y = Std.int(areaTop);
		var w = Std.int(screenW - safeLeft - safeRight);
		var h = Std.int(areaBottom - areaTop);
		return ui.window(handle, x, y, w, h);
	}

	/** Floating action button above the bottom of the free area. Draw it after content(). **/
	public static function fab(ui: Zui, icon: String, label: String = null): Bool {
		var t = theme;
		var font = ui.ops.font;
		var size = sp(ui, 15);
		var h = dp(ui, 56);
		var w = label == null ? h : dp(ui, 16 + 24 + 8 + 20) + Draw.width(font, size, label);
		var x = screenW - safeRight - dp(ui, 16) - w;
		var y = areaBottom - dp(ui, 16) - h;
		var g = beginScreen(ui, x, y, w);
		var down = pressed(ui, x, y, w, h);
		g.color = Draw.alpha(0xff000000, 0.18);
		Draw.fillRoundRect(g, x, y + dp(ui, 3), w, h, dp(ui, 16)); // Shadow
		g.color = down ? Draw.mix(t.primaryContainer, t.onPrimaryContainer, 0.12) : t.primaryContainer;
		Draw.fillRoundRect(g, x, y, w, h, dp(ui, 16));
		if (label == null) Draw.icon(ui, g, icon, x + w / 2, y + h / 2, sp(ui, 24), t.onPrimaryContainer);
		else {
			Draw.icon(ui, g, icon, x + dp(ui, 16 + 12), y + h / 2, sp(ui, 24), t.onPrimaryContainer);
			Draw.textMid(ui, g, label, x + dp(ui, 16 + 24 + 8), y + h / 2, size, t.onPrimaryContainer);
		}
		var r = tapped(ui, x, y, w, h);
		endScreen(ui);
		return r;
	}

	static function iconButton(ui: Zui, g: Graphics, icon: String, x: Float, y: Float, size: Float, color: Int): Bool {
		if (pressed(ui, x, y, size, size)) {
			g.color = Draw.alpha(color, 0.12);
			Draw.fillCircle(g, x + size / 2, y + size / 2, size / 2);
		}
		Draw.icon(ui, g, icon, x + size / 2, y + size / 2, sp(ui, 24), color);
		return tapped(ui, x, y, size, size);
	}

	// Screen space hit tests (outside of windows)

	static inline function inside(px: Float, py: Float, x: Float, y: Float, w: Float, h: Float): Bool {
		return px >= x && px < x + w && py >= y && py < y + h;
	}

	/** Finger lifted inside the rect after pressing inside it. **/
	public static function tapped(ui: Zui, x: Float, y: Float, w: Float, h: Float): Bool {
		return ui.enabled && ui.inputEnabled && ui.inputReleased && inside(ui.inputX, ui.inputY, x, y, w, h) &&
			inside(ui.inputStartedX, ui.inputStartedY, x, y, w, h);
	}

	/** Finger is down inside the rect and has not turned into a scroll. **/
	public static function pressed(ui: Zui, x: Float, y: Float, w: Float, h: Float): Bool {
		return ui.enabled && ui.inputEnabled && ui.inputDown && ui.touchScrollHandle == null && inside(ui.inputX, ui.inputY, x, y, w, h) &&
			inside(ui.inputStartedX, ui.inputStartedY, x, y, w, h);
	}
}
