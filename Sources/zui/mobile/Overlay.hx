package zui.mobile;

import kha.graphics2.Graphics;

private typedef Modal = {
	var kind: Int; // 0 = dialog, 1 = action sheet
	var title: String;
	var message: String;
	var buttons: Array<String>;
	var callback: Int->Void;
	var destructive: Int;
	var cancel: String;
	var openTime: Float;
	var openFrame: Int;
	var closeTime: Float; // < 0 while open
}

private typedef Toast = {
	var text: String;
	var icon: String;
	var start: Float;
	var duration: Float;
}

/**
	Modal dialogs, action sheets and toasts. They are drawn by Mobile.end() above everything else.
	While a dialog or sheet is open, the screen below does not receive input.
**/
@:access(zui.Zui)
class Overlay {

	static var modals: Array<Modal> = [];
	static var toasts: Array<Toast> = [];
	static inline var ANIM = 0.18;

	/** Alert dialog. callback receives the index of the tapped button. **/
	public static function alert(title: String, message: String, buttons: Array<String> = null, callback: Int->Void = null, destructive = -1) {
		if (buttons == null) buttons = ["OK"];
		modals.push({kind: 0, title: title, message: message, buttons: buttons, callback: callback, destructive: destructive,
			cancel: null, openTime: now(), openFrame: Mobile.frame, closeTime: -1});
	}

	/**
		Bottom action sheet. callback receives the option index, or -1 for cancel / tap outside.
		destructive marks one option in red.
	**/
	public static function actionSheet(title: String, options: Array<String>, callback: Int->Void = null, destructive = -1, cancel = "キャンセル") {
		modals.push({kind: 1, title: title, message: null, buttons: options, callback: callback, destructive: destructive,
			cancel: cancel, openTime: now(), openFrame: Mobile.frame, closeTime: -1});
	}

	/** Short message at the bottom of the screen. **/
	public static function toast(text: String, icon: String = null, seconds = 2.5) {
		toasts = [{text: text, icon: icon, start: now(), duration: seconds}]; // Newest replaces the current one
	}

	public static function isModal(): Bool {
		return modals.length > 0;
	}

	static inline function now(): Float {
		return kha.Scheduler.realTime();
	}

	static inline function dp(ui: Zui, v: Float): Float return v * ui.SCALE();
	static inline function sp(ui: Zui, v: Float): Int return Std.int(v * ui.SCALE());

	static inline function ease(p: Float): Float {
		p = p < 0 ? 0 : p > 1 ? 1 : p;
		return 1 - (1 - p) * (1 - p) * (1 - p);
	}

	static function close(m: Modal, index: Int) {
		if (m.closeTime >= 0) return;
		m.closeTime = now();
		if (m.callback != null) m.callback(index);
	}

	public static function draw(ui: Zui, g: Graphics) {
		var t = now();
		drawToasts(ui, g, t);
		if (modals.length == 0) return;
		var m = modals[modals.length - 1];
		var p = m.closeTime >= 0 ? 1 - (t - m.closeTime) / ANIM : (t - m.openTime) / ANIM;
		if (m.closeTime >= 0 && p <= 0) {
			modals.pop();
			return;
		}
		var k = ease(p);
		// Input belongs to the overlay only from the frame after it opened, and not while closing
		var input = Mobile.frame > m.openFrame && m.closeTime < 0;
		g.color = Draw.alpha(Mobile.theme.scrim, k);
		g.fillRect(0, 0, Mobile.screenW, Mobile.screenH);
		if (m.kind == 0) drawDialog(ui, g, m, k, input);
		else drawSheet(ui, g, m, k, input);
	}

	static function drawDialog(ui: Zui, g: Graphics, m: Modal, k: Float, input: Bool) {
		var th = Mobile.theme;
		var font = ui.ops.font;
		var sw = Mobile.screenW;
		var sh = Mobile.screenH;
		var w = Math.min(sw - dp(ui, 48), dp(ui, 340));
		var pad = dp(ui, 24);
		var titleSize = sp(ui, 20);
		var msgSize = sp(ui, 15);
		var lines = m.message != null ? Draw.wrap(font, msgSize, m.message, w - pad * 2) : [];
		var lh = font.height(msgSize) * 1.4;
		var btnH = dp(ui, 40);
		var h = pad + font.height(titleSize) + dp(ui, 12) + lines.length * lh + dp(ui, 20) + btnH + dp(ui, 16);
		var x = (sw - w) / 2;
		var y = (sh - h) / 2 + (1 - k) * dp(ui, 24);
		g.color = Draw.alpha(th.surface, k);
		Draw.fillRoundRect(g, x, y, w, h, dp(ui, 24));
		var cy = y + pad;
		Draw.text(ui, g, m.title, x + pad, cy, titleSize, Draw.alpha(th.onSurface, k));
		cy += font.height(titleSize) + dp(ui, 12);
		for (l in lines) {
			Draw.text(ui, g, l, x + pad, cy, msgSize, Draw.alpha(th.onSurfaceVariant, k));
			cy += lh;
		}
		// Buttons, right aligned, last one is the primary action
		var bs = sp(ui, 15);
		var bx = x + w - dp(ui, 16);
		var by = y + h - dp(ui, 16) - btnH;
		var i = m.buttons.length;
		while (--i >= 0) {
			var label = m.buttons[i];
			var bw = Draw.width(font, bs, label) + dp(ui, 24);
			bx -= bw;
			var down = input && Mobile.pressed(ui, bx, by, bw, btnH);
			if (down) {
				g.color = Draw.alpha(th.primary, 0.12);
				Draw.fillRoundRect(g, bx, by, bw, btnH, btnH / 2);
			}
			var c = i == m.destructive ? th.error : th.primary;
			Draw.textMid(ui, g, label, bx + bw / 2, by + btnH / 2, bs, Draw.alpha(c, k), 1);
			if (input && Mobile.tapped(ui, bx, by, bw, btnH)) close(m, i);
			bx -= dp(ui, 4);
		}
	}

