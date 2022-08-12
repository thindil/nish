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
import contracts
import columnamount, constants, input, lstring, options, output, resultcode

type HistoryRange* = ExtendedNatural
  ## FUNCTION
  ##
  ## Used to store the amount of commands in the shell's history

using
  db: DbConn # Connection to the shell's database

proc historyLength*(db): HistoryRange {.gcsafe, sideEffect, raises: [],
    tags: [ReadDbEffect, WriteIOEffect, ReadEnvEffect, TimeEffect], locks: 0,
        contractual.} =
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
  require:
    db != nil
  body:
    try:
      return parseInt(s = db.getValue(query = sql(query =
        "SELECT COUNT(*) FROM history")))
    except DbError, ValueError:
      showError(message = "Can't get the length of the shell's commands history. Reason: ",
          e = getCurrentException())
      return HistoryRange.low()

proc initHistory*(db; helpContent: var HelpTable): HistoryRange {.gcsafe,
    sideEffect, raises: [], tags: [ReadDbEffect, WriteIOEffect,
    WriteDbEffect, ReadEnvEffect, TimeEffect], locks: 0, contractual.} =
  ## FUNCTION
  ##
  ## Initialize shell's commands history and set help related to the history
  ## commands
  ##
  ## PARAMETERS
  ##
  ## * db          - the connection to the shell's database
  ## * helpContent - the content of the shell's help system
  ##
  ## RETURNS
  ##
  ## The length of the shell's commands' history
  require:
    db != nil
  body:
    # Set the history related help content
    helpContent["history"] = HelpEntry(usage: "history ?subcommand?",
        content: "If entered without subcommand, show the list of available subcommands for history. Otherwise, execute the selected subcommand.")
    helpContent["history clear"] = HelpEntry(usage: "history clear",
        content: "Clear the shell's commands' history.")
    # Return the current help index set on the last command in the shell's history
    return historyLength(db = db)

proc updateHistory*(commandToAdd: string; db;
    returnCode: ResultCode = ResultCode(QuitSuccess)): HistoryRange {.gcsafe,
        sideEffect, raises: [], tags: [ReadDbEffect, WriteDbEffect,
        WriteIOEffect, ReadEnvEffect, TimeEffect], locks: 0, contractual.} =
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
  require:
    db != nil
    commandToAdd.len() > 0
  body:
    result = historyLength(db = db)
    try:
      if returnCode != QuitSuccess and db.getValue(query = sql(query =
        "SELECT value FROM options WHERE option='historySaveInvalid'")) == "false":
        return
    except DbError:
      showError(message = "Can't get value of option historySaveInvalid. Reason: ",
          e = getCurrentException())
      return
    try:
      if result == parseInt(s = db.getValue(query = sql(query =
        "SELECT value FROM options where option='historyLength'"))):
        db.exec(query = sql(query = "DELETE FROM history ORDER BY lastused, amount ASC LIMIT 1"));
        result.dec()
    except DbError, ValueError:
      showError(message = "Can't get value of option historyLength. Reason: ",
          e = getCurrentException())
      return
    try:
      # Update history if there is the command in the history in the same directory
      let currentDir = getCurrentDir()
      if db.execAffectedRows(query = sql(
          query = "UPDATE history SET amount=amount+1, lastused=datetime('now') WHERE command=? AND path=?"),
           commandToAdd, currentDir) == 0:
        # Update history if there is the command in the history
        if db.execAffectedRows(query = sql(
            query = "UPDATE history SET amount=amount+1, lastused=datetime('now'), path=? WHERE command=?"),
             currentDir, commandToAdd) == 0:
          # If command isn't in the history, add it
          db.exec(query = sql(query = "INSERT INTO history (command, amount, lastused, path) VALUES (?, 1, datetime('now'), ?)"),
              commandToAdd, currentDir)
          result.inc()
    except DbError, OSError:
      showError(message = "Can't update the shell's history. Reason: ",
          e = getCurrentException())

proc getHistory*(historyIndex: HistoryRange; db;
    searchFor: UserInput = emptyLimitedString(
        capacity = maxInputLength)): string {.gcsafe, sideEffect, locks: 0,
        raises: [], tags: [ReadDbEffect, ReadEnvEffect, WriteIOEffect,
        TimeEffect], contractual.} =
  ## FUNCTION
  ##
  ## Get the command with the selected index from the shell history
  ##
  ## PARAMETERS
  ##
  ## * historyIndex - the index of command in the shell's commands' history which
  ##                 will be get
  ## * db          - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## The selected command from the shell's commands' history.
  require:
    db != nil
  body:
    try:
      if searchFor.len() == 0:
        let value = db.getValue(query = sql(
            query = "SELECT command FROM history WHERE path=? ORDER BY lastused DESC, amount ASC LIMIT 1 OFFSET ?"),
            getCurrentDir(), $(historyLength(db = db) - historyIndex))
        if value.len() == 0:
          result = db.getValue(query = sql(
              query = "SELECT command FROM history ORDER BY lastused DESC, amount ASC LIMIT 1 OFFSET ?"),
              $(historyLength(db = db) - historyIndex))
        else:
          result = value
      else:
        let value = db.getValue(query = sql(
            query = "SELECT command FROM history WHERE command LIKE ? AND path=? ORDER BY lastused DESC, amount DESC"),
            searchFor & "%", getCurrentDir())
        if value.len() == 0:
          result = db.getValue(query = sql(
              query = "SELECT command FROM history WHERE command LIKE ? ORDER BY lastused DESC, amount DESC"),
              searchFor & "%")
        else:
          result = value
        if result.len() == 0:
          result = $searchFor
    except DbError, OSError:
      showError("Can't get the selected command from the shell's history. Reason: ",
          getCurrentException())

