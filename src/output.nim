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

## This module contains code related to showing the results of user's commands
## like normal output, errors or formated tables headers.

# Standard library imports
import std/[strutils, tables, terminal]
# External modules imports
import contracts, nancy, termstyle
import norm/sqlite
# Internal imports
import constants, logger, resultcode, theme

type OutputMessage* = string
  ## Used to store message to show to the user

using
  message: OutputMessage # The message to show to the user
  db: DBConn # The connection to the shell's database

proc showOutput*(message; db; newLine: bool = true;
    color: ThemeColor = default; centered: bool = false) {.sideEffect,
    raises: [], tags: [ReadIOEffect, WriteIOEffect, RootEffect], contractual.} =
  ## Show the selected message to the user. If newLine is true, add a new line
  ## after message.
  ##
  ## * message  - the message to show
  ## * db       - the connection to the shell's database
  ## * newLine  - if true, add a new line after the message
  ## * fgColor  - the color of the text
  ## * centered - if true, center the message on the screen
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
        stdout.write(a = style(ss = newMessage, style = getColor(db = db,
            name = color)))
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

proc showError*(message: OutputMessage; db;
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
    ).ColumnAmount except ValueError: 80.ColumnAmount); db) {.sideEffect,
        raises: [], tags: [ReadIOEffect, WriteIOEffect, RootEffect],
            contractual.} =
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
      let color = getColor(db = db, name = headers)

      proc echoTableSeps(table: TerminalTable; seps = defaultSeps;
          color: string) {.sideEffect, raises: [], tags: [WriteIOEffect,
              RootEffect], contractual.} =
        body:
          try:
            let sizes = table.getColumnSizes(terminalWidth() - 4, padding = 3)
            stdout.write(color)
            printSeparator(top)
            for k, entry in table.entries(sizes):
              for _, row in entry():
                stdout.write(seps.vertical & " ")
                for i, cell in row():
                  stdout.write(cell & (if i != sizes.high: " " & seps.vertical & " " else: ""))
                stdout.write(color & " " & seps.vertical & "\n")
              if k != table.rows - 1:
                printSeparator(center)
            stdout.write(color)
            printSeparator(bottom)
            stdout.write("\e[0m")
          except:
            showError(message = "Can't draw table. Reason: ",
                e = getCurrentException(), db = db)

      var table: TerminalTable = TerminalTable()
      table.add(parts = style(ss = message.center(width = width.int),
          style = color))
      case headerType
      of "unicode":
        table.echoTableSeps(seps = boxSeps, color = color)
      of "ascii":
        table.echoTableSeps(color = color)
      of "none":
        table.echoTable
      else:
        discard
    except DbError, IOError, Exception:
      showError(message = "Can't show form header. Reason: ",
          e = getCurrentException(), db = db)

proc selectOption*(options: Table[char, string];
    default: char; prompt: string; db): char {.sideEffect, raises: [], tags: [ReadIOEffect,
    WriteIOEffect, RootEffect], contractual.} =
  ## Show the list of options from which the user can select one value
  ##
  ## * options - the list of options from which the user can select one
  ## * default - the default value for the list
  ## * prompt  - the text displayed at the end of the list
  ## * db      - the connection to the shell's database
  ##
  ## Returns the option selected by the user from the options list or the
  ## default value if there was any error
  require:
    options.len > 0
    db != nil
  body:
    var keysList: seq[char] = @[]
    for key, value in options:
      showOutput(message = $key & ") " & value, db = db)
      keysList.add(y = key)
    showOutput(message = prompt & " (" & keysList.join(sep = "/") & "): ",
        db = db, color = promptColor)
    result = try:
        getch()
      except IOError:
        default
    while result.toLowerAscii notin keysList:
      result = try:
        getch()
      except IOError:
        default

proc confirm*(prompt: string; db): bool {.sideEffect, raises: [], tags: [
    ReadIOEffect, WriteIOEffect, RootEffect], contractual.} =
  ## Ask the user for confirmation of something, waiting until the user press
  ## key 'y' or 'n'
  ##
  ## * prompt - the text displayed as a temporary prompt
  ## * db     - the connection to the shell's database
  ##
  ## Returns true if the user confirms an action (press the 'y' key) and
  ## returns false if the user cancels an action (press the 'n' key).
  require:
    db != nil
  body:
    showOutput(message = prompt & "(y/n): ", newLine = false, db = db)
    var inputChar: char = try:
        getch()
      except IOError:
        'y'
    while inputChar notin {'n', 'N', 'y', 'Y'}:
      inputChar = try:
        getch()
      except IOError:
        'y'
    try:
      stderr.writeLine(x = $inputChar)
    except IOError:
      discard
    return inputChar in {'y', 'Y'}

proc showFormPrompt*(prompt: string; db) {.sideEffect, raises: [], tags: [
    ReadIOEffect, WriteIOEffect, RootEffect], contractual.} =
  ## Show the prompt in the shell's forms
  ##
  ## * prompt - the text displayed as a form's prompt
  ## * db     - the connection to the shell's database
  require:
    db != nil
    prompt.len > 0
  body:
    showOutput(message = prompt & ": ", newLine = false, db = db,
        color = promptColor)
