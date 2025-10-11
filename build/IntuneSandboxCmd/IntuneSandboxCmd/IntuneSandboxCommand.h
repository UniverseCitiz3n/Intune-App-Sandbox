#pragma once

#include "pch.h"

// {E6A6A7E5-6C7C-4E3F-AAC4-2D47FBCF08F8}
extern const CLSID CLSID_IntuneSandboxCommand;

namespace IntuneSandbox
{
    enum class SelectionKind
    {
        None,
        IntuneWinPackage,
        Directory
    };

    enum class CommandKind
    {
        RunTest,
        RunTestWithWinget,
        PackWithIntuneWinUtil
    };

    class ATL_NO_VTABLE CIntuneSandboxChildCommand final
        : public ATL::CComObjectRootEx<ATL::CComSingleThreadModel>
        , public IExplorerCommand
    {
    public:
        CIntuneSandboxChildCommand() = default;

        void Initialize(CommandKind kind) noexcept;

        BEGIN_COM_MAP(CIntuneSandboxChildCommand)
            COM_INTERFACE_ENTRY(IExplorerCommand)
        END_COM_MAP()

        // IExplorerCommand
        IFACEMETHODIMP GetTitle(IShellItemArray* psiItemArray, LPWSTR* ppszName) override;
        IFACEMETHODIMP GetIcon(IShellItemArray* psiItemArray, LPWSTR* ppszIcon) override;
        IFACEMETHODIMP GetToolTip(IShellItemArray* psiItemArray, LPWSTR* ppszInfotip) override;
        IFACEMETHODIMP GetCanonicalName(GUID* pguidCommandName) override;
        IFACEMETHODIMP GetState(IShellItemArray* psiItemArray, BOOL fOkToBeSlow, EXPCMDSTATE* pCmdState) override;
        IFACEMETHODIMP Invoke(IShellItemArray* psiItemArray, IBindCtx* pbc) override;
        IFACEMETHODIMP GetFlags(EXPCMDFLAGS* pFlags) override;
        IFACEMETHODIMP EnumSubCommands(IEnumExplorerCommand** ppEnum) override;

    private:
        static HRESULT DuplicateString(const std::wstring& value, LPWSTR* destination) noexcept;
        static bool FileExists(const wchar_t* path) noexcept;
        static HRESULT GetFirstItemPath(IShellItemArray* items, std::wstring& path) noexcept;
        static std::wstring GetPowerShellExecutable();
        std::wstring BuildArguments(const std::wstring& packagePath) const;

        CommandKind m_kind{ CommandKind::RunTest };
    };

    class ATL_NO_VTABLE CIntuneSandboxCommandEnumerator final
        : public ATL::CComObjectRootEx<ATL::CComSingleThreadModel>
        , public IEnumExplorerCommand
    {
    public:
        CIntuneSandboxCommandEnumerator() = default;

        BEGIN_COM_MAP(CIntuneSandboxCommandEnumerator)
            COM_INTERFACE_ENTRY(IEnumExplorerCommand)
        END_COM_MAP()

        HRESULT Initialize(const std::vector<CComPtr<IExplorerCommand>>& commands);

        // IEnumExplorerCommand
        IFACEMETHODIMP Next(ULONG celt, IExplorerCommand** apUICommand, ULONG* pceltFetched) override;
        IFACEMETHODIMP Skip(ULONG celt) override;
        IFACEMETHODIMP Reset() override;
        IFACEMETHODIMP Clone(IEnumExplorerCommand** ppEnum) override;

    private:
        std::vector<CComPtr<IExplorerCommand>> m_commands;
        size_t m_currentIndex{ 0 };
    };

    class ATL_NO_VTABLE CIntuneSandboxCommand final
        : public ATL::CComObjectRootEx<ATL::CComSingleThreadModel>
        , public ATL::CComCoClass<CIntuneSandboxCommand, &CLSID_IntuneSandboxCommand>
        , public IExplorerCommand
        , public IObjectWithSite
    {
    public:
        CIntuneSandboxCommand() = default;

        DECLARE_NO_REGISTRY()

        BEGIN_COM_MAP(CIntuneSandboxCommand)
            COM_INTERFACE_ENTRY(IExplorerCommand)
            COM_INTERFACE_ENTRY(IObjectWithSite)
        END_COM_MAP()

        // IExplorerCommand
        IFACEMETHODIMP GetTitle(IShellItemArray* psiItemArray, LPWSTR* ppszName) override;
        IFACEMETHODIMP GetIcon(IShellItemArray* psiItemArray, LPWSTR* ppszIcon) override;
        IFACEMETHODIMP GetToolTip(IShellItemArray* psiItemArray, LPWSTR* ppszInfotip) override;
        IFACEMETHODIMP GetCanonicalName(GUID* pguidCommandName) override;
        IFACEMETHODIMP GetState(IShellItemArray* psiItemArray, BOOL fOkToBeSlow, EXPCMDSTATE* pCmdState) override;
        IFACEMETHODIMP Invoke(IShellItemArray* psiItemArray, IBindCtx* pbc) override;
        IFACEMETHODIMP GetFlags(EXPCMDFLAGS* pFlags) override;
        IFACEMETHODIMP EnumSubCommands(IEnumExplorerCommand** ppEnum) override;

        // IObjectWithSite
        IFACEMETHODIMP SetSite(IUnknown* punkSite) override;
        IFACEMETHODIMP GetSite(REFIID riid, void** ppvSite) override;

    private:
        void ResetSelection() noexcept;
        HRESULT UpdateSelectionFromSite();
        HRESULT UpdateSelectionFromItems(IShellItemArray* items);
        bool HasAvailableCommands() const noexcept;
        static HRESULT DuplicateString(const std::wstring& value, LPWSTR* destination) noexcept;
        static bool FileExists(const wchar_t* path) noexcept;

        CComPtr<IUnknown> m_site;
        CComPtr<IShellItemArray> m_selection;
        std::wstring m_selectedPath;
        SelectionKind m_selectionKind{ SelectionKind::None };
    };
}

OBJECT_ENTRY_AUTO(CLSID_IntuneSandboxCommand, IntuneSandbox::CIntuneSandboxCommand)
