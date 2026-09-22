#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

namespace {

// One copy of the app per signed-in Windows user. Two copies share one set of
// local files — the account, drafts, the engine — and each believes it owns
// them. The name is in `Local\`, so another Windows user on the same machine
// runs their own copy.
constexpr const wchar_t kSingleInstanceMutex[] =
    L"Local\\rs.pejovic.chesscoach.single-instance";

// Brings the copy already running to the front. Its window may still be
// hidden if it is starting up; then there is nothing to show yet, and this
// launch leaves it to finish.
void FocusRunningInstance() {
  HWND existing = ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"Mislisha");
  if (existing == nullptr) return;
  if (::IsIconic(existing)) ::ShowWindow(existing, SW_RESTORE);
  ::SetForegroundWindow(existing);
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
#ifndef _DEBUG
  // Held until the process ends; Windows releases it then, crash included, so
  // a copy that died never locks the next one out. A debug build (`flutter
  // run`) is left out, so development can run beside the installed app.
  HANDLE single_instance =
      ::CreateMutexW(nullptr, FALSE, kSingleInstanceMutex);
  if (single_instance != nullptr && ::GetLastError() == ERROR_ALREADY_EXISTS) {
    FocusRunningInstance();
    ::CloseHandle(single_instance);
    return EXIT_SUCCESS;
  }
#endif

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
  if (!window.Create(L"Mislisha", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
