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

import std/[os, strutils, terminal]

proc showPrompt*(promptEnabled: bool; previousCommand: string;
    resultCode: int) {.gcsafe, locks: 0, sideEffect, raises: [OSError, IOError,
        ValueError], tags: [ReadIOEffect, WriteIOEffect].} =
  ## Show the shell prompt if the shell wasn't started in one command mode
  if not promptEnabled:
    return
  let
    currentDirectory: string = getCurrentDir()
    homeDirectory: string = getHomeDir()
  if endsWith(currentDirectory & "/", homeDirectory):
    stdout.styledWrite(fgBlue, "~")
  else:
    let homeIndex: int = currentDirectory.find(homeDirectory)
    if homeIndex > -1:
      stdout.styledWrite(fgBlue, "~/" & currentDirectory[homeIndex +
          homeDirectory.len()..^1])
    else:
      stdout.styledWrite(fgBlue, currentDirectory)
  if previousCommand != "" and resultCode != QuitSuccess:
    stdout.styledWrite(fgRed, "[" & $resultCode & "]")
  stdout.styledWrite(fgBlue, "# ")

proc showOutput*(message: string; newLine: bool;
    promptEnabled: bool; previousCommand: string; returnCode: int) {.gcsafe,
        locks: 0, sideEffect, raises: [OSError, IOError, ValueError], tags: [
            ReadIOEffect, WriteIOEffect].} =
  ## Show the selected message and prompt (if enabled, default) to the user.
  ## If newLine is true, add a new line after message.
  showPrompt(promptEnabled, previousCommand, returnCode)
  if message != "":
    stdout.write(message)
    if newLine:
      stdout.writeLine("")
  stdout.flushFile()

proc showError*(message: string = ""): int {.gcsafe, locks: 0, sideEffect,
    raises: [IOError, ValueError], tags: [WriteIOEffect].} =
  ## Print the message to standard error and set the shell return
  ## code to error. If message is empty, print the current exception message
  if message == "":
    stderr.styledWriteLine(fgRed, getCurrentExceptionMsg())
  else:
    stderr.styledWriteLine(fgRed, message)
  result = QuitFailure

