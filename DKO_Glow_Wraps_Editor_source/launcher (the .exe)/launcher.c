/* Double K.O. Designs launcher.
 * Starts the tool's PowerShell window using the Windows PowerShell that ships with Windows.
 * The script (engine\<SCRIPT>) is read from disk and handed to PowerShell on standard input
 * (powershell.exe -Command -). This needs no -ExecutionPolicy override (input read from stdin is
 * not governed by execution policy) and no -WindowStyle Hidden (this is a windowless GUI program,
 * so PowerShell gets no console). The script finds its own engine folder from DKO_ENGINE_DIR.
 * If PowerShell stops within a few seconds, its output is shown and saved to
 * %LOCALAPPDATA%\<APPDIR>\launch_log.txt. */
#include <windows.h>
#include <wchar.h>

#ifndef APP_TITLE
#define APP_TITLE L"DKO Glow Wraps Colors"
#endif
#ifndef APP_SCRIPT
#define APP_SCRIPT L"DKO_Glow_Wraps_Colors.ps1"
#endif
#ifndef APP_DIR
#define APP_DIR L"DKO_Glow_Wraps_Colors"
#endif

int WINAPI wWinMain(HINSTANCE h, HINSTANCE p, LPWSTR a, int n)
{
    wchar_t exe[MAX_PATH], dir[MAX_PATH], engine[MAX_PATH], ps1[MAX_PATH], psexe[MAX_PATH];
    wchar_t sysdir[MAX_PATH], cmd[1024], logdir[MAX_PATH], logf[MAX_PATH];

    GetModuleFileNameW(NULL, exe, MAX_PATH);
    wcscpy(dir, exe);
    wchar_t *s = wcsrchr(dir, L'\\'); if (s) *s = 0;
    swprintf(engine, MAX_PATH, L"%ls\\engine", dir);
    swprintf(ps1, MAX_PATH, L"%ls\\%ls", engine, APP_SCRIPT);
    if (GetFileAttributesW(ps1) == INVALID_FILE_ATTRIBUTES) {
        MessageBoxW(NULL, L"The 'engine' folder was not found next to this program.\n\n"
                          L"Unpack the whole zip and start it from that folder.", APP_TITLE, MB_OK | MB_ICONERROR);
        return 1;
    }

    /* read the script file into memory */
    HANDLE hf = CreateFileW(ps1, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, 0, NULL);
    if (hf == INVALID_HANDLE_VALUE) {
        MessageBoxW(NULL, L"Could not open the program's script file.", APP_TITLE, MB_OK | MB_ICONERROR);
        return 1;
    }
    DWORD sz = GetFileSize(hf, NULL), got = 0;
    char *buf = (char *)HeapAlloc(GetProcessHeap(), 0, sz ? sz : 1);
    if (!buf || !ReadFile(hf, buf, sz, &got, NULL)) { CloseHandle(hf); 
        MessageBoxW(NULL, L"Could not read the program's script file.", APP_TITLE, MB_OK | MB_ICONERROR); return 1; }
    CloseHandle(hf);
    char *data = buf; DWORD dlen = got;
    if (dlen >= 3 && (unsigned char)data[0] == 0xEF && (unsigned char)data[1] == 0xBB && (unsigned char)data[2] == 0xBF) {
        data += 3; dlen -= 3;      /* drop a UTF-8 byte-order mark */
    }

    GetSystemDirectoryW(sysdir, MAX_PATH);
    swprintf(psexe, MAX_PATH, L"%ls\\WindowsPowerShell\\v1.0\\powershell.exe", sysdir);
    swprintf(cmd, 1024, L"\"%ls\" -NoProfile -NonInteractive -STA -Command -", psexe);

    /* the script finds its engine folder here when it is read from standard input */
    SetEnvironmentVariableW(L"DKO_ENGINE_DIR", engine);

    /* log file for PowerShell's own messages (errors that happen before the window opens) */
    DWORD ln = GetEnvironmentVariableW(L"LOCALAPPDATA", logdir, MAX_PATH);
    if (!ln || ln >= MAX_PATH) wcscpy(logdir, dir);
    wcscat(logdir, L"\\" APP_DIR);
    CreateDirectoryW(logdir, NULL);
    swprintf(logf, MAX_PATH, L"%ls\\launch_log.txt", logdir);

    SECURITY_ATTRIBUTES sa = { sizeof sa, NULL, TRUE };
    HANDLE hin_r = NULL, hin_w = NULL;
    if (!CreatePipe(&hin_r, &hin_w, &sa, 0)) {
        MessageBoxW(NULL, L"Could not start Windows PowerShell.", APP_TITLE, MB_OK | MB_ICONERROR); return 1; }
    SetHandleInformation(hin_w, HANDLE_FLAG_INHERIT, 0);   /* our write end stays private */
    HANDLE hl = CreateFileW(logf, GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, &sa, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);

    STARTUPINFOW si; PROCESS_INFORMATION pi;
    ZeroMemory(&si, sizeof si); si.cb = sizeof si;
    si.dwFlags = STARTF_USESTDHANDLES;
    si.hStdInput = hin_r;
    si.hStdOutput = (hl != INVALID_HANDLE_VALUE) ? hl : NULL;
    si.hStdError  = (hl != INVALID_HANDLE_VALUE) ? hl : NULL;
    ZeroMemory(&pi, sizeof pi);

    if (!CreateProcessW(psexe, cmd, NULL, NULL, TRUE, CREATE_NO_WINDOW, NULL, dir, &si, &pi)) {
        MessageBoxW(NULL, L"Could not start Windows PowerShell, which this program needs.", APP_TITLE, MB_OK | MB_ICONERROR);
        return 1;
    }
    CloseHandle(pi.hThread);
    CloseHandle(hin_r);                                   /* the child has its own copy */
    if (hl != INVALID_HANDLE_VALUE) CloseHandle(hl);

    /* hand the script to PowerShell on standard input, then signal end of input */
    DWORD off = 0, wrote = 0;
    while (off < dlen && WriteFile(hin_w, data + off, dlen - off, &wrote, NULL) && wrote) off += wrote;
    CloseHandle(hin_w);
    HeapFree(GetProcessHeap(), 0, buf);

    /* the window normally stays open far longer than this; an early exit means something went wrong */
    if (WaitForSingleObject(pi.hProcess, 12000) == WAIT_OBJECT_0) {
        DWORD code = 0; GetExitCodeProcess(pi.hProcess, &code);
        char rb[3000] = {0}; DWORD rn = 0;
        HANDLE hr = CreateFileW(logf, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_EXISTING, 0, NULL);
        if (hr != INVALID_HANDLE_VALUE) { ReadFile(hr, rb, sizeof rb - 1, &rn, NULL); CloseHandle(hr); }
        if (code != 0 || rn > 0) {
            wchar_t msg[4000], wb[3000];
            MultiByteToWideChar(CP_UTF8, 0, rb, -1, wb, 3000);
            swprintf(msg, 4000, L"The window could not open (exit code %lu).\n\n%ls\n\nThis text is also saved in:\n%ls",
                     code, rn ? wb : L"(no message)", logf);
            MessageBoxW(NULL, msg, APP_TITLE, MB_OK | MB_ICONERROR);
        }
    }
    CloseHandle(pi.hProcess);
    return 0;
}