proc clearHistory*(db): HistoryRange {.gcsafe, sideEffect, raises: [], tags: [
    ReadIOEffect, WriteIOEffect, ReadDbEffect, WriteDbEffect, TimeEffect],
    locks: 0, contractual.} =
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
  require:
    db != nil
  body:
    try:
      db.exec(query = sql(query = "DELETE FROM history"));
    except DbError:
      showError(message = "Can't clear the shell's commands history. Reason: ",
          e = getCurrentException())
      return historyLength(db = db)
    showOutput(message = "Shell's commands' history cleared.",
        fgColor = fgGreen)
    return 0;

proc helpHistory*(db): HistoryRange {.gcsafe, sideEffect, raises: [], tags: [
    ReadDbEffect, WriteDbEffect, ReadIOEffect, WriteIOEffect, ReadEnvEffect,
    TimeEffect], locks: 0, contractual.} =
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
  require:
    db != nil
  body:
    showOutput(message = """Available subcommands are: clear, list

          To see more information about the subcommand, type help history [command],
          for example: help history clear.
  """)
    return updateHistory(commandToAdd = "history", db = db)

proc showHistory*(db; arguments: UserInput = emptyLimitedString(
    capacity = maxInputLength)): HistoryRange {.gcsafe, sideEffect, raises: [],
    tags: [ReadDbEffect, WriteDbEffect, ReadIOEffect, WriteIOEffect,
    ReadEnvEffect, TimeEffect], locks: 0, contractual.} =
  ## FUNCTION
  ##
  ## Show the last X entries to the shell's history. X can be set in the shell's
  ## options as 'historyAmount' option or as an argument by the user.
  ##
  ## PARAMETERS
  ##
  ## * db        - the connection to the shell's database
  ## * arguments - the string with arguments entered by the user for the command.
  ##               Can be empty. Default value is empty.
  ##
  ## RETURNS
  ##
  ## The last X entries to the shell's history.
  require:
    db != nil
  body:
    let
      argumentsList: seq[string] = split(s = $arguments)
      amount: HistoryRange = try:
          parseInt(s = (if argumentsList.len() > 1: argumentsList[
              1] else: $getOption(optionName = initLimitedString(capacity = 13,
              text = "historyAmount"), db = db)))
        except ValueError, CapacityError:
          showError(message = "Can't get setting for the amount of history commands to show.")
          return updateHistory(commandToAdd = "history list", db = db,
              returnCode = QuitFailure.ResultCode)
      spacesAmount: ColumnAmount = try:
            (terminalWidth() / 12).ColumnAmount
        except ValueError:
          6.ColumnAmount
      historyDirection: string = try:
          if argumentsList.len() > 3: (if argumentsList[3] ==
              "true": "ASC" else: "DESC") else:
            if $getOption(optionName = initLimitedString(capacity = 14,
              text = "historyReverse"), db = db) == "true": "ASC" else: "DESC"
        except CapacityError:
          showError(message = "Can't get setting for the reverse order of history commands to show.")
          return updateHistory(commandToAdd = "history list", db = db,
              returnCode = QuitFailure.ResultCode)
      orderText: string = try:
          if argumentsList.len() > 2: argumentsList[2] else: $getOption(
              optionName = initLimitedString(capacity = 11,
                  text = "historySort"), db = db)
        except CapacityError:
          showError(message = "Can't get setting for the order of history commands to show.")
          return updateHistory(commandToAdd = "history list", db = db,
              returnCode = QuitFailure.ResultCode)
      historyOrder: string =
        case orderText
        of "recent": "lastused " & historyDirection
        of "amount": "amount " & historyDirection
        of "name": "command " & (if historyDirection ==
            "DESC": "ASC" else: "DESC")
        of "recentamount": "lastused " & historyDirection & ", amount " & historyDirection
        else:
          showError(message = "Unknown type of history sort order")
          return updateHistory(commandToAdd = "history list", db = db,
            returnCode = QuitFailure.ResultCode)
    showFormHeader(message = "The last commands from the shell's history")
    showOutput(message = indent(s = "Last used                Times      Command",
        count = spacesAmount.int), fgColor = fgMagenta)
    try:
      for row in db.fastRows(query = sql(
          query = "SELECT command, lastused, amount FROM history ORDER BY " &
          historyOrder & " LIMIT 0, ?"), amount):
        showOutput(message = indent(s = row[1] & "      " & center(s = row[2],
            width = 5) & "      " & row[0], count = spacesAmount.int))
      return updateHistory(commandToAdd = "history list", db = db)
    except DbError:
      showError(message = "Can't get the last commands from the shell's history. Reason: ",
          e = getCurrentException())
      return updateHistory(commandToAdd = "history list", db = db,
          returnCode = QuitFailure.ResultCode)

