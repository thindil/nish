import os

# Package

version = "0.4.0"
author = "Bartek thindil Jasicki"
description = "An experimental command line shell"
license = "BSD-3-Clause"
srcDir = "src"
bin = @["nish"]
binDir = "bin"


# Dependencies

requires "nim >= 1.6.6"
requires "https://github.com/thindil/NimContracts#head"
requires "nimassets >= 0.2.4"

# Tasks

task debug, "builds the shell in debug mode":
  exec "nimble install -d -y"
  exec "nimassets -d=help -o=src/helpcontent.nim"
  exec "nim c -d:debug --styleCheck:hint --spellSuggest:auto --verbosity:2 --errorMax:0 --outdir:" &
      binDir & " " & srcDir & DirSep & "nish.nim"

task release, "builds the project in release mode":
  exec "nimble install -d -y"
  exec "nimassets -d=help -o=src/helpcontent.nim"
  exec "nim c -d:release --passc:-flto --passl:-s --outdir:" & binDir & " " &
      srcDir & DirSep & "nish.nim"

task tests, "run the project unit tests":
  exec "nimassets -d=help -o=src/helpcontent.nim"
  exec "testament pattern \"tests/**/*.nim\""
