# zui

Portable immediate mode UI library designed for tools and debug interfaces. Written in [Haxe](https://haxe.org/) and [Kha](http://kha.tech/), used in [ArmorPaint](http://armorpaint.org).

![](https://armorpaint.org/img/zui.jpg)

## Getting started
- Clone into *your_kha_project/Libraries*
- Add `project.addLibrary('zui');` into *khafile.js*
``` hx
	// In init()
	var ui = new Zui({ font: myFont });

	// In render()
	public function render(frames: Array<Framebuffer>) {
		var g = frames[0].g2;
		g.begin();
		// Draw your stuff...
		g.end();

		ui.begin(g);
		if (ui.window(Id.handle(), x, y, w, h, drag)) {
			if (ui.button("Hello")) {
				trace("World");
			}
		}
		ui.end();

		// Draw more stuff...
	}
```

## Elements
``` hx
function tab(handle: Handle, text: String, vertical = false): Bool;
function panel(handle: Handle, text: String, isTree = false): Bool;
function image(image: Image, tint = 0xffffffff): State;
function text(text: String, align = Left, bg = 0x00000000);
function textInput(handle: Handle, label = "", align = Left): String;
function button(text: String, align = Center, label = ""): Bool;
function check(handle: Handle, text: String): Bool;
function radio(groupId: Handle, pos: Int, text: String): Bool;
function combo(handle: Handle, texts: Array<String>, label = ""): Int;
function slider(handle: Handle, text: String, from: Float, to: Float, filled = false, precision = 100, displayValue = true): Float;
function tooltip(text: String);
function tooltipImage(image: Image);

// Formatting
function row(ratios: Array<Float>);
function separator(h = 4, fill = true);
function indent();
function unindent();
```

Id.hx - simple macros to generate handles
``` hx
var state = ui.check(Id.handle(), "Check Box");
```

Ext.hx - prebuilt elements:
``` hx
function colorWheel(...); // See examples
function fileBrowser(...);
function inlineRadio(handle: Handle, texts: Array<String>): Int;
function textArea(handle: Handle, align = Left): String;
```

Nodes.hx - drawing node systems
``` hx
nodes.nodeCanvas(...); // See examples
```

## Mobile

Touch support in the core (`Zui.hx`), switched on at runtime:
``` hx
Zui.touchInput     // true while input comes from a finger (set automatically by zui.mobile.Mobile)
Zui.touchScroll    // drag windows with a finger
Zui.kineticScroll  // keep scrolling after a flick (Zui.scrollFriction)
Zui.touchSlop      // dp a finger may move before a tap becomes a drag
Zui.softKeyboard   // bridge for on-screen keyboards / IME (zui.mobile.HtmlSoftKeyboard on HTML5)
```
With `touchInput`, presses jump to the finger position, lifted fingers stop hovering, taps that turned into
scrolls are not released, sliders follow the finger and do not open a text editor, and combos hide their
search field. Elements scrolled outside their window ignore input that lands next to the window.

`zui.mobile` adds screen layout, widgets and overlays on top of that:
``` hx
Mobile.init(ui, {iconFont: Assets.fonts.icons}); // DPI scale, full-screen canvas, safe areas, keyboard bridge

// In render():
Mobile.begin(ui, g);
Mobile.appBar(ui, "Title", null, [Icons.SEARCH]);         // top bar, returns tapped icon index
var tab = Mobile.tabBar(ui, hTabs, [{icon: Icons.HOME, label: "Home"}, ...]);
if (Mobile.content(ui, hContent)) {                      // scrolling window between the bars
	Widgets.button(ui, "Save", Filled, Icons.CHECK);
	Widgets.toggle(ui, Id.handle(), "Wi-Fi");
	ui.check(Id.handle(), "Standard zui elements work too");
}
if (Mobile.fab(ui, Icons.ADD)) Overlay.toast("Added");
Mobile.end(ui);                                          // draws dialogs, sheets and toasts
```
- `Widgets`: button (filled / tonal / outlined / text / danger), iconButton, toggle, segmented, stepper, slider,
  progress, spinner, listItem, sectionHeader, paragraph, chips, pageDots, textField, searchBar, card / endCard,
  wheelPicker, margin, space
- `Overlay`: alert, actionSheet, toast (modal overlays block input below them)
- `MobileThemes.light` / `dark` / `create(dark, primaryColor)`: colors plus a touch sized zui theme (48dp rows)
- `Icons`: Material Icons code points, `Draw`: rounded shapes, text and icon helpers

On HTML5, add `project.addDefine('kha_html5_disable_automatic_size_adjust');` so `Mobile` can size the canvas
at device resolution. Text fields raise the on-screen keyboard through a hidden `<input>`, which also gives
IME (e.g. Japanese) input on desktop browsers.

## Examples
Check out [examples/](https://github.com/armory3d/zui/tree/master/examples) folder. To run specific example, simply drop it's folder into [KodeStudio](https://github.com/KTXSoftware/KodeStudio/releases) and hit run. If you are having trouble compiling, clone latest [Kha](https://github.com/Kode/Kha) repository into your example folder (alongside the `khafile.js`). This will let KodeStudio pick up the most recent Kha.

## Theming
Themes can be defined using TTheme typedef. Check zui.Themes class for example. Set ZuiOptions.theme when creating new Zui instance to overwrite default theme.

## Snippets

**Check element for changes**
```hx
var hcombo = Id.handle();
ui.combo(hcombo, ["Item 1", "item 2"]);
if (hcombo.changed) {
	trace("Combo value changed this frame");
}
```

**Force redrawing zui window on demand**
```hx
function render(..) {
    // Get window handle
    var hwin = Id.handle();
    // Force redraw - set each frame or whenever desired
    hwin.redraws = 1;
    if (ui.window(hwin, x, y, w, h)) { ... }
}
```

**Using render targets - prevent nested begin/end calls**
```hx
g2.begin();
..
g2.end();

renderTarget.g2.begin();
..
renderTarget.g2.end();

zui.begin(); // Zui also draws to texture..
..
zui.end();

g2.begin();
..
g2.end();
```

**Using Id.handle() in a for loop**
```hx
// Id.handle() works at compile time
// Call .nest() to get unique handle per iteration
for (i in 0...3) Id.handle().nest(i);
// Or use new zui.Handle() directly
```

**Set initial Id.handle() state**
```hx
var h1 = Id.handle({selected: true});
var h2 = Id.handle({position: 0});
var h3 = Id.handle({value: 1.0});
var h4 = Id.handle({text: "Text"});
```

## Custom integration
Using the powerful render target system of Kha, it is possible to easily integrate the library into any scenario. Set ZuiOptions.autoNotifyInput to false when creating a new Zui instance. You can then manually process the input and render the resulting texture in any way you may need.
``` hx
zui.onMouseDown(button:Int, x: Int, y: Int)
zui.onMouseUp(button:Int, x: Int, y: Int)
zui.onMouseMove(x: Int, y: Int, movementX: Int, movementY: Int)
zui.onMouseWheel(delta: Int)
```

---

Inspired by [imgui](https://github.com/ocornut/imgui).
