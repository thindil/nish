# Copyright © 2022-2023 Bartek Jasicki
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

## This module contains code related to showing the results of user's commands
## like normal output, errors or formated tables headers.

# Standard library imports
import std/[strutils, tables, terminal]
# External modules imports
import contracts, nancy, nimalyzer, termstyle
import norm/sqlite
# Internal imports
import constants, logger, resultcode, theme

type OutputMessage* = string
  ## Used to store message to show to the user

using message: OutputMessage # The message to show to the user

proc showOutput*(message; newLine: bool = true;
    fgColor: ForegroundColor = fgDefault; centered: bool = false) {.sideEffect,
    raises: [], tags: [ReadIOEffect, WriteIOEffect, RootEffect], contractual.} =
  ## Show the selected message to the user. If newLine is true, add a new line
  ## after message.
  ##
  ## * message         - the message to show
  ## * newLine         - if true, add a new line after the message
  ## * fgColor         - the color of the text (foreground)
  ## * centered        - if true, center the message on the screen
  body:
    if message != "":
      var newMessage: OutputMessage = if centered:
          try:
            center(s = message, width = terminalWidth())
          except ValueError:
            message
        else:
          message
      try:
        {.ruleOff: "namedParams".}
        stdout.styledWrite(fgColor, newMessage)
        {.ruleOn: "namedParams".}
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
    stdout.flushFile

proc showError*(message: OutputMessage; db: DbConn;
    e: ref Exception = nil): ResultCode {.sideEffect, raises: [], tags: [
    WriteIOEffect, RootEffect], discardable, contractual.} =
  ## Print the message to standard error and set the shell return
  ## code to error. If parameter e is also supplied, it show stack trace for
  ## the current exception in debug mode.
  ##
  ## * message - the error message to show
  ## * db      - the connection to the shell's database
  ## * e       - the reference to an exception which occured. Can be empty.
  ##             Default value is nil
  ##
  ## Always returns QuitFailure
  require:
    message.len > 0
  ensure:
    result == QuitFailure
  body:
    try:
      if e != nil:
        stderr.writeLine(x = "")
      let color: string = getColor(db = db, name = errors)
      stderr.write(a = style(ss = message, style = color))
      if e == nil:
        stderr.writeLine(x = "")
      else:
        stderr.writeLine(x = style(ss = $e.name, style = color))
        logToFile(message = $e.name)
        stderr.writeLine(x = style(ss = getCurrentExceptionMsg(),
            style = color))
        logToFile(message = getCurrentExceptionMsg())
        when defined(debug):
          stderr.write(a = style(ss = e.getStackTrace, style = color))
          logToFile(message = e.getStackTrace)
    except:
      try:
        stderr.writeLine(x = message)
      except IOError:
        discard
    return QuitFailure.ResultCode

proc showFormHeader*(message; width: ColumnAmount = (try: terminalWidth(
    ).ColumnAmount except ValueError: 80.ColumnAmount);
    db: DbConn) {.sideEffect, raises: [], tags: [ReadIOEffect, WriteIOEffect,
        RootEffect], contractual.} =
  ## Show form's header with the selected message
  ##
  ## * message - the text which will be shown in the header
  ## * width   - the width of the header. Default value is the current width
  ##             of the terminal
  ## * db      - the connection to the shell's database
  require:
    message.len > 0
    db != nil
  body:
    type LocalOption = ref object
      value: string
    try:
      var option: LocalOption = LocalOption()
      db.rawSelect(qry = "SELECT value FROM options WHERE option='outputHeaders'", obj = option)
      let headerType: string = option.value
      if headerType == "hidden":
        return
      var table: TerminalTable = TerminalTable()
      table.add(parts = yellow(ss = message.center(width = width.int)))
      case headerType
      of "unicode":
        table.echoTableSeps(seps = boxSeps)
      of "ascii":
        table.echoTableSeps
      of "none":
        table.echoTable
      else:
        discard
    except DbError, IOError, Exception:
      showError(message = "Can't show form header. Reason: ",
          e = getCurrentException(), db = db)

proc selectOption*(options: Table[char, string];
    default: char; prompt: string): char {.sideEffect, raises: [], tags: [ReadIOEffect,
    WriteIOEffect, RootEffect], contractual.} =
  ## Show the list of options from which the user can select one value
  ##
  ## * options - the list of options from which the user can select one
  ## * default - the default value for the list
  ## * prompt  - the text displayed at the end of the list
  ##
  ## Returns the option selected by the user from the options list or the
  ## default value if there was any error
  require:
    options.len > 0
  body:
    var keysList: seq[char] = @[]
    for key, value in options:
      showOutput(message = $key & ") " & value)
      keysList.add(y = key)
    showOutput(message = prompt & " (" & keysList.join(sep = "/") & "): ")
    result = try:
        getch()
      except IOError:
        default
    while result.toLowerAscii notin keysList:
      result = try:
        getch()
      except IOError:
        default
