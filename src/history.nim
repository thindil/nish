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

## This module contains code related to the shell's commands' history system,
## like adding the commands to it, printing to the user, clearing or searching
## in.

# Standard library imports
import std/[db_sqlite, os, strutils, terminal]
# External modules imports
import ansiparse, contracts, nancy, termstyle
# Internal imports
import commandslist, constants, help, input, lstring, output, resultcode

const historyCommands* = ["clear", "list", "find"]
  ## The list of available subcommands for command history

type HistoryRange* = ExtendedNatural
  ## Used to store the amount of commands in the shell's history

using
  db: DbConn # Connection to the shell's database
  arguments: UserInput # The arguments for a command entered by the user

proc historyLength*(db): HistoryRange {.gcsafe, sideEffect, raises: [], tags: [
    ReadDbEffect, WriteIOEffect, ReadEnvEffect, TimeEffect, RootEffect],
    contractual.} =
  ## Get the current length of the shell's commmands' history
  ##
  ## * db - the connection to the shell's database
  ##
  ## Returns the amount of commands in the shell's commands' history or -1 if can't
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
      return HistoryRange.low

proc updateHistory*(commandToAdd: string; db;
    returnCode: ResultCode = ResultCode(QuitSuccess)): HistoryRange {.gcsafe,
    sideEffect, raises: [], tags: [ReadDbEffect, WriteDbEffect, WriteIOEffect,
    ReadEnvEffect, TimeEffect, RootEffect], contractual.} =
  ## Add the selected command to the shell history and increase the current
  ## history index. If there is the command in the shell's history, only update
  ## its amount ond last used timestamp. Remove the oldest entry if there is
  ## maximum allowed amount of history's entries.
  ##
  ## * commandToAdd - the command entered by the user which will be added
  ## * db           - the connection to the shell's database
  ## * returnCode   - the return code (success or failure) of the command to add
  ##
  ## Returns the new length of the shell's commands' history.
  require:
    db != nil
    commandToAdd.len > 0
  body:
    result = historyLength(db = db)
    let historyAmount = try:
        parseInt(s = db.getValue(query = sql(
            query = "SELECT value FROM options WHERE option='historyLength'")))
      except DbError, ValueError:
        500
    if historyAmount == 0:
      return
    try:
      if returnCode != QuitSuccess and db.getValue(query = sql(query =
        "SELECT value FROM options WHERE option='historySaveInvalid'")) == "false":
        return
    except DbError:
      showError(message = "Can't get value of option historySaveInvalid. Reason: ",
          e = getCurrentException())
      return
    if result >= historyAmount:
      try:
        db.exec(query = sql(query = "DELETE FROM history WHERE rowid IN (SELECT rowid FROM history ORDER BY lastused, amount ASC LIMIT ?)"),
            (if result == historyAmount: 1 else: result - historyAmount))
        result = historyLength(db = db)
      except DbError, ValueError:
        showError(message = "Can't delete exceeded entries from the shell's history. Reason: ",
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
          result.inc
    except DbError, OSError:
      showError(message = "Can't update the shell's history. Reason: ",
          e = getCurrentException())

proc getHistory*(historyIndex: HistoryRange; db;
    searchFor: UserInput = emptyLimitedString(
    capacity = maxInputLength)): string {.gcsafe, sideEffect, raises: [],
    tags: [ReadDbEffect, ReadEnvEffect, WriteIOEffect, TimeEffect, RootEffect],
    contractual.} =
  ## Get the command with the selected index from the shell history
  ##
  ## * historyIndex - the index of command in the shell's commands' history which
  ##                  will be get
  ## * db           - the connection to the shell's database
  ## * searchFor    - the part of full command which will be get from the shell's
  ##                  commands' history. Can be empty. If set, will be used instead
  ##                  of historyIndex
  ##
  ## Returns the selected command from the shell's commands' history.
  require:
    db != nil
  body:
    try:
      # Get the command based on the historyIndex parameter
      if searchFor.len == 0:
        let value = db.getValue(query = sql(
            query = "SELECT command FROM history WHERE path=? ORDER BY lastused DESC, amount ASC LIMIT 1 OFFSET ?"),
            getCurrentDir(), $(historyLength(db = db) - historyIndex))
        if value.len == 0:
          result = db.getValue(query = sql(
              query = "SELECT command FROM history ORDER BY lastused DESC, amount ASC LIMIT 1 OFFSET ?"),
              $(historyLength(db = db) - historyIndex))
        else:
          result = value
      # Get the command based on the searchFor parameter
      else:
        let value = db.getValue(query = sql(
            query = "SELECT command FROM history WHERE command LIKE ? AND path=? ORDER BY lastused DESC, amount DESC"),
            searchFor & "%", getCurrentDir())
        if value.len == 0:
          result = db.getValue(query = sql(
              query = "SELECT command FROM history WHERE command LIKE ? ORDER BY lastused DESC, amount DESC"),
              searchFor & "%")
        else:
          result = value
        if result.len == 0:
          result = $searchFor
    except DbError, OSError:
      showError("Can't get the selected command from the shell's history. Reason: ",
          getCurrentException())

proc clearHistory*(db): ResultCode {.gcsafe, sideEffect, raises: [], tags: [
    ReadIOEffect, WriteIOEffect, ReadDbEffect, WriteDbEffect, TimeEffect,
    RootEffect], contractual.} =
  ## Clear the shell's history, don't add the command to the history
  ##
  ## * db - the connection to the shell's database
  ##
  ## Returns QuitSuccess if the shell's history was cleared otherwise QuitFailure
  require:
    db != nil
  body:
    try:
      db.exec(query = sql(query = "DELETE FROM history"));
    except DbError:
      return showError(message = "Can't clear the shell's commands history. Reason: ",
          e = getCurrentException())
    showOutput(message = "Shell's commands' history cleared.",
        fgColor = fgGreen)
    return QuitSuccess.ResultCode

proc showHistory*(db; arguments): ResultCode {.sideEffect, raises: [],
    tags: [ReadDbEffect, WriteDbEffect, ReadIOEffect, WriteIOEffect,
    ReadEnvEffect, TimeEffect, RootEffect], contractual.} =
  ## Show the last X entries to the shell's history. X can be set in the shell's
  ## options as 'historyAmount' option or as an argument by the user.
  ##
  ## * db        - the connection to the shell's database
  ## * arguments - the string with arguments entered by the user for the command.
  ##
  ## Returns QuitSucces if the history was properly shown otherwise QuitFailure.
  require:
    db != nil
    arguments.len > 0
  body:
    let
      argumentsList: seq[string] = split(s = $arguments)
      amount: HistoryRange = try:
          parseInt(s = (if argumentsList.len > 1: argumentsList[
              1] else: db.getValue(query = sql(
                  query = "SELECT value FROM options WHERE option='historyAmount'"))))
        except ValueError, DbError:
          return showError(message = "Can't get setting for the amount of history commands to show.")
      historyDirection: string = try:
          if argumentsList.len > 3: (if argumentsList[3] ==
              "true": "ASC" else: "DESC") else:
            if db.getValue(query = sql(query = "SELECT value FROM options WHERE option='historyReverse'")) ==
                "true": "ASC" else: "DESC"
        except DbError:
          return showError(message = "Can't get setting for the reverse order of history commands to show.")
      orderText: string = try:
          if argumentsList.len > 2: argumentsList[2] else: db.getValue(
              query = sql(
              query = "SELECT value FROM options WHERE option='historySort'"))
        except DbError:
          return showError(message = "Can't get setting for the order of history commands to show.")
      historyOrder: string =
        case orderText
        of "recent": "lastused " & historyDirection
        of "amount": "amount " & historyDirection
        of "name": "command " & (if historyDirection ==
            "DESC": "ASC" else: "DESC")
        of "recentamount": "lastused " & historyDirection & ", amount " & historyDirection
        else:
          return showError(message = "Unknown type of history sort order")
    var table: TerminalTable
    try:
      table.add(magenta("Last used"), magenta("Times"), magenta("Command"))
    except UnknownEscapeError, InsufficientInputError, FinalByteError:
      return showError(message = "Can't show history list. Reason: ",
          e = getCurrentException())
    try:
      for row in db.fastRows(query = sql(
          query = "SELECT command, lastused, amount FROM history ORDER BY " &
          historyOrder & " LIMIT 0, ?"), amount):
        table.add(row[1], row[2], row[0])
      var width: int = 0
      for size in table.getColumnSizes(maxSize = int.high):
        width = width + size
      showFormHeader(message = "The last " & $amount &
          " commands from the shell's history", width = width.ColumnAmount, db = db)
    except DbError, UnknownEscapeError, InsufficientInputError, FinalByteError:
      return showError(message = "Can't get the last commands from the shell's history. Reason: ",
          e = getCurrentException())
    try:
      table.echoTable
    except IOError, Exception:
      return showError(message = "Can't show the list of last commands from the shell's history. Reason: ",
          e = getCurrentException())
    return QuitSuccess.ResultCode

proc findInHistory*(db; arguments): ResultCode {.raises: [], tags: [
    ReadIOEffect, WriteIOEffect, ReadDbEffect, RootEffect], contractual.} =
  ## Find the selected term in the shell's commands' history
  ##
  ## * db        - the connection to the shell's database
  ## * arguments - the string with arguments entered by the user for the command.
  ##
  ## Returns QuitSucces if the term found in the shell's comamnds' history, otherwise
  ## QuitFailure.
  require:
    db != nil
    arguments.len > 0
  body:
    var searchFor: string = strip(s = $arguments)
    if searchFor.len < 5:
      return showError(message = "You have to enter a search term for which you want to look in the history.")
    let searchTerm = searchFor[5..^1]
    searchFor = replace(s = searchTerm, sub = '*', by = '%')
    var table: TerminalTable
    try:
      result = QuitFailure.ResultCode
      let maxRows = db.getValue(query = sql(
          query = "SELECT value FROM options WHERE option='historySearchAmount'")).parseInt
      var currentRow: int = 0
      for row in db.fastRows(query = sql(
          query = "SELECT command FROM history WHERE command LIKE ? ORDER BY lastused DESC, amount DESC"),
          "%" & searchFor & "%"):
        table.add(row[0])
        result = QuitSuccess.ResultCode
        currentRow.inc
        if currentRow == maxRows:
          break
      if result == QuitFailure:
        showOutput(message = "No commands found in the shell's history for '" &
            searchTerm & "'")
        return
      try:
        showFormHeader(message = "The search results for '" & searchTerm &
            "' in the history:", width = table.getColumnSizes(
            maxSize = int.high)[0].ColumnAmount, db = db)
        table.echoTable
      except IOError, Exception:
        return showError(message = "Can't show the list of search results from history. Reason: ",
            e = getCurrentException())
    except DbError, ValueError, UnknownEscapeError, InsufficientInputError, FinalByteError:
      return showError(message = "Can't get the last commands from the shell's history. Reason: ",
          e = getCurrentException())

proc updateHistoryDb*(db; dbVersion: Natural): ResultCode {.gcsafe, sideEffect,
    raises: [], tags: [ReadDbEffect, WriteDbEffect, WriteIOEffect,
    ReadEnvEffect, TimeEffect, RootEffect], contractual.} =
  ## Update the table history to the new version if needed
  ##
  ## * db        - the connection to the shell's database
  ## * dbVersion - the version of the database schema from which upgrade is make
  ##
  ## Returns QuitSuccess if update was successfull, otherwise QuitFailure and
  ## show message what wrong
  require:
    db != nil
  body:
    try:
      if dbVersion < 2:
        db.exec(query = sql(query = """ALTER TABLE history ADD path VARCHAR(""" &
            $maxInputLength & """)"""))
        db.exec(query = sql(query = "UPDATE options SET valuetype='natural' WHERE option='historyLength'"))
        db.exec(query = sql(query = "INSERT INTO options (option, value, description, valuetype, defaultvalue, readonly) VALUES ('historySort', 'recentamount', 'How to sort the list of the last commands from shell history.', 'historysort', 'recentamount', '0')"))
        db.exec(query = sql(query = "INSERT INTO options (option, value, description, valuetype, defaultvalue, readonly) VALUES ('historyReverse', 'false', 'Reverse order when showing the last commands from shell history.', 'boolean', 'false', '0')"))
      if dbVersion < 3:
        db.exec(query = sql(query = "UPDATE options SET valuetype='positive' WHERE option='historyAmount'"))
        db.exec(query = sql(query = "INSERT INTO options (option, value, description, valuetype, defaultvalue, readonly) VALUES ('historySearchAmount', '20', 'The amount of results to return when search shell history.', 'positive', '20', '0')"))
    except DbError, CapacityError:
      return showError(message = "Can't update table for the shell's history. Reason: ",
          e = getCurrentException())
    return QuitSuccess.ResultCode

proc createHistoryDb*(db): ResultCode {.gcsafe, sideEffect, raises: [], tags: [
    WriteDbEffect, ReadDbEffect, WriteIOEffect, ReadEnvEffect, TimeEffect,
    RootEffect], contractual.} =
  ## Create the table history and set shell's options related to the history
  ##
  ## * db - the connection to the shell's database
  ##
  ## Returns QuitSuccess if creation was successfull, otherwise QuitFailure and
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
      db.exec(query = sql(query = "INSERT INTO options (option, value, description, valuetype, defaultvalue, readonly) VALUES ('historyLength', '500', 'Max amount of entries in shell commands history.', 'natural', '500', '0')"))
      db.exec(query = sql(query = "INSERT INTO options (option, value, description, valuetype, defaultvalue, readonly) VALUES ('historyAmount', '20', 'Amount of entries in shell commands history to show with history list command.', 'natural', '20', '0')"))
      db.exec(query = sql(query = "INSERT INTO options (option, value, description, valuetype, defaultvalue, readonly) VALUES ('historySaveInvalid', 'false', 'Save in shell command history also invalid commands.', 'boolean', 'false', '0')"))
      db.exec(query = sql(query = "INSERT INTO options (option, value, description, valuetype, defaultvalue, readonly) VALUES ('historySort', 'recentamount', 'How to sort the list of the last commands from shell history.', 'historysort', 'recentamount', '0')"))
      db.exec(query = sql(query = "INSERT INTO options (option, value, description, valuetype, defaultvalue, readonly) VALUES ('historyReverse', 'false', 'Reverse order when showing the last commands from shell history.', 'boolean', 'false', '0')"))
      db.exec(query = sql(query = "INSERT INTO options (option, value, description, valuetype, defaultvalue, readonly) VALUES ('historySearchAmount', '20', 'The amount of results to return when search shell history.', 'positive', '20', '0')"))
    except DbError, CapacityError:
      return showError(message = "Can't create 'history' table. Reason: ",
          e = getCurrentException())
    return QuitSuccess.ResultCode

proc initHistory*(db; commands: ref CommandsList): HistoryRange {.
    sideEffect, raises: [], tags: [ReadDbEffect, WriteIOEffect, WriteDbEffect,
    ReadEnvEffect, TimeEffect, RootEffect], contractual.} =
  ## Initialize shell's commands history and set the history commands
  ##
  ## * db          - the connection to the shell's database
  ## * commands    - the list of the shell's commands
  ##
  ## Returns the length of the shell's commands' history
  require:
    db != nil
  body:
    # Add commands related to the shell's history system
    proc historyCommand(arguments; db; list: CommandLists): ResultCode {.raises: [
        ], contractual.} =
      ## FUNCTION
      ##
      ## The code of the shell's command "history" and its subcommands
      ##
      ## PARAMETERS
      ##
      ## * arguments - the arguments entered by the user for the command
      ## * db        - the connection to the shell's database
      ## * list      - the additional data for the command, like list of help
      ##               entries, etc
      ##
      ## RETURNS
      ## QuitSuccess if the selected command was successfully executed,
      ## otherwise QuitFailure.
      body:
        # No subcommand entered, show available options
        if arguments.len == 0:
          return showHelpList(command = "history",
              subcommands = historyCommands)
        # Clear the shell's commands' history
        elif arguments == "clear":
          return clearHistory(db = db)
        elif arguments.len > 3:
          # Show the last executed shell's commands
          if arguments[0..3] == "list":
            return showHistory(db = db, arguments = arguments)
          # Find the string in the shell's commands' history
          elif arguments[0..3] == "find":
            return findInHistory(db = db, arguments = arguments)
        try:
          return showUnknownHelp(subCommand = arguments,
              command = initLimitedString(capacity = 7, text = "history"),
              helpType = initLimitedString(capacity = 7, text = "history"))
        except CapacityError:
          return QuitFailure.ResultCode
    try:
      addCommand(name = initLimitedString(capacity = 8, text = "history"),
          command = historyCommand, commands = commands)
    except CapacityError, CommandsListError:
      showError(message = "Can't add commands related to the shell's history. Reason: ",
          e = getCurrentException())
    # Return the current help index set on the last command in the shell's history
    return historyLength(db = db)
