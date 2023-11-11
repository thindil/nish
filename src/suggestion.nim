# Copyright © 2023 Bartek Jasicki
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

## This module contains code related to the correction of invalid commands
## entered by the user.

# Standard library imports
import std/[editdistance, os, strutils, tables]
# External modules imports
import contracts
# Internal imports
import commandslist, constants

var suggestions: seq[string] = @[]
  ## the list of all available commands to the user, used in the suggestions
  ## system

proc fillSuggestionsList*(aliases: ref AliasesList;
    commands: ref CommandsList) {.raises: [], tags: [ReadEnvEffect,
    ReadDirEffect], contractual.} =
  ## Fill the list of suggestions with commands. Do nothing if the list is
  ## filled already
  ##
  ## * aliases  - the list of the shell's aliases
  ## * commands - the list of the shell's commands
  body:
    # if suggestions list is not empty, quit
    if suggestions.len > 0:
      return
    # Add aliases to the suggestions list
    for alias in aliases.keys:
      suggestions.add(y = $alias)
    # Add all commands to the suggestions list
    for command in commands.keys:
      suggestions.add(y = command)
    # Add built-in shell's commands to the suggestions list
    for command in builtinCommands:
      suggestions.add(y = command)
    for path in getEnv(key = "PATH").split(sep = PathSep):
      for file in walkFiles(pattern = path & DirSep & "*"):
        let fileName: string = file.extractFilename
        if fileName notin suggestions:
          suggestions.add(y = fileName)

proc suggestCommand*(invalidName: string;
    start: var Natural): string {.raises: [], tags: [], contractual.} =
  ## Get the command suggestion, based on Levenshtein distance algorithm
  ##
  ## * invalidName - the name of the invalid command for which the suggestion
  ##                 will be looked for
  ## * start       - the index for suggestions list from which start looking
  ##                 for the suggestion
  ##
  ## Returns the name of the suggested command and the modified parameter
  ## start. If no suggestion found, returns an empty string.
  require:
    invalidName.len > 0
  body:
    if start >= suggestions.len:
      return ""
    for i in start .. suggestions.high:
      if editDistanceAscii(a = invalidName, b = suggestions[i]) == 1:
        start = i + 1
        return suggestions[i]
    return ""
