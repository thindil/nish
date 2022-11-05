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

# Standard library imports
import std/[db_sqlite, os, osproc, strutils, terminal]
# External modules imports
import contracts
# Internal imports
import constants, directorypath, lstring, options, output, resultcode

proc getFormattedDir*(): DirectoryPath {.gcsafe, sideEffect, raises: [], tags: [
    ReadIOEffect], contractual.} =
  body:
    result = try:
      getCurrentDir().DirectoryPath
    except OSError:
      "[unknown dir]".DirectoryPath
    let homeDirectory: DirectoryPath = getHomeDir().DirectoryPath
    if endsWith(s = result & "/", suffix = $homeDirectory):
      return "~".DirectoryPath
    else:
      let homeIndex: ExtendedNatural = result.find(sub = homeDirectory)
      if homeIndex > -1:
        return DirectoryPath("~/" & result.string[homeIndex +
                homeDirectory.len()..^1])

proc showPrompt*(promptEnabled: bool; previousCommand: string;
    resultCode: ResultCode; db: DbConn): Natural {.gcsafe, sideEffect, raises: [],
    tags: [ReadIOEffect, WriteIOEffect, ReadDbEffect, TimeEffect, RootEffect],
    discardable, contractual.} =
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
  ##
  ## RETURNS
  ##
  ## The length of the last line of the prompt
  require:
    db != nil
  body:
    result = 0
    if not promptEnabled:
      return
    try:
      let promptCommand: OptionValue = getOption(optionName = initLimitedString(
          capacity = 13, text = "promptCommand"), db = db,
              defaultValue = initLimitedString(
          capacity = 8, text = "built-in"))
      if promptCommand != "built-in":
        var (output, exitCode) = execCmdEx(command = $promptCommand)
        if exitCode != QuitSuccess:
          showError(message = "Can't execute external command as the shell's prompt.")
          return
        if output.endsWith(suffix = '\n'):
          output.stripLineEnd()
          stdout.writeLine(output)
          return
        stdout.write(output)
        return output.len()
    except CapacityError, Exception:
      showError(message = "Can't get command for prompt. Reason: ",
          e = getCurrentException())
      return
    let currentDirectory: DirectoryPath = getFormattedDir()
    try:
      stdout.styledWrite(fgBlue, $currentDirectory)
    except ValueError, IOError:
      try:
        stdout.write(s = $currentDirectory)
      except IOError:
        discard
    result = currentDirectory.len()
    if previousCommand != "" and resultCode != QuitSuccess:
      let resultString = $resultCode
      try:
        stdout.styledWrite(fgRed, "[" & $resultCode & "]")
      except ValueError, IOError:
        try:
          stdout.write(s = "[" & resultString & "]")
        except IOError:
          discard
      result = result + 2 + resultString.len()
    try:
      stdout.styledWrite(fgBlue, "# ")
    except ValueError, IOError:
      try:
        stdout.write(s = "# ")
      except IOError:
        discard
    result = result + 2
