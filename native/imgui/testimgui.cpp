#define CWGL_DECL_ENUMS
#include "yuniframe/cwgl.h"
#include "yuniframe/yfrm.h"

#include "imgui.h"

bool ImGui_ImplCwgl_Init(cwgl_ctx_t* ctx);
void ImGui_ImplCwgl_RenderDrawData(ImDrawData* draw_data);

bool ImGui_ImplYfrm_ProcessEvent0(const int32_t* events, size_t start, size_t end);
bool ImGui_ImplYfrm_Init();

static int w,h;
static int buf[128];
static int init = 0;
static int events;
static cwgl_ctx* ctx;
static bool showdemo = true;
static int frame;

extern "C" int
YFRM_FRAME(void* bogus){
    yfrm_frame_begin0(ctx);
    if(!init){
        ImGui_ImplYfrm_Init();
        ImGui_ImplCwgl_Init(ctx);
        init = 1;
    }else{
        /* Clear */
        cwgl_viewport(ctx, 0, 0, w, h);
        cwgl_disable(ctx, SCISSOR_TEST);
        cwgl_clearColor(ctx, 0, 0, 0, 1.0f);
        cwgl_clear(ctx, COLOR_BUFFER_BIT);

        /* Draw something */
        // FIXME: Should go to backend
        ImGuiIO& io = ImGui::GetIO(); 
        io.DisplaySize = ImVec2((float)w, (float)h);
        io.DisplayFramebufferScale = ImVec2(1.0f, 1.0f);

        io.DeltaTime = 1.0f/60.0f; /* 60Hz */

        ImGui::NewFrame();
        ImGui::ShowDemoWindow(&showdemo);
        ImGui::Render();
        ImGui_ImplCwgl_RenderDrawData(ImGui::GetDrawData());

        for(;;){
            events = yfrm_query0(0, buf, 128);
            if(events > 0){
                ImGui_ImplYfrm_ProcessEvent0(buf, 0, events);
            }else{
                break;
            }
        }
    }
    yfrm_frame_end0(ctx);
    frame ++;

    return 0;
}

extern "C" int
YFRM_ENTRYPOINT(int ac, const char** av){
    yfrm_init();

    w = 1280;
    h = 720;
    ctx = yfrm_cwgl_ctx_create(w,h,0,0);
    ImGui::CreateContext();
    ImGui::StyleColorsDark();

    frame = 0;

    return 0;
}
