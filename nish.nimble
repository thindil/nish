import os

# Package

version = "0.3.0"
author = "Bartek thindil Jasicki"
description = "An experimental command line shell"
license = "BSD-3-Clause"
srcDir = "src"
bin = @["nish"]
binDir = "bin"


# Dependencies

requires "nim >= 1.6.6"
requires "contracts >= 0.2.1"

# Tasks

task debug, "builds the shell in debug mode":
  exec "nimble install -d -y"
  exec "nim c -d:debug --styleCheck:hint --spellSuggest:auto --verbosity:2 --errorMax:0 --outdir:" &
      binDir & " " & srcDir & DirSep & "nish.nim"

task release, "builds the project in release mode":
  exec "nimble install -d -y"
  exec "nim c -d:release --passc:-flto --passl:-s --outdir:" & binDir & " " &
      srcDir & DirSep & "nish.nim"

task test, "run the project unit tests":
  exec "testament pattern \"tests/**/*.nim\""
