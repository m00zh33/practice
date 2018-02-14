;process_chamaleon by hasherezade ported to asm by hh86
;https://github.com/hasherezade/process_chameleon
;12/02/2018

%include "pc.inc"

section .text
global _main
_main:

;-----------------------------------------------------------------------------
;recover ntdll and kernel32 image base
;-----------------------------------------------------------------------------

        fs mov  eax, dword [tebProcessEnvironmentBlock]
        mov     edx, dword [eax + pebLdr]
        mov     ecx, dword [edx + ldrInLoadOrderModuleList + 10h]
        mov     ebp, dword [ecx + mlDllBase - 10h]
        mov     esi, dword [edx + ldrInLoadOrderModuleList]
        push    esi
        push    eax
        lodsd
        xchg    esi, eax
        lodsd
        push    dword [eax + mlDllBase]
        call    parse_exps

;-----------------------------------------------------------------------------
;API CRC table, null terminated
;-----------------------------------------------------------------------------

        dd      058FF5064h                   ;RtlEnterCriticalSection
        dd      09FF81F51h                   ;RtlLeaveCriticalSection
        db      0

        mov     ebp, dword [esp + ntdcrcstk_size]
        call    parse_exps

;-----------------------------------------------------------------------------
;API CRC table, null terminated
;-----------------------------------------------------------------------------

        dd      0B09315F4h                   ;CloseHandle
        dd      0251097CCh                   ;ExitProcess
        dd      0526E0DCDh                   ;ExpandEnvironmentStringsW
        dd      0FC6B42F1h                   ;GetModuleFileNameW
        dd      02E50340Bh                   ;IsWow64Process
        dd      03FC1BD8Dh                   ;LoadLibraryA
        dd      0CCE95612h                   ;WriteFile
        dd      0D6874364h                   ;lstrcmpiA
        dd      0E90E2A0Ch                   ;lstrlenA
        dd      01DDA9F5Dh                   ;lstrlenW
        db      0

        call    load_usrdll

user32dll:
        db      "user32", 0
        
;-----------------------------------------------------------------------------
;API CRC table, null terminated
;-----------------------------------------------------------------------------

usrcrcbegin:
        dd      04B220411h                   ;GetDesktopWindow
        dd      0572D5D8Eh                   ;MessageBoxA
        dd      0A3F9E8DFh                   ;MessageBoxW
        db      0

;-----------------------------------------------------------------------------
;get paths and lock PEB for edit
;-----------------------------------------------------------------------------

        enter   MAX_PATH * 4, 0
        mov     edi, esp
        mov     edx, MAX_PATH
        lea     esi, dword [edi + edx * 2]
        push    edx                          ;GetModuleFileNameW
        push    esi                          ;GetModuleFileNameW
        push    ecx                          ;GetModuleFileNameW
        push    edx
        push    edi
        call    skip_calc

calc_path:
        dw      "%", "S", "Y", "S", "T", "E", "M", "R", "O", "O", "T", "%", "\", "s", "y", 
        dw      "s", "t", "e", "m", "3", "2", "\", "c", "a", "l", "c", ".", "e", "x", "e", 0

msg_calc:
        db      "My momma calls me calc :D", 0

tlt_calc:
        db      "Hello", 0

tlt_real:
        dw      "R", "e", "a", "l", " ", "p", "a", "t", "h", ":", 0

skip_calc:
        pop     ebx
        push    ebx
        call    dword [ebp + 4 + usrcrcstk_size + krncrcstk.kExpandEnvironmentStringsW]
        call    dword [ebp + 4 + usrcrcstk_size + krncrcstk.kGetModuleFileNameW]
        mov     eax, dword [ebp + 4 + usrcrcstk_size + krncrcstk_size + ntdcrcstk_size + 4]
        mov     ecx, dword [eax + pebFastPebLock]
        push    ecx                          ;RtlLeaveCriticalSection
        push    eax
        push    ecx
        call    dword [ebp + 4 + usrcrcstk_size + krncrcstk_size + ntdcrcstk.kRtlEnterCriticalSection]
        pop     eax
        pushad
        mov     ebx, dword [eax + pebProcessParameters]
        push    edi
        lea     edx, dword [ebx + RTL_USER_PROCESS_PARAMETERS + ImagePathName]
        mov     esi, edi
        call    setup_string
        pop     esi
        push    esi
        lea     edx, dword [ebx + RTL_USER_PROCESS_PARAMETERS + CommandLine]
        call    setup_string
        mov     eax, dword [ebp + 4 + usrcrcstk_size + krncrcstk_size + ntdcrcstk_size + 8]
        test    eax, eax
        je      skip_update
        mov     ecx, dword [eax + mlDllBase]
        jecxz   skip_update
        lea     edx, dword [ebx + RTL_USER_PROCESS_PARAMETERS + ImagePathName]
        lea     eax, dword [eax + mlFullDllName]
        call    setup_module
        add     eax, mlBaseDllName - mlFullDllName
        call    setup_module