proc updateHistoryDb*(db): ResultCode {.gcsafe, sideEffect, raises: [], tags: [
    ReadDbEffect, WriteDbEffect, WriteIOEffect, ReadEnvEffect, TimeEffect],
    locks: 0, contractual.} =
  ## FUNCTION
  ##
  ## Update the table history to the new version if needed
  ##
  ## PARAMETERS
  ##
  ## * db - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## QuitSuccess if update was successfull, otherwise QuitFailure and
  ## show message what wrong
  require:
    db != nil
  body:
    try:
      db.exec(query = sql(query = """ALTER TABLE history ADD path VARCHAR(""" &
          $maxInputLength & """)"""))
      setOption(optionName = initLimitedString(capacity = 13,
          text = "historyLength"), valueType = ValueType.natural, db = db)
      setOption(optionName = initLimitedString(capacity = 13,
          text = "historyAmount"), valueType = ValueType.natural, db = db)
      setOption(optionName = initLimitedString(capacity = 11,
          text = "historySort"), value = initLimitedString(capacity = 12,
          text = "recentamount"), description = initLimitedString(capacity = 63,
          text = "How to sort the list of the last commands from shell history."),
          valueType = ValueType.historysort, db = db)
      setOption(optionName = initLimitedString(capacity = 14,
          text = "historyReverse"), value = initLimitedString(capacity = 5,
          text = "false"), description = initLimitedString(capacity = 64,
          text = "Reverse order when showing the last commands from shell history."),
          valueType = ValueType.boolean, db = db)
    except DbError, CapacityError:
      return showError(message = "Can't update table for the shell's history. Reason: ",
          e = getCurrentException())
    return QuitSuccess.ResultCode

proc createHistoryDb*(db): ResultCode {.gcsafe, sideEffect, raises: [], tags: [
    WriteDbEffect, ReadDbEffect, WriteIOEffect, ReadEnvEffect, TimeEffect],
    locks: 0, contractual.} =
  ## FUNCTION
  ##
  ## Create the table history and set shell's options related to the history
  ##
  ## PARAMETERS
  ##
  ## * db - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## QuitSuccess if creation was successfull, otherwise QuitFailure and
  ## show message what wrong
  require:
    db != nil
  body:
    try:
      db.exec(query = sql(query = """CREATE TABLE history (
                   command     VARCHAR(""" & $maxInputLength &
          """) PRIMARY KEY,
                   lastused    DATETIME NOT NULL DEFAULT 'datetime(''now'')',
                   amount      INTEGER NOT NULL DEFAULT 1,
                   path        VARCHAR(""" & $maxInputLength &
            """)
                )"""))
      setOption(optionName = initLimitedString(capacity = 13,
          text = "historyLength"), value = initLimitedString(capacity = 3,
          text = "500"), description = initLimitedString(capacity = 48,
          text = "Max amount of entries in shell commands history."),
          valueType = ValueType.natural, db = db)
      setOption(optionName = initLimitedString(capacity = 13,
          text = "historyAmount"), value = initLimitedString(capacity = 2,
          text = "20"), description = initLimitedString(capacity = 78,
          text = "Amount of entries in shell commands history to show with history list command."),
          valueType = ValueType.natural, db = db)
      setOption(optionName = initLimitedString(capacity = 20,
          text = "historySaveInvalid"), value = initLimitedString(capacity = 5,
          text = "false"), description = initLimitedString(capacity = 52,
          text = "Save in shell command history also invalid commands."),
          valueType = ValueType.boolean, db = db)
      setOption(optionName = initLimitedString(capacity = 11,
          text = "historySort"), value = initLimitedString(capacity = 12,
          text = "recentamount"), description = initLimitedString(capacity = 63,
          text = "How to sort the list of the last commands from shell history."),
          valueType = ValueType.historysort, db = db)
      setOption(optionName = initLimitedString(capacity = 14,
          text = "historyReverse"), value = initLimitedString(capacity = 5,
          text = "false"), description = initLimitedString(capacity = 64,
          text = "Reverse order when showing the last commands from shell history."),
          valueType = ValueType.boolean, db = db)
    except DbError, CapacityError:
      return showError(message = "Can't create 'history' table. Reason: ",
          e = getCurrentException())
    return QuitSuccess.ResultCode
