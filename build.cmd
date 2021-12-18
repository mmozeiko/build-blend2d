@echo off
setlocal enabledelayedexpansion

rem *** check dependencies ***

where /q git.exe || (
  echo ERROR: "git.exe" not found
  exit /b 1
)

where /q curl.exe || (
  echo ERROR: "curl.exe" not found
  exit /b 1
)

where /q cmake.exe || (
  echo ERROR: "cmake.exe" not found
  exit /b 1
)

if exist "%ProgramFiles%\7-Zip\7z.exe" (
  set SZIP="%ProgramFiles%\7-Zip\7z.exe"
) else (
  where /q 7za.exe || (
    echo ERROR: 7-Zip installation or "7za.exe" not found
    exit /b 1
  )
  set SZIP=7za.exe
)

rem *** Visual Studio environment ***

where /Q cl.exe || (
  set __VSCMD_ARG_NO_LOGO=1
  for /f "tokens=*" %%i in ('"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -requires Microsoft.VisualStudio.Workload.NativeDesktop -property installationPath') do set VS=%%i
  if "!VS!" equ "" (
    echo ERROR: Visual Studio installation not found
    exit /b 1
  )  
  call "!VS!\VC\Auxiliary\Build\vcvarsall.bat" amd64 || exit /b 1
)

rem *** download sources ***

echo Downloading asmjit
if exist asmjit (
  pushd asmjit
  git pull --force --no-tags --depth 1 || exit /b 1
  popd
) else (
  git clone --depth 1 --no-tags --single-branch https://github.com/asmjit/asmjit || exit /b 1
)

echo Downloading blend2d
if exist blend2d.src (
  pushd blend2d.src
  git pull --force --no-tags --depth 1 || exit /b 1
  popd
) else (
  git clone --depth 1 --no-tags --single-branch https://github.com/blend2d/blend2d blend2d.src || exit /b 1
)

rem *** build ***

cmake                                         ^
  -S blend2d.src                              ^
  -B blend2d.build                            ^
  -A x64                                      ^
  -G "Visual Studio 17 2022"                  ^
  -D CMAKE_INSTALL_PREFIX="%CD%\blend2d"      ^
  -D CMAKE_POLICY_DEFAULT_CMP0091=NEW         ^
  -D CMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded || exit /b 1

cmake --build blend2d.build --config Release --target install

copy /y blend2d.src\.git\refs\heads\master blend2d\commit.txt 1>nul 2>nul

rem *** done ***
rem output is in blend2d folder

if "%GITHUB_WORKFLOW%" neq "" (
  set /p BLEND2D_COMMIT=<blend2d\commit.txt

  for /F "skip=1" %%D in ('WMIC OS GET LocalDateTime') do (set LDATE=%%D & goto :dateok)
  :dateok
  set BUILD_DATE=%LDATE:~0,4%-%LDATE:~4,2%-%LDATE:~6,2%

  %SZIP% a -mx=9 blend2d-%BUILD_DATE%.zip blend2d || exit /b 1

  echo ::set-output name=BLEND2D_COMMIT::%BLEND2D_COMMIT%
  echo ::set-output name=BUILD_DATE::%BUILD_DATE%
)
