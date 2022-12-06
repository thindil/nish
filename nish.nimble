import os

# Package

version = "0.4.0"
author = "Bartek thindil Jasicki"
description = "A non-POSIX, multiplatform command line shell"
license = "BSD-3-Clause"
srcDir = "src"
bin = @["nish"]
binDir = "bin"


# Dependencies

requires "nim >= 1.6.6"
requires "contracts >= 0.2.2"
requires "nimassets >= 0.2.4"
requires "nancy >= 0.1.1"
requires "termstyle >= 0.1.0"

# Tasks

task debug, "builds the shell in debug mode":
  exec "nimble install -d -y"
  exec "nimassets -d=help -o=src/helpcontent.nim"
  exec "nim c -d:debug --styleCheck:hint --spellSuggest:auto --errorMax:0 --outdir:" &
      binDir & " " & srcDir & DirSep & "nish.nim"

task release, "builds the project in release mode":
  exec "nimble install -d -y"
  exec "nimassets -d=help -o=src/helpcontent.nim"
  exec "nim c -d:release --passc:-flto --passl:-s --outdir:" & binDir & " " &
      srcDir & DirSep & "nish.nim"

task tests, "run the project unit tests":
  exec "nimassets -d=help -o=src/helpcontent.nim"
  exec "testament pattern \"tests/**/*.nim\""
