// The loadable Elder ENB runtime. ENBSeries LoadLibrary's this .dllplugin from
// the game-root enbseries\ folder; on attach it resolves the already-running
// ENB host through the neutral core and registers Elder's callback. The
// rendering payload wires in as Elder's own shader stack matures; today this is
// the runtime shell that attaches to ENB and reports host-resolution status, so
// a diagnostics reader can confirm the plugin is live and bound.

#include <elder/runtime/PulsePublication.hpp>

#include <enbcore/enb/LoadedHostResolver.hpp>

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

#if defined(_MSC_VER)
void __stdcall ElderEnbCallback(const enbcore::enb::CallbackId) noexcept
#else
void ElderEnbCallback(const enbcore::enb::CallbackId) noexcept
#endif
{
    // Elder's rendering payload is not wired yet; the callback is a safe no-op
    // so the plugin never destabilises a live ENB frame while attached.
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

BOOL WINAPI DllMain(HINSTANCE instance, const DWORD reason, LPVOID) noexcept
{
    if (reason == DLL_PROCESS_ATTACH) {
        DisableThreadLibraryCalls(instance);
        ResolveAndRegisterHost();
    }
    return TRUE;
}
