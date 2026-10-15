# Packaged modules: <Wine build path>|<path under CrossOver's SharedSupport/CrossOver>.
# Empty build paths are non-Wine modules; output and package filenames are install basenames.
MODULE_TABLE='
dlls/ntdll/ntdll.so|lib/wine/x86_64-unix/ntdll.so
dlls/kernel32/x86_64-windows/kernel32.dll|lib/wine/x86_64-windows/kernel32.dll
dlls/ntoskrnl.exe/x86_64-windows/ntoskrnl.exe|lib/wine/x86_64-windows/ntoskrnl.exe
programs/lsass/x86_64-windows/lsass.exe|lib/wine/x86_64-windows/lsass.exe
programs/wineboot/x86_64-windows/wineboot.exe|lib/wine/x86_64-windows/wineboot.exe
server/wineserver|CrossOver-Hosted Application/wineserver
|lib64/libMoltenVK.dylib
'

MODULE_NAMES=()
MODULE_INSTALL_PATHS=()
WINE_BUILD_PATHS=()
WINE_MODULE_NAMES=()
while IFS='|' read -r build install; do
  [ -n "$install" ] || continue
  MODULE_NAMES+=("${install##*/}")
  MODULE_INSTALL_PATHS+=("$install")
  if [ -n "$build" ]; then
    WINE_BUILD_PATHS+=("$build")
    WINE_MODULE_NAMES+=("${install##*/}")
  fi
done <<< "$MODULE_TABLE"
unset build install
