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

import std/[db_sqlite, os, strutils, tables, terminal]
import constants, input, lstring, options, output

type
  HistoryRange* = ExtendedNatural # Used to store the amount of commands in the shell's history

using
  db: DbConn # Connection to the shell's database

proc historyLength*(db): HistoryRange {.gcsafe, sideEffect, raises: [],
    tags: [ReadDbEffect, WriteIOEffect, ReadEnvEffect, TimeEffect].} =
  ## FUNCTION
  ##
  ## Get the current length of the shell's commmands' history
  ##
  ## PARAMETERS
  ##
  ## * db - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## The amount of commands in the shell's commands' history or -1 if can't
  ## get the current amount of commands.
  try:
    return parseInt(s = db.getValue(query = sql(query =
      "SELECT COUNT(*) FROM history")))
  except DbError, ValueError:
    discard showError(message = "Can't get the length of the shell's commands history. Reason: " &
        getCurrentExceptionMsg())
    return HistoryRange.low()

proc initHistory*(db; helpContent: var HelpTable): HistoryRange {.gcsafe,
    sideEffect, raises: [], tags: [ReadDbEffect, WriteIOEffect,
    WriteDbEffect, ReadEnvEffect, TimeEffect].} =
  ## FUNCTION
  ##
  ## Initialize shell's commands history. Create history table if not exists,
  ## set the current historyIndex, options related to the history and help
  ## related to the history commands
  ##
  ## PARAMETERS
  ##
  ## * db          - the connection to the shell's database
  ## * helpContent - the content of the shell's help system
  ##
  ## RETURNS
  ##
  ## The length of the shell's commands' history or -1 if can't create the
  ## history's table in the shell's database

  # Set the history related options
  var
    optionName: LimitedString = initLimitedString(capacity = 20,
        text = "historyLength")
  if getOption(optionName = optionName, db = db) == "":
    setOption(optionName = optionName, value = initLimitedString(capacity = 3,
        text = "500"), description = initLimitedString(capacity = 48,
            text = "Max amount of entries in shell commands history."),
        valueType = ValueType.integer, db = db)
  try:
    optionName.setString(text = "historyAmount")
  except CapacityError:
    discard showError(message = "Can't set name of the option historyAmount to set.")
    return HistoryRange.low()
  if getOption(optionName = optionName, db = db) == "":
    setOption(optionName = optionName, value = initLimitedString(capacity = 2,
        text = "20"), description = initLimitedString(capacity = 78,
            text = "Amount of entries in shell commands history to show with history show command."),
         valueType = ValueType.integer, db = db)
  try:
    optionName.setString(text = "historySaveInvalid")
  except CapacityError:
    discard showError(message = "Can't set name of the option historySaveInvalid to set.")
    return HistoryRange.low()
  if getOption(optionName = optionName, db = db) == "":
    setOption(optionName = optionName, value = initLimitedString(capacity = 5,
        text = "false"), description = initLimitedString(capacity = 52,
            text = "Save in shell command history also invalid commands."),
        valueType = ValueType.boolean, db = db)
  # Create history table if not exists
  try:
    db.exec(query = sql(query = """CREATE TABLE IF NOT EXISTS history (
                 command     VARCHAR(""" & $maxInputLength &
        """) PRIMARY KEY,
                 lastused    DATETIME NOT NULL DEFAULT 'datetime(''now'')',
                 amount      INTEGER NOT NULL DEFAULT 1
              )"""))
  except DbError as e:
    discard showError(message = "Can't create table for the shell's history. Reason: " & e.msg)
    return HistoryRange.low()
  # Set the history related help content
  helpContent["history"] = HelpEntry(usage: "history ?subcommand?",
      content: "If entered without subcommand, show the list of available subcommands for history. Otherwise, execute the selected subcommand.")
  helpContent["history clear"] = HelpEntry(usage: "history clear",
      content: "Clear the shell's commands' history.")
  # Return the current help index set on the last command in the shell's history
  return historyLength(db = db)

proc updateHistory*(commandToAdd: string; db;
    returnCode: ResultCode = ResultCode(QuitSuccess)): HistoryRange {.gcsafe,
        sideEffect, raises: [],
    tags: [ReadDbEffect, WriteDbEffect, WriteIOEffect, ReadEnvEffect,
    TimeEffect].} =
  ## FUNCTION
  ##
  ## Add the selected command to the shell history and increase the current
  ## history index. If there is the command in the shell's history, only update
  ## its amount ond last used timestamp. Remove the oldest entry if there is
  ## maximum allowed amount of history's entries.
  ##
  ## PARAMETERS
  ##
  ## * commandToAdd - the command entered by the user which will be added
  ## * db           - the connection to the shell's database
  ## * returnCode   - the return code (success or failure) of the command to add
  ##
  ## RETURNS
  ##
  ## The new length of the shell's commands' history.
  result = historyLength(db = db)
  try:
    if returnCode != QuitSuccess and db.getValue(query = sql(query =
      "SELECT value FROM options WHERE option='historySaveInvalid'")) == "false":
      return
  except DbError as e:
    discard showError(message = "Can't get value of option historySaveInvalid. Reason: " & e.msg)
    return
  try:
    if result == parseInt(s = db.getValue(query = sql(query =
      "SELECT value FROM options where option='historyLength'"))):
      db.exec(query = sql(query = "DELETE FROM history ORDER BY lastused, amount ASC LIMIT 1"));
      result.dec()
  except DbError, ValueError:
    discard showError(message = "Can't get value of option historyLength. Reason: " &
        getCurrentExceptionMsg())
    return
  try:
    if db.execAffectedRows(query = sql(query = "UPDATE history SET amount=amount+1, lastused=datetime('now') WHERE command=?"),
        commandToAdd) == 0:
      db.exec(query = sql(query = "INSERT INTO history (command, amount, lastused) VALUES (?, 1, datetime('now'))"), commandToAdd)
      result.inc()
  except DbError as e:
    discard showError(message = "Can't update the shell's history. Reason: " & e.msg)
    return

