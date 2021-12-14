import os

task debug, "builds the project in debug mode":
  switch("define", "debug")
  switch("styleCheck", "error")
  switch("spellSuggest")
  switch("outdir", "bin")
  setCommand("c", "src" & DirSep & "nish.nim")

task release, "builds the project in release mode":
  switch("define", "release")
  switch("passc", "-flto")
  switch("outdir", "bin")
  setCommand("c", "src" & DirSep & "nish.nim")
