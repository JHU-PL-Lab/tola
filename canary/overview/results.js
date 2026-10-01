(function(){
// §1.2's rows: each runs file carries its machine's, their cells computed
// in canary_overview_results.ml and filed by column; this lays them out
// under the page's columns
var cd=document.getElementById('rtcols'), tb=document.getElementById('rtbody'),
    box=document.getElementById('tab-results');
if(!cd||!tb||!box) return;
var C; try{ C=JSON.parse(cd.textContent); }catch(e){ return; }
var rows=[];
(window.CANARY_RUNS||[]).forEach(function(r){
  (r.views||[]).forEach(function(w){ if(w.row) rows.push(w.row); }); });
if(!rows.length){ var nn=document.getElementById('rtnone'); if(nn) nn.hidden=false; return; }
rows.sort(function(a,b){ return a.sort<b.sort?-1:a.sort>b.sort?1:0; });
tb.innerHTML=rows.map(function(r){
  return r.head+C.keys.map(function(k){ return (r.cells||{})[k]||C.missing; }).join('')+'</tr>'; }).join('');
// a row's name draws its chain in §1
box.addEventListener('click',function(e){ var a=e.target.closest('a[data-key]'); if(!a) return;
  if(window.canaryDraw&&window.canaryDraw(a.dataset.key)) e.preventDefault(); });
})();
