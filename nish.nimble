import os

# Package

version = "0.6.0"
author = "Bartek thindil Jasicki"
description = "A non-POSIX, multiplatform command line shell"
license = "BSD-3-Clause"
srcDir = "src"
bin = @["nish"]
binDir = "bin"


# Dependencies

requires "nim >= 1.6.14"
requires "contracts >= 0.2.2"
requires "nimassets >= 0.2.4"
requires "nancy >= 0.1.1"
requires "termstyle >= 0.1.0"
requires "nimalyzer >= 0.7.1"
requires "norm >= 2.8.1"
requires "unittest2"

# Tasks

task man, "create the UNIX man page for the shell":
  let readme = readFile("README.md")
  var man = readFile("tools" & DirSep & "nish.1.in")
  man = man.replace("[README.md]", readme)
  man = man.replace("[VERSION]", version)
  writeFile(binDir & DirSep & "nish.1", man)
  echo "The Unix man page for the shell was created."

task debug, "builds the shell in debug mode":
  exec "nimble install -d -y"
  exec "nimassets -d=help -o=" & srcDir & DirSep & "helpcontent.nim"
  exec "nim c -d:debug --styleCheck:hint --spellSuggest:auto --errorMax:0 --outdir:" &
      binDir & " " & srcDir & DirSep & "nish.nim"

task release, "builds the project in release mode":
  exec "nimble install -d -y"
  exec "nimassets -d=help -o=" & srcDir & DirSep & "helpcontent.nim"
  exec "nim c -d:release --passc:-flto --passl:-s --outdir:" & binDir & " " &
      srcDir & DirSep & "nish.nim"

task test, "run the project unit tests":
  exec "nimassets -d=help -o=" & srcDir & DirSep & "helpcontent.nim"
  for file in listFiles("tests"):
    if file.endsWith("nim") and file != "tests" & DirSep & "megatest.nim":
      exec "nim c --verbosity:0 -r " & file

task releasearm, "builds the project in release mode for Linux on arm":
  exec "nimble install -d -y"
  exec "nimassets -d=help -o=" & srcDir & DirSep & "helpcontent.nim"
  exec "nim c --cpu:arm -d:release --passc:-flto --passl:-s --outdir:" &
      binDir & " " & srcDir & DirSep & "nish.nim"

task releasewindows, "builds the project in release mode for Windows 64-bit":
  exec "nimble install -d -y"
  exec "nimassets -d=help -o=" & srcDir & DirSep & "helpcontent.nim"
  exec "nim c -d:mingw --os:windows --cpu:amd64 --amd64.windows.gcc.exe:x86_64-w64-mingw32-gcc --amd64.windows.gcc.linkerexe=x86_64-w64-mingw32-gcc  -d:release --passc:-flto --passl:-s --outdir:" & binDir & " " & srcDir & DirSep & "nish.nim"
