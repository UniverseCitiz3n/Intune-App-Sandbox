#include "pch.h"
#include "IntuneSandboxCommand.h"

class CIntuneSandboxCmdModule final : public ATL::CAtlDllModuleT<CIntuneSandboxCmdModule>
{
};

CIntuneSandboxCmdModule _AtlModule;

extern "C" BOOL WINAPI DllMain(HINSTANCE hInstance, DWORD dwReason, LPVOID lpReserved)
{
    return _AtlModule.DllMain(dwReason, lpReserved);
}

extern "C" STDAPI DllCanUnloadNow(void)
{
    return _AtlModule.DllCanUnloadNow();
}

extern "C" STDAPI DllGetClassObject(REFCLSID rclsid, REFIID riid, LPVOID* ppv)
{
    return _AtlModule.DllGetClassObject(rclsid, riid, ppv);
}

extern "C" STDAPI DllRegisterServer(void)
{
    return S_OK;
}

extern "C" STDAPI DllUnregisterServer(void)
{
    return S_OK;
}
