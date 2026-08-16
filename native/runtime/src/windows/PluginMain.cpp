// The loadable Elder ENB runtime. ENBSeries LoadLibrary's this .dllplugin from
// the game-root enbseries\ folder; on attach it resolves the already-running
// ENB host through the neutral core and registers Elder's callback.
//
// On every BeginFrame the callback measures the frame, publishes the pulse
// through the neutral core, applies Elder's publication policy, and writes the
// result to the shader stack as ElderRuntimeFramePulse. It also publishes the
// transactional Elder runtime payload for the ordered shader tree. Room light
// is optionally derived from public SkyrimBridge-named shader parameters when
// they are present and current; exposure_color remains neutral/reserved.
//
// Everything decidable is in FrameDriver, which is pure and tested. What stays
// here is the clock, the host pointers, and the write. The callback runs on the
// render thread inside a live frame, so it allocates nothing, locks nothing,
// and cannot throw.

#include <elder/runtime/FrameDriver.hpp>
#include <elder/runtime/PulsePublication.hpp>
#include <elder/runtime/RenderPayloadController.hpp>
#include <elder/runtime/ShaderParameterBridge.hpp>

#include <enbcore/enb/LoadedHostResolver.hpp>
#include <enbcore/enb/SdkContract.hpp>
#include <enbcore/runtime/FramePulse.hpp>

#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <Windows.h>

#include <atomic>
#include <cstdint>

namespace {

std::atomic<std::uint32_t> g_host_resolution_code{
    static_cast<std::uint32_t>(enbcore::enb::HostResolutionCode::HostNotFound)};
std::atomic<bool> g_exports_resolved{false};
std::atomic<bool> g_callback_registered{false};

// Published frame count, exposed through the diagnostics export so a reader can
// tell a bound-but-idle plugin from one that is actually driving frames.
std::atomic<std::uint64_t> g_published_frames{0U};

// Host exports captured at attach. Only ever written before the callback is
// registered, and only ever read afterwards.
enbcore::enb::SdkExports g_exports{};

// Frame state. Touched exclusively by the callback, which ENB calls on one
// render thread, so no synchronisation is needed here and none is implied.
enbcore::runtime::FramePulseState g_pulse_state{};
std::int64_t g_previous_ticks = 0;
bool g_has_previous_frame = false;

elder::runtime::RenderPayloadController g_payload_controller{};
elder::runtime::PublicBridgeRoomLightSource g_bridge_room_light_source{};
std::uint64_t g_payload_generation = 0U;

[[nodiscard]] float TicksToSeconds(const std::int64_t delta_ticks) noexcept
{
    LARGE_INTEGER frequency{};
    if (!QueryPerformanceFrequency(&frequency) || frequency.QuadPart <= 0) {
        return 0.0F;
    }
    return static_cast<float>(static_cast<double>(delta_ticks)
                              / static_cast<double>(frequency.QuadPart));
}

// Measures the frame, then reports it. A first frame has no previous timestamp,
// so it is deliberately reported as unmeasured rather than assigned a guess.
[[nodiscard]] elder::runtime::FrameTiming MeasureFrame() noexcept
{
    LARGE_INTEGER now{};
    if (!QueryPerformanceCounter(&now)) {
        return elder::runtime::FrameTiming{0.0F, false};
    }

    const bool had_previous = g_has_previous_frame;
    const std::int64_t previous = g_previous_ticks;
    g_previous_ticks = now.QuadPart;
    g_has_previous_frame = true;

    if (!had_previous) {
        return elder::runtime::FrameTiming{0.0F, false};
    }
    return elder::runtime::FrameTiming{TicksToSeconds(now.QuadPart - previous), true};
}

[[nodiscard]] elder::runtime::RenderPayload BuildRuntimeRenderPayload() noexcept
{
    ++g_payload_generation;
    const elder::runtime::PublicBridgeRoomLightSourceResult bridge_room =
        g_bridge_room_light_source.readRoomLight();
    return elder::runtime::MakeRenderPayload(
        bridge_room.room_light,
        elder::runtime::NeutralExposureColorPayload(),
        g_payload_generation);
}

#if defined(_MSC_VER)
void __stdcall ElderEnbCallback(const enbcore::enb::CallbackId callback) noexcept
#else
void ElderEnbCallback(const enbcore::enb::CallbackId callback) noexcept
#endif
{
    if (callback == enbcore::enb::CallbackId::PreSave
        || callback == enbcore::enb::CallbackId::PreReset
        || callback == enbcore::enb::CallbackId::OnExit) {
        static_cast<void>(g_payload_controller.handleLifecycle(callback));
        return;
    }

    if (callback != enbcore::enb::CallbackId::BeginFrame) {
        return;
    }
    if (g_exports.set_parameter == nullptr) {
        return;
    }

    const enbcore::enb::RenderInfo* render_info =
        g_exports.get_render_info != nullptr ? g_exports.get_render_info() : nullptr;

    const elder::runtime::FrameOutcome outcome =
        elder::runtime::DriveFrame(g_pulse_state, render_info, MeasureFrame());

    g_published_frames.store(g_pulse_state.published_frames,
                             std::memory_order_relaxed);

    // Written on every frame, including the inactive payload. Skipping the
    // write when a pulse is withheld would leave the last live value in front
    // of shaders, which is the one failure this whole path exists to prevent.
    enbcore::enb::Parameter parameter = outcome.parameter;
    for (const char* const shader : elder::runtime::kElderTargetShaders) {
        g_exports.set_parameter(nullptr,
                                const_cast<char*>(shader),
                                const_cast<char*>(elder::runtime::kElderFramePulseSymbol),
                                &parameter);
    }

    if (g_payload_controller.ready()) {
        static_cast<void>(
            g_payload_controller.publish(BuildRuntimeRenderPayload()));
    }
}

void ResolveAndRegisterHost() noexcept
{
    enbcore::enb::WindowsLoadedModulePlatform platform;
    const enbcore::enb::HostResolutionResult host =
        enbcore::enb::ResolveLoadedEnbHost(platform);

    g_host_resolution_code.store(static_cast<std::uint32_t>(host.code),
                                 std::memory_order_relaxed);
    g_exports_resolved.store(host.exports_resolved, std::memory_order_relaxed);

    if (host.exports_resolved
        && (host.code == enbcore::enb::HostResolutionCode::Ready
            || host.code == enbcore::enb::HostResolutionCode::NotReady)
        && host.exports.set_callback_function != nullptr) {
        g_exports = host.exports;
        g_payload_controller.bind(elder::runtime::ShaderParameterBridge{
            g_exports.get_parameter,
            g_exports.set_parameter,
        });
        g_bridge_room_light_source.bind(elder::runtime::ShaderParameterBridge{
            g_exports.get_parameter,
            g_exports.set_parameter,
        });
        host.exports.set_callback_function(&ElderEnbCallback);
        g_callback_registered.store(true, std::memory_order_relaxed);
    }
}

}  // namespace

