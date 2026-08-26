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
  id          : int option;  (* sequential action number from step_id_table — used as [N] in diagrams *)
  tag         : string;
  action        : string;
  output_rel  : string;  (* relative path from run dir to step output_dir (shared, no variant subdir) *)
  variant_key : string;  (* "" for single-variant, "19" for llvm/19, etc. — used to qualify file names *)
  expectation : string;  (* "Expect_success" | "Expect_failure" | "Expect_compat_failure" *)
  status      : string;  (* "done" | "failed" | "skipped" | "not_in_spec" *)
}

(* Top-level index entry: one per (project, variant) run. *)
type index_entry = {
  project       : string;
  variant       : string;
  run_at        : string;        (* "YYYY-MM-DD HH:MM:SS" or "" *)
  href          : string;        (* relative URL to the run's result.html *)
  total_steps   : int;
  done_steps    : int;
  failed_steps  : int;
  skipped_steps : int;
  source_kind   : string;        (* "git:url", "local:path", "prebuilt", "" *)
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
      let id_json = match s.id with Some n -> Int.to_string n | None -> "null" in
      Printf.sprintf
        "    %s: { id: %s, action: %s, output_rel: %s, variant_key: %s, expectation: %s, status: %s }"
        (json_string s.tag) id_json
        (json_string s.action) (json_string s.output_rel)
        (json_string s.variant_key)
        (json_string s.expectation) (json_string s.status))
  in
  "{\n" ^ String.concat ~sep:",\n" entries ^ "\n  }"

(* The page: HTML + inline CSS + JS. Mermaid loaded from CDN; logs
   loaded lazily on node click via fetch (relative paths). *)
let render
    ~project ~variant ~run_at ~index_rel
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
  header { padding: 12px 24px; background: #fff; border-bottom: 1px solid #ddd; display: flex; align-items: center; gap: 16px; flex-wrap: wrap; }
  header h1 { margin: 0; font-size: 18px; }
  header .meta { color: #777; font-size: 13px; }
  main { display: flex; height: calc(100vh - 60px); }
  .left { flex: 1; overflow: auto; padding: 16px; }
  .right { width: 360px; border-left: 1px solid #ddd; background: #fff; display: flex; flex-direction: column; box-sizing: border-box; overflow: hidden; }
  .view-selector { display: flex; gap: 8px; flex-wrap: wrap; margin-bottom: 16px; }
  .view-btn { padding: 6px 12px; border: 1px solid #999; background: #fff; cursor: pointer; border-radius: 4px; font-size: 13px; }
  .view-btn.active { background: #1976d2; color: #fff; border-color: #1976d2; }
  .view-btn:hover:not(.active) { background: #e3f2fd; }
  .mermaid { background: #fff; border: 1px solid #ddd; border-radius: 4px; padding: 12px; }
  .mermaid svg { max-width: 100%%; }
  .placeholder { color: #999; font-style: italic; font-size: 12px; padding: 8px 0; }
  /* Status badges — mirrors Mermaid classDef colors */
  .badge { display: inline-block; padding: 1px 6px; border-radius: 10px; font-size: 10px; font-weight: 700; white-space: nowrap; }
  .badge.done          { background: #c8e6c9; color: #1b5e20; }
  .badge.expected_fail { background: #fff9c4; color: #7a6000; }
  .badge.failed        { background: #ffcdd2; color: #b71c1c; }
  .badge.skipped       { background: #e0e0e0; color: #555; }
  .badge.not_in_spec   { background: #fafafa; color: #bbb; border: 1px solid #ddd; }
  /* Action list (right panel) */
  .panel-hdr { padding: 10px 14px 8px; font-size: 11px; font-weight: 700; color: #999; text-transform: uppercase; letter-spacing: 0.5px; border-bottom: 1px solid #eee; flex-shrink: 0; }
  .action-list { flex: 1 1 0; overflow-y: auto; padding: 4px 0; }
  .action-row { display: flex; align-items: center; gap: 6px; padding: 4px 14px; cursor: pointer; transition: opacity 0.15s; }
  .action-row:hover { background: #f5f5f5; }
  .action-row.selected { background: #e3f2fd; }
  .action-row.out-of-view { opacity: 0.3; }
  .action-id { font-family: monospace; font-size: 11px; color: #aaa; min-width: 32px; flex-shrink: 0; }
  .action-tag { flex: 1; font-family: monospace; font-size: 11px; color: #333; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .action-row.not-in-spec .action-tag { color: #bbb; }
  /* Step detail (bottom of right panel) */
  .action-detail { border-top: 1px solid #eee; overflow-y: auto; max-height: 45%%; padding: 10px 14px; flex-shrink: 0; font-size: 12px; }
  .action-detail:empty { display: none; }
  .detail-hdr { font-weight: 600; font-size: 12px; margin-bottom: 6px; }
  .detail-meta { margin-bottom: 8px; }
  .exp-badge { font-family: monospace; font-size: 10px; color: #888; margin-left: 6px; }
  .detail-file { margin-bottom: 12px; }
  .detail-file h3 { margin: 0 0 3px; font-size: 11px; color: #555; font-weight: 600; }
  .detail-file pre { background: #f5f5f5; padding: 6px 8px; border-radius: 3px; overflow: auto; font-size: 11px; max-height: 200px; margin: 0; }
  /* Legend */
  .legend { display: flex; flex-direction: column; gap: 5px; margin-bottom: 12px; font-size: 12px; }
  .legend-row { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; color: #555; }
  .legend-section { font-size: 10px; font-weight: 700; color: #999; text-transform: uppercase; letter-spacing: 0.5px; min-width: 80px; flex-shrink: 0; }
  .legend-item { display: flex; align-items: center; gap: 5px; white-space: nowrap; }
  .ln { display: inline-block; width: 28px; height: 18px; border-radius: 3px; }
  .ln-done     { background: #c8e6c9; border: 3px solid #4caf50; }
  .ln-done-ctx { background: #e8f5e9; border: 1.5px solid #a5d6a7; }
  .ln-expfail  { background: #fff9c4; border: 2px solid #f9a825; }
  .ln-failed   { background: #ffcdd2; border: 2px solid #c62828; }
  .ln-skipped  { background: #f5f5f5; border: 2px dashed #9e9e9e; }
  .ln-nospec   { background: #fafafa; border: 2px dashed #bdbdbd; }
</style>
</head>
<body>
<header>
  <a href="%s" style="color:#666;text-decoration:none;font-size:13px;">← all runs</a>
  <h1>canary <span style="color: #1976d2;">%s/%s</span></h1>
  <span class="meta">run at %s</span>
</header>
<main>
  <div class="left">
%s
    <div class="legend">
      <div class="legend-row">
        <span class="legend-section">Nodes</span>
        <span class="legend-item">
          <svg width="30" height="18" viewBox="0 0 30 18" style="vertical-align:middle">
            <polygon points="1,1 23,1 29,7 29,17 1,17" fill="#fff3e0" stroke="#ff9800" stroke-width="1.5"/>
            <polyline points="23,1 23,7 29,7" fill="none" stroke="#ff9800" stroke-width="1.5"/>
          </svg>Artifact
        </span>
        <span class="legend-item">
          <svg width="30" height="18" viewBox="0 0 30 18" style="vertical-align:middle">
            <polygon points="7,1 23,1 29,9 23,17 7,17 1,9" fill="#f8f8f8" stroke="#999" stroke-width="1.5"/>
          </svg>Action
        </span>
        <span class="legend-item">
          <svg width="34" height="18" viewBox="0 0 34 18" style="vertical-align:middle">
            <rect x="1" y="1" width="32" height="16" rx="8" fill="#f8f8f8" stroke="#999" stroke-width="1.5"/>
          </svg>Probe / follow-up
        </span>
      </div>
      <div class="legend-row">
        <span class="legend-section">Status</span>
        <span class="legend-item"><span class="ln ln-done"></span>Done</span>
        <span class="legend-item"><span class="ln ln-done-ctx"></span>Done (other view)</span>
        <span class="legend-item"><span class="ln ln-expfail"></span>Expected failure</span>
        <span class="legend-item"><span class="ln ln-failed"></span>Unexpected outcome</span>
        <span class="legend-item"><span class="ln ln-skipped"></span>Skipped</span>
        <span class="legend-item"><span class="ln ln-nospec"></span>Not in spec</span>
      </div>
      <div class="legend-row">
        <span class="legend-section">Edges</span>
        <span class="legend-item">
          <svg width="38" height="10" viewBox="0 0 38 10" style="vertical-align:middle">
            <line x1="2" y1="5" x2="30" y2="5" stroke="#4caf50" stroke-width="2.5"/>
            <polygon points="28,2 37,5 28,8" fill="#4caf50"/>
          </svg>Primary data flow (color = action status)
        </span>
        <span class="legend-item">
          <svg width="38" height="10" viewBox="0 0 38 10" style="vertical-align:middle">
            <line x1="2" y1="5" x2="30" y2="5" stroke="#bdbdbd" stroke-width="1.5" stroke-dasharray="4,3"/>
            <polygon points="28,2 37,5 28,8" fill="#bdbdbd"/>
          </svg>Runtime / context dependency
        </span>
      </div>
    </div>
    <div id="diagram" class="mermaid"></div>
  </div>
  <aside class="right" id="action-panel">
    <div class="panel-hdr">Actions</div>
    <div class="action-list" id="action-list"></div>
    <div class="action-detail" id="action-detail"></div>
  </aside>
</main>
<script src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"></script>
<script>
  const VIEWS = %s;
  const STEPS = %s;
  const diagramDiv = document.getElementById('diagram');
  const actionList = document.getElementById('action-list');
  const actionDetail = document.getElementById('action-detail');
  let currentView = %s;
  let highlightedNode = null;

  function escape(s) {
    return String(s).replace(/[&<>]/g, c =>
      ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c]));
  }

  // ── Action list ──────────────────────────────────────────────────────────
  const BADGE = {
    done:          ['done',     'done'],
    expected_fail: ['exp.fail', 'expected_fail'],
    failed:        ['fail',     'failed'],
    skipped:       ['skip',     'skipped'],
    not_in_spec:   ['n/a',      'not_in_spec'],
  };

  function buildActionList() {
    const sorted = Object.entries(STEPS).sort(([, a], [, b]) => {
      const ai = a.id ?? Infinity, bi = b.id ?? Infinity;
      return ai !== bi ? ai - bi : 0;
    });
    let html = '';
    for (const [tag, meta] of sorted) {
      const idStr = meta.id != null ? '[' + meta.id + ']' : '';
      const [btxt, bcls] = BADGE[meta.status] || [meta.status, meta.status];
      const nisCls = meta.status === 'not_in_spec' ? ' not-in-spec' : '';
      html += '<div class="action-row' + nisCls + '" data-tag="' + escape(tag) + '" id="row-' + escape(tag) + '">'
            + '<span class="action-id">' + escape(idStr) + '</span>'
            + '<span class="action-tag" title="' + escape(tag) + '">' + escape(tag) + '</span>'
            + '<span class="badge ' + bcls + '">' + btxt + '</span>'
            + '</div>';
    }
    actionList.innerHTML = html;
    actionList.querySelectorAll('.action-row').forEach(row =>
      row.addEventListener('click', () => showStep(row.dataset.tag)));
  }

  function selectRow(tag) {
    actionList.querySelectorAll('.action-row.selected').forEach(r => r.classList.remove('selected'));
    const row = document.getElementById('row-' + tag);
    if (row) {
      row.classList.add('selected');
      row.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
    }
  }

  // Highlight the diagram node corresponding to tag (drop-shadow ring).
  function highlightDiagramNode(tag) {
    if (highlightedNode) { highlightedNode.style.filter = ''; highlightedNode = null; }
    document.querySelectorAll('g.node').forEach(g => {
      const m = (g.id || '').match(/^flowchart-(.+)-\d+$/);
      if (!m) return;
      const nodeId = m[1];
      if (nodeId === 'A_' + tag || nodeId === 'S_' + tag) {
        g.style.filter = 'drop-shadow(0 0 5px #1976d2)';
        highlightedNode = g;
      }
    });
  }

  // Dim rows for steps that have no node in the current rendered diagram.
  function updateActionListForView() {
    const inView = new Set();
    document.querySelectorAll('g.node').forEach(g => {
      const m = (g.id || '').match(/^flowchart-(.+)-\d+$/);
      if (!m) return;
      const nodeId = m[1];
      let t = null;
      if (nodeId.startsWith('A_')) t = nodeId.slice(2);
      else if (nodeId.startsWith('S_')) t = nodeId.slice(2);
      if (t && STEPS[t]) inView.add(t);
    });
    actionList.querySelectorAll('.action-row').forEach(row => {
      row.classList.toggle('out-of-view', !inView.has(row.dataset.tag));
    });
    // scroll to first visible in-view row (skip already-selected)
    const first = actionList.querySelector('.action-row:not(.out-of-view)');
    if (first && !actionList.querySelector('.action-row.selected')) {
      first.scrollIntoView({ block: 'nearest' });
    }
  }

  // ── Step detail ──────────────────────────────────────────────────────────
  async function showStep(tag) {
    selectRow(tag);
    highlightDiagramNode(tag);
    const meta = STEPS[tag];
    if (!meta) {
      actionDetail.innerHTML = '<p class="placeholder">No metadata for ' + escape(tag) + '</p>';
      return;
    }
    const [btxt, bcls] = BADGE[meta.status] || [meta.status, meta.status];
    actionDetail.innerHTML =
      '<div class="detail-hdr">' + escape(tag) + '</div>'
      + '<div class="detail-meta"><span class="badge ' + bcls + '">' + btxt + '</span>'
      + '<span class="exp-badge">' + escape(meta.expectation) + '</span></div>'
      + '<div style="color:#999;font-size:11px">loading…</div>';

    const vk = meta.variant_key || '';
    const vkFile = (base, ext) => vk ? base + '_' + vk + '.' + ext : base + '.' + ext;
    const candidates = [
      vkFile('probe', 'log'), vkFile('summary', 'json'),
      vkFile('inspect_stub', 'json'), vkFile('install', 'log'), vkFile('symbols', 'log')
    ];
    let filesHtml = '';
    for (const fname of candidates) {
      try {
        const resp = await fetch(meta.output_rel + '/' + fname);
        if (resp.ok) {
          const txt = await resp.text();
          if (txt.length > 0)
            filesHtml += '<div class="detail-file"><h3>' + escape(fname) + '</h3>'
                       + '<pre>' + escape(txt) + '</pre></div>';
        }
      } catch (_) { }
    }
    actionDetail.innerHTML =
      '<div class="detail-hdr">' + escape(tag) + '</div>'
      + '<div class="detail-meta"><span class="badge ' + bcls + '">' + btxt + '</span>'
      + '<span class="exp-badge">' + escape(meta.expectation) + '</span></div>'
      + (filesHtml || '<p class="placeholder">No log files found.</p>');
  }

  // ── Diagram rendering & node clicks ─────────────────────────────────────
  let renderCounter = 0;
  async function renderView(name) {
    currentView = name;
    document.querySelectorAll('.view-btn').forEach(b =>
      b.classList.toggle('active', b.dataset.view === name));
    const v = VIEWS[name];
    if (!v) { diagramDiv.textContent = '(no view: ' + name + ')'; return; }
    diagramDiv.innerHTML = '<div style="color:#999">rendering…</div>';
    const id = 'mmd-' + (++renderCounter);
    highlightedNode = null;
    try {
      const { svg, bindFunctions } = await mermaid.render(id, v.mmd);
      diagramDiv.innerHTML = svg;
      if (bindFunctions) bindFunctions(diagramDiv);
      attachClicks(diagramDiv);
      updateActionListForView();
    } catch (err) {
      const msg = (err && err.message) ? err.message : String(err);
      diagramDiv.innerHTML =
        '<div style="color:#b71c1c;background:#ffebee;padding:12px;border-radius:4px;">'
        + '<b>Mermaid error</b><br><pre style="white-space:pre-wrap;font-size:12px;margin-top:8px">'
        + escape(msg) + '</pre></div>'
        + '<details style="margin-top:8px"><summary>view source (' + escape(name) + ')</summary>'
        + '<pre style="font-size:11px">' + escape(v.mmd) + '</pre></details>';
    }
  }

  function attachClicks(container) {
    container.querySelectorAll('g.node').forEach(g => {
      const id = g.id || '';
      // Mermaid SVG node ids: flowchart-{nodeId}-{seqIndex}
      // Greedy (.+) correctly strips the trailing -\d+ even when nodeId contains digits.
      const m = id.match(/^flowchart-(.+)-\d+$/);
      if (!m) return;
      const nodeId = m[1];
      let tag = null;
      if (nodeId.startsWith('S_')) {
        // mermaid_of_steps nodes
        const t = nodeId.slice(2);
        if (STEPS[t]) tag = t;
      } else if (nodeId.startsWith('A_')) {
        // schema-view action nodes; may be collapsed (multiple steps → one node)
        const t = nodeId.slice(2);
        if (STEPS[t]) tag = t;
        else tag = Object.keys(STEPS).find(k => k.startsWith(t + '_')) ?? null;
      }
      if (!tag) return;
      g.style.cursor = 'pointer';
      g.addEventListener('click', () => showStep(tag));
    });
  }

  // ── Init ─────────────────────────────────────────────────────────────────
  document.querySelectorAll('.view-btn').forEach(b =>
    b.addEventListener('click', () => renderView(b.dataset.view)));

  mermaid.initialize({ startOnLoad: false, theme: 'default', flowchart: { htmlLabels: true } });
  buildActionList();
  renderView(currentView);
</script>
</body>
</html>
|}
    project variant            (* title *)
    index_rel                  (* ← all runs href *)
    project variant run_at     (* header *)
    selector
    views_json steps_json
    (json_string default_view)

(* ── Top-level index page ──
   Lists every (project, variant) run found under _out/canary/projects/.
   Renders as a simple table with status counts and a link to each run's
   result.html. Usually written to _out/canary/projects/index.html. *)

let _status_inspect (e : index_entry) =
  let parts = ref [] in
  if e.failed_steps > 0 then
    parts := Printf.sprintf {|<span class="badge failed">%d failed</span>|}
              e.failed_steps :: !parts;
  if e.done_steps > 0 then
    parts := Printf.sprintf {|<span class="badge done">%d done</span>|}
              e.done_steps :: !parts;
  if e.skipped_steps > 0 then
    parts := Printf.sprintf {|<span class="badge skipped">%d skipped</span>|}
              e.skipped_steps :: !parts;
  String.concat ~sep:" " (List.rev !parts)

let _index_row (e : index_entry) =
  let html_escape s =
    String.concat_map s ~f:(function
      | '<' -> "&lt;" | '>' -> "&gt;" | '&' -> "&amp;" | c -> String.of_char c)
  in
  let row_status_class =
    if e.failed_steps > 0 then "row-failed"
    else if e.done_steps > 0 then "row-done"
    else "row-skipped"
  in
  Printf.sprintf
    {|<tr class="%s"><td><a href="%s">%s</a></td><td>%s</td><td>%s</td><td>%d</td><td>%s</td><td class="src">%s</td></tr>|}
    row_status_class
    (html_escape e.href)
    (html_escape e.project)
    (html_escape e.variant)
    (html_escape e.run_at)
    e.total_steps
    (_status_inspect e)
    (html_escape e.source_kind)

(* BOTH matrix links, unconditionally (2026-08-26): the result matrix is
   one file per platform ([Canary_matrix.matrix_filename] — Linux
   [matrix.html], macOS [matrix_mac.html]) until a cross-platform
   aggregating viewer lands. Listing both statically keeps this index
   BYTE-IDENTICAL whichever machine renders it; making the links
   conditional on file existence would have the two machines rewrite each
   other's committed index on every run, which is the churn the
   per-platform filename exists to avoid. The cost is one dead link until
   the other platform's first `canary result` is committed. *)
let render_index ~(entries : index_entry list) ~generated_at =
  (* Group by project, sort variants newest-first within each project. *)
  let by_project =
    List.sort entries ~compare:(fun a b -> String.compare a.project b.project)
    |> List.group ~break:(fun a b -> not (String.equal a.project b.project))
  in
  let project_sections =
    List.map by_project ~f:(fun group ->
        let project = match List.hd group with Some e -> e.project | None -> "" in
        let sorted = List.sort group ~compare:(fun a b ->
            String.compare b.run_at a.run_at) in
        let rows = List.map sorted ~f:_index_row |> String.concat ~sep:"\n      " in
        Printf.sprintf
          {|<section><h2>%s</h2>
<table>
  <thead><tr><th>variant</th><th>run at</th><th>steps</th><th>status</th><th>source</th></tr></thead>
  <tbody>
      %s
  </tbody>
</table></section>|}
          project rows)
    |> String.concat ~sep:"\n"
  in
  let total_runs = List.length entries in
  let total_failed =
    List.count entries ~f:(fun e -> e.failed_steps > 0)
  in
  Printf.sprintf {|<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>canary runs</title>
<style>
  body { font-family: system-ui, sans-serif; margin: 0; padding: 0; background: #fafafa; color: #222; }
  header { padding: 12px 24px; background: #fff; border-bottom: 1px solid #ddd; display: flex; align-items: center; gap: 16px; flex-wrap: wrap; }
  header h1 { margin: 0; font-size: 18px; }
  header .meta { color: #777; font-size: 13px; }
  main { padding: 24px; max-width: 1100px; margin: 0 auto; }
  section { margin-bottom: 32px; }
  section h2 { margin: 0 0 8px; font-size: 16px; color: #1976d2; border-bottom: 1px solid #eee; padding-bottom: 4px; }
  table { width: 100%%; border-collapse: collapse; background: #fff; border: 1px solid #ddd; border-radius: 4px; overflow: hidden; }
  th, td { text-align: left; padding: 8px 12px; border-bottom: 1px solid #eee; font-size: 13px; }
  th { background: #f5f5f5; font-weight: 600; color: #555; }
  tr:last-child td { border-bottom: none; }
  tr.row-failed td:first-child a { color: #c62828; font-weight: 600; }
  tr.row-done td:first-child a { color: #2e7d32; font-weight: 500; }
  tr.row-skipped td:first-child { color: #888; }
  td a { text-decoration: none; }
  td a:hover { text-decoration: underline; }
  td.src { color: #888; font-family: monospace; font-size: 11px; }
  .badge { display: inline-block; padding: 2px 8px; border-radius: 12px; font-size: 11px; font-weight: 600; margin-right: 4px; }
  .badge.done { background: #c8e6c9; color: #1b5e20; }
  .badge.failed { background: #ffcdd2; color: #b71c1c; }
  .badge.skipped { background: #e0e0e0; color: #555; }
  .empty { padding: 40px; text-align: center; color: #999; }
</style>
</head>
<body>
<header>
  <h1>canary runs</h1>
  <span class="meta">%d runs · %d with failures · generated %s</span>
  <a href="matrix.html" style="font-size: 13px;">result matrix</a>
  <a href="matrix_mac.html" style="font-size: 13px;">result matrix (mac)</a>
</header>
<main>
%s
</main>
</body>
</html>
|}
    total_runs total_failed generated_at
    (if List.is_empty entries
     then {|<p class="empty">No runs found. Run `canary action <project>` to populate.</p>|}
     else project_sections)
