package zui.mobile;

import zui.Themes.TTheme;

/**
	Colors and metrics for the mobile widgets.
	Sizes are in dp (density independent pixels) and get multiplied by `Zui.SCALE()`.
	`zui` is the matching theme for the standard Zui elements (button, check, textInput, ...).
**/
typedef MobileTheme = {
	var name: String;
	var dark: Bool;
	var primary: Int;
	var onPrimary: Int;
	var primaryContainer: Int;
	var onPrimaryContainer: Int;
	var background: Int;
	var surface: Int; // Cards, sheets, dialogs
	var surfaceVariant: Int; // Text fields, tracks, inactive controls
	var onSurface: Int;
	var onSurfaceVariant: Int;
	var outline: Int;
	var divider: Int;
	var error: Int;
	var success: Int;
	var scrim: Int; // Modal backdrop
	var inverseSurface: Int; // Toasts
	var onInverseSurface: Int;
	var appBar: Int;
	var onAppBar: Int;
	var tabBar: Int;
	var radius: Float; // Card / dialog corner radius in dp
	var zui: TTheme;
}

class MobileThemes {

	public static var light(get, null): MobileTheme;
	public static var dark(get, null): MobileTheme;

	static function get_light(): MobileTheme {
		if (light == null) light = create(false, 0xff3d5afe);
		return light;
	}

	static function get_dark(): MobileTheme {
		if (dark == null) dark = create(true, 0xff8c9eff);
		return dark;
	}

	/** Build a light or dark theme around a primary color. **/
	public static function create(isDark: Bool, primary: Int): MobileTheme {
		var t: MobileTheme = isDark ? {
			name: "Mobile Dark",
			dark: true,
			primary: primary,
			onPrimary: 0xff0b1446,
			primaryContainer: 0xff2c3a7a,
			onPrimaryContainer: 0xffdde1ff,
			background: 0xff121318,
			surface: 0xff1d1f26,
			surfaceVariant: 0xff2a2d36,
			onSurface: 0xffe3e2e9,
			onSurfaceVariant: 0xffa9adbc,
			outline: 0xff5b5f6e,
			divider: 0xff2c2f38,
			error: 0xffff6e6e,
			success: 0xff5fd38d,
			scrim: 0x99000000,
			inverseSurface: 0xffe3e2e9,
			onInverseSurface: 0xff1d1f26,
			appBar: 0xff1d1f26,
			onAppBar: 0xffe3e2e9,
			tabBar: 0xff1d1f26,
			radius: 16,
			zui: null
		} : {
			name: "Mobile Light",
			dark: false,
			primary: primary,
			onPrimary: 0xffffffff,
			primaryContainer: 0xffdee1ff,
			onPrimaryContainer: 0xff0b1a6b,
			background: 0xfff6f6fb,
			surface: 0xffffffff,
			surfaceVariant: 0xffe8e9f2,
			onSurface: 0xff1a1b21,
			onSurfaceVariant: 0xff5d6070,
			outline: 0xffb4b7c6,
			divider: 0xffe2e3ec,
			error: 0xffd32f2f,
			success: 0xff2e7d32,
			scrim: 0x66000000,
			inverseSurface: 0xff2f3036,
			onInverseSurface: 0xfff1f0f7,
			appBar: 0xffffffff,
			onAppBar: 0xff1a1b21,
			tabBar: 0xffffffff,
			radius: 16,
			zui: null
		};
		t.zui = zuiTheme(t);
		return t;
	}

	/** Standard Zui theme with touch friendly sizes (48dp rows, 16dp text). **/
	public static function zuiTheme(m: MobileTheme): TTheme {
		return {
			NAME: m.name,
			WINDOW_BG_COL: m.background,
			WINDOW_TINT_COL: 0xffffffff,
			ACCENT_COL: m.surfaceVariant,
			ACCENT_HOVER_COL: Draw.mix(m.surfaceVariant, m.onSurface, 0.06),
			ACCENT_SELECT_COL: m.primary,
			BUTTON_COL: m.surfaceVariant,
			BUTTON_TEXT_COL: m.onSurface,
			BUTTON_HOVER_COL: Draw.mix(m.surfaceVariant, m.onSurface, 0.06),
			BUTTON_PRESSED_COL: Draw.mix(m.surfaceVariant, m.onSurface, 0.16),
			TEXT_COL: m.onSurface,
			LABEL_COL: m.onSurfaceVariant,
			SEPARATOR_COL: m.divider,
			HIGHLIGHT_COL: m.primary,
			CONTEXT_COL: m.surface,
			PANEL_BG_COL: m.surface,
			FONT_SIZE: 16,
			ELEMENT_W: 120,
			ELEMENT_H: 48,
			ELEMENT_OFFSET: 4,
			ARROW_SIZE: 8,
			BUTTON_H: 40,
			CHECK_SIZE: 22,
			CHECK_SELECT_SIZE: 12,
			SCROLL_W: 6,
			TEXT_OFFSET: 12,
			TAB_W: 16,
			FILL_WINDOW_BG: true,
			FILL_BUTTON_BG: true,
			FILL_ACCENT_BG: true,
			LINK_STYLE: Line,
			FULL_TABS: true
		};
	}
}
