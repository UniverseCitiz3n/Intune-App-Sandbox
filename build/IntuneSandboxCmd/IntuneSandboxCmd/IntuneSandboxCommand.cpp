#include "pch.h"
#include "IntuneSandboxCommand.h"

#include <cwchar>

using namespace IntuneSandbox;

namespace
{
    constexpr wchar_t kParentTitle[] = L"Intune-App-Sandbox";
    constexpr wchar_t kParentIconPath[] = L"C:\\SandboxEnvironment\\core\\intunewin-Box-icon.ico";
    constexpr wchar_t kInvokeTestScriptPath[] = L"C:\\SandboxEnvironment\\core\\Invoke-Test.ps1";
    constexpr wchar_t kInvokeIntuneWinScriptPath[] = L"C:\\SandboxEnvironment\\core\\Invoke-IntunewinUtil.ps1";

    bool HasExtension(const std::wstring& path, const wchar_t* extension)
    {
        const size_t index = path.find_last_of(L'.');
        if (index == std::wstring::npos)
        {
            return false;
        }

        return _wcsicmp(path.c_str() + index, extension) == 0;
    }
}

const CLSID CLSID_IntuneSandboxCommand = { 0xE6A6A7E5, 0x6C7C, 0x4E3F, { 0xAA, 0xC4, 0x2D, 0x47, 0xFB, 0xCF, 0x08, 0xF8 } };

// CIntuneSandboxChildCommand

void CIntuneSandboxChildCommand::Initialize(CommandKind kind) noexcept
{
    m_kind = kind;
}

HRESULT CIntuneSandboxChildCommand::DuplicateString(const std::wstring& value, LPWSTR* destination) noexcept
{
    if (!destination)
    {
        return E_POINTER;
    }

    *destination = nullptr;
    if (value.empty())
    {
        return S_OK;
    }

    const size_t bytes = (value.length() + 1) * sizeof(wchar_t);
    auto* buffer = static_cast<wchar_t*>(::CoTaskMemAlloc(bytes));
    if (!buffer)
    {
        return E_OUTOFMEMORY;
    }

    ::memcpy_s(buffer, bytes, value.c_str(), bytes);
    *destination = buffer;
    return S_OK;
}

bool CIntuneSandboxChildCommand::FileExists(const wchar_t* path) noexcept
{
    if (!path)
    {
        return false;
    }

    const DWORD attributes = ::GetFileAttributesW(path);
    return attributes != INVALID_FILE_ATTRIBUTES;
}

HRESULT CIntuneSandboxChildCommand::GetFirstItemPath(IShellItemArray* items, std::wstring& path) noexcept
{
    path.clear();
    if (!items)
    {
        return E_INVALIDARG;
    }

    CComPtr<IShellItem> firstItem;
    HRESULT hr = items->GetItemAt(0, &firstItem);
    if (FAILED(hr))
    {
        return hr;
    }

    PWSTR rawPath = nullptr;
    hr = firstItem->GetDisplayName(SIGDN_FILESYSPATH, &rawPath);
    if (FAILED(hr))
    {
        return hr;
    }

    path.assign(rawPath ? rawPath : L"");
    if (rawPath)
    {
        ::CoTaskMemFree(rawPath);
    }

    return S_OK;
}

std::wstring CIntuneSandboxChildCommand::GetPowerShellExecutable()
{
    wchar_t systemRoot[MAX_PATH] = {};
    const DWORD length = ::GetEnvironmentVariableW(L"SystemRoot", systemRoot, ARRAYSIZE(systemRoot));
    std::wstring basePath;
    if (length > 0 && length < ARRAYSIZE(systemRoot))
    {
        basePath.assign(systemRoot, length);
    }
    else
    {
        basePath = L"C:\\Windows";
    }

    basePath += L"\\System32\\WindowsPowerShell\\v1.0\\powershell.exe";
    return basePath;
}

std::wstring CIntuneSandboxChildCommand::BuildArguments(const std::wstring& packagePath) const
{
    std::wstring arguments = L"-ExecutionPolicy Bypass -NoProfile -File \"";

    switch (m_kind)
    {
    case CommandKind::RunTest:
    case CommandKind::RunTestWithWinget:
        arguments += kInvokeTestScriptPath;
        break;
    case CommandKind::PackWithIntuneWinUtil:
        arguments += kInvokeIntuneWinScriptPath;
        break;
    }

    arguments += L"\" -PackagePath \"";
    arguments += packagePath;
    arguments += L"\"";

    if (m_kind == CommandKind::RunTestWithWinget)
    {
        arguments += L" -EnableWinget";
    }

    return arguments;
}

