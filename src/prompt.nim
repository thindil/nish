# Copyright © 2022-2024 Bartek Jasicki
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

## This module contains code related to the shell's prompt, like showing the
## prompt or getting formatted directory name

# Standard library imports
import std/[os, osproc, paths, strutils]
# External modules imports
import contracts, termstyle
import norm/sqlite
# Internal imports
import constants, options, output, theme, types

proc getFormattedDir*(): Path {.sideEffect, raises: [], tags: [
    ReadIOEffect], contractual.} =
  ## Get the formatted current directory path, replace home directory with
  ## tilde, etc.
  ##
  ## Returns the formatted path to the current directory
  body:
    result = try:
      getCurrentDirectory()
    except OSError:
      "[unknown dir]".Path
    let homeDirectory: Path = getHomeDir().Path
    if endsWith(s = $result & "/", suffix = homeDirectory.string):
      return "~".Path
    let homeIndex: ExtendedNatural = result.string.find(sub = homeDirectory.string)
    if homeIndex > -1:
      return ("~/" & ($result)[homeIndex +
          homeDirectory.len..^1]).Path

proc showPrompt*(promptEnabled: bool; previousCommand: string;
    resultCode: ResultCode; db: DbConn): Natural {.sideEffect, raises: [],
    tags: [ReadIOEffect, WriteIOEffect, ReadDbEffect, TimeEffect, RootEffect],
    discardable, contractual.} =
  ## Show the shell prompt if the shell wasn't started in one command mode
  ##
  ## * promptEnabled   - if true, show the prompt
  ## * previousCommand - the previous command executed by the user
  ## * resultCode      - the result of the previous command executed by the user
  ## * db              - the connection to the shell's database
  ##
  ## Returns the length of the last line of the prompt
  require:
    db != nil
  body:
    result = 0
    if not promptEnabled:
      return
    try:
      let promptCommand: OptionValue = getOption(optionName = "promptCommand", db = db,
              defaultValue = "built-in")
      if promptCommand != "built-in":
        var (output, exitCode) = execCmdEx(command = $promptCommand)
        if exitCode != QuitSuccess:
          showError(message = "Can't execute external command as the shell's prompt.", db = db)
          return
        if output.endsWith(suffix = '\n'):
          output.stripLineEnd
          stdout.writeLine(x = output)
          return
        stdout.write(s = output)
        return output.len
    except:
      showError(message = "Can't get command for prompt. Reason: ",
          e = getCurrentException(), db = db)
      return
    result = 0
    if previousCommand != "" and resultCode != QuitSuccess:
      let resultString: string = $exitStatusLikeShell(status = resultCode.cint)
      try:
        stdout.write(s = style(ss = "[" & resultString & "] ", style = getColor(
            db = db, name = promptError)))
      except ValueError, IOError:
        try:
          stdout.write(s = "[" & resultString & "] ")
        except IOError:
          discard
      result = 3 + resultString.len
    let currentDirectory: Path = getFormattedDir()
    try:
      stdout.write(s = style(ss = $currentDirectory, style = getColor(db = db,
          name = promptColor)))
    except ValueError, IOError:
      try:
        stdout.write(s = $currentDirectory)
      except IOError:
        discard
    result += currentDirectory.len
    try:
      stdout.write(s = style(ss = "# ", style = getColor(db = db,
          name = promptColor)))
    except ValueError, IOError:
      try:
        stdout.write(s = "# ")
      except IOError:
        discard
    result += 2
