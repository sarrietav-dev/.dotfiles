import { View, div } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { closeOverlay, focused, hc, layout, nextCommand, notify, props, run, setShared, shared, theme } from "herdr";

// The app-side twin of the Herdr TUI prefix in ~/.config/herdr/config.toml:
// Ctrl+Space opens the hint, and the bindings below are the ones that config
// gives prefix keys, so the same muscle memory works in both. Only repeatable
// actions start a timer: the first key after the prefix can take as long as
// you like.
const PREFIX_KEY = "ctrl-space";
const PREFIX_HC = "ctrl+space";
const PREFIX_LABEL = "Ctrl+Space";
const REPEAT_MS = 500;
// Zen mode: hide everything but the terminals. Each id is hidden only if the
// shown layout has it, and what was shown is remembered in shared state.
const ZEN_IDS = ["sidebar", "tabs", "status", "panel"];
const BINDINGS = [
  // Tabs
  ["c", "New tab", "tab.new"],
  ["k", "Close tab", "tab.close", { confirmed: true }],
  ["r", "Rename tab", "tab.rename"],
  ["n", "Next tab", "tab.next"],
  ["p", "Previous tab", "tab.prev"],
  // Panes
  ["h", "Split down", "pane.split", { direction: "down" }],
  ["v", "Split right", "pane.split", { direction: "right" }],
  ["x", "Close pane", "pane.close"],
  ["z", "Zoom pane", "pane.zoom"],
  // Spaces
  ["C", "New space", "space.new"],
  ["K", "Close space", "space.close", { confirmed: true }],
  ["R", "Rename space", "space.rename"],
  ["N", "Next space", "space.next", {}, true],
  ["P", "Previous space", "space.prev", {}, true],
  // App
  ["g", "Go to a tab, space or agent", "mod.open", { name: "picker" }],
  ["d", "Minimize window", "window.minimize"],
  ["Z", "Zen mode", null],
  ["?", "Help", "app.help"],
  ...Array.from({ length: 9 }, (_, i) => [String(i + 1), `Tab ${i + 1}`, "tab.select", { index: i + 1 }]),
];

function forwardKey(e, key) {
  if (["enter", "tab", "backspace", "left", "right", "up", "down", "space"].includes(e.key)) return e.key;
  if (key === " ") return "space";
  if (/^[A-Z]$/.test(key)) return `shift+${key.toLowerCase()}`;
  if (key.length === 1 && "abcdefghijklmnopqrstuvwxyz0123456789`\\[],=-.';/".includes(key)) return key === "\\" ? "backslash" : key;
  return null;
}

function find(node, id) {
  if (node?.id === id) return node;
  for (const child of node?.children ?? []) {
    const found = find(child, id);
    if (found) return found;
  }
  return null;
}

export default class TmuxPrefix extends View {
  init(_props, cx) {
    this.handle = cx.focus_handle();
    this.handle.focus();
    this.repeat = false;
    this.generation = 0;
    // The mod-specific key binding beats the global opener while we're open.
    cx.spawn(async (cx) => {
      for (;;) {
        await nextCommand();
        this.sendPrefix(cx);
      }
    });
  }

  dismiss() {
    closeOverlay(props().overlay);
  }

  send(key, cx) {
    this.generation++;
    const terminal = focused()?.terminal;
    if (!terminal) return this.dismiss();
    // hc starts its subprocess at the call, before closing cancels this view's tasks.
    const pending = hc(["keys", terminal, key]);
    cx.spawn(async () => {
      const result = await pending;
      if (result.code !== 0) console.log(`tmux-prefix: ${result.stderr}`);
    });
    this.dismiss();
  }

  sendPrefix(cx) {
    this.send(PREFIX_HC, cx);
  }

  toggleZen() {
    const root = layout();
    const state = shared("zen");
    // Leave only if the snapshot belongs to the layout that is still shown.
    if (state && state.layout === shared("layout")) {
      for (const [id, hidden] of Object.entries(state.hidden ?? {})) {
        if (!find(root, id)) continue;
        run(hidden ? "layout.hide" : "layout.show", { id });
      }
      setShared("zen", null);
      return;
    }
    if (state) setShared("zen", null);
    const hidden = {};
    for (const id of ZEN_IDS) {
      const node = find(root, id);
      if (!node) continue;
      hidden[id] = !!node.hidden;
      run("layout.hide", { id });
    }
    setShared("zen", { layout: shared("layout"), hidden });
    notify({ title: "Zen mode", body: `${PREFIX_LABEL} Z brings the window back` });
  }

  key(e, cx) {
    cx.stop_propagation();
    const m = e.modifiers;
    if (e.key === "escape") return this.dismiss();
    if (e.keystroke === PREFIX_KEY) return this.sendPrefix(cx);
    const plain = !m.control && !m.alt && !m.platform;
    const key = plain ? (e.key_char ?? (m.shift && e.key.length === 1 ? e.key.toUpperCase() : e.key)) : e.key;
    const binding = plain && BINDINGS.find((b) => b[0] === key);
    if (!binding) {
      const forwarded = this.repeat && plain && forwardKey(e, key);
      if (forwarded) return this.send(forwarded, cx);
      return this.dismiss();
    }
    const [, , command, args = {}, repeatable = false] = binding;
    if (command === null) {
      this.dismiss();
      this.toggleZen();
      return;
    }
    if (!repeatable) this.dismiss();
    run(command, args);
    if (repeatable) {
      this.repeat = true;
      const generation = ++this.generation;
      cx.timer.after(REPEAT_MS, () => {
        if (this.generation === generation) this.dismiss();
      });
      cx.notify();
    }
  }

  render() {
    const t = theme();
    const zen = shared("zen");
    const rows = BINDINGS.filter(([key]) => !/^\d$/.test(key));
    return v_flex().id("tmux-prefix").track_focus(this.handle)
      .on_key_down((e, cx) => this.key(e, cx))
      .p(14).gap(8).bg(t.popover).text_color(t.foreground).text_size(12)
      .child(h_flex().justify_between().child(div().font_semibold().child(this.repeat ? `Repeat · ${REPEAT_MS} ms` : `${PREFIX_LABEL} · waiting for a key`))
        .child(div().text_color(t.muted).child(`Esc cancel · ^${PREFIX_LABEL.split("+").pop()} send prefix`)))
      .child(v_flex().h(360).min_h(0).overflow_y_scrollbar().children(rows.map(([key, label, , , repeatable]) =>
        h_flex().h(20).flex_none().items_center().gap(12).child(div().w(40).text_color(t.accent).child(key))
          .child(div().flex_1().child(key === "Z" && zen ? "Leave zen mode" : label)).child(div().text_color(t.dim).child(repeatable ? "repeat" : "")))))
      .child(div().text_color(t.muted).child("1–9 tabs · N/P spaces repeat for 500 ms · ? help"));
  }
}
