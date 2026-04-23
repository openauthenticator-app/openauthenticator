#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include "firebase/app.h"
#include "firebase/future.h"

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <memory>

#include "win32_window.h"

#include "include/firebase/app/future_manager.h"
#include "firebase/internal/future_impl.h"

using FunctionRegistryCallback = void (*)(void*);

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  static inline FlutterWindow* FlutterWindow::instance = nullptr;
  std::unique_ptr<flutter::MethodChannel<>> method_channel_auth;

  virtual ~FlutterWindow();
  static FlutterWindow* GetInstance(const flutter::DartProject& project);
  FlutterWindow(FlutterWindow const&) = delete;
  void operator=(FlutterWindow const&) = delete;

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam, LPARAM const lparam) noexcept override;
  using Entry = std::pair<FunctionRegistryCallback, void*>;

 private:
  firebase::FutureManager future_manager_;

  firebase::FutureManager& future_manager() {
    return future_manager_;
  }

  firebase::ReferenceCountedFutureImpl* future();

  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  std::optional<std::string> user_uid;

  static bool AddListener(firebase::App* app, void* callback, void* context);
  static bool RemoveListener(firebase::App* app, void* callback, void* context);
  static bool GetCurrentUserIdToken(firebase::App* app, void* force_refresh, void* out);
  static bool GetCurrentUserUid(firebase::App* app, void*, void* out);

  std::vector<Entry> callbacks;
};

// Used by FlutterWindow functions that return a future
enum FlutterWindowFn {
  kFlutterWindowFnGetCurrentUserIdToken = 0,
  kFlutterWindowFnCount,
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