// Minimal diagnostics export: reports whether the plugin resolved and bound the
// ENB host, so an external reader can confirm the plugin is live.
extern "C" __declspec(dllexport) BOOL WINAPI
ElderEnbRuntimeProbeV1(std::uint32_t* const host_code_out,
                       BOOL* const registered_out) noexcept
{
    if (host_code_out == nullptr || registered_out == nullptr) {
        return FALSE;
    }
    *host_code_out = g_host_resolution_code.load(std::memory_order_relaxed);
    *registered_out = g_callback_registered.load(std::memory_order_relaxed) ? TRUE : FALSE;
    return g_exports_resolved.load(std::memory_order_relaxed) ? TRUE : FALSE;
}

// Frame diagnostics. Added alongside the V1 probe rather than folded into it,
// because changing that signature would break any reader already built against
// it. Reports how many pulses have been published, which is what distinguishes
// a plugin that is merely bound from one that is driving frames.
extern "C" __declspec(dllexport) BOOL WINAPI
ElderEnbRuntimeFrameProbeV1(std::uint64_t* const published_frames_out) noexcept
{
    if (published_frames_out == nullptr) {
        return FALSE;
    }
    *published_frames_out = g_published_frames.load(std::memory_order_relaxed);
    return g_callback_registered.load(std::memory_order_relaxed) ? TRUE : FALSE;
}

BOOL WINAPI DllMain(HINSTANCE instance, const DWORD reason, LPVOID) noexcept
{
    if (reason == DLL_PROCESS_ATTACH) {
        DisableThreadLibraryCalls(instance);
        ResolveAndRegisterHost();
    }
    return TRUE;
}
