@echo on
:: Delegate to the Unixy script. We need to translate the key path variables
:: to be Unix-y rather than Windows-y, though.
set "saved_recipe_dir=%RECIPE_DIR%"
set "saved_source_dir=%SRC_DIR%"

FOR /F "delims=" %%i IN ('cygpath.exe -u "%PYTHON%"') DO set "BAZEL_PYTHON=%%i"
FOR /F "delims=" %%i IN ('cygpath.exe -u "%LIBRARY_PREFIX%\usr\bin\bash.exe"') DO set "BAZEL_SH=%%i"

:: FOR /F "delims=" %%i IN ('cygpath.exe -u -p "%PATH%"') DO set "PATH_OVERRIDE=%%i"
FOR /F "delims=" %%i IN ('cygpath.exe -u "%LIBRARY_PREFIX%"') DO set "LIBRARY_PREFIX=%%i"
FOR /F "delims=" %%i IN ('cygpath.exe -u "%PREFIX%"') DO set "PREFIX=%%i"
FOR /F "delims=" %%i IN ('cygpath.exe -u "%PYTHON%"') DO set "PYTHON=%%i"
FOR /F "delims=" %%i IN ('cygpath.exe -u "%RECIPE_DIR%"') DO set "RECIPE_DIR=%%i"
FOR /F "delims=" %%i IN ('cygpath.exe -u "%SP_DIR%"') DO set "SP_DIR=%%i"
FOR /F "delims=" %%i IN ('cygpath.exe -u "%SRC_DIR%"') DO set "SRC_DIR=%%i"
FOR /F "delims=" %%i IN ('cygpath.exe -u "%STDLIB_DIR%"') DO set "STDLIB_DIR=%%i"
FOR /F "delims=" %%i IN ('cygpath.exe -u "%JAVA_HOME%"') DO set "JAVA_HOME=%%i"

:: Need a very short TMPDIR otherwise we hit the max path limit while compiling bazel
FOR /F "delims=" %%i IN ('cygpath.exe -u "%SYSTEMDRIVE%\t"') DO set "TMPDIR=%%i"
FOR /F "delims=" %%i IN ('cygpath.exe -u "%SYSTEMDRIVE%\t"') DO set "TEMP=%%i"

set MSYSTEM=MINGW%ARCH%
set MSYS2_PATH_TYPE=inherit
set CHERE_INVOKING=1
set "BAZEL_VC=%VSINSTALLDIR%VC"
set "BAZEL_VS=%VSINSTALLDIR%"
set "EXTRA_BAZEL_ARGS=--host_javabase=@local_jdk//:jdk"

:: We need to unset some environment variables to make the java command line short enough
set AGENT_CLOUDID=
set AGENT_DISABLELOGPLUGIN_TESTFILEPUBLISHERPLUGIN=
set AGENT_DISABLELOGPLUGIN_TESTRESULTLOGPLUGIN=
set AGENT_ENABLE_PIPELINEARTIFACT_LARGE_CHUNK_SIZE=
set AGENT_HOMEDIRECTORY=
set AGENT_ID=
set AGENT_ISSELFHOSTED=
set AGENT_JOBNAME=
set AGENT_JOBSTATUS=
set AGENT_LOGTOBLOBSTORAGESERVICE=
set AGENT_MACHINENAME=
set AGENT_NAME=
set AGENT_OS=
set AGENT_OSARCHITECTURE=
set AGENT_READONLYVARIABLES=
set AGENT_RETAINDEFAULTENCODING=
set AGENT_ROOTDIRECTORY=
set AGENT_SERVEROMDIRECTORY=
set AGENT_TASKRESTRICTIONSENFORCEMENTMODE=
set AGENT_TEMPDIRECTORY=
set AGENT_TOOLSDIRECTORY=
set AGENT_USEWORKSPACEID=
set AGENT_VERSION=
set AGENT_WORKFOLDER=
set ANDROID_HOME=
set ANDROID_NDK=
set ANDROID_NDK_HOME=
set ANDROID_NDK_LATEST_HOME=
set ANDROID_NDK_PATH=
set ANDROID_NDK_ROOT=
set ANDROID_SDK_ROOT=
set ANT_HOME=
set AZURE_CONFIG_DIR=
set AZURE_DEVOPS_CACHE_DIR=
set AZURE_DEVOPS_EXT_CONFIG_DIR=
set AZURE_EXTENSION_DIR=
set AZURE_HTTP_USER_AGENT=
set CHOCOLATEYINSTALL=
set CHROMEWEBDRIVER=
set COMPUTERNAME=
set DOTNET_MULTILEVEL_LOOKUP=
set DOTNET_NOLOGO=
set DOTNET_SKIP_FIRST_TIME_EXPERIENCE=
set EDGEWEBDRIVER=
set FSHARPINSTALLDIR=
set GECKOWEBDRIVER=
set GOROOT_1_19_X64=
set GOROOT_1_20_X64=
set GOROOT_1_21_X64=
set NPY_VER=
set PIPX_BIN_DIR=
set PIPX_HOME=
set PIP_CACHE_DIR=
set PIP_IGNORE_INSTALLED=
set PIP_NO_BUILD_ISOLATION=
set PIP_NO_DEPENDENCIES=
set PIP_NO_INDEX=
set PROCESSOR_IDENTIFIER=
set PROCESSOR_REVISION=
set PY3K=
set PYTHONNOUSERSITE=
set PYTHONUNBUFFERED=
set PY_VCRUNTIME_REDIST=
set PY_VER=
set RTOOLS43_HOME=
set R_VER=
set SBT_HOME=
:: show remaining environment variables, in case the list grows enough
:: to run into "/lib/jvm/bin/java: Argument list too long" again.
set

bash -lx ./compile.sh
if errorlevel 1 exit 1

copy output\bazel.exe %LIBRARY_BIN%\
