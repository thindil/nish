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

import std/[db_sqlite, os, osproc, strutils, tables, terminal]
import constants, directorypath, lstring, options, output, resultcode

proc showPrompt*(promptEnabled: bool; previousCommand: string;
    resultCode: ResultCode; db: DbConn) {.gcsafe, sideEffect, raises: [],
    tags: [ReadIOEffect, WriteIOEffect, ReadDbEffect, TimeEffect,
        RootEffect].} =
  ## FUNCTION
  ##
  ## Show the shell prompt if the shell wasn't started in one command mode
  ##
  ## PARAMETERS
  ##
  ## * promptEnabled   - if true, show the prompt
  ## * previousCommand - the previous command executed by the user
  ## * resultCode      - the result of the previous command executed by the user
  ## * db              - the connection to the shell's database
  if not promptEnabled:
    return
  try:
    let promptCommand: OptionValue = getOption(optionName = initLimitedString(
        capacity = 13, text = "promptCommand"), db = db,
            defaultValue = initLimitedString(
        capacity = 8, text = "built-in"))
    if promptCommand != "built-in":
      let (output, exitCode) = execCmdEx(command = $promptCommand)
      if exitCode != QuitSuccess:
        discard showError(message = "Can't execute external command as the shell's prompt.")
        return
      stdout.write(output)
      return
  except CapacityError, Exception:
    discard showError(message = "Can't get command for prompt. Reason: ",
        e = getCurrentException())
    return
  let
    currentDirectory: DirectoryPath = try:
      getCurrentDir().DirectoryPath
    except OSError:
      "[unknown dir]".DirectoryPath
    homeDirectory: DirectoryPath = getHomeDir().DirectoryPath
  if endsWith(s = currentDirectory & "/", suffix = $homeDirectory):
    try:
      stdout.styledWrite(fgBlue, "~")
    except ValueError, IOError:
      try:
        stdout.write(s = "~")
      except IOError:
        discard
  else:
    let
      homeIndex: ExtendedNatural = currentDirectory.find(sub = homeDirectory)
      promptPath: string = currentDirectory.string[homeIndex +
              homeDirectory.len()..^1]
    if homeIndex > -1:
      try:
        stdout.styledWrite(fgBlue, "~/" & promptPath)
      except ValueError, IOError:
        try:
          stdout.write(s = "~/" & promptPath)
        except IOError:
          discard
    else:
      try:
        stdout.styledWrite(fgBlue, $currentDirectory)
      except ValueError, IOError:
        try:
          stdout.write(s = $currentDirectory)
        except IOError:
          discard
  if previousCommand != "" and resultCode != QuitSuccess:
    try:
      stdout.styledWrite(fgRed, "[" & $resultCode & "]")
    except ValueError, IOError:
      try:
        stdout.write(s = "[" & $resultCode & "]")
      except IOError:
        discard
  try:
    stdout.styledWrite(fgBlue, "# ")
  except ValueError, IOError:
    try:
      stdout.write(s = "# ")
    except IOError:
      discard

func initPrompt*(helpContent: var HelpTable) {.gcsafe, locks: 0,
    raises: [], tags: [].} =
  helpContent["prompt"] = HelpEntry(usage: "set options promptCommand 'program ?arguments?'",
      content: "The shell's prompt can be set as output of a command. It is possible by setting the shell's option promptCommand. For example, to set the prompt to listing the current directory, you can type options set promptCommand 'ls -a .'. Please remember, that the command will be executed every time before you execute another command.")