IFACEMETHODIMP CIntuneSandboxChildCommand::GetTitle(IShellItemArray*, LPWSTR* ppszName)
{
    if (!ppszName)
    {
        return E_POINTER;
    }

    std::wstring title;
    switch (m_kind)
    {
    case CommandKind::RunTest:
        title = L"Run test in Sandbox";
        break;
    case CommandKind::RunTestWithWinget:
        title = L"Run test in Sandbox (WinGet enabled)";
        break;
    case CommandKind::PackWithIntuneWinUtil:
        title = L"Pack with IntunewinUtil";
        break;
    }

    return DuplicateString(title, ppszName);
}

IFACEMETHODIMP CIntuneSandboxChildCommand::GetIcon(IShellItemArray*, LPWSTR* ppszIcon)
{
    return DuplicateString(kParentIconPath, ppszIcon);
}

IFACEMETHODIMP CIntuneSandboxChildCommand::GetToolTip(IShellItemArray*, LPWSTR* ppszInfotip)
{
    if (ppszInfotip)
    {
        *ppszInfotip = nullptr;
    }

    return S_FALSE;
}

IFACEMETHODIMP CIntuneSandboxChildCommand::GetCanonicalName(GUID* pguidCommandName)
{
    if (!pguidCommandName)
    {
        return E_POINTER;
    }

    *pguidCommandName = GUID_NULL;
    return S_OK;
}

IFACEMETHODIMP CIntuneSandboxChildCommand::GetState(IShellItemArray*, BOOL, EXPCMDSTATE* pCmdState)
{
    if (!pCmdState)
    {
        return E_POINTER;
    }

    const wchar_t* scriptPath = nullptr;
    switch (m_kind)
    {
    case CommandKind::RunTest:
    case CommandKind::RunTestWithWinget:
        scriptPath = kInvokeTestScriptPath;
        break;
    case CommandKind::PackWithIntuneWinUtil:
        scriptPath = kInvokeIntuneWinScriptPath;
        break;
    }

    *pCmdState = FileExists(scriptPath) ? ECS_ENABLED : ECS_HIDDEN;
    return S_OK;
}

IFACEMETHODIMP CIntuneSandboxChildCommand::Invoke(IShellItemArray* psiItemArray, IBindCtx*)
{
    std::wstring packagePath;
    HRESULT hr = GetFirstItemPath(psiItemArray, packagePath);
    if (FAILED(hr))
    {
        return hr;
    }

    if (packagePath.empty())
    {
        return E_FAIL;
    }

    const std::wstring executable = GetPowerShellExecutable();
    const std::wstring arguments = BuildArguments(packagePath);

    SHELLEXECUTEINFOW execInfo{};
    execInfo.cbSize = sizeof(execInfo);
    execInfo.fMask = SEE_MASK_FLAG_NO_UI | SEE_MASK_NOASYNC;
    execInfo.lpFile = executable.c_str();
    execInfo.lpParameters = arguments.c_str();
    execInfo.nShow = SW_SHOWNORMAL;

    if (!::ShellExecuteExW(&execInfo))
    {
        return HRESULT_FROM_WIN32(::GetLastError());
    }

    return S_OK;
}

IFACEMETHODIMP CIntuneSandboxChildCommand::GetFlags(EXPCMDFLAGS* pFlags)
{
    if (!pFlags)
    {
        return E_POINTER;
    }

    *pFlags = ECF_DEFAULT;
    return S_OK;
}

IFACEMETHODIMP CIntuneSandboxChildCommand::EnumSubCommands(IEnumExplorerCommand** ppEnum)
{
    if (ppEnum)
    {
        *ppEnum = nullptr;
    }

    return E_NOTIMPL;
}

// CIntuneSandboxCommandEnumerator

HRESULT CIntuneSandboxCommandEnumerator::Initialize(const std::vector<CComPtr<IExplorerCommand>>& commands)
{
    m_commands = commands;
    m_currentIndex = 0;
    return S_OK;
}

IFACEMETHODIMP CIntuneSandboxCommandEnumerator::Next(ULONG celt, IExplorerCommand** apUICommand, ULONG* pceltFetched)
{
    if (!apUICommand)
    {
        return E_POINTER;
    }

    ULONG fetched = 0;
    while (fetched < celt && m_currentIndex < m_commands.size())
    {
        apUICommand[fetched] = m_commands[m_currentIndex];
        if (apUICommand[fetched])
        {
            apUICommand[fetched]->AddRef();
        }
        ++fetched;
        ++m_currentIndex;
    }

    if (pceltFetched)
    {
        *pceltFetched = fetched;
    }

    return fetched == celt ? S_OK : S_FALSE;
}

IFACEMETHODIMP CIntuneSandboxCommandEnumerator::Skip(ULONG celt)
{
    const size_t remaining = m_commands.size() - m_currentIndex;
    if (celt > remaining)
    {
        m_currentIndex = m_commands.size();
        return S_FALSE;
    }

    m_currentIndex += celt;
    return S_OK;
}

