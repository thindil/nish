import os

switch("app", "console")

task debug, "builds the project in debug mode":
  switch("outdir", "bin")
  switch("define", "debug")
  switch("styleCheck", "error")
  switch("spellSuggest", "auto")
  switch("verbosity", "2")
  setCommand("c", "src" & DirSep & "nish.nim")

task release, "builds the project in release mode":
  switch("outdir", "bin")
  switch("define", "release")
  switch("passc", "-flto")
  switch("passl", "-s")
  setCommand("c", "src" & DirSep & "nish.nim")
