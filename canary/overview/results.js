(function(){
var fd=document.getElementById('framesdata'), box=document.getElementById('rtable');
if(!fd||!box) return;
var FR; try{ FR=JSON.parse(fd.textContent); }catch(e){ return; }
var esc=function(s){ return String(s==null?'':s).replace(/&/g,'&amp;').replace(/</g,'&lt;')
  .replace(/>/g,'&gt;').replace(/"/g,'&quot;'); };
var rows=[];
(window.CANARY_RUNS||[]).forEach(function(r){
  (r.views||[]).forEach(function(w){ rows.push({m:r.machine,w:w}); }); });
if(!rows.length){ var nn=document.getElementById('rtnone'); if(nn) nn.hidden=false; return; }
rows.sort(function(a,b){ var x=a.w.project+'|'+a.w.id+'|'+a.m, y=b.w.project+'|'+b.w.id+'|'+b.m;
  return x<y?-1:x>y?1:0; });
var STEP={ran:['✓','rt-ok'],warm:['✓','rt-warm'],fail:['✗','rt-bad'],xfail:['xf','rt-xf'],
  blocked:['⊘','rt-bad'],unrecorded:['·','rt-dim'],absent:['—','rt-dim'],inside:['⌂','rt-dim'],
  included:['∈','rt-dim'],
  observed:['~','rt-dim'],not_ours:['~','rt-dim']};
var OUT={holds:['✓','rt-ok'],violated:['✗','rt-bad'],error:['err','rt-bad'],
  unavailable:['no-evid','rt-gap'],undeclared:['no-decl','rt-gap'],inconclusive:['no-ref','rt-gap'],
  vacuous:['none','rt-gap'],not_implemented:['planned','rt-gap'],not_applicable:['n/a','rt-dim'],
  'n/a':['n/a','rt-dim'],disabled:['off','rt-dim']};
var node=function(id){ return FR.nodes[id]||{label:id,layer:'art'}; };
var F=FR.frames, h1='<tr><th class="rt-lab" rowspan="3">chain · machine</th>', h2='<tr>', h3='<tr>', i=0;
while(i<F.length){ var s=F[i].side, lab=F[i].side_label, span=0;
  while(i<F.length&&F[i].side===s){ span+=F[i].cols.length; i++; }
  h1+='<th class="rt-side" colspan="'+span+'">'+esc(lab)+'</th>'; }
F.forEach(function(f){
  h2+='<th class="rt-fr" colspan="'+f.cols.length+'">'+esc(f.label)+'</th>';
  f.cols.forEach(function(c){
    if(c.k==='n'){ var n=node(c.id);
      h3+='<th class="rt-'+n.layer+'" title="'+esc(c.id)+'">'+esc(n.label)+'</th>'; }
    else if(c.k==='p')
      h3+='<th class="rt-hp rt-u-'+c.layer+'" title="'+esc(c.edges.join(', '))+'">'+esc(c.label)+'</th>';
    else
      h3+='<th class="rt-hc rt-u-'+c.layer+'" title="'+esc(c.slug+' — '+c.stage+', at '+c.site)+'">'
        +(c.stage==='pre'?'›':'»')+esc(c.code)+'</th>'; }); });
var body=rows.map(function(x){
  var v=x.w, key=v.id+'@'+x.m, gone=v.gone||[], edges=v.edges||{}, shown={};
  // a frame is in this chain when a step realized one of its pieces
  var on=function(f){ return f.cols.some(function(c){ return c.k==='p'&&c.edges.some(function(e){
    var st=edges[e]; return st&&st!=='absent'&&gone.indexOf(e)<0; }); }); };
  var tr='<tr id="row-'+esc(key)+'"><th class="rt-lab"><a href="#rec='+encodeURIComponent(key)
    +'" data-key="'+esc(key)+'"><b>'+esc(v.project)+'</b> '+esc(v.id)+'</a> <span class="rt-m">@'
    +esc(x.m)+'</span></th>';
  F.forEach(function(f){ var here=on(f);
    f.cols.forEach(function(c){
      if(c.k==='n'){ var n=node(c.id), cls='rt-'+n.layer;
        if(!here||gone.indexOf(c.id)>=0){ tr+='<td class="'+cls+' rt-off"></td>'; return; }
        var nm=(v.names||{})[c.id], label=nm?nm.label:'', from=nm?nm.from:'',
          place=(v.nodes||{})[c.id]||'';
        // the first cell of a node shows it; a later one is where it is consumed
        var full=[label,place].filter(function(t){ return t; }).join(' — ');
        if(shown[c.id]){ tr+='<td class="'+cls+' rt-rep" title="'+esc(full)+'">'+esc(label)+'</td>'; return; }
        shown[c.id]=1;
        var cnt=(v.counts||{})[c.id];
        tr+='<td class="'+cls+(from==='declared'?' rt-decl':'')+'" title="'+esc(full)+'">'
          +esc(label||place)+(cnt?' <span class="rt-x">'+esc(cnt)+'</span>':'')+'</td>'; }
      else if(c.k==='p'){
        if(!here){ tr+='<td class="rt-off"></td>'; return; }
        var st='absent';
        c.edges.forEach(function(e){ var s=edges[e]; if(s&&s!=='absent'&&st==='absent') st=s; });
        var mk=STEP[st]||['?','rt-dim'];
        tr+='<td class="rt-p '+mk[1]+'" title="'+esc(c.edges.join(', ')+': '+st)+'">'+mk[0]+'</td>'; }
      else {
        if(!here){ tr+='<td class="rt-off"></td>'; return; }
        var o=(v.outcomes||{})[c.slug], mk2=o?(OUT[o]||[o,'rt-dim']):['·','rt-dim'],
          b=(v.blames||{})[c.slug];
        tr+='<td class="rt-c '+mk2[1]+'" title="'+esc(c.slug+': '+(o||'not evaluated in any recorded run')
          +(b?' — blame: '+b+' ('+((FR.blames||{})[b]||'')+')':''))
          +'">'+esc(mk2[0])+'</td>'; } }); });
  return tr+'</tr>'; }).join('');
box.innerHTML='<thead>'+h1+h2+h3+'</thead><tbody>'+body+'</tbody>';
// a row's name draws its chain in §1
box.addEventListener('click',function(e){ var a=e.target.closest('a[data-key]'); if(!a) return;
  if(window.canaryDraw&&window.canaryDraw(a.dataset.key)) e.preventDefault(); });
})();