IFACEMETHODIMP CIntuneSandboxCommandEnumerator::Reset()
{
    m_currentIndex = 0;
    return S_OK;
}

IFACEMETHODIMP CIntuneSandboxCommandEnumerator::Clone(IEnumExplorerCommand** ppEnum)
{
    if (!ppEnum)
    {
        return E_POINTER;
    }

    *ppEnum = nullptr;

    CComObject<CIntuneSandboxCommandEnumerator>* clone = nullptr;
    HRESULT hr = CComObject<CIntuneSandboxCommandEnumerator>::CreateInstance(&clone);
    if (FAILED(hr))
    {
        return hr;
    }

    clone->AddRef();
    hr = clone->Initialize(m_commands);
    if (FAILED(hr))
    {
        clone->Release();
        return hr;
    }

    clone->m_currentIndex = m_currentIndex;
    *ppEnum = clone;
    return S_OK;
}

// CIntuneSandboxCommand

HRESULT CIntuneSandboxCommand::DuplicateString(const std::wstring& value, LPWSTR* destination) noexcept
{
    if (!destination)
    {
        return E_POINTER;
    }

    *destination = nullptr;
    if (value.empty())
    {
        return S_OK;
    }

    const size_t bytes = (value.length() + 1) * sizeof(wchar_t);
    auto* buffer = static_cast<wchar_t*>(::CoTaskMemAlloc(bytes));
    if (!buffer)
    {
        return E_OUTOFMEMORY;
    }

    ::memcpy_s(buffer, bytes, value.c_str(), bytes);
    *destination = buffer;
    return S_OK;
}

bool CIntuneSandboxCommand::FileExists(const wchar_t* path) noexcept
{
    if (!path)
    {
        return false;
    }

    const DWORD attributes = ::GetFileAttributesW(path);
    return attributes != INVALID_FILE_ATTRIBUTES;
}

void CIntuneSandboxCommand::ResetSelection() noexcept
{
    m_selection.Release();
    m_selectedPath.clear();
    m_selectionKind = SelectionKind::None;
}

HRESULT CIntuneSandboxCommand::UpdateSelectionFromItems(IShellItemArray* items)
{
    ResetSelection();
    if (!items)
    {
        return S_OK;
    }

    m_selection = items;

    CComPtr<IShellItem> firstItem;
    HRESULT hr = items->GetItemAt(0, &firstItem);
    if (FAILED(hr))
    {
        return S_OK;
    }

    PWSTR path = nullptr;
    hr = firstItem->GetDisplayName(SIGDN_FILESYSPATH, &path);
    if (FAILED(hr))
    {
        return S_OK;
    }

    m_selectedPath.assign(path ? path : L"");
    if (path)
    {
        ::CoTaskMemFree(path);
    }

    if (m_selectedPath.empty())
    {
        return S_OK;
    }

    const DWORD attributes = ::GetFileAttributesW(m_selectedPath.c_str());
    if (attributes != INVALID_FILE_ATTRIBUTES && (attributes & FILE_ATTRIBUTE_DIRECTORY))
    {
        m_selectionKind = SelectionKind::Directory;
        return S_OK;
    }

    if (HasExtension(m_selectedPath, L".intunewin"))
    {
        m_selectionKind = SelectionKind::IntuneWinPackage;
    }

    return S_OK;
}

HRESULT CIntuneSandboxCommand::UpdateSelectionFromSite()
{
    if (!m_site)
    {
        ResetSelection();
        return S_OK;
    }

    CComPtr<IServiceProvider> provider;
    HRESULT hr = m_site->QueryInterface(IID_PPV_ARGS(&provider));
    if (FAILED(hr))
    {
        ResetSelection();
        return S_OK;
    }

    CComPtr<IShellItemArray> items;
    hr = provider->QueryService(SID_SSelection, IID_PPV_ARGS(&items));
    if (FAILED(hr))
    {
        ResetSelection();
        return S_OK;
    }

    return UpdateSelectionFromItems(items);
}

bool CIntuneSandboxCommand::HasAvailableCommands() const noexcept
{
    switch (m_selectionKind)
    {
    case SelectionKind::IntuneWinPackage:
        return FileExists(kInvokeTestScriptPath);
    case SelectionKind::Directory:
        return FileExists(kInvokeIntuneWinScriptPath);
    default:
        return false;
    }
}

IFACEMETHODIMP CIntuneSandboxCommand::GetTitle(IShellItemArray*, LPWSTR* ppszName)
{
    return DuplicateString(kParentTitle, ppszName);
}

