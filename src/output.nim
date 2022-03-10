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
    resultCode: int) {.gcsafe, locks: 0, sideEffect, raises: [],
        tags: [ReadIOEffect, WriteIOEffect].} =
  ## Show the shell prompt if the shell wasn't started in one command mode
  if not promptEnabled:
    return
  let
    currentDirectory: string = (try: getCurrentDir() except OSError: "[unknown dir]")
    homeDirectory: string = getHomeDir()
  if endsWith(currentDirectory & "/", homeDirectory):
    try:
      stdout.styledWrite(fgBlue, "~")
    except ValueError, IOError:
      echo("~")
  else:
    let homeIndex: int = currentDirectory.find(homeDirectory)
    if homeIndex > -1:
      try:
        stdout.styledWrite(fgBlue, "~/" & currentDirectory[homeIndex +
            homeDirectory.len()..^1])
      except ValueError, IOError:
        echo("~/" & currentDirectory[homeIndex + homeDirectory.len()..^1])
    else:
      try:
        stdout.styledWrite(fgBlue, currentDirectory)
      except ValueError, IOError:
        echo(currentDirectory)
  if previousCommand != "" and resultCode != QuitSuccess:
    try:
      stdout.styledWrite(fgRed, "[" & $resultCode & "]")
    except ValueError, IOError:
      echo("[" & $resultCode & "]")
  try:
    stdout.styledWrite(fgBlue, "# ")
  except ValueError, IOError:
    echo("# ")

proc showOutput*(message: string; newLine: bool = true;
    promptEnabled: bool = false; previousCommand: string = "";
        returnCode: int = QuitSuccess; fgColor: ForegroundColor = fgDefault) {.gcsafe,
            locks: 0, sideEffect, raises: [], tags: [ReadIOEffect,
                WriteIOEffect].} =
  ## Show the selected message and prompt (if enabled, default) to the user.
  ## If newLine is true, add a new line after message.
  showPrompt(promptEnabled, previousCommand, returnCode)
  if message != "":
    try:
      stdout.styledWrite(fgColor, message)
    except IOError, ValueError:
      try:
        stdout.write(message)
      except IOError:
        discard
    if newLine:
      echo("")
  stdout.flushFile()

proc showError*(message: string = ""): int {.gcsafe, locks: 0, sideEffect,
    raises: [], tags: [WriteIOEffect].} =
  ## Print the message to standard error and set the shell return
  ## code to error. If message is empty, print the current exception message
  if message == "":
    let
      currentException = getCurrentException()
      stackTrace = getStackTrace(currentException)
    try:
      stderr.styledWriteLine(fgRed, "Type: " & $currentException.name)
      stderr.styledWriteLine(fgRed, "Message: " & currentException.msg)
      if stackTrace.len() > 0:
        stderr.styledWriteLine(fgRed, stackTrace)
    except IOError, ValueError:
      echo("Type: " & $currentException.name)
      echo("Message: " & currentException.msg)
      if stackTrace.len() > 0:
        echo(stackTrace)
  else:
    try:
      stderr.styledWriteLine(fgRed, message)
    except IOError, ValueError:
      echo(message)
  result = QuitFailure

proc showFormHeader*(message: string; length: int = 23) {.gcsafe, locks: 0,
    sideEffect, raises: [], tags: [ReadIOEffect, WriteIOEffect].} =
  ## Show form's header with selected length and message
  showOutput(message = repeat('#', length), fgColor = fgYellow)
  showOutput(message = message, fgColor = fgYellow)
  showOutput(message = repeat('#', length), fgColor = fgYellow)
