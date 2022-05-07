#!/usr/bin/env -S nim --hints:Off

import std/[os, strutils]

let zshConfig = readFile(getHomeDir() & ".zshrc")

for line in zshConfig.splitLines():
  var query: string = ""
  if line.startsWith("HISTSIZE="):
    query = "UPDATE options SET value='" & line[9..^1] & "' WHERE option='historyLength'"
  if query.len() > 0:
    echo query