IFACEMETHODIMP CIntuneSandboxCommand::GetIcon(IShellItemArray*, LPWSTR* ppszIcon)
{
    return DuplicateString(kParentIconPath, ppszIcon);
}

IFACEMETHODIMP CIntuneSandboxCommand::GetToolTip(IShellItemArray*, LPWSTR* ppszInfotip)
{
    if (ppszInfotip)
    {
        *ppszInfotip = nullptr;
    }

    return S_FALSE;
}

IFACEMETHODIMP CIntuneSandboxCommand::GetCanonicalName(GUID* pguidCommandName)
{
    if (!pguidCommandName)
    {
        return E_POINTER;
    }

    *pguidCommandName = CLSID_IntuneSandboxCommand;
    return S_OK;
}

IFACEMETHODIMP CIntuneSandboxCommand::GetState(IShellItemArray* psiItemArray, BOOL, EXPCMDSTATE* pCmdState)
{
    if (!pCmdState)
    {
        return E_POINTER;
    }

    if (psiItemArray)
    {
        UpdateSelectionFromItems(psiItemArray);
    }

    *pCmdState = HasAvailableCommands() ? ECS_ENABLED : ECS_HIDDEN;
    return S_OK;
}

IFACEMETHODIMP CIntuneSandboxCommand::Invoke(IShellItemArray*, IBindCtx*)
{
    return E_NOTIMPL;
}

IFACEMETHODIMP CIntuneSandboxCommand::GetFlags(EXPCMDFLAGS* pFlags)
{
    if (!pFlags)
    {
        return E_POINTER;
    }

    *pFlags = static_cast<EXPCMDFLAGS>(ECF_DEFAULT | ECF_HASSUBCOMMANDS);
    return S_OK;
}

IFACEMETHODIMP CIntuneSandboxCommand::EnumSubCommands(IEnumExplorerCommand** ppEnum)
{
    if (!ppEnum)
    {
        return E_POINTER;
    }

    *ppEnum = nullptr;

    if (!HasAvailableCommands())
    {
        return S_FALSE;
    }

    std::vector<CComPtr<IExplorerCommand>> commands;

    if (m_selectionKind == SelectionKind::IntuneWinPackage)
    {
        if (!FileExists(kInvokeTestScriptPath))
        {
            return S_FALSE;
        }

        CComObject<CIntuneSandboxChildCommand>* runTest = nullptr;
        HRESULT hr = CComObject<CIntuneSandboxChildCommand>::CreateInstance(&runTest);
        if (FAILED(hr))
        {
            return hr;
        }
        runTest->AddRef();
        runTest->Initialize(CommandKind::RunTest);
        commands.emplace_back(runTest);

        CComObject<CIntuneSandboxChildCommand>* runTestWinget = nullptr;
        hr = CComObject<CIntuneSandboxChildCommand>::CreateInstance(&runTestWinget);
        if (FAILED(hr))
        {
            return hr;
        }
        runTestWinget->AddRef();
        runTestWinget->Initialize(CommandKind::RunTestWithWinget);
        commands.emplace_back(runTestWinget);
    }
    else if (m_selectionKind == SelectionKind::Directory)
    {
        if (!FileExists(kInvokeIntuneWinScriptPath))
        {
            return S_FALSE;
        }

        CComObject<CIntuneSandboxChildCommand>* packCommand = nullptr;
        HRESULT hr = CComObject<CIntuneSandboxChildCommand>::CreateInstance(&packCommand);
        if (FAILED(hr))
        {
            return hr;
        }
        packCommand->AddRef();
        packCommand->Initialize(CommandKind::PackWithIntuneWinUtil);
        commands.emplace_back(packCommand);
    }
    else
    {
        return S_FALSE;
    }

    if (commands.empty())
    {
        return S_FALSE;
    }

    CComObject<CIntuneSandboxCommandEnumerator>* enumerator = nullptr;
    HRESULT hr = CComObject<CIntuneSandboxCommandEnumerator>::CreateInstance(&enumerator);
    if (FAILED(hr))
    {
        return hr;
    }

    enumerator->AddRef();
    hr = enumerator->Initialize(commands);
    if (FAILED(hr))
    {
        enumerator->Release();
        return hr;
    }

    *ppEnum = enumerator;
    return S_OK;
}

IFACEMETHODIMP CIntuneSandboxCommand::SetSite(IUnknown* punkSite)
{
    m_site = punkSite;
    return UpdateSelectionFromSite();
}

IFACEMETHODIMP CIntuneSandboxCommand::GetSite(REFIID riid, void** ppvSite)
{
    if (!ppvSite)
    {
        return E_POINTER;
    }

    *ppvSite = nullptr;
    if (!m_site)
    {
        return E_FAIL;
    }

    return m_site->QueryInterface(riid, ppvSite);
}
