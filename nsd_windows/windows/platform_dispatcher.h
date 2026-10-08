#pragma once
#include <windows.h>
#include <atomic>
#include <functional>
#include <memory>
#include <mutex>

namespace nsd_windows {
class PlatformDispatcher {
 public:
  PlatformDispatcher();
  ~PlatformDispatcher();
  void Post(std::function<void()> callback,std::function<void()> discard);
  void Shutdown();
 private:
  HWND window_ = nullptr;
  std::mutex post_mutex_;
  std::shared_ptr<std::atomic<bool>> alive_ = std::make_shared<std::atomic<bool>>(true);
  std::shared_ptr<std::atomic<int>> pending_ = std::make_shared<std::atomic<int>>(0);
};
}
