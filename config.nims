import os

switch("outdir", "bin")
switch("app", "console")

task debug, "builds the project in debug mode":
  switch("define", "debug")
  switch("styleCheck", "error")
  switch("spellSuggest", "auto")
  setCommand("c", "src" & DirSep & "nish.nim")

task release, "builds the project in release mode":
  switch("define", "release")
  switch("passc", "-flto")
  setCommand("c", "src" & DirSep & "nish.nim")
