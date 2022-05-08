#!/usr/bin/env -S nim --hints:Off
# Copyright © 2022 Bartek Jasicki <thindil@laeran.pl>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 1. Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
# 3. Neither the name of the copyright holder nor the
# names of its contributors may be used to endorse or promote products
# derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY COPYRIGHT HOLDERS AND CONTRIBUTORS ''AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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
