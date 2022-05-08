#!/usr/bin/env -S nim --hints:Off

import std/[os, strutils]

let zshConfig = readFile(getHomeDir() & ".zshrc")
var sqlContent: seq[string]

for line in zshConfig.splitLines():
  var query: string = ""
  var equalIndex: int = -1
  if line.startsWith("HISTSIZE="):
    query = "UPDATE options SET value='" & line[9..^1] & "' WHERE option='historyLength'"
  elif line.startsWith("alias "):
    equalIndex = line.find('=')
    if line[equalIndex + 1] == '\'':
      query = "INSERT INTO aliases (name, path, recursive, commands, description) VALUES ('" &
          line[6..equalIndex - 1] & "', '/', 1, '" & line[
          equalIndex + 2..^2] & "', 'Alias imported from zsh')"
  elif line.startsWith("export "):
    equalIndex = line.find('=')
    query = "INSERT INTO variables (name, path, recursive, value, description) VALUES ('" &
        line[7..equalIndex - 1] & "', '/', 1, '" & line[equalIndex + 1..^1].strip(chars = {'"'}) &
        "', 'Variable imported from zsh')"
  if query.len() > 0:
    sqlContent.add(query)

writeFile("zsh.sql", sqlContent.join("\n"))
