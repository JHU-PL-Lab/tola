(function(){
// THE CHAIN, CHOSEN (§1). Five choices — the two package managers, the
// mechanism, the cooperation — or a package in canary, which sets the
// other four, names the nodes, and draws its recorded run where a machine
// recorded one. Every set a choice draws is in #joindata
// (canary_overview_join.ml), every recorded word in the per-machine
// overview_runs.js (canary_overview_runs.ml); this keeps the state, looks
// them up and applies them.
var jbox=document.getElementById('join'), J=null;
try{ J=JSON.parse(document.getElementById('joindata').textContent); }catch(e){}
if(jbox&&J){
  var S={m:J.default.m, k:J.default.k, ps:null, pl:J.default.pl, c:null, v:null, hl:null};
  var jesc=function(s){ var d=document.createElement('span'); d.textContent=s; return d.innerHTML; };
  var caseOf=function(id){
    for(var i=0;i<J.cases.length;i++) if(J.cases[i].id===id) return J.cases[i];
    return null; };
  // every machine's recorded worlds, by the package each realizes
  var VIEWS={}, BYCASE={};
  (window.CANARY_RUNS||[]).forEach(function(r){
    (r.views||[]).forEach(function(w){
      w.key=w.id+'@'+r.machine; w.machine=r.machine; VIEWS[w.key]=w;
      (BYCASE[w['case']]=BYCASE[w['case']]||[]).push(w); }); });
  var STATES=['ran','warm','xfail','fail','blocked','unrecorded','absent','inside','included','not_ours','observed','claim'],
      OUTS=['violated','holds','partial','undecided','unevaluated'];
  // a line longer than its box is squeezed to fit rather than cut: every
  // character stays readable on hover-zoom, and none spills onto an edge
  var fit=function(t, w){ if(!t) return;
    t.removeAttribute('textLength'); t.removeAttribute('lengthAdjust');
    try{ if(t.textContent&&t.getComputedTextLength()>w){
      t.setAttribute('textLength', w); t.setAttribute('lengthAdjust','spacingAndGlyphs'); } }catch(e){} };
  var list=function(id, head, items){ var el=document.getElementById(id); if(!el) return;
    el.innerHTML=items.length?'<p class="mechnote"><strong>'+head+'</strong></p><ul class="unpl">'
      +items.join('')+'</ul>':''; };
  var key=function(){ return S.k+'|'+(S.ps||'*')+'|'+(S.pl||'*'); };
  var draw=function(){
    // every answer below is computed in canary_overview_draw.ml and
    // looked up here: a recorded world's own, else its package's, else
    // the four buttons' choice
    var c=S.c&&caseOf(S.c), v=c&&S.v?VIEWS[S.v]:null, ch=c?{}:(J.choices[key()]||{}),
        mech=J.mechanisms[S.m]||{},
        band=c||(ch.band?J.bands[ch.band]:null)||{gone:[],dead:[]},
        gone=v?(v.gone||[]):(mech.gone||[]).concat(band.gone||[]),
        dead=v?[]:(band.dead||[]), lines=(c?c.lines:ch.lines)||{},
        related=(!c&&S.hl&&J.related[S.hl])||[];
    // the line under a node: a recorded name first, then the package's or
    // the choice's, each with its source
    var lineOf=function(id){ return (v&&v.lines&&v.lines[id])||lines[id]||null; };
    var prov=[];
    jbox.classList.toggle('rec', !!v);
    jbox.querySelectorAll('[data-edge]').forEach(function(g){
      var e=g.getAttribute('data-edge'), t=g.querySelector('title'), mk=g.querySelector('.phm');
      g.classList.toggle('gone', gone.indexOf(e)>=0);
      g.classList.toggle('jdead', dead.indexOf(e)>=0);
      STATES.forEach(function(s){ g.classList.remove('st-'+s); });
      OUTS.forEach(function(o){ g.classList.remove('cl-'+o); });
      if(t&&g.dataset.gtitle===undefined) g.dataset.gtitle=t.textContent;
      var obs=v&&(v.observed||{})[e], ph=v&&(v.placeholders||{})[e];
      if(v){ g.classList.add('st-'+(v.edges[e]||'absent'));
        if(v.badges[e]) g.classList.add('cl-'+v.badges[e]); }
      // THE BADGES (2026-09-24): the agreements on this edge that apply to
      // the chain drawn — a recorded run's own list, else its mechanism's —
      // filled for the checked ones, hollow for the placeholders
      var cl=((v?v.edge_claims:mech.claims)||{})[e]||[],
          cn=((v?v.edge_counts:mech.counts)||{})[e]||[0,0], nc=cn[0], np=cn[1],
          bc=g.querySelector('.cbadge.chk'), tc=g.querySelector('.cnum.chk'),
          bp=g.querySelector('.cbadge.cand'), tp=g.querySelector('.cnum.cand');
      if(bc&&tc&&bp&&tp){
        bc.classList.toggle('none',!nc); tc.classList.toggle('none',!nc); tc.textContent=nc;
        bp.classList.toggle('none',!np); tp.classList.toggle('none',!np); tp.textContent=np;
        var hx=nc?bp.dataset.x2:bp.dataset.x1; bp.setAttribute('cx',hx); tp.setAttribute('x',hx); }
      // the edge's own description, what this run recorded there, and the
      // agreements its badges count — one on several edges says so
      var listed=cl.map(function(x){ var a=J.agreements[x[0]]||{},
          also=(a.edges||[]).filter(function(y){ return y!==e; });
        return (a.code?a.code+' ':'')+x[0]+' — '+x[1]+(also.length?' (also on '+also.join(', ')+')':''); });
      if(t) t.textContent=g.dataset.gtitle+(obs?' — recorded here: '+obs:'')
        +(listed.length?'\nagreements here:\n'+listed.join('\n'):'');
      // the placeholder marker: where a package manager did something
      // inside our action that this run does not record
      if(mk){ mk.classList.toggle('on', !!ph);
        mk.classList.toggle('not_yet', !!ph && ph.some(function(x){ return x.unseen==='not_yet'; }));
        var mt=mk.querySelector('title');
        if(mt) mt.textContent=ph?ph.map(function(x){ return x.text; }).join('\n'):''; } });
    jbox.querySelectorAll('[data-node]').forEach(function(g){
      var id=g.getAttribute('data-node'), l=g.querySelector('.nlabel'),
          s=g.querySelector('.ncase'), pe=g.querySelector('.nplace'), n=lineOf(id),
          line=n?n.text:'', place=v&&v.nodes?(v.nodes[id]||''):'';
      g.classList.toggle('gone', gone.indexOf(id)>=0);
      g.classList.toggle('dim', !!v && (v.dim||[]).indexOf(id)>=0);
      // the package nodes the last clicked button is about
      g.classList.toggle('related', related.indexOf(id)>=0);
      if(s){ s.textContent=line;
        s.classList.toggle('rec-name', !!n && n.from==='recorded');
        s.classList.toggle('term', !!n && n.kind==='term');
        s.setAttribute('y', place?s.dataset.y2:s.dataset.y1); }
      if(pe) pe.textContent=place;
      // squeezed to the node's own box, which is narrower for a source
      var box=g.querySelector('rect'), bw=(box?+box.getAttribute('width'):208)-12;
      fit(s, bw); fit(pe, bw);
      if(l&&l.dataset.y0) l.setAttribute('y', place?l.dataset.y2:(line?l.dataset.y1:l.dataset.y0));
      var lab=l?l.textContent:id;
      if(line) prov.push([lab, n.kind, line, n.src]);
      if(place) prov.push([lab, 'placement', place, (v.place_sources||{})[id]]); });
    // the list under the diagram: every line above, with its source
    var pb=document.getElementById('jprovbody'), psum=document.getElementById('jprovsum');
    if(pb){ var cnt={};
      pb.innerHTML=prov.map(function(p){ var s=p[3], k=s?s.kind:'none'; cnt[k]=(cnt[k]||0)+1;
        return '<tr><td>'+jesc(p[0])+'</td><td>'+p[1]+'</td><td><code>'+jesc(p[2])+'</code></td><td>'
          +(s?'<span class="src '+k+'">'+k+'</span> '+(k==='run'?'<code>'+jesc(s.what)+'</code>':jesc(s.what))
            +' — <code>'+jesc(s.at)+'</code>':'<span class="src render">no source</span>')+'</td></tr>'; }).join('');
      if(psum) psum.innerHTML=prov.length
        ?'Where the '+prov.length+' line'+(prov.length===1?'':'s')+' under the node labels come from: '
          +['code','run','render','none'].filter(function(k){ return cnt[k]; }).map(function(k){
            return cnt[k]+' <span class="src '+(k==='none'?'render':k)+'">'+(k==='none'?'no source':k)+'</span>'; }).join(' · ')
        :'No line is written under a node label in this drawing.'; }
    var ids=J.runs[S.m+'|'+key()]||[];
    jbox.querySelectorAll('button[data-g]').forEach(function(b){
      var g=b.dataset.g, val=b.dataset.v;
      b.classList.toggle('on', g==='c' ? S.c===val : S[g]===val);
      // the packages the choice picks out, while none is chosen
      if(g==='c') b.classList.toggle('hint', !c && ids.indexOf(val)>=0); });
    // a cooperation says what it is whether or not a package is chosen;
    // its band's note only while none is
    jbox.querySelectorAll('.jnote').forEach(function(p){
      var d=p.dataset;
      p.hidden=!((d.jm&&d.jm===S.m)||(d.jk&&d.jk===S.k)||(d.jkb&&!c&&d.jkb===S.k)
                ||(d.jc&&d.jc===S.c)||(d.jpm&&(d.jpm===S.ps||d.jpm===S.pl))); });
    // how many chains the cooperation's band was drawn from, as narrowed
    if(!c&&band.n) jbox.querySelectorAll('.jcount').forEach(function(x){ x.textContent=band.n; });
    var runs=document.getElementById('jruns'), miss=document.getElementById('jmiss');
    if(runs){
      var seen={}, who=[];
      ids.forEach(function(id){ var x=caseOf(id), w=x?x.project+' ('+x.lang+')':id;
        if(!seen[w]){ seen[w]=1; who.push(w); } });
      runs.innerHTML=who.length?'<strong>Canary runs this chain:</strong> '+jesc(who.sort().join(', '))+' (§3.4).'
        :'No chain canary runs has this choice.'; }
    // why the band drawn is not the choice's own
    if(miss){ var why=ch.note||''; miss.textContent=why; miss.hidden=!why; }
    // THE RECORDED RUN (merged from the retired §2.1): which world is
    // drawn, and everything it recorded or could not
    var worlds=c?(BYCASE[c.id]||[]):[], bar=document.getElementById('jrecbar'),
        sel=document.getElementById('jworld'), norec=document.getElementById('jnorec'),
        recd=document.getElementById('jrec');
    if(bar) bar.hidden=!v;
    if(recd) recd.hidden=!v;
    if(norec) norec.hidden=!(c&&!worlds.length);
    if(sel){ sel.innerHTML='';
      worlds.forEach(function(w){ var o=document.createElement('option'); o.value=w.key;
        o.textContent=w.scenario+' ('+w.machine+')'; o.selected=(w.key===S.v); sel.appendChild(o); }); }
    if(!v) return;
    var head=document.getElementById('jrechead');
    if(head) head.textContent=v.project+' — '+v.lang+' — '+v.scenario+' — recorded on '
      +(v.recorded_on.length?v.recorded_on.join(', '):'(no platform logged)')
      +(v.span?' — '+v.span[0]+' … '+v.span[1]:' — nothing recorded yet')
      +(v.chain?'\nchain: '+v.chain.mechanism+' · '+v.chain.lang_side+' ↔ '
        +v.chain.native_side+' · '+v.chain.character:'');
    // …and back to its row in §1.2
    if(head){ var ra=document.createElement('a'); ra.href='#row-'+v.key;
      ra.textContent='its row in §1.2';
      head.appendChild(document.createTextNode('\n')); head.appendChild(ra); }
    var ob=v.observed||{};
    list('jrecobserved','What this run recorded around the bridge:',
      Object.keys(ob).map(function(e){ return '<li><code>'+jesc(e)+'</code> — '+jesc(ob[e])+'</li>'; }));
    var phs=v.placeholders||{}, byText={}, order=[];
    Object.keys(phs).forEach(function(e){ phs[e].forEach(function(x){
      if(!byText[x.text]){ byText[x.text]={unseen:x.unseen, edges:[]}; order.push(x.text); }
      byText[x.text].edges.push(e); }); });
    list('jrecph','What the package managers did here that this run does not record:',
      order.map(function(tx){ var p=byText[tx];
        return '<li><b>'+(p.unseen==='not_yet'?'not recorded yet':'out of reach')+'</b> — '
          +jesc(tx)+' <span class="from">('+p.edges.map(function(e){ return '<code>'+jesc(e)+'</code>'; }).join(', ')
          +')</span></li>'; }));
    var cl=Object.keys(v.claims||{}), cand=v.candidates||[], ce=document.getElementById('jrecclaims');
    if(ce) ce.innerHTML=(cl.length
      ?'<p class="mechnote"><strong>Claims the graph places, in this world:</strong> '
        +cl.map(function(x){ return '<code>'+jesc(x)+'</code> <span class="o-'+v.claims[x]+'">'
          +jesc(v.claims[x])+'</span>'; }).join(' · ')+'</p>':'')
      // a placeholder claim applies only where its edge exists in this chain
      +(cand.length?'<p class="mechnote"><strong>Placeholder claims that apply to this chain</strong> — named, no evaluator: '
        +cand.map(function(x){ return '<code>'+jesc(x)+'</code>'; }).join(' · ')+'</p>':'');
    var up=Object.keys(v.unplaced||{});
    list('jrecunplaced','Steps of this world with no edge on the page:',
      up.map(function(tg){ return '<li><code>'+jesc(tg)+'</code> — '+jesc(v.unplaced[tg])+'</li>'; }));
  };
  var pick=function(g,val){
    if(g==='m'){ S.m=val; var d=(J.mechanisms[val]||{}).pl; if(d) S.pl=d; }
    else if(g==='ps'){ S.ps=(S.ps===val?null:val); }
    else if(g==='pl'){ S.pl=(S.pl===val?null:val); }
    else if(g==='k'){ S.k=val; S.c=null; }
    else if(g==='c'){ var x=caseOf(val); if(x){ S.c=val; S.m=x.m; S.k=x.k; S.ps=x.ps; S.pl=x.pl;
      var ws=BYCASE[val]||[]; S.v=ws.length?ws[0].key:null; } }
    // the package nodes a non-package button is about; a package names
    // its own nodes instead, and a package manager clicked off lights none
    S.hl=(g==='c'||(g==='ps'&&!S.ps)||(g==='pl'&&!S.pl))?null:g+'|'+val;
    // a package stays chosen only while every choice agrees with it
    var c=S.c&&caseOf(S.c);
    if(c&&(c.m!==S.m||c.k!==S.k||c.ps!==S.ps||c.pl!==S.pl)) S.c=null;
    if(!S.c) S.v=null;
    draw();
  };
  jbox.addEventListener('click',function(e){
    var b=e.target.closest('button[data-g]'); if(b) pick(b.dataset.g,b.dataset.v); });
  // each component's box on its own button: a way of looking at the
  // chain, kept across choices
  var fig=jbox.querySelector('svg.diagram');
  if(fig) jbox.querySelectorAll('button[data-box]').forEach(function(b){
    b.addEventListener('click',function(){
      var on=b.classList.toggle('on');
      fig.querySelectorAll('.cbx[data-c="'+b.dataset.box+'"]').forEach(function(g){
        g.classList.toggle('shown',on); }); }); });
  var wsel=document.getElementById('jworld');
  if(wsel) wsel.addEventListener('change',function(){ S.v=wsel.value; draw(); });
  // #chain=<id> — §3.4's rows link here; #rec=<world> — one recorded world
  var h=/#chain=([^&]+)/.exec(location.hash), r=/#rec=([^&]+)/.exec(location.hash),
      want=h?decodeURIComponent(h[1]):null, world=r?decodeURIComponent(r[1]):null;
  var go=function(id,w){ if(caseOf(id)){ pick('c',id); if(w&&VIEWS[w]){ S.v=w; draw(); }
    jbox.scrollIntoView(); } };
  // §1.2's rows draw their chain here
  window.canaryDraw=function(key){ var w=VIEWS[key]; if(!w) return false; go(w['case'],key); return true; };
  if(world&&VIEWS[world]) go(VIEWS[world]['case'],world);
  else if(want&&caseOf(want)) go(want);
  else draw();
  document.querySelectorAll('a[href^="#chain="]').forEach(function(a){
    a.addEventListener('click',function(e){ e.preventDefault();
      go(decodeURIComponent(a.getAttribute('href').slice(7))); }); });
}
// hovering an edge fills the detail strip. The SVG <title> is still
// there for keyboard and for people who hover slowly, but a strip that
// stays put is readable while comparing two edges.
var strip=document.getElementById('edet');
if(strip){
  document.querySelectorAll('svg .edge').forEach(function(g){
    g.addEventListener('mouseenter',function(){
      var t=g.querySelector('title');
      strip.textContent = t ? t.textContent : '';
      strip.classList.add('lit');
    });
    g.addEventListener('mouseleave',function(){ strip.classList.remove('lit'); });
  });
}
})();