	static function drawSheet(ui: Zui, g: Graphics, m: Modal, k: Float, input: Bool) {
		var th = Mobile.theme;
		var font = ui.ops.font;
		var sw = Mobile.screenW;
		var sh = Mobile.screenH;
		var itemH = dp(ui, 56);
		var titleH = m.title != null && m.title != "" ? dp(ui, 52) : dp(ui, 12);
		var handleH = dp(ui, 20);
		var cancelH = m.cancel != null ? itemH + dp(ui, 8) : 0;
		var h = handleH + titleH + m.buttons.length * itemH + cancelH + dp(ui, 8) + Mobile.safeBottom;
		var w = Math.min(sw, dp(ui, 560));
		var x = (sw - w) / 2;
		var y = sh - h * k;
		g.color = th.surface;
		Draw.fillTopRoundRect(g, x, y, w, h + dp(ui, 2), dp(ui, 28));
		g.color = th.outline;
		Draw.fillRoundRect(g, x + w / 2 - dp(ui, 16), y + dp(ui, 8), dp(ui, 32), dp(ui, 4), dp(ui, 2)); // Drag handle
		var cy = y + handleH;
		var pad = dp(ui, 24);
		if (m.title != null && m.title != "") {
			Draw.textMid(ui, g, Draw.fit(font, sp(ui, 14), m.title, w - pad * 2), x + pad, cy + titleH / 2, sp(ui, 14), th.onSurfaceVariant);
		}
		cy += titleH;
		var size = sp(ui, 16);
		for (i in 0...m.buttons.length) {
			if (input && Mobile.pressed(ui, x, cy, w, itemH)) {
				g.color = Draw.alpha(th.onSurface, 0.08);
				g.fillRect(x, cy, w, itemH);
			}
			Draw.textMid(ui, g, m.buttons[i], x + pad, cy + itemH / 2, size, i == m.destructive ? th.error : th.onSurface);
			if (input && Mobile.tapped(ui, x, cy, w, itemH)) close(m, i);
			cy += itemH;
		}
		if (m.cancel != null) {
			g.color = th.divider;
			g.fillRect(x + pad, cy + dp(ui, 4) - 1, w - pad * 2, Math.max(1, dp(ui, 0.5)));
			cy += dp(ui, 8);
			if (input && Mobile.pressed(ui, x, cy, w, itemH)) {
				g.color = Draw.alpha(th.onSurface, 0.08);
				g.fillRect(x, cy, w, itemH);
			}
			Draw.textMid(ui, g, m.cancel, x + w / 2, cy + itemH / 2, size, th.primary, 1);
			if (input && Mobile.tapped(ui, x, cy, w, itemH)) close(m, -1);
		}
		// Tap on the backdrop cancels
		if (input && ui.inputReleased && ui.inputY < y && ui.inputStartedY < y) close(m, -1);
	}

	static function drawToasts(ui: Zui, g: Graphics, t: Float) {
		if (toasts.length == 0) return;
		var toast = toasts[0];
		var age = t - toast.start;
		if (age > toast.duration + ANIM) {
			toasts = [];
			return;
		}
		var k = ease(age < ANIM ? age / ANIM : age > toast.duration ? 1 - (age - toast.duration) / ANIM : 1);
		var th = Mobile.theme;
		var font = ui.ops.font;
		var size = sp(ui, 15);
		var iconW = toast.icon != null ? dp(ui, 28) : 0;
		var maxW = Math.min(Mobile.screenW - dp(ui, 32), dp(ui, 480));
		var text = Draw.fit(font, size, toast.text, maxW - dp(ui, 32) - iconW);
		var w = Draw.width(font, size, text) + dp(ui, 32) + iconW;
		var h = dp(ui, 48);
		var x = (Mobile.screenW - w) / 2;
		var y = Mobile.areaBottom - dp(ui, 24) - h + (1 - k) * dp(ui, 16);
		g.color = Draw.alpha(th.inverseSurface, k);
		Draw.fillRoundRect(g, x, y, w, h, dp(ui, 12));
		if (toast.icon != null) Draw.icon(ui, g, toast.icon, x + dp(ui, 16) + dp(ui, 10), y + h / 2, sp(ui, 20), Draw.alpha(th.onInverseSurface, k));
		Draw.textMid(ui, g, text, x + dp(ui, 16) + iconW, y + h / 2, size, Draw.alpha(th.onInverseSurface, k));
	}
}
