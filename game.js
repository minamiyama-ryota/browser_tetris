(function(){
"use strict";
var FW=10,FH=20,BS=26,NB=18,CDUR=50,GARB_MAX=8;
var NEXT_COUNT=6; // 内部は常に6個保持
var NEXT_SHOW=3;  // 表示数(1~6, 開始画面で設定)
var CS_DATA=[
{k:'neon',I:'#44e5f7',O:'#f7e944',T:'#c76bfa',S:'#5afa6b',Z:'#fa5a5a',J:'#5a8afa',L:'#faa95a',G:'#888'},
{k:'candy',I:'#ff90c0',O:'#ffe060',T:'#d080ff',S:'#80ffa0',Z:'#ff8080',J:'#80b0ff',L:'#ffb870',G:'#d0b0c0'},
{k:'mint',I:'#60d8b0',O:'#e8e060',T:'#b080e0',S:'#70e890',Z:'#e88080',J:'#70a0e0',L:'#e0a868',G:'#a0c8b0'},
{k:'sky',I:'#60c0f0',O:'#f0e060',T:'#b888e8',S:'#70e080',Z:'#f08888',J:'#6898e8',L:'#e8a860',G:'#a0b8d0'},
{k:'retro',I:'#00e8e8',O:'#e8e800',T:'#e000e0',S:'#00e800',Z:'#e80000',J:'#0000e8',L:'#e88800',G:'#666'}
];
var CS_KEYS=['neon','candy','mint','sky','retro'],curCS=0;
function COL(t){return CS_DATA[curCS][t];}
function GCOL(){return CS_DATA[curCS].G;}
var SH={
I:[[[0,0],[1,0],[2,0],[3,0]],[[0,0],[0,1],[0,2],[0,3]],[[0,0],[1,0],[2,0],[3,0]],[[0,0],[0,1],[0,2],[0,3]]],
O:[[[0,0],[1,0],[0,1],[1,1]],[[0,0],[1,0],[0,1],[1,1]],[[0,0],[1,0],[0,1],[1,1]],[[0,0],[1,0],[0,1],[1,1]]],
T:[[[0,0],[1,0],[2,0],[1,1]],[[1,0],[0,1],[1,1],[1,2]],[[1,0],[0,1],[1,1],[2,1]],[[0,0],[0,1],[1,1],[0,2]]],
S:[[[1,0],[2,0],[0,1],[1,1]],[[0,0],[0,1],[1,1],[1,2]],[[1,0],[2,0],[0,1],[1,1]],[[0,0],[0,1],[1,1],[1,2]]],
Z:[[[0,0],[1,0],[1,1],[2,1]],[[1,0],[0,1],[1,1],[0,2]],[[0,0],[1,0],[1,1],[2,1]],[[1,0],[0,1],[1,1],[0,2]]],
J:[[[0,0],[0,1],[1,1],[2,1]],[[0,0],[1,0],[0,1],[0,2]],[[0,0],[1,0],[2,0],[2,1]],[[1,0],[1,1],[0,2],[1,2]]],
L:[[[2,0],[0,1],[1,1],[2,1]],[[0,0],[0,1],[0,2],[1,2]],[[0,0],[1,0],[2,0],[0,1]],[[0,0],[1,0],[1,1],[1,2]]]
};
var PT=['I','O','T','S','Z','J','L'],LSC=[0,100,350,600,1000];
var BG=['midnight','ocean','deepspace','cream','lavender','skyblue'],bgI=0;
var CLR_FX=[null,{c:'rgba(200,230,255,.9)',g:'rgba(150,200,255,'},{c:'rgba(200,255,150,.9)',g:'rgba(150,255,100,'},{c:'rgba(255,220,100,.95)',g:'rgba(255,200,50,'},{c:'rgba(255,130,180,.95)',g:'rgba(255,80,150,'}];
function $(id){return document.getElementById(id);}
var g1,g2;
var nextCanvases1=[],nextCanvases2=[];

/* NEXT canvas 動的生成 */
function buildNextCanvases(){
  var nw1=$('nw1'),nw2=$('nw2');
  nw1.innerHTML='';nw2.innerHTML='';
  nextCanvases1=[];nextCanvases2=[];
  for(var i=0;i<NEXT_SHOW;i++){
    var c1=document.createElement('canvas');
    c1.className='nc';c1.width=NB*5;c1.height=NB*4;
    var lbl1=document.createElement('div');
    lbl1.className='nl';lbl1.textContent=(i+1)+'';
    nw1.appendChild(c1);nw1.appendChild(lbl1);
    nextCanvases1.push({c:c1,x:c1.getContext('2d')});

    var c2=document.createElement('canvas');
    c2.className='nc';c2.width=NB*5;c2.height=NB*4;
    var lbl2=document.createElement('div');
    lbl2.className='nl';lbl2.textContent=(i+1)+'';
    nw2.appendChild(c2);nw2.appendChild(lbl2);
    nextCanvases2.push({c:c2,x:c2.getContext('2d')});
  }
}

function initC(){
  function ic(id,w,h){var e=$(id);e.width=w;e.height=h;return{c:e,x:e.getContext('2d')};}
  g1=ic('c1',FW*BS,FH*BS);g2=ic('c2',FW*BS,FH*BS);
  buildNextCanvases();
}
function mkB(){var b=[];for(var r=0;r<FH;r++){var row=[];for(var c=0;c<FW;c++)row.push(null);b.push(row);}return b;}
function cpB(b){var n=[];for(var i=0;i<b.length;i++)n.push(b[i].slice());return n;}
function rnd(){return PT[Math.floor(Math.random()*PT.length)];}
function ok(t,r,x,y,b){var s=SH[t][r];for(var i=0;i<s.length;i++){var bx=x+s[i][0],by=y+s[i][1];if(bx<0||bx>=FW||by>=FH)return false;if(by>=0&&b[by][bx]!==null)return false;}return true;}
var shLv=1,shLn=0;
function calcDI(){return Math.max(80,1000-(shLv-1)*80);}
function addLn(n){shLn+=n;shLv=Math.floor(shLn/10)+1;var di=calcDI();p1.di=di;p2.di=di;$('slv').textContent=shLv;$('sln').textContent=shLn;}
function getGD(){return parseInt($('gdel').value)*100;}

/* 開始画面スライダー */
$('wset').addEventListener('input',function(){$('wval').textContent=this.value;});
$('hset').addEventListener('input',function(){$('hval').textContent=this.value;});
$('nset').addEventListener('input',function(){$('nval').textContent=this.value;});
$('gdel0').addEventListener('input',function(){$('gdv0').textContent=(parseInt(this.value)*0.1).toFixed(1)+'s';});
$('gmax0').addEventListener('input',function(){$('gmv0').textContent=this.value;});
$('gdel').addEventListener('input',function(){$('gdv').textContent=(parseInt(this.value)*0.1).toFixed(1)+'s';});

function mkP(id){return{id:id,b:mkB(),t:null,r:0,px:0,py:0,np:[],sc:0,lc:0,go:false,di:1000,ldt:0,ai:true,at:null,aq:[],amt:0,cr:null,caS:-1,clC:0,gP:0,gT:-1};}
var p1,p2,gover,pau,aid,started=false;
function enemy(p){return p===p1?p2:p1;}

function fillNp(p){
  while(p.np.length<NEXT_COUNT)p.np.push(rnd());
}

function spawn(p){
  p.t=p.np[0];p.r=0;p.px=Math.floor(FW/2)-1;p.py=0;
  p.np.shift();
  fillNp(p);
  if(!ok(p.t,p.r,p.px,p.py,p.b)){p.go=true;chkEnd();return;}
  if(p.ai)aiCalc(p);
}
function mv(p,dx,dy){if(ok(p.t,p.r,p.px+dx,p.py+dy,p.b)){p.px+=dx;p.py+=dy;return true;}return false;}
function rot2(p){var nr=(p.r+1)%4,ks=[0,-1,1,-2,2];for(var i=0;i<ks.length;i++){if(ok(p.t,nr,p.px+ks[i],p.py,p.b)){p.r=nr;p.px+=ks[i];return;}}}
function hardDrop(p){while(mv(p,0,1)){}lock(p);}
function lock(p){
  var s=SH[p.t][p.r];for(var i=0;i<s.length;i++){var bx=p.px+s[i][0],by=p.py+s[i][1];if(by<0){p.go=true;chkEnd();return;}p.b[by][bx]=p.t;}
  p.t=null;var rows=[];for(var r=0;r<FH;r++){var full=true;for(var c=0;c<FW;c++){if(p.b[r][c]===null){full=false;break;}}if(full)rows.push(r);}
  if(rows.length>0){p.cr=rows;p.caS=-1;p.clC=rows.length;}else{spawn(p);}
}
function finCl(p,ts){
  var cl=p.clC;p.cr.sort(function(a,b){return a-b;});
  for(var i=p.cr.length-1;i>=0;i--){p.b.splice(p.cr[i],1);var row=[];for(var c=0;c<FW;c++)row.push(null);p.b.unshift(row);}
  p.sc+=LSC[Math.min(cl,4)]*shLv;p.lc+=cl;addLn(cl);p.cr=null;p.caS=-1;p.clC=0;
  /* 行消しでお邪魔遅延リセット */
  var send=cl;
  if(p.gP>0){
    var cancel=Math.min(p.gP,send);p.gP-=cancel;send-=cancel;
    if(p.gP>0){p.gT=ts;} /* 遅延タイマーリセット */
    else{p.gP=0;p.gT=-1;}
    uG(p);
  }
  if(send>0){var en=enemy(p);en.gP+=send;if(en.gT<0)en.gT=ts;if(en.gP>=GARB_MAX)doGarb(en);uG(en);}
  uUI(p);spawn(p);
}
function doGarb(p){var cnt=p.gP;p.gP=0;p.gT=-1;uG(p);pushG(p,cnt);}
function pushG(p,cnt){
  if(cnt<=0||p.go)return;
  for(var i=0;i<cnt;i++){
    p.b.shift();var row=[];
    /* お邪魔ブロック: 1行に2か所以上穴を空ける */
    var holeCount=2+Math.floor(Math.random()*2); /* 2~3個の穴 */
    var holes={};
    while(Object.keys(holes).length<holeCount){
      holes[Math.floor(Math.random()*FW)]=true;
    }
    for(var c=0;c<FW;c++)row.push(holes[c]?null:'G');
    p.b.push(row);
  }
  if(p.t!==null&&!ok(p.t,p.r,p.px,p.py,p.b)){var esc=false;for(var dy=1;dy<=cnt+2;dy++){if(ok(p.t,p.r,p.px,p.py-dy,p.b)){p.py-=dy;esc=true;break;}}if(!esc){p.go=true;chkEnd();}}
  if(p.ai&&p.t!==null&&!p.go)aiCalc(p);
}
function uG(p){
  var pct=GARB_MAX>0?Math.min(100,p.gP/GARB_MAX*100):0;
  $('gf'+p.id).style.width=pct+'%';
  /* 遅延ゲージ: 残り遅延を半透明で重ねる */
  var gDelay=getGD();
  var delPct=0;
  if(p.gP>0&&p.gT>0&&gDelay>0){
    var elapsed=performance.now()-p.gT;
    var remain=Math.max(0,gDelay-elapsed);
    delPct=remain/gDelay*100;
  }
  $('gd'+p.id).style.width=delPct+'%';
  /* 常に最大行数を表示 */
  $('g'+p.id).textContent=p.gP+'/'+GARB_MAX;
}
function uUI(p){$('s'+p.id).textContent=p.sc;$('ln'+p.id).textContent=p.lc;}
function chkEnd(){
  if(!p1.go&&!p2.go)return;gover=true;if(aid)cancelAnimationFrame(aid);
  $('fs1').textContent=p1.sc;$('fs2').textContent=p2.sc;var w=$('wt');
  if(p1.go&&p2.go){w.textContent=p1.sc>p2.sc?'🏆 1P WIN!':p2.sc>p1.sc?'🏆 2P WIN!':'🤝 DRAW!';w.style.color=p1.sc>=p2.sc?'#5ef0ff':'#ff7eb3';}
  else if(p1.go){w.textContent='🏆 2P WIN!';w.style.color='#ff7eb3';}
  else{w.textContent='🏆 1P WIN!';w.style.color='#5ef0ff';}
  $('gov').classList.remove('hid');
}

/* ===== AI ===== */
function colH(b){var h=[];for(var c=0;c<FW;c++){h[c]=0;for(var r=0;r<FH;r++){if(b[r][c]!==null){h[c]=FH-r;break;}}}return h;}
function evB(b){
  var h=colH(b),aH=0;for(var i=0;i<FW;i++)aH+=h[i];
  var ho=0;for(var c=0;c<FW;c++){var f=false;for(var r=0;r<FH;r++){if(b[r][c]!==null)f=true;else if(f)ho++;}}
  var bu=0;for(var j=0;j<FW-1;j++)bu+=Math.abs(h[j]-h[j+1]);
  var mH=0;for(var k=0;k<FW;k++){if(h[k]>mH)mH=h[k];}
  var bah=0;for(var c2=0;c2<FW;c2++){var ab=0;for(var r2=0;r2<FH;r2++){if(b[r2][c2]!==null)ab++;else if(ab>0)bah+=ab;}}
  var af=0;for(var r3=0;r3<FH;r3++){var fl=0;for(var c3=0;c3<FW;c3++){if(b[r3][c3]!==null)fl++;}if(fl>=FW-1)af+=2.0;else if(fl>=FW-2)af+=0.8;}
  /* 行消し優先・積み上げ回避の重み付け */
  var sc=-0.75*aH-8.0*ho-0.25*bu-0.40*mH-4.0*bah+af;
  if(mH>FH*0.6)sc-=(mH-FH*0.6)*5;
  if(mH>FH*0.75)sc-=(mH-FH*0.75)*10;
  if(mH>FH*0.85)sc-=(mH-FH*0.85)*25;
  return sc;
}
function simP(b,type,rot,tx){
  if(!ok(type,rot,tx,0,b))return null;var y=0;while(ok(type,rot,tx,y+1,b))y++;
  var nb=cpB(b);var s=SH[type][rot];for(var i=0;i<s.length;i++){var bx=tx+s[i][0],by=y+s[i][1];if(by<0)return null;nb[by][bx]=type;}
  var cl=0;for(var r=FH-1;r>=0;r--){var f=true;for(var c=0;c<FW;c++){if(nb[r][c]===null){f=false;break;}}if(f){nb.splice(r,1);var row=[];for(var c2=0;c2<FW;c2++)row.push(null);nb.unshift(row);cl++;r++;}}
  return{b:nb,cl:cl};
}
function allP(b,type){
  var pl=[],seen={};for(var rot=0;rot<4;rot++){var s=SH[type][rot];var mn=s[0][0],mx=s[0][0];for(var i=1;i<s.length;i++){if(s[i][0]<mn)mn=s[i][0];if(s[i][0]>mx)mx=s[i][0];}
  for(var x=-mn;x<=FW-1-mx;x++){var key=rot+','+x;if(seen[key])continue;seen[key]=true;var res=simP(b,type,rot,x);if(res)pl.push({x:x,r:rot,b:res.b,cl:res.cl});}}return pl;
}
function clB(cl){return cl>=4?30:cl===3?15:cl===2?7:cl===1?3:0;}

/* 多段先読みAI (ビームサーチ風) */
function findBestDeep(b,curT,npArr){
  var depth=Math.min(npArr.length,NEXT_SHOW); /* NEXT表示数分先読み */
  if(depth<1)depth=1;
  var BEAM_W=depth<=2?40:depth<=3?20:depth<=4?12:8;

  /* 1手目: 全配置を列挙 */
  var cpl=allP(b,curT);
  if(cpl.length===0)return null;

  var beam=[];
  for(var i=0;i<cpl.length;i++){
    var sc=evB(cpl[i].b)+clB(cpl[i].cl);
    beam.push({move:{x:cpl[i].x,r:cpl[i].r},b:cpl[i].b,score:sc});
  }
  /* ビーム幅で刈り込み */
  beam.sort(function(a,b2){return b2.score-a.score;});
  if(beam.length>BEAM_W)beam=beam.slice(0,BEAM_W);

  /* 2手目以降 */
  for(var d=0;d<depth;d++){
    var nextT=npArr[d];
    if(!nextT)break;
    var newBeam=[];
    for(var bi=0;bi<beam.length;bi++){
      var npl=allP(beam[bi].b,nextT);
      if(npl.length===0){
        newBeam.push(beam[bi]);
        continue;
      }
      var bestNs=-Infinity,bestNb=null;
      for(var ni=0;ni<npl.length;ni++){
        var ns=evB(npl[ni].b)+clB(npl[ni].cl);
        if(ns>bestNs){bestNs=ns;bestNb=npl[ni].b;}
      }
      newBeam.push({move:beam[bi].move,b:bestNb,score:beam[bi].score*0.3+bestNs*0.7});
    }
    newBeam.sort(function(a,b2){return b2.score-a.score;});
    if(newBeam.length>BEAM_W)newBeam=newBeam.slice(0,BEAM_W);
    beam=newBeam;
  }

  if(beam.length===0)return null;
  beam.sort(function(a,b2){return b2.score-a.score;});
  return beam[0].move;
}

function aiCalc(p){
  if(!p.t||p.go)return;
  var best=findBestDeep(p.b,p.t,p.np);
  if(!best){p.at=null;p.aq=[];return;}p.at=best;p.aq=[];
  var rotN=(best.r-p.r+4)%4;for(var i=0;i<rotN;i++)p.aq.push('r');
  var sr=p.r,sx=p.px;
  for(var ri=0;ri<rotN;ri++){var nr=(sr+1)%4,ks=[0,-1,1,-2,2];for(var ki=0;ki<ks.length;ki++){if(ok(p.t,nr,sx+ks[ki],p.py,p.b)){sr=nr;sx+=ks[ki];break;}}}
  var dx=best.x-sx;if(dx<0)for(var l=0;l<-dx;l++)p.aq.push('l');else for(var m=0;m<dx;m++)p.aq.push('R');
  p.aq.push('d');$('ast'+p.id).textContent='x='+best.x;$('ast'+p.id).className='as act';
}
function aiExec(p){if(!p.ai||p.go||pau||p.aq.length===0||p.cr)return;var a=p.aq.shift();switch(a){case'r':rot2(p);break;case'l':mv(p,-1,0);break;case'R':mv(p,1,0);break;case'd':hardDrop(p);uUI(p);break;}}
function aiInt(p){var v=parseInt($('asp'+p.id).value);return Math.max(3,120-v*6);} /* 高速化 */

/* ===== 描画 ===== */
function fBg(){return getComputedStyle(document.body).getPropertyValue('--field').trim()||'#10102a';}
function gCol(){return getComputedStyle(document.body).getPropertyValue('--grid').trim()||'rgba(255,255,255,.04)';}
function dBl(ctx,x,y,col,sz){ctx.fillStyle=col;ctx.fillRect(x*sz+1,y*sz+1,sz-2,sz-2);ctx.fillStyle='rgba(255,255,255,.28)';ctx.fillRect(x*sz+1,y*sz+1,sz-2,3);ctx.fillRect(x*sz+1,y*sz+1,3,sz-2);ctx.fillStyle='rgba(0,0,0,.15)';ctx.fillRect(x*sz+sz-3,y*sz+1,2,sz-2);ctx.fillRect(x*sz+1,y*sz+sz-3,sz-2,2);}
function dField(p,gc,ts){
  var ctx=gc.x,cw=gc.c.width,ch=gc.c.height;
  ctx.fillStyle=fBg();ctx.fillRect(0,0,cw,ch);
  ctx.strokeStyle=gCol();ctx.lineWidth=1;
  for(var c=0;c<=FW;c++){ctx.beginPath();ctx.moveTo(c*BS,0);ctx.lineTo(c*BS,ch);ctx.stroke();}
  for(var r=0;r<=FH;r++){ctx.beginPath();ctx.moveTo(0,r*BS);ctx.lineTo(cw,r*BS);ctx.stroke();}
  var clSet=null,animT=0,clN=0;
  if(p.cr){clSet={};for(var ci=0;ci<p.cr.length;ci++)clSet[p.cr[ci]]=true;clN=p.clC;if(p.caS<0)p.caS=ts;animT=Math.min(1,(ts-p.caS)/CDUR);}
  var fx=clN>0&&clN<=4?CLR_FX[clN]:clN>4?CLR_FX[4]:CLR_FX[1];
  for(var r2=0;r2<FH;r2++){
    var isCl=clSet&&clSet[r2]===true;
    for(var c2=0;c2<FW;c2++){
      if(p.b[r2][c2]===null)continue;var isG=p.b[r2][c2]==='G';var color=isG?GCOL():COL(p.b[r2][c2]);
      if(isCl&&fx){ctx.save();ctx.globalAlpha=1-animT;ctx.fillStyle=fx.c;ctx.fillRect(c2*BS,r2*BS,BS,BS);ctx.globalAlpha=Math.max(0,.4-animT);dBl(ctx,c2,r2,color,BS);ctx.restore();
      }else{dBl(ctx,c2,r2,color,BS);if(isG){ctx.strokeStyle='rgba(0,0,0,.2)';ctx.lineWidth=1;ctx.strokeRect(c2*BS+3,r2*BS+3,BS-6,BS-6);}}
    }
    if(isCl&&fx){ctx.save();ctx.globalAlpha=(1-animT)*0.6;ctx.fillStyle=fx.c;var lw=cw*Math.min(1,animT/0.15);ctx.fillRect((cw-lw)/2,r2*BS,lw,BS);ctx.restore();}
  }
  if(p.t!==null){
    if(p.ai&&p.at){var ty=0;while(ok(p.t,p.at.r,p.at.x,ty+1,p.b))ty++;var ts2=SH[p.t][p.at.r];for(var ai2=0;ai2<ts2.length;ai2++){var abx=p.at.x+ts2[ai2][0],aby=ty+ts2[ai2][1];if(aby<0)continue;ctx.fillStyle='rgba(255,211,105,.08)';ctx.fillRect(abx*BS,aby*BS,BS,BS);ctx.strokeStyle='rgba(255,211,105,.3)';ctx.lineWidth=1;ctx.strokeRect(abx*BS+1,aby*BS+1,BS-2,BS-2);}}
    var gy=p.py;while(ok(p.t,p.r,p.px,gy+1,p.b))gy++;var gs=SH[p.t][p.r];ctx.strokeStyle='rgba(255,255,255,.25)';ctx.lineWidth=1;
    for(var gi=0;gi<gs.length;gi++){var gx=p.px+gs[gi][0],gby=gy+gs[gi][1];if(gby<0)continue;ctx.strokeRect(gx*BS+2,gby*BS+2,BS-4,BS-4);}
    var ps=SH[p.t][p.r];for(var pi=0;pi<ps.length;pi++){var pbx=p.px+ps[pi][0],pby=p.py+ps[pi][1];if(pby<0)continue;dBl(ctx,pbx,pby,COL(p.t),BS);}
  }
  var gDelay=getGD();
  if(p.gP>0&&p.gT>0&&gDelay>0){var remain=Math.max(0,gDelay-(ts-p.gT));ctx.fillStyle='rgba(255,150,50,.7)';ctx.font='bold 10px sans-serif';ctx.textAlign='left';ctx.fillText((remain/1000).toFixed(1)+'s',4,ch-4);ctx.textAlign='start';}
  if(p.go){ctx.fillStyle='rgba(0,0,0,.5)';ctx.fillRect(0,0,cw,ch);ctx.fillStyle='#fa5a5a';ctx.font='bold 18px sans-serif';ctx.textAlign='center';ctx.fillText('GAME OVER',cw/2,ch/2);ctx.textAlign='start';}
}
function dNext(gc,type){
  gc.x.fillStyle=fBg();gc.x.fillRect(0,0,gc.c.width,gc.c.height);
  if(!type)return;var s=SH[type][0];var mnX=s[0][0],mxX=s[0][0],mnY=s[0][1],mxY=s[0][1];
  for(var i=1;i<s.length;i++){if(s[i][0]<mnX)mnX=s[i][0];if(s[i][0]>mxX)mxX=s[i][0];if(s[i][1]<mnY)mnY=s[i][1];if(s[i][1]>mxY)mxY=s[i][1];}
  var pw=mxX-mnX+1,ph=mxY-mnY+1;var ox=(gc.c.width/NB-pw)/2-mnX,oy=(gc.c.height/NB-ph)/2-mnY;
  for(var j=0;j<s.length;j++)dBl(gc.x,s[j][0]+ox,s[j][1]+oy,COL(type),NB);
}

/* ===== ループ ===== */
function upd(p,ts){
  if(p.go)return;
  if(p.cr){if(p.caS<0)p.caS=ts;if(ts-p.caS>=CDUR){finCl(p,ts);p.ldt=ts;}return;}
  var gDelay=getGD();
  if(p.gP>0&&p.gT>0){if(gDelay===0||(ts-p.gT>=gDelay))doGarb(p);}
  if(p.ai&&p.t!==null&&p.aq.length>0){var iv=aiInt(p);if(ts-p.amt>iv){aiExec(p);p.amt=ts;}}
  if(ts-p.ldt>p.di){if(p.t!==null){if(!mv(p,0,1))lock(p);}p.ldt=ts;uUI(p);}
}
function loop(ts){
  if(gover||pau||!started)return;
  upd(p1,ts);upd(p2,ts);
  dField(p1,g1,ts);dField(p2,g2,ts);
  /* NEXT描画 */
  for(var i=0;i<NEXT_SHOW;i++){
    dNext(nextCanvases1[i],p1.np[i]||null);
    dNext(nextCanvases2[i],p2.np[i]||null);
  }
  /* 遅延ゲージをリアルタイム更新 */
  uG(p1);uG(p2);
  aid=requestAnimationFrame(loop);
}

/* ===== スケーリング ===== */
function fitWrap(){
  var wrap=$('wrap');wrap.style.transform='none';
  var tw=started?FW:(parseInt($('wset').value)||10);
  var th=started?FH:(parseInt($('hset').value)||20);
  var contentW=(tw*BS+90)*2+80+30;var contentH=th*BS+120;
  var winW=window.innerWidth-16;var winH=window.innerHeight-16;
  var scale=Math.min(1,winW/contentW,winH/contentH);
  wrap.style.transform='scale('+scale+')';
}
window.addEventListener('resize',fitWrap);

/* ===== 制御 ===== */
function init(){
  p1=mkP(1);p2=mkP(2);gover=false;pau=false;shLv=1;shLn=0;
  var di=calcDI();p1.di=di;p2.di=di;
  p1.np=[];p2.np=[];
  fillNp(p1);fillNp(p2);
  spawn(p1);spawn(p2);syncAI(p1);syncAI(p2);
  uUI(p1);uUI(p2);uG(p1);uG(p2);
  $('slv').textContent='1';$('sln').textContent='0';
  $('gov').classList.add('hid');$('pov').classList.add('hid');
}
function syncAI(p){var btn=$('ab'+p.id),st=$('ast'+p.id);if(p.ai){btn.textContent='AI ON';btn.className='ab on';st.textContent='稼働中';st.className='as act';}else{btn.textContent='AI OFF';btn.className='ab off';st.textContent='待機中';st.className='as';p.at=null;p.aq=[];}}
function togAI(p){p.ai=!p.ai;syncAI(p);if(p.ai&&p.t&&!p.go)aiCalc(p);}
function togPau(){if(gover||!started)return;pau=!pau;if(pau)$('pov').classList.remove('hid');else{$('pov').classList.add('hid');aid=requestAnimationFrame(loop);}}
function setBg(i){bgI=i;applyTheme();}
function setCSel(i){curCS=i;applyTheme();}
function applyTheme(){
  document.body.className='bg-'+BG[bgI]+' cs-'+CS_KEYS[curCS];
  var ds=document.querySelectorAll('.td');for(var j=0;j<ds.length;j++){if(parseInt(ds[j].getAttribute('data-t'))===bgI)ds[j].classList.add('act');else ds[j].classList.remove('act');}
  var cs=document.querySelectorAll('.csb');for(var k=0;k<cs.length;k++){if(parseInt(cs[k].getAttribute('data-cs'))===curCS)cs[k].classList.add('act');else cs[k].classList.remove('act');}
}
var tds=document.querySelectorAll('.td');for(var ti=0;ti<tds.length;ti++){(function(d){d.addEventListener('click',function(){setBg(parseInt(d.getAttribute('data-t')));});})(tds[ti]);}
var csbs=document.querySelectorAll('.csb');for(var ci=0;ci<csbs.length;ci++){(function(d){d.addEventListener('click',function(){setCSel(parseInt(d.getAttribute('data-cs')));});})(csbs[ci]);}

function goToStart(){
  if(aid)cancelAnimationFrame(aid);
  started=false;gover=false;pau=false;
  $('gov').classList.add('hid');$('pov').classList.add('hid');$('startov').classList.remove('hid');
  $('wset').value=FW;$('wval').textContent=FW;
  $('hset').value=FH;$('hval').textContent=FH;
  $('nset').value=NEXT_SHOW;$('nval').textContent=NEXT_SHOW;
  $('gmax0').value=GARB_MAX;$('gmv0').textContent=GARB_MAX;
  $('gdel0').value=$('gdel').value;$('gdv0').textContent=$('gdv').textContent;
}
function startGame(){
  FW=parseInt($('wset').value);FH=parseInt($('hset').value);
  NEXT_SHOW=parseInt($('nset').value);
  GARB_MAX=parseInt($('gmax0').value);
  $('gdel').value=$('gdel0').value;$('gdv').textContent=$('gdv0').textContent;
  initC();init();fitWrap();
  $('startov').classList.add('hid');started=true;aid=requestAnimationFrame(loop);
}
document.addEventListener('keydown',function(e){
  if(e.key==='Escape'){if(started)goToStart();return;}
  if(e.key==='p'||e.key==='P'){togPau();return;}
  if(e.key==='b'||e.key==='B'){setBg((bgI+1)%BG.length);return;}
  if(e.key==='c'||e.key==='C'){setCSel((curCS+1)%CS_KEYS.length);return;}
  if(e.key==='1'){togAI(p1);return;}
  if(e.key==='2'){togAI(p2);return;}
  if(pau||gover||!started)return;
  /* 1P手動操作 (AI OFF時) */
  if(!p1.ai&&p1.t&&!p1.go){
    if(e.key==='ArrowLeft')mv(p1,-1,0);
    else if(e.key==='ArrowRight')mv(p1,1,0);
    else if(e.key==='ArrowDown')mv(p1,0,1);
    else if(e.key==='ArrowUp')rot2(p1);
    else if(e.key===' '){hardDrop(p1);uUI(p1);}
  }
  /* 2P手動操作 (AI OFF時) */
  if(!p2.ai&&p2.t&&!p2.go){
    if(e.key==='a'||e.key==='A')mv(p2,-1,0);
    else if(e.key==='d'||e.key==='D')mv(p2,1,0);
    else if(e.key==='s'||e.key==='S')mv(p2,0,1);
    else if(e.key==='w'||e.key==='W')rot2(p2);
    else if(e.key==='q'||e.key==='Q'){hardDrop(p2);uUI(p2);}
  }
});
$('ab1').addEventListener('click',function(){togAI(p1);});
$('ab2').addEventListener('click',function(){togAI(p2);});
$('startbtn').addEventListener('click',startGame);
$('rbtn').addEventListener('click',function(){$('gov').classList.add('hid');startGame();});
applyTheme();fitWrap();
})();