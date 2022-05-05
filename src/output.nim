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
import constants

type
  OutputMessage* = string # Used to store message to show to the user

using
  message: OutputMessage # The message to show to the user

proc showPrompt*(promptEnabled: bool; previousCommand: string;
    resultCode: ResultCode) {.gcsafe, locks: 0, sideEffect, raises: [],
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
    currentDirectory: DirectoryPath = try:
      getCurrentDir()
    except OSError:
      "[unknown dir]"
    homeDirectory: DirectoryPath = getHomeDir()
  if endsWith(s = currentDirectory & "/", suffix = homeDirectory):
    try:
      stdout.styledWrite(fgBlue, "~")
    except ValueError, IOError:
      try:
        stdout.write(s = "~")
      except IOError:
        discard
  else:
    let homeIndex: ExtendedNatural = currentDirectory.find(sub = homeDirectory)
    if homeIndex > -1:
      try:
        stdout.styledWrite(fgBlue, "~/" & currentDirectory[homeIndex +
            homeDirectory.len()..^1])
      except ValueError, IOError:
        try:
          stdout.write(s = "~/" & currentDirectory[homeIndex +
              homeDirectory.len()..^1])
        except IOError:
          discard
    else:
      try:
        stdout.styledWrite(fgBlue, currentDirectory)
      except ValueError, IOError:
        try:
          stdout.write(s = currentDirectory)
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

proc showOutput*(message; newLine: bool = true; promptEnabled: bool = false;
    previousCommand: string = ""; returnCode: ResultCode = QuitSuccess;
    fgColor: ForegroundColor = fgDefault; centered: bool = false) {.gcsafe,
    locks: 0, sideEffect, raises: [], tags: [ReadIOEffect, WriteIOEffect].} =
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
  showPrompt(promptEnabled = promptEnabled, previousCommand = previousCommand,
      resultCode = returnCode)
  if message != "":
    var newMessage: OutputMessage
    if centered:
      try:
        newMessage = center(s = message, width = terminalWidth())
      except ValueError:
        newMessage = message
    else:
      newMessage = message
    try:
      stdout.styledWrite(fgColor, newMessage)
    except IOError, ValueError:
      try:
        stdout.write(s = newMessage)
      except IOError:
        discard
    if newLine:
      try:
        stdout.writeLine(x = "")
      except IOError:
        discard
  stdout.flushFile()

proc showError*(message: OutputMessage): ResultCode {.gcsafe, sideEffect,
    raises: [], tags: [WriteIOEffect].} =
  ## FUNCTION
  ##
  ## Print the message to standard error and set the shell return
  ## code to error.
  ##
  ## PARAMETERS
  ##
  ## * message - the error message to show
  ##
  ## RETURNS
  ## Always QuitFailure
  try:
    stderr.styledWriteLine(fgRed, message)
  except IOError, ValueError:
    try:
      stdout.writeLine(x = message)
    except IOError:
      discard
  return QuitFailure

proc showFormHeader*(message) {.gcsafe, locks: 0,
    sideEffect, raises: [], tags: [ReadIOEffect, WriteIOEffect].} =
  ## FUNCTION
  ##
  ## Show form's header with the selected message
  ##
  ## PARAMETERS
  ##
  ## * message - the text which will be shown in the header
  let
    length: ColumnAmount = try: terminalWidth() except ValueError: 80
    spacesAmount: ColumnAmount = (length / 12).int
  showOutput(message = indent(s = repeat(c = '=', count = length - (
      spacesAmount * 2)), count = spacesAmount), fgColor = fgYellow)
  showOutput(message = center(s = message, width = length), fgColor = fgYellow)
  showOutput(message = indent(s = repeat(c = '=', count = length - (
      spacesAmount * 2)), count = spacesAmount), fgColor = fgYellow)