skip_update:
        pop     edi
        push    edi
        call    dword [ebp + 4 + usrcrcstk_size + krncrcstk.klstrlenW]
        push    edi
        lea     edi, dword [edi + eax * 2]
        xchg    eax, ecx

find_loop:
        cmp     byte [edi], "\"
        je      found_slash
        dec     edi
        loop    find_loop
        jmp     skip_dirupdate

found_slash:
        mov     byte [edi], 0
        pop     esi
        lea     edx, dword [ebx + RTL_USER_PROCESS_PARAMETERS + CurrentDirectory + DosPath]
        call    setup_string

skip_dirupdate:
        popad
        call    dword [ebp + 4 + usrcrcstk_size + krncrcstk_size + ntdcrcstk.kRtlLeaveCriticalSection]
        call    dword [ebp + 4 + usrcrcstk.uGetDesktopWindow]
        xor     edi, edi
        push    edi                          ;ExitProcess
        lea     edx, dword [ebx + (tlt_real - calc_path)]
        push    edi                          ;MessageBoxW
        push    edx                          ;MessageBoxW
        push    esi                          ;MessageBoxW
        push    eax                          ;MessageBoxW
        lea     edx, dword [ebx + (tlt_calc - calc_path)]
        lea     ecx, dword [ebx + (msg_calc - calc_path)]
        push    edi
        push    edx
        push    ecx
        push    eax
        call    dword [ebp + 4 + usrcrcstk.uMessageBoxA]
        call    dword [ebp + 4 + usrcrcstk.uMessageBoxW]
        call    dword [ebp + 4 + usrcrcstk_size + krncrcstk.kExitProcess]

setup_string:
        mov     edi, dword [edx + UNICODE_STRING.Buffer]
        movzx   ecx, word [edx + UNICODE_STRING.MaximumLength]
        push    edi
        xor     eax, eax
        rep     stosb
        pop     edi
        push    edx
        push    esi
        call    dword [ebp + 4 + usrcrcstk_size + krncrcstk.klstrlenW]
        pop     edx
        add     eax, eax
        mov     ecx, eax
        mov     word [edx + UNICODE_STRING.UniLength], ax
        rep     movsb
        ret

setup_module:
        mov     cx, word [edx + UNICODE_STRING.UniLength]
        mov     word [eax + UNICODE_STRING.UniLength], cx
        mov     cx, word [edx + UNICODE_STRING.MaximumLength]
        mov     word [eax + UNICODE_STRING.MaximumLength], cx
        mov     ecx, dword [edx + UNICODE_STRING.Buffer]
        mov     dword [eax + UNICODE_STRING.Buffer], ecx
        ret

load_usrdll:
        pop     esi
        push    esi
        call    dword [esp + 4 + krncrcstk.kLoadLibraryA]
        add     esi, usrcrcbegin - user32dll
        xchg    eax, ebp
        push    esi

;-----------------------------------------------------------------------------
;parse export table
;-----------------------------------------------------------------------------

parse_exps:
        pop     esi
        mov     ebx, ebp
        mov     eax, dword [ebp + IMAGE_DOS_HEADER.e_lfanew]
        add     ebx, dword [ebp + eax + 78h] ;IMAGE_DOS_HEADER_lfanew shl 1
        cdq

walk_names:
        mov     eax, ebp
        mov     edi, ebp
        inc     edx
        add     eax, dword [ebx + IMAGE_EXPORT_DIRECTORY.AddressOfNames]
        add     edi, dword [eax + edx * 4]
        or      eax, -1

crc_outer:
        xor     al, byte [edi]
        push    8
        pop     ecx

crc_inner:
        shr     eax, 1
        jnc     crc_skip
        xor     eax, 0edb88320h

crc_skip:
        loop    crc_inner
        inc     edi
        cmp     byte [edi], cl
        jne     crc_outer
        not     eax
        cmp     dword [esi], eax
        jne     walk_names
        mov     edi, ebp
        mov     eax, ebp
        add     edi, dword [ebx + IMAGE_EXPORT_DIRECTORY.AddressOfNameOrdinals]
        movzx   edi, word [edi + edx * 2]
        add     eax, dword [ebx + IMAGE_EXPORT_DIRECTORY.AddressOfFunctions]
        mov     eax, dword [eax + edi * 4]
        add     eax, ebp
        push    eax
        lodsd
        sub     cl, byte [esi]
        jnz     walk_names
        inc     esi
        jmp     esi