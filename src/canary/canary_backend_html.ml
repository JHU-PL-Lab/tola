open Base

(* HTML viewer for a canary run.
   Generates a self-contained result.html that:
   - lists the available views (overview + per-slice .mmd files)
   - renders the selected view inline via mermaid.js (CDN by default)
   - lets the user click a node to open the corresponding step's
     output dir files (probe.log, summary.json, ...) in a side drawer.

   No server needed — open result.html directly in a browser. The page
   reads the list of files under each step's output_dir lazily via
   relative-path fetch when a node is clicked.

   See doc/canary/design/diagram.md (Step 3). *)

type view_entry = {
  name  : string;        (* short id used as filename, e.g. "source" *)
  title : string;        (* nice title for the selector button *)
  mmd   : string;        (* mermaid source — already rendered *)
}

type step_meta = {
  tag         : string;
  rule        : string;
  output_rel  : string;  (* relative path from run dir to step output_dir *)
  expectation : string;  (* "Expect_success" | "Expect_failure" | "Expect_compat_failure" *)
  status      : string;  (* "done" | "failed" | "skipped" | "not_in_spec" *)
}

let json_string s =
  let buf = Buffer.create (String.length s + 2) in
  Buffer.add_char buf '"';
  String.iter s ~f:(fun c ->
      match c with
      | '"'  -> Buffer.add_string buf {|\"|}
      | '\\' -> Buffer.add_string buf {|\\|}
      | '\n' -> Buffer.add_string buf {|\n|}
      | '\r' -> Buffer.add_string buf {|\r|}
      | '\t' -> Buffer.add_string buf {|\t|}
      | c when Char.to_int c < 0x20 ->
          Buffer.add_string buf
            (Printf.sprintf "\\u%04x" (Char.to_int c))
      | c -> Buffer.add_char buf c);
  Buffer.add_char buf '"';
  Buffer.contents buf

let render_view_selector views ~default =
  let buttons =
    List.map views ~f:(fun v ->
        let active = if String.equal v.name default then " active" else "" in
        Printf.sprintf
          {|<button class="view-btn%s" data-view="%s">%s</button>|}
          active v.name v.title)
    |> String.concat ~sep:"\n        "
  in
  Printf.sprintf {|    <div class="view-selector">
        %s
    </div>|} buttons

let render_views_data views =
  let entries = List.map views ~f:(fun v ->
      Printf.sprintf "    %s: { title: %s, mmd: %s }"
        (json_string v.name) (json_string v.title) (json_string v.mmd))
  in
  "{\n" ^ String.concat ~sep:",\n" entries ^ "\n  }"

let render_steps_data steps =
  let entries = List.map steps ~f:(fun s ->
      Printf.sprintf
        "    %s: { rule: %s, output_rel: %s, expectation: %s, status: %s }"
        (json_string s.tag)
        (json_string s.rule) (json_string s.output_rel)
        (json_string s.expectation) (json_string s.status))
  in
  "{\n" ^ String.concat ~sep:",\n" entries ^ "\n  }"

(* The page: HTML + inline CSS + JS. Mermaid loaded from CDN; logs
   loaded lazily on node click via fetch (relative paths). *)
let render
    ~project ~variant ~run_at
    ~(views : view_entry list)
    ~(default_view : string)
    ~(steps : step_meta list) =
  let views_json = render_views_data views in
  let steps_json = render_steps_data steps in
  let selector = render_view_selector views ~default:default_view in
  Printf.sprintf {|<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>canary: %s/%s</title>
<style>
  body { font-family: system-ui, sans-serif; margin: 0; padding: 0; background: #fafafa; color: #222; }
  header { padding: 12px 24px; background: #fff; border-bottom: 1px solid #ddd; display: flex; align-items: baseline; gap: 24px; }
  header h1 { margin: 0; font-size: 18px; }
  header .meta { color: #777; font-size: 13px; }
  main { display: flex; height: calc(100vh - 60px); }
  .left { flex: 1; overflow: auto; padding: 16px; }
  .right { width: 480px; border-left: 1px solid #ddd; background: #fff; overflow: auto; padding: 16px; box-sizing: border-box; }
  .view-selector { display: flex; gap: 8px; flex-wrap: wrap; margin-bottom: 16px; }
  .view-btn { padding: 6px 12px; border: 1px solid #999; background: #fff; cursor: pointer; border-radius: 4px; font-size: 13px; }
  .view-btn.active { background: #1976d2; color: #fff; border-color: #1976d2; }
  .view-btn:hover:not(.active) { background: #e3f2fd; }
  .mermaid { background: #fff; border: 1px solid #ddd; border-radius: 4px; padding: 12px; }
  .mermaid svg { max-width: 100%%; }
  .drawer h2 { margin: 0 0 8px; font-size: 16px; }
  .drawer .step-meta { font-size: 13px; color: #555; margin-bottom: 12px; }
  .drawer .step-meta span { margin-right: 12px; }
  .drawer .file { margin-bottom: 16px; }
  .drawer .file h3 { margin: 0 0 4px; font-size: 13px; color: #333; font-weight: 600; }
  .drawer pre { background: #f5f5f5; padding: 8px; border-radius: 4px; overflow: auto; font-size: 12px; max-height: 400px; }
  .placeholder { color: #999; font-style: italic; }
  /* Status colors mirroring Mermaid classDef in the views */
  .badge { display: inline-block; padding: 2px 8px; border-radius: 12px; font-size: 11px; font-weight: 600; }
  .badge.done { background: #c8e6c9; color: #1b5e20; }
  .badge.failed { background: #ffcdd2; color: #b71c1c; }
  .badge.skipped { background: #e0e0e0; color: #555; }
  .badge.not_in_spec { background: #fafafa; color: #888; border: 1px solid #ccc; }
  .exp-badge { font-family: monospace; font-size: 11px; color: #555; }
</style>
</head>
<body>
<header>
  <h1>canary <span style="color: #1976d2;">%s/%s</span></h1>
  <span class="meta">run at %s</span>
</header>
<main>
  <div class="left">
%s
    <div id="diagram" class="mermaid"></div>
  </div>
  <aside class="right drawer" id="drawer">
    <h2>Step details</h2>
    <p class="placeholder">Click a node in the diagram to inspect its output files.</p>
  </aside>
</main>
<script src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"></script>
<script>
  const VIEWS = %s;
  const STEPS = %s;
  const drawer = document.getElementById('drawer');
  const diagramDiv = document.getElementById('diagram');
  let currentView = %s;

  let renderCounter = 0;
  async function renderView(name) {
    currentView = name;
    document.querySelectorAll('.view-btn').forEach(b =>
      b.classList.toggle('active', b.dataset.view === name));
    const v = VIEWS[name];
    if (!v) { diagramDiv.textContent = '(no view: ' + name + ')'; return; }
    diagramDiv.innerHTML = '<div style="color:#999">rendering…</div>';
    const id = 'mmd-' + (++renderCounter);
    try {
      const { svg, bindFunctions } = await mermaid.render(id, v.mmd);
      diagramDiv.innerHTML = svg;
      if (bindFunctions) bindFunctions(diagramDiv);
      attachClicks(diagramDiv);
    } catch (err) {
      const msg = (err && err.message) ? err.message : String(err);
      diagramDiv.innerHTML =
        '<div style="color:#b71c1c;background:#ffebee;padding:12px;border-radius:4px;">' +
        '<b>Mermaid error</b><br><pre style="white-space:pre-wrap;font-size:12px;margin-top:8px">' +
        escape(msg) + '</pre></div>' +
        '<details style="margin-top:8px"><summary>view source (' + escape(name) + ')</summary>' +
        '<pre style="font-size:11px">' + escape(v.mmd) + '</pre></details>';
    }
  }

  function attachClicks(container) {
    // Each Mermaid node's group has class "node" with id starting with "flowchart-S_<tag>-..."
    // For result.mmd (schema view) the node id pattern is different, so we
    // also handle nodes whose label text starts with a tag.
    container.querySelectorAll('g.node').forEach(g => {
      const id = g.id || '';
      let tag = null;
      // S_<tag>-N pattern from mermaid_of_steps
      const m1 = id.match(/^flowchart-S_([^\s-]+(?:_[^\s-]+)*)-/);
      if (m1) tag = m1[1];
      if (!tag) return;
      g.style.cursor = 'pointer';
      g.addEventListener('click', () => showStep(tag));
    });
  }

  async function showStep(tag) {
    const meta = STEPS[tag];
    if (!meta) {
      drawer.innerHTML = '<h2>Step details</h2><p class="placeholder">No metadata for ' + tag + '</p>';
      return;
    }
    let html = '<h2>' + escape(tag) + '</h2>';
    html += '<div class="step-meta">';
    html += '<span class="badge ' + meta.status + '">' + meta.status + '</span>';
    html += '<span><b>rule:</b> ' + escape(meta.rule) + '</span>';
    html += '<span class="exp-badge">' + escape(meta.expectation) + '</span>';
    html += '</div>';
    // Try to fetch the canonical files in the step's output_dir
    const candidates = ['probe.log', 'summary.json', 'stub_summary.json', 'install.log', 'symbols.log'];
    for (const fname of candidates) {
      const url = meta.output_rel + '/' + fname;
      try {
        const resp = await fetch(url);
        if (resp.ok) {
          const txt = await resp.text();
          if (txt.length > 0) {
            html += '<div class="file"><h3>' + escape(fname) + '</h3><pre>' + escape(txt) + '</pre></div>';
          }
        }
      } catch (e) { /* ignore */ }
    }
    if (!html.includes('<div class="file">')) {
      html += '<p class="placeholder">No log/summary files found at ' + escape(meta.output_rel) + '/</p>';
    }
    drawer.innerHTML = html;
  }

  function escape(s) {
    return String(s).replace(/[&<>]/g, c =>
      ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c]));
  }

  // Selector clicks
  document.querySelectorAll('.view-btn').forEach(b =>
    b.addEventListener('click', () => renderView(b.dataset.view)));

  // Initial render
  mermaid.initialize({ startOnLoad: false, theme: 'default', flowchart: { htmlLabels: true } });
  renderView(currentView);
</script>
</body>
</html>
|}
    project variant            (* title *)
    project variant run_at     (* header *)
    selector
    views_json steps_json
    (json_string default_view)
