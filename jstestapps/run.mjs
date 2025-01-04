import ncccutilp from "./lib/nccc/ncccutil.mjs";
import compat from "./compat-node.mjs";

const ncccutil = ncccutilp(compat);

function dllpath(name){
    return compat.debug_prefix.debug_prefix + "/libnccc_" + name + ".so";
}

const modyfrm = ncccutil.opennccc(dllpath("yfrm"));
const lib_yfrm = ncccutil.loadlib(ncccutil.resolvenccc(modyfrm, "yfrm")).exports;
console.log(lib_yfrm);
const lib_cwgl = ncccutil.loadlib(ncccutil.resolvenccc(modyfrm, "cwgl")).exports;
console.log(lib_cwgl);

// libs
const yfrm_init = lib_yfrm.yfrm_init.proc;
const yfrm_cwgl_ctx_create = lib_yfrm.yfrm_cwgl_ctx_create.proc;
const yfrm_query0 = lib_yfrm.yfrm_query0.proc;
const yfrm_wait0 = lib_yfrm.yfrm_wait0.proc;
const yfrm_frame_begin0 = lib_yfrm.yfrm_frame_begin0.proc;
const yfrm_frame_end0 = lib_yfrm.yfrm_frame_end0.proc;

const cwgl_viewport = lib_cwgl.cwgl_viewport.proc;
const cwgl_clear = lib_cwgl.cwgl_clear.proc;
const cwgl_clearColor = lib_cwgl.cwgl_clearColor.proc;

const initr = yfrm_init();
const ctx_cwgl = yfrm_cwgl_ctx_create(1280, 720, 0, 1);

cwgl_viewport(ctx_cwgl, 0, 0, 1280, 720);

let cur = 0.0;
const evq = ncccutil.malloc(256 * 4);

const COLOR_BUFFER_BIT = 0x4000;
function fill(ctx){
    yfrm_frame_begin0(ctx);
    cwgl_clearColor(ctx, cur, cur, cur, cur);
    cwgl_clear(ctx, COLOR_BUFFER_BIT);
    yfrm_frame_end0(ctx);
}

function step(ctx){
    yfrm_wait0(0);
    const r = yfrm_query0(0, evq, 256 * 4);
    console.log("EVENT:", r);
    cur += 0.05;
    if(cur > 1.0){
        cur -= 1.0;
    }
    console.log(cur);
    fill(ctx);
}

for(;;){
    step(ctx_cwgl);
}
