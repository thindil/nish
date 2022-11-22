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
import std/[strutils, terminal]
# External modules imports
import contracts
# Internal imports
import columnamount, resultcode

type OutputMessage* = string
  ## FUNCTION
  ##
  ## Used to store message to show to the user

using message: OutputMessage # The message to show to the user

proc showOutput*(message; newLine: bool = true;
    fgColor: ForegroundColor = fgDefault; centered: bool = false) {.gcsafe,
    sideEffect, raises: [], tags: [ReadIOEffect, WriteIOEffect], contractual.} =
  ## FUNCTION
  ##
  ## Show the selected message to the user. If newLine is true, add a new line
  ## after message.
  ##
  ## PARAMETERS
  ##
  ## * message         - the message to show
  ## * newLine         - if true, add a new line after the message
  ## * fgColor         - the color of the text (foreground)
  ## * centered        - if true, center the message on the screen
  body:
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

proc showError*(message: OutputMessage; e: ref Exception = nil): ResultCode {.gcsafe,
    sideEffect, raises: [], tags: [WriteIOEffect], discardable.} =
  ## FUNCTION
  ##
  ## Print the message to standard error and set the shell return
  ## code to error. If parameter e is also supplied, it show stack trace for
  ## the current exception in debug mode.
  ##
  ## PARAMETERS
  ##
  ## * message - the error message to show
  ## * e       - the reference to an exception which occured. Can be empty.
  ##             Default value is nil
  ##
  ## RETURNS
  ##
  ## Always QuitFailure
  try:
    if e != nil:
      stderr.writeLine(x = "")
    stderr.styledWrite(fgRed, message)
    if e != nil:
      stderr.styledWriteLine(fgRed, getCurrentExceptionMsg())
      when defined(debug):
        stderr.styledWrite(fgRed, getStackTrace(e = e))
    else:
      stderr.writeLine(x = "")
  except IOError, ValueError:
    try:
      stderr.writeLine(x = message)
    except IOError:
      discard
  return QuitFailure.ResultCode

proc showFormHeader*(message; spaces: ColumnAmount = 0.ColumnAmount) {.gcsafe,
    sideEffect, raises: [], tags: [ReadIOEffect, WriteIOEffect].} =
  ## FUNCTION
  ##
  ## Show form's header with the selected message
  ##
  ## PARAMETERS
  ##
  ## * message - the text which will be shown in the header
  ## * spaces  - the amount of spaces used as margin. If set to 0, use amount
  ##             based on termminal width. Default value is 0.
  let
    length: ColumnAmount = try: terminalWidth().ColumnAmount except ValueError: 80.ColumnAmount
    spacesAmount: ColumnAmount = if spaces == 0: length / 12 else: spaces
  showOutput(message = indent(s = repeat(c = '=', count = length - (
      spacesAmount * 2)), count = spacesAmount.int), fgColor = fgYellow)
  showOutput(message = center(s = message, width = length.int),
      fgColor = fgYellow)
  showOutput(message = indent(s = repeat(c = '=', count = length - (
      spacesAmount * 2)), count = spacesAmount.int), fgColor = fgYellow)