proc getHistory*(historyIndex: HistoryRange; db;
    searchFor: UserInput = initLimitedString(
        capacity = maxInputLength)): string {.gcsafe, sideEffect, locks: 0,
            raises: [], tags: [ReadDbEffect, ReadEnvEffect, WriteIOEffect,
                TimeEffect].} =
  ## FUNCTION
  ##
  ## Get the command with the selected index from the shell history
  ##
  ## PARAMETERS
  ##
  ## *historyIndex - the index of command in the shell's commands' history which
  ##                 will be get
  ## * db          - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## The selected command from the shell's commands' history.
  try:
    if searchFor.len() == 0:
      result = db.getValue(query = sql(query = "SELECT command FROM history ORDER BY lastused DESC, amount ASC LIMIT 1 OFFSET ?"),
          $(historyLength(db = db) - historyIndex));
    else:
      result = db.getValue(query = sql(query = "SELECT command FROM history WHERE command LIKE ? ORDER BY lastused DESC, amount DESC"),
          searchFor & "%");
      if result.len() == 0:
        result = $searchFor
  except DbError as e:
    result = "Can't get the selected command from the shell's history. Reason: " & e.msg

proc clearHistory*(db): HistoryRange {.gcsafe, sideEffect, raises: [], tags: [
    ReadIOEffect, WriteIOEffect, ReadDbEffect, WriteDbEffect, TimeEffect].} =
  ## FUNCTION
  ##
  ## Clear the shell's history, don't add the command to the history
  ##
  ## PARAMETERS
  ##
  ## * db - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## The new last index in the shell's commands history
  try:
    db.exec(query = sql(query = "DELETE FROM history"));
  except DbError as e:
    discard showError(message = "Can't clear the shell's commands history. Reason: " & e.msg)
    return historyLength(db = db)
  showOutput(message = "Shell's commands' history cleared.", fgColor = fgGreen)
  return 0;

proc helpHistory*(db): HistoryRange {.gcsafe, sideEffect, raises: [], tags: [
    ReadDbEffect, WriteDbEffect, ReadIOEffect, WriteIOEffect, ReadEnvEffect,
    TimeEffect].} =
  ## FUNCTION
  ##
  ## Show short help about available subcommands related to the shell's
  ## commands' history
  ##
  ## PARAMETERS
  ##
  ## * db - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## The new length of the shell's commands' history.
  showOutput(message = """Available subcommands are: clear, show

        To see more information about the subcommand, type help history [command],
        for example: help history clear.
""")
  return updateHistory(commandToAdd = "history", db = db)

proc showHistory*(db): HistoryRange {.gcsafe, sideEffect, raises: [], tags: [
    ReadDbEffect, WriteDbEffect, ReadIOEffect, WriteIOEffect, ReadEnvEffect,
    TimeEffect].} =
  ## FUNCTION
  ##
  ## Show the last X entries to the shell's history. X can be set in the shell's
  ## options as 'historyAmount' option.
  ##
  ## PARAMETERS
  ##
  ## * db - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## The new length of the shell's commands' history.
  let
    amount: HistoryRange = try:
        parseInt(s = $getOption(optionName = initLimitedString(capacity = 13,
            text = "historyAmount"), db = db))
      except ValueError:
        discard showError(message = "Can't get setting for the amount of history commands to show.")
        return updateHistory(commandToAdd = "history show", db = db,
            returnCode = ResultCode(QuitFailure))
    spacesAmount: ColumnAmount = try:
          (terminalWidth() / 12).int
      except ValueError:
        6
  showFormHeader(message = "The last commands from the shell's history")
  showOutput(message = indent(s = "Last used                Times      Command",
      count = spacesAmount), fgColor = fgMagenta)
  try:
    for row in db.fastRows(query = sql(query = "SELECT command, lastused, amount FROM history ORDER BY lastused, amount ASC LIMIT ? OFFSET (SELECT COUNT(*)-? from history)"),
        amount, amount):
      showOutput(message = indent(s = row[1] & "      " & center(s = row[2],
          width = 5) & "      " & row[0], count = spacesAmount))
    return updateHistory(commandToAdd = "history show", db = db)
  except DbError as e:
    discard showError(message = "Can't get the last commands from the shell's history. Reason: " & e.msg)
    return updateHistory(commandToAdd = "history show", db = db,
        returnCode = ResultCode(QuitFailure))
