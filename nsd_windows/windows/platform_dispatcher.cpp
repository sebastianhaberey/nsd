#include "platform_dispatcher.h"
#include <stdexcept>
#include <mutex>
namespace nsd_windows {
namespace {
constexpr UINT kDispatch = WM_APP + 0x389;
struct Task {
  Task(std::function<void()> callback,std::function<void()> discard,
      std::shared_ptr<std::atomic<bool>> alive,std::shared_ptr<std::atomic<int>> pending)
      : callback(std::move(callback)),discard(std::move(discard)),alive(std::move(alive)),pending(std::move(pending)) {}
  std::function<void()> callback, discard;
  std::shared_ptr<std::atomic<bool>> alive;
  std::shared_ptr<std::atomic<int>> pending;
  ~Task() { if (discard) discard(); --*pending; }
};
LRESULT CALLBACK DispatchWindow(HWND window,UINT message,WPARAM wparam,LPARAM lparam) {
  if (message == kDispatch) {
    std::unique_ptr<Task> task(reinterpret_cast<Task*>(lparam));
    if (*task->alive) {
      task->discard = nullptr;
      try { task->callback(); } catch (...) { /* Native callback cannot unwind into the message pump. */ }
    }
    return 0;
  }
  return DefWindowProcW(window,message,wparam,lparam);
}
}
PlatformDispatcher::PlatformDispatcher() {
  // A message-only window is created on Flutter's platform thread. Posting DNS
  // results to it obeys Flutter's messenger affinity without blocking workers.
  WNDCLASSW cls{};
  cls.lpfnWndProc = DispatchWindow;
  cls.hInstance = GetModuleHandleW(nullptr);
  cls.lpszClassName = L"LpcNsdPlatformDispatcher";
  RegisterClassW(&cls);
  window_ = CreateWindowExW(0,cls.lpszClassName,L"",0,0,0,0,0,HWND_MESSAGE,nullptr,cls.hInstance,nullptr);
  if (!window_) throw std::runtime_error("NSD platform dispatcher unavailable");
}
void PlatformDispatcher::Post(std::function<void()> callback,std::function<void()> discard) {
  std::lock_guard<std::mutex> lock(post_mutex_);
  if (!*alive_) { discard(); return; }
  if (pending_->fetch_add(1) >= 256) { --*pending_; discard(); return; }
  auto task = std::make_unique<Task>(std::move(callback),std::move(discard),alive_,pending_);
  if (PostMessageW(window_,kDispatch,0,reinterpret_cast<LPARAM>(task.get()))) task.release();
}
void PlatformDispatcher::Shutdown() {
  std::lock_guard<std::mutex> lock(post_mutex_);
  if (!alive_->exchange(false)) return;
  MSG message;
  while (PeekMessageW(&message,window_,kDispatch,kDispatch,PM_REMOVE)) delete reinterpret_cast<Task*>(message.lParam);
  DestroyWindow(window_); window_ = nullptr;
}
PlatformDispatcher::~PlatformDispatcher() { Shutdown(); }
}
