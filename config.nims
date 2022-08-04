import os

switch("app", "console")

task release, "builds the project in release mode":
  switch("outdir", "bin")
  switch("define", "release")
  switch("passc", "-flto")
  switch("passl", "-s")
#  switch("assertions", "off")
  setCommand("c", "src" & DirSep & "nish.nim")
