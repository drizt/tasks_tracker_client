#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

namespace {

constexpr wchar_t kInstanceMutexName[] =
    L"Local\\io.github.drizt.tasks_tracker_client";
constexpr wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";
constexpr wchar_t kWindowTitle[] = L"tasks_tracker_client";
constexpr int kWindowLookupAttempts = 40;
constexpr DWORD kWindowLookupDelayMs = 50;

void ActivateExistingWindow() {
  for (int attempt = 0; attempt < kWindowLookupAttempts; ++attempt) {
    HWND window = ::FindWindow(kWindowClassName, kWindowTitle);
    if (window != nullptr) {
      const int show_command = ::IsIconic(window) ? SW_RESTORE : SW_SHOW;
      ::ShowWindowAsync(window, show_command);
      ::SetWindowPos(window, HWND_TOP, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);
      ::SetForegroundWindow(window);
      return;
    }

    ::Sleep(kWindowLookupDelayMs);
  }
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  HANDLE instance_mutex = ::CreateMutex(nullptr, TRUE, kInstanceMutexName);
  if (instance_mutex == nullptr) {
    return EXIT_FAILURE;
  }

  if (::GetLastError() == ERROR_ALREADY_EXISTS) {
    ActivateExistingWindow();
    ::CloseHandle(instance_mutex);
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(kWindowTitle, origin, size)) {
    ::CoUninitialize();
    ::CloseHandle(instance_mutex);
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  ::CloseHandle(instance_mutex);
  return EXIT_SUCCESS;
}
