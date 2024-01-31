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

## This module contains code related to the shell's commands' history system,
## like adding the commands to it, printing to the user, clearing or searching
## in.

# Standard library imports
import std/[os, strutils, times]
# External modules imports
import ansiparse, contracts, nancy, termstyle
import norm/[model, pragmas, sqlite]
# Internal imports
import commandslist, constants, help, output, options, resultcode, theme

const historyCommands: seq[string] = @["clear", "list", "find"]
  ## The list of available subcommands for command history

type
  HistoryRange* = ExtendedNatural
    ## Used to store the amount of commands in the shell's history
  HistoryEntry* {.tableName: "history".} = ref object of Model
    ## Data structure for the shell's commands' history entry
    ##
    ## * command  - the command executed by the user
    ## * lastUsed - the time when the command was recently excute
    ## * amount   - how many times the user executed the command
    ## * path     - the full path in which the command was executed
    command*: string
    lastUsed: DateTime
    amount: int
    path: string

using
  db: DbConn # Connection to the shell's database
  arguments: UserInput # The arguments for a command entered by the user

proc historyLength*(db): HistoryRange {.sideEffect, raises: [], tags: [
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
      return db.count(T = HistoryEntry)
    except:
      showError(message = "Can't get the length of the shell's commands history. Reason: ",
          e = getCurrentException(), db = db)
      return HistoryRange.low

proc newHistoryEntry(command: string = ""; lastUsed: DateTime = now();
    amount: Positive = 1; path: string = ""): HistoryEntry {.raises: [], tags: [],
    contractual.} =
  ## Create a new data structure for the shell's commands' history entry.
  ##
  ## * command  - the command executed by the user
  ## * lastUsed - the time when the command was recently excute
  ## * amount   - how many times the user executed the command
  ## * path     - the full path in which the command was executed
  ##
  ## Returns the new data structure for the selected shell's commands' history entry.
  body:
    return HistoryEntry(command: command, lastUsed: lastUsed, amount: amount, path: path)

proc updateHistory*(commandToAdd: string; db;
    returnCode: ResultCode = QuitSuccess.ResultCode): HistoryRange {.sideEffect,
    raises: [], tags: [ReadDbEffect, WriteDbEffect, WriteIOEffect,
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
    result = db.historyLength
    var value: OptionValue = ""
    let historyAmount: Natural = try:
        value = getOption(optionName = "historyLength", db = db, defaultValue = "500")
        ($value).parseInt
      except:
        500
    if historyAmount == 0:
      return
    try:
      value = getOption(optionName = "historySaveInvalid", db = db,
          defaultValue = "false")
      if returnCode != QuitSuccess and value == "false":
        return
    except:
      showError(message = "Can't get value of option historySaveInvalid. Reason: ",
          e = getCurrentException(), db = db)
      return
    if result >= historyAmount:
      try:
        var entries: seq[HistoryEntry] = @[newHistoryEntry()]
        db.select(objs = entries, cond = "id IN (SELECT id FROM history ORDER BY lastused, amount ASC LIMIT ?)",
            params = (if result == historyAmount: 1 else: result -
                historyAmount))
        db.delete(objs = entries)
        result = db.historyLength
      except:
        showError(message = "Can't delete exceeded entries from the shell's history. Reason: ",
            e = getCurrentException(), db = db)
        return
    try:
      # Update history if there is the command in the history in the same directory
      let currentDir: string = getCurrentDirectory()
      var entry: HistoryEntry = newHistoryEntry()
      # If the history entry exists, update the amount and time
      if db.exists(T = HistoryEntry, cond = "command=? AND path=?", params = [
          commandToAdd.dbValue, currentDir.dbValue]):
        db.select(obj = entry, cond = "command=? AND path=?", params = [
            commandToAdd.dbValue, currentDir.dbValue])
        entry.amount.inc
        entry.lastUsed = now()
        db.update(obj = entry)
      elif db.exists(T = HistoryEntry, cond = "command=?",
          params = commandToAdd):
        db.select(obj = entry, cond = "command=?", params = commandToAdd)
        entry.path = currentDir
        entry.amount.inc
        entry.lastUsed = now()
        db.update(obj = entry)
      # Add the new entry to the shell's history
      else:
        entry = newHistoryEntry(command = commandToAdd, path = currentDir)
        db.insert(obj = entry)
        result.inc
    except:
      showError(message = "Can't update the shell's history. Reason: ",
          e = getCurrentException(), db = db)

proc getHistory*(historyIndex: HistoryRange; db;
    searchFor: UserInput = ""): string {.sideEffect, raises: [], tags: [
    ReadDbEffect, ReadEnvEffect, WriteIOEffect, TimeEffect, RootEffect],
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
      type LocalEntry = ref object
        command: string
      var entry: LocalEntry = LocalEntry()
      # Get the command based on the historyIndex parameter
      if searchFor.len == 0:
        if db.exists(T = HistoryEntry, cond = "path=?",
            params = getCurrentDirectory()):
          db.rawSelect(qry = "SELECT command FROM history WHERE path=? ORDER BY lastused DESC, amount ASC LIMIT 1 OFFSET ?",
              obj = entry, params = [getCurrentDirectory().dbValue, ($(
              historyLength(db = db) - historyIndex)).dbValue])
        if entry.command.len == 0 and db.exists(T = HistoryEntry):
          db.rawSelect(qry = "SELECT command FROM history ORDER BY lastused DESC, amount ASC LIMIT 1 OFFSET ?",
              obj = entry, params = $(historyLength(db = db) - historyIndex))
        return entry.command
      # Get the command based on the searchFor parameter
      if db.exists(T = HistoryEntry, cond = "command LIKE ? AND path=?",
          params = [(searchFor & "%").dbValue, getCurrentDirectory().dbValue]):
        db.rawSelect(qry = "SELECT command FROM history WHERE command LIKE ? AND path=? ORDER BY lastused DESC, amount DESC",
            obj = entry, params = [(searchFor & "%").dbValue,
            getCurrentDirectory().dbValue])
      if entry.command.len == 0:
        if db.exists(T = HistoryEntry, cond = "command LIKE ?", params = (
            searchFor & "%").dbValue):
          db.rawSelect(qry = "SELECT command FROM history WHERE command LIKE ? ORDER BY lastused DESC, amount DESC",
              obj = entry, params = (searchFor & "%").dbValue)
      if entry.command.len > 0:
        return entry.command
    except:
      showError(message = "Can't get the selected command from the shell's history. Reason: ",
          e = getCurrentException(), db = db)
    return $searchFor

proc clearHistory(db): ResultCode {.sideEffect, raises: [], tags: [
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
      sqlite.exec(db = db, query = sql(query = "DELETE FROM history"));
    except DbError:
      return showError(message = "Can't clear the shell's commands history. Reason: ",
          e = getCurrentException(), db = db)
    showOutput(message = "Shell's commands' history cleared.",
        color = success, db = db)
    return QuitSuccess.ResultCode

proc showHistory(db; arguments): ResultCode {.sideEffect, raises: [],
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
    var value: OptionValue = ""
    let
      argumentsList: seq[string] = split(s = $arguments)
      amount: HistoryRange = try:
          if argumentsList.len > 1:
            argumentsList[1].parseInt
          else:
            value = getOption(optionName = "historyAmount", db = db)
            ($value).parseInt
        except:
          return showError(message = "Can't get setting for the amount of history commands to show.", db = db)
      historyDirection: string = try:
          if argumentsList.len > 3: (if argumentsList[3] ==
              "true": "ASC" else: "DESC") else:
            value = getOption(optionName = "historyReverse", db = db)
            if value == "true":
              "ASC"
            else:
              "DESC"
        except:
          return showError(message = "Can't get setting for the reverse order of history commands to show.", db = db)
      orderText: string = try:
          if argumentsList.len > 2:
            argumentsList[2]
          else:
            value = getOption(optionName = "historySort", db = db)
            $value
        except:
          return showError(message = "Can't get setting for the order of history commands to show.", db = db)
      historyOrder: string =
        case orderText
        of "recent": "lastused " & historyDirection
        of "amount": "amount " & historyDirection
        of "name": "command " & (if historyDirection ==
            "DESC": "ASC" else: "DESC")
        of "recentamount": "lastused " & historyDirection & ", amount " & historyDirection
        else:
          return showError(message = "Unknown type of history sort order", db = db)
    var table: TerminalTable = TerminalTable()
    try:
      let color: string = getColor(db = db, name = tableHeaders)
      table.add(parts = [style(ss = "Last used", style = color), style(
          ss = "Times", style = color), style(ss = "Command", style = color)])
    except UnknownEscapeError, InsufficientInputError, FinalByteError:
      return showError(message = "Can't show history list. Reason: ",
          e = getCurrentException(), db = db)
    try:
      type LocalEntry = ref object
        command: string
        lastUsed: DateTime
        amount: int
      var entries: seq[LocalEntry] = @[LocalEntry()]
      db.rawSelect(qry = "SELECT command, lastused, amount FROM history ORDER BY " &
          historyOrder & " LIMIT 0, ?", objs = entries, params = amount)
      let color: string = getColor(db = db, name = default)
      for entry in entries:
        table.add(parts = [style(ss = entry.lastUsed.local.format(
            f = "yyyy-MM-dd HH:mm:ss"), style = color), style(
            ss = $entry.amount, style = color), style(ss = entry.command,
            style = color)])
      var width: int = 0
      for size in table.getColumnSizes(maxSize = int.high):
        width += size
      showFormHeader(message = "The last " & $amount &
          " commands from the shell's history", width = width.ColumnAmount, db = db)
    except:
      return showError(message = "Can't get the last commands from the shell's history. Reason: ",
          e = getCurrentException(), db = db)
    try:
      table.echoTable
    except IOError, Exception:
      return showError(message = "Can't show the list of last commands from the shell's history. Reason: ",
          e = getCurrentException(), db = db)
    return QuitSuccess.ResultCode

proc findInHistory(db; arguments): ResultCode {.raises: [], tags: [
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
      return showError(message = "You have to enter a search term for which you want to look in the history.", db = db)
    let searchTerm: string = searchFor[5..^1]
    searchFor = replace(s = searchTerm, sub = '*', by = '%')
    var table: TerminalTable = TerminalTable()
    try:
      result = QuitFailure.ResultCode
      let maxRows: int = ($getOption(optionName = "historySearchAmount", db = db)).parseInt
      var currentRow: int = 0
      type LocalEntry = ref object
        command: string
      var entries: seq[LocalEntry] = @[LocalEntry()]
      db.rawSelect(qry = "SELECT command FROM history WHERE command LIKE ? ORDER BY lastused DESC, amount DESC",
          objs = entries, params = "%" & searchFor & "%")
      for entry in entries:
        table.add(parts = style(ss = entry.command, style = getColor(db = db,
            name = default)))
        result = QuitSuccess.ResultCode
        currentRow.inc
        if currentRow == maxRows:
          break
      if result == QuitFailure:
        showOutput(message = "No commands found in the shell's history for '" &
            searchTerm & "'", db = db)
        return
      try:
        showFormHeader(message = "The search results for '" & searchTerm &
            "' in the history:", width = table.getColumnSizes(
            maxSize = int.high)[0].ColumnAmount, db = db)
        table.echoTable
      except IOError, Exception:
        return showError(message = "Can't show the list of search results from history. Reason: ",
            e = getCurrentException(), db = db)
    except:
      return showError(message = "Can't get the last commands from the shell's history. Reason: ",
          e = getCurrentException(), db = db)

proc updateHistoryDb*(db; dbVersion: Natural): ResultCode {.sideEffect,
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
        db.exec(query = sql(query = """ALTER TABLE history ADD path TEXT"""))
        var
          newOptions: seq[Option] = @[newOption(name = "historySaveInvalid",
              value = "false",
              description = "Save in shell command history also invalid commands.",
              valueType = boolean, defaultValue = "false", readOnly = false),
              newOption(name = "historySort", value = "recentamount",
              description = "How to sort the list of the last commands from shell history.",
              valueType = historysort, defaultValue = "recentamount",
              readOnly = false), newOption(name = "historyReverse",
              value = "false",
              description = "Reverse order when showing the last commands from shell history.",
              valueType = boolean, defaultValue = "false", readOnly = false),
              newOption(name = "historySearchAmount", value = "20",
              description = "The amount of results to return when search shell history.",
              valueType = natural, defaultValue = "20", readOnly = false)]
          updatedOptions: seq[Option] = @[newOption(name = "historyLength",
              value = "500",
              description = "Max amount of entries in shell commands history.",
              valueType = natural, defaultValue = "500", readOnly = false),
              newOption(name = "historyAmount", value = "20",
              description = "Amount of entries in shell commands history to show with history list command.",
              valueType = natural, defaultValue = "20", readOnly = false)]
        db.update(objs = updatedOptions)
        db.insert(objs = newOptions)
      if dbVersion < 4:
        db.exec(query = sql(query = """ALTER TABLE history ADD id INTEGER NOT NULL DEFAULT 0"""))
        db.exec(query = sql(query = """UPDATE history SET id=rowid"""))
        db.exec(query = sql(query = """ALTER TABLE history DROP lastused"""))
        db.exec(query = sql(query = """ALTER TABLE history ADD lastUsed FLOAT NOT NULL DEFAULT 0"""))
    except:
      return showError(message = "Can't update table for the shell's history. Reason: ",
          e = getCurrentException(), db = db)
    return QuitSuccess.ResultCode

proc createHistoryDb*(db): ResultCode {.sideEffect, raises: [], tags: [
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
      db.createTables(obj = newHistoryEntry())
      var newOptions: seq[Option] = @[newOption(name = "historyLength",
          value = "500",
          description = "Max amount of entries in shell commands history.",
          valueType = natural, defaultValue = "500", readOnly = false),
          newOption(name = "historyAmount", value = "20",
          description = "Amount of entries in shell commands history to show with history list command.",
          valueType = natural, defaultValue = "20", readOnly = false),
          newOption(name = "historySaveInvalid", value = "false",
          description = "Save in shell command history also invalid commands.",
          valueType = boolean, defaultValue = "false", readOnly = false),
          newOption(name = "historySort", value = "recentamount",
          description = "How to sort the list of the last commands from shell history.",
          valueType = historysort, defaultValue = "recentamount",
          readOnly = false), newOption(name = "historyReverse", value = "false",
          description = "Reverse order when showing the last commands from shell history.",
          valueType = boolean, defaultValue = "false", readOnly = false),
          newOption(name = "historySearchAmount", value = "20",
          description = "The amount of results to return when search shell history.",
          valueType = natural, defaultValue = "20", readOnly = false)]
      db.insert(objs = newOptions)
      return QuitSuccess.ResultCode
    except:
      return showError(message = "Can't create 'history' table. Reason: ",
          e = getCurrentException(), db = db)

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
        ], tags: [WriteIOEffect, WriteDbEffect, TimeEffect, ReadDbEffect,
        ReadIOEffect, ReadEnvEffect, RootEffect], contractual.} =
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
              subcommands = historyCommands, db = db)
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
        return showUnknownHelp(subCommand = arguments,
            command = "history",
            helpType = "history", db = db)
    try:
      addCommand(name = "history",
          command = historyCommand, commands = commands,
          subCommands = historyCommands)
    except:
      showError(message = "Can't add commands related to the shell's history. Reason: ",
          e = getCurrentException(), db = db)
    # Return the current help index set on the last command in the shell's history
    return historyLength(db = db)
