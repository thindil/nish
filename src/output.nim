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

import std/[os, strutils, terminal, times]
import constants

using
  message: string # The message to show to the user

proc showPrompt*(promptEnabled: bool; previousCommand: string;
    resultCode: int) {.gcsafe, locks: 0, sideEffect, raises: [],
        tags: [ReadIOEffect, WriteIOEffect].} =
  ## FUNCTION
  ##
  ## Show the shell prompt if the shell wasn't started in one command mode
  ##
  ## PARAMETERS
  ##
  ## * promptEnabled   - if true, show the prompt
  ## * previousCommand - the previous command executed by the user
  ## * resultCode      - the result of the previous command executed by the user
  if not promptEnabled:
    return
  let
    currentDirectory: DirectoryPath = (try: getCurrentDir() except OSError: "[unknown dir]")
    homeDirectory: DirectoryPath = getHomeDir()
  if endsWith(currentDirectory & "/", homeDirectory):
    try:
      stdout.styledWrite(fgBlue, "~")
    except ValueError, IOError:
      try:
        stdout.write("~")
      except IOError:
        discard
  else:
    let homeIndex: int = currentDirectory.find(homeDirectory)
    if homeIndex > -1:
      try:
        stdout.styledWrite(fgBlue, "~/" & currentDirectory[homeIndex +
            homeDirectory.len()..^1])
      except ValueError, IOError:
        try:
          stdout.write("~/" & currentDirectory[homeIndex + homeDirectory.len()..^1])
        except IOError:
          discard
    else:
      try:
        stdout.styledWrite(fgBlue, currentDirectory)
      except ValueError, IOError:
        try:
          stdout.write(currentDirectory)
        except IOError:
          discard
  if previousCommand != "" and resultCode != QuitSuccess:
    try:
      stdout.styledWrite(fgRed, "[" & $resultCode & "]")
    except ValueError, IOError:
      try:
        stdout.write("[" & $resultCode & "]")
      except IOError:
        discard
  try:
    stdout.styledWrite(fgBlue, "# ")
  except ValueError, IOError:
    try:
      stdout.write("# ")
    except IOError:
      discard

proc showOutput*(message; newLine: bool = true;
    promptEnabled: bool = false; previousCommand: string = "";
        returnCode: int = QuitSuccess; fgColor: ForegroundColor = fgDefault;
            centered: bool = false) {.gcsafe, locks: 0, sideEffect, raises: [],
                tags: [ReadIOEffect, WriteIOEffect].} =
  ## FUNCTION
  ##
  ## Show the selected message and prompt (if enabled, default) to the user.
  ## If newLine is true, add a new line after message.
  ##
  ## PARAMETERS
  ##
  ## * message         - the message to show
  ## * newLine         - if true, add a new line after the message
  ## * promptEnabled   - if true, show the prompt
  ## * previousCommand - the previous command executed by the user
  ## * resultCode      - the result of the previous command executed by the user
  ## * fgColor         - the color of the text (foreground)
  ## * centered        - if true, center the message on the screen
  showPrompt(promptEnabled, previousCommand, returnCode)
  if message != "":
    var newMessage: string
    if centered:
      try:
        newMessage = center(message, terminalWidth())
      except ValueError:
        newMessage = message
    else:
      newMessage = message
    try:
      stdout.styledWrite(fgColor, newMessage)
    except IOError, ValueError:
      try:
        stdout.write(newMessage)
      except IOError:
        discard
    if newLine:
      try:
        stdout.writeLine("")
      except IOError:
        discard
  stdout.flushFile()

proc showError*(message: string = ""): int {.gcsafe, sideEffect,
    raises: [], tags: [WriteIOEffect, ReadEnvEffect, TimeEffect].} =
  ## Print the message to standard error and set the shell return
  ## code to error. If message is empty, print the current exception message
  if message == "":
    let
      currentException: ref Exception = getCurrentException()
      stackTrace: string = getStackTrace(currentException)
    try:
      stderr.styledWriteLine(fgRed, "Type: " & $currentException.name)
      stderr.styledWriteLine(fgRed, "Message: " & currentException.msg)
      if stackTrace.len() > 0:
        stderr.styledWriteLine(fgRed, stackTrace)
    except IOError, ValueError:
      try:
        stdout.writeLine("Type: " & $currentException.name)
        stdout.writeLine("Message: " & currentException.msg)
        if stackTrace.len() > 0:
          stdout.writeLine(stackTrace)
      except IOError:
        discard
    finally:
      if stackTrace.len() > 0:
        try:
          let debugFile: File = open(getCacheDir() & DirSep & "nish" & DirSep &
              "error.log", fmAppend)
          debugFile.writeLine("Version: " & shellVersion)
          debugFile.writeLine("Date: " & $now())
          debugFile.writeLine(stackTrace)
          debugFile.writeLine(repeat('-', 40))
          close(debugFile)
        except IOError:
          discard
  else:
    try:
      stderr.styledWriteLine(fgRed, message)
    except IOError, ValueError:
      try:
        stdout.writeLine(message)
      except IOError:
        discard
  result = QuitFailure

proc showFormHeader*(message) {.gcsafe, locks: 0,
    sideEffect, raises: [], tags: [ReadIOEffect, WriteIOEffect].} =
  ## Show form's header with the selected message
  let
    length: Natural = try: terminalWidth() except ValueError: 80
    spacesAmount: Natural = (length / 12).int
  showOutput(message = indent(repeat('=', length - (spacesAmount * 2)),
      spacesAmount), fgColor = fgYellow)
  showOutput(message = center(message, length), fgColor = fgYellow)
  showOutput(message = indent(repeat('=', length - (spacesAmount * 2)),
      spacesAmount), fgColor = fgYellow)
