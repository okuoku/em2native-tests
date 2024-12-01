// Yuniframe version

//
// Copyright (c) 2013 Mikko Mononen memon@inside.org
//
// This software is provided 'as-is', without any express or implied
// warranty.  In no event will the authors be held liable for any damages
// arising from the use of this software.
// Permission is granted to anyone to use this software for any purpose,
// including commercial applications, and to alter it and redistribute it
// freely, subject to the following restrictions:
// 1. The origin of this software must not be misrepresented; you must not
//    claim that you wrote the original software. If you use this software
//    in a product, an acknowledgment in the product documentation would be
//    appreciated but is not required.
// 2. Altered source versions must be plainly marked as such, and must not be
//    misrepresented as being the original software.
// 3. This notice may not be removed or altered from any source distribution.
//

#include <yuniframe/yfrm.h>
#include <stdio.h>
#include "nanovg.h"
#define NANOVG_CWGL_IMPLEMENTATION
#include "nanovg_cwgl.h"
//#include "nanovg_gl_utils.h"
#include "demo.h"
//#include "perf.h"

int blowup = 0;
int screenshot = 0;
int premult = 0;

#if 0
static void key(GLFWwindow* window, int key, int scancode, int action, int mods)
{
	NVG_NOTUSED(scancode);
	NVG_NOTUSED(mods);
	if (key == GLFW_KEY_ESCAPE && action == GLFW_PRESS)
		glfwSetWindowShouldClose(window, GL_TRUE);
	if (key == GLFW_KEY_SPACE && action == GLFW_PRESS)
		blowup = !blowup;
	if (key == GLFW_KEY_S && action == GLFW_PRESS)
		screenshot = 1;
	if (key == GLFW_KEY_P && action == GLFW_PRESS)
		premult = !premult;
}
#endif
static DemoData data;
static NVGcontext* vg = NULL;
static double prevt = 0;
static uint64_t frm;
static cwgl_ctx* ctx;

int YFRM_FRAME(void* bogus){
    double mx, my, t, dt;
    int winWidth, winHeight;
    int fbWidth, fbHeight;
    float pxRatio;

    yfrm_frame_begin0(ctx);
    // Consume events
    {
        int events;
        int buf[128];
        for(;;){
            events = yfrm_query0(0, buf, 128);
            if(events == 0){
                break;
            }
        }

    }

    t = 1 * frm;
    dt = 1; // FIXME: delta
    prevt = t;
    //updateGraph(&fps, dt);

    mx = 0;
    my = 0; // FIXME: mouse
    fbWidth = 1280;
    fbHeight = 720;
    winWidth = 1280;
    winHeight = 720;
    // Calculate pixel ration for hi-dpi devices.
    pxRatio = (float)fbWidth / (float)winWidth;

    // Update and render
    cwgl_viewport(ctx, 0, 0, fbWidth, fbHeight);
    if (premult)
        cwgl_clearColor(ctx, 0,0,0,0);
    else
        cwgl_clearColor(ctx, 0.3f, 0.3f, 0.32f, 1.0f);
    cwgl_clear(ctx, COLOR_BUFFER_BIT|DEPTH_BUFFER_BIT|STENCIL_BUFFER_BIT);

    cwgl_enable(ctx, BLEND);
    cwgl_blendFunc(ctx, SRC_ALPHA, ONE_MINUS_SRC_ALPHA);
    cwgl_enable(ctx, CULL_FACE);
    cwgl_disable(ctx, DEPTH_TEST);

    nvgBeginFrame(vg, winWidth, winHeight, pxRatio);

    renderDemo(vg, mx,my, winWidth,winHeight, t, blowup, &data);
    //renderGraph(vg, 5,5, &fps);

    nvgEndFrame(vg);

    if (screenshot) {
        screenshot = 0;
        saveScreenShot(fbWidth, fbHeight, premult, "dump.png");
    }

    cwgl_enable(ctx, DEPTH_TEST);

    yfrm_frame_end0(ctx);
    frm++;
    return 0;

#if 0
exit:
    freeDemoData(vg, &data);
    nvgDeleteCWGL(vg);
#endif
}

int YFRM_ENTRYPOINT(int ac, const char** av){
        ctx = yfrm_cwgl_ctx_create(1280,720,0,0);
        yfrm_frame_begin0(ctx); // Initial frame
	vg = nvgCreateCWGL(ctx, NVG_ANTIALIAS | NVG_STENCIL_STROKES | NVG_DEBUG);
	if (vg == NULL) {
		printf("Could not init nanovg.\n");
		return -1;
	}

	if (loadDemoData(vg, &data) == -1)
		return -1;

	prevt = 0.0; // FIXME: prev time
        frm = 0;
        yfrm_frame_end0(ctx); // Initial frame
	return 0;
}
