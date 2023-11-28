# Copyright © 2023 Bartek Jasicki
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

## This module contains code related to start and close the connection to
## the shell's database.

# Standard library imports
import std/[os, osproc, strutils, terminal]
# External modules imports
import contracts, nimalyzer
import norm/sqlite
# Internal imports
import aliases, constants, commandslist, completion, directorypath, help,
    history, logger, lstring, options, output, plugins, resultcode, variables

const
  dbCommands*: seq[string] = @["optimize", "backup", "import"]
    ## The list of available subcommands for command alias

using
  db: DbConn # Connection to the shell's database
  arguments: UserInput # The string with arguments entered by the user for the command

var dbFile: DirectoryPath = "".DirectoryPath ## The full path to the shell's database

proc closeDb*(returnCode: ResultCode; db) {.sideEffect, raises: [],
    tags: [DbEffect, WriteIOEffect, ReadEnvEffect, TimeEffect, RootEffect],
    contractual.} =
  ## Close the shell database and quit from the program with the selected return code
  ##
  ## * returnCode - the exit code to return with the end of the program
  ## * db         - the connection to the shell's database
  require:
    db != nil
  body:
    try:
      logToFile(message = "Stopping the shell in debug mode.")
      db.close
    except DbError:
      showError(message = "Can't close properly the shell database. Reason:",
          e = getCurrentException())
      quit QuitFailure
    quit returnCode.int

proc startDb*(dbPath: DirectoryPath): DbConn {.sideEffect, raises: [], tags: [
    ReadIOEffect, WriteDirEffect, DbEffect, WriteIOEffect, ReadEnvEffect,
    TimeEffect, RootEffect], contractual.} =
  ## Open connection to the shell database. Create database if not exists.
  ## Set the historyIndex to the last command
  ##
  ## * dbPath - The full path to the database file
  ##
  ## Returns pointer to the database connection. If connection cannot be established,
  ## returns nil.
  require:
    dbPath.len > 0
  body:
    try:
      discard existsOrCreateDir(dir = parentDir(path = $dbPath))
    except OSError, IOError:
      showError(message = "Can't create directory for the shell's database. Reason: ",
          e = getCurrentException())
      return nil
    let dbExists: bool = fileExists(filename = $dbPath)
    try:
      result = open(connection = $dbPath, user = "", password = "", database = "")
    except DbError:
      showError(message = "Can't open the shell's database. Reason: ",
          e = getCurrentException())
      return nil
    let options: array[10, Option] = [newOption(name = "dbVersion", value = "5",
        description = "Version of the database schema (read only).",
        valueType = ValueType.natural, readOnly = true, defaultValue = "5"),
        newOption(name = "promptCommand", value = "built-in",
        description = "The command which output will be used as the prompt of shell.",
        valueType = ValueType.command, readOnly = false,
        defaultValue = "built-in"), newOption(name = "setTitle", value = "true",
        description = "Set a terminal title to currently running command.",
        valueType = ValueType.boolean, readOnly = false, defaultValue = "true"),
        newOption(name = "colorSyntax", value = "true",
        description = "Color the user input with info about invalid commands, quotes, etc.",
        valueType = ValueType.boolean, readOnly = false, defaultValue = "true"),
        newOption(name = "completionAmount", value = "100",
        description = "The amount of Tab completions to show.",
        valueType = ValueType.natural, readOnly = false, defaultValue = "100"),
        newOption(name = "outputHeaders", value = "unicode",
        description = "How to present the headers of commands.",
        valueType = ValueType.header, readOnly = false,
        defaultValue = "unicode"), newOption(name = "helpColumns", value = "5",
        description = "The amount of columns for help list command.",
        valueType = ValueType.positive, readOnly = false, defaultValue = "5"),
        newOption(name = "completionColumns", value = "5",
        description = "The amount of columns for Tab completion list.",
        valueType = ValueType.positive, readOnly = false, defaultValue = "5"),
        newOption(name = "completionCheckCase", value = "false",
        description = "If true, Tab completion for directories and files is case-sensitive.",
        valueType = ValueType.boolean, readOnly = false,
        defaultValue = "false"),
        newOption(name = "suggestionPrecision", value = "1",
        description = "How precise is the commands' suggestion system.",
        valueType = ValueType.natural, readOnly = false, defaultValue = "1")]
    # Create a new database if not exists
    if not dbExists:
      if result.createAliasesDb == QuitFailure:
        return nil
      if result.createOptionsDb == QuitFailure:
        return nil
      if result.createHistoryDb == QuitFailure:
        return nil
      if result.createVariablesDb == QuitFailure:
        return nil
      if result.createPluginsDb == QuitFailure:
        return nil
      if result.createHelpDb == QuitFailure:
        return nil
      if result.createCompletionDb == QuitFailure:
        return nil
      try:
        for option in options:
          setOption(optionName = initLimitedString(capacity = 40,
              text = option.option), value = initLimitedString(capacity = 40,
              text = option.value), description = initLimitedString(
              capacity = 256, text = option.description),
              valueType = option.valueType, db = result, readOnly = (
              if option.readOnly: 1 else: 0))
      except CapacityError:
        showError(message = "Can't set database schema. Reason: ",
            e = getCurrentException())
        return nil
    # If database version is different than the newest, update database
    try:
      let dbVersion: int = parseInt(s = $getOption(
          optionName = initLimitedString(capacity = 9, text = "dbVersion"),
              db = result,
          defaultValue = initLimitedString(capacity = 1, text = "0")))
      case dbVersion
      of 0 .. 1:
        if result.updateOptionsDb(dbVersion = dbVersion) == QuitFailure:
          return nil
        if result.updateHistoryDb(dbVersion = dbVersion) == QuitFailure:
          return nil
        if result.updateAliasesDb(dbVersion = dbVersion) == QuitFailure:
          return nil
        if result.createPluginsDb == QuitFailure:
          return nil
        if result.createHelpDb == QuitFailure:
          return nil
        if result.createCompletionDb == QuitFailure:
          return nil
        for option in options:
          setOption(optionName = initLimitedString(capacity = 40,
              text = option.option), value = initLimitedString(capacity = 40,
              text = option.value), description = initLimitedString(
              capacity = 256, text = option.description),
              valueType = option.valueType, db = result, readOnly = (
              if option.readOnly: 1 else: 0))
      of 2:
        if result.updatePluginsDb == QuitFailure:
          return nil
        if result.updateHistoryDb(dbVersion = dbVersion) == QuitFailure:
          return nil
        if result.createCompletionDb == QuitFailure:
          return nil
        for i in options.low..options.high:
          if i == 1:
            continue
          setOption(optionName = initLimitedString(capacity = 40,
              text = options[i].option), value = initLimitedString(
              capacity = 40,
              text = options[i].value), description = initLimitedString(
              capacity = 256, text = options[i].description),
              valueType = options[i].valueType, db = result, readOnly = (
              if options[i].readOnly: 1 else: 0))
      of 3:
        if result.updateOptionsDb(dbVersion = dbVersion) == QuitFailure:
          return nil
        if result.updateHelpDb(dbVersion = dbVersion) == QuitFailure:
          return nil
        if result.updateHistoryDb(dbVersion = dbVersion) == QuitFailure:
          return nil
        if result.createCompletionDb == QuitFailure:
          return nil
        setOption(optionName = initLimitedString(capacity = 40,
            text = options[0].option), value = initLimitedString(capacity = 40,
            text = options[0].value), description = initLimitedString(
            capacity = 256, text = options[0].description),
            valueType = options[0].valueType, db = result, readOnly = (
            if options[0].readOnly: 1 else: 0))
        setOption(optionName = initLimitedString(capacity = 40,
            text = options[8].option), value = initLimitedString(capacity = 40,
            text = options[8].value), description = initLimitedString(
            capacity = 256, text = options[8].description),
            valueType = options[8].valueType, db = result, readOnly = (
            if options[8].readOnly: 1 else: 0))
        setOption(optionName = initLimitedString(capacity = 40,
            text = options[9].option), value = initLimitedString(capacity = 40,
            text = options[9].value), description = initLimitedString(
            capacity = 256, text = options[8].description),
            valueType = options[9].valueType, db = result, readOnly = (
            if options[9].readOnly: 1 else: 0))
      of 4:
        if result.createCompletionDb == QuitFailure:
          return nil
        setOption(optionName = initLimitedString(capacity = 40,
            text = options[0].option), value = initLimitedString(capacity = 40,
            text = options[0].value), description = initLimitedString(
            capacity = 256, text = options[0].description),
            valueType = options[0].valueType, db = result, readOnly = (
            if options[0].readOnly: 1 else: 0))
      of 5:
        discard
      else:
        showError(message = "Invalid version of database.")
        return nil
    except CapacityError, DbError, ValueError:
      showError(message = "Can't update database. Reason: ",
          e = getCurrentException())
      return nil
    dbFile = dbPath

proc optimizeDb*(arguments; db): ResultCode {.sideEffect,
    raises: [], tags: [WriteDbEffect, ReadDbEffect, WriteIOEffect, ReadIOEffect,
    RootEffect], contractual.} =
  ## Optimize the shell's database
  ##
  ## * arguments - the user entered text with arguments for optimize database
  ## * db        - the connection to the shell's database
  ##
  ## Returns QuitSuccess if the database was successfully optimized, otherwise
  ## QuitFailure.
  require:
    arguments.len > 7
    arguments.startsWith(prefix = "optimize")
    db != nil
  body:
    try:
      db.exec(query = "PRAGMA optimize;VACUUM;".SqlQuery)
      showOutput(message = "The shell's database was optimized.",
          fgColor = fgGreen)
    except:
      return showError(message = "Can't optimize the shell's database. Reason: ",
          e = getCurrentException())
    return QuitSuccess.ResultCode

proc backupDb*(arguments; db): ResultCode {.sideEffect, raises: [], tags: [
    WriteIOEffect, ExecIOEffect, ReadIOEffect, RootEffect], contractual.} =
  ## Create a SQL file with the shell's database.
  ##
  ## * arguments - the user entered text with arguments for optimize database
  ## * db        - the connection to the shell's database
  ##
  ## Returns QuitSuccess if the data from the database was properly exported
  ## to the file, otherwise QuitFailure.
  require:
    arguments.len > 7
    arguments.startsWith(prefix = "backup")
    db != nil
  body:
    const tablesNames: array[6, string] = ["aliases", "completions", "history",
        "options", "plugins", "variables"]
    let args: seq[string] = split(s = $arguments, sep = ' ')
    if args.len < 2:
      return showError(message = "Enter the name of the file where the database will be saved.")
    if args.len > 2:
      for argument in args[2 .. ^1]:
        if argument notin tablesNames:
          return showError(message = "Unknown type of the shell's data to backup. Available types are: " &
              tablesNames.join(sep = ", "))
    try:
      args[1].writeFile(content = execCmdEx(command = "sqlite3 " & dbFile &
          " '.dump " & (if args.len > 2: args[2 .. ^1].join(
          sep = " ") else: "") & "'").output)
      showOutput(message = "The backup file: '" & $args[1] & "' created.",
          fgColor = fgGreen)
    except:
      return showError(message = "Can't create the backup of the shell's database. Reason: ",
          e = getCurrentException())
    return QuitSuccess.ResultCode

proc importDb*(arguments; db): ResultCode {.sideEffect, raises: [],
    contractual.} =
  ## Import data from the SQL file into the shell's database
  ##
  ## * arguments - the user entered text with arguments for optimize database
  ## * db        - the connection to the shell's database
  ##
  ## Returns QuitSuccess if the data from the file was correctly imported into
  ## the database, otherwise QuitFailure.
  require:
    arguments.len > 7
    arguments.startsWith(prefix = "import")
    db != nil
  body:
    let args: seq[string] = split(s = $arguments, sep = ' ')
    if args.len < 2:
      return showError(message = "Enter the name of the file from which the data will be imported to the database.")
    try:
      let res = execCmdEx(command = "sqlite3 " & dbFile & " '.read " & args[1] & "'")
      if res.exitCode == 0:
        showOutput(message = "The data from the file: '" & $args[1] &
            "' was imported to the database.", fgColor = fgGreen)
      else:
        return showError(message = "Can't import the data into the shell's database. Reason: " & res.output)
    except:
      return showError(message = "Can't import the data into the shell's database. Reason: ",
          e = getCurrentException())
    return QuitSuccess.ResultCode

proc initDb*(db; commands: ref CommandsList) {.sideEffect, raises: [], tags: [
    ReadDbEffect, WriteIOEffect, ReadEnvEffect, TimeEffect, WriteDbEffect,
    ReadIOEffect, RootEffect], contractual.} =
  ## Initialize the shell's database. Set database's related commands
  ##
  ## * db          - the connection to the shell's database
  ## * commands    - the list of the shell's commands
  ##
  ## Returns the updated list of the shell's commands.
  require:
    db != nil
  body:
    # Add commands related to the shell's aliases
    proc dbCommand(arguments; db; list: CommandLists): ResultCode {.raises: [],
        tags: [WriteIOEffect, WriteDbEffect, TimeEffect, ReadDbEffect,
        ReadIOEffect, ReadEnvEffect, RootEffect], ruleOff: "paramsUsed",
        contractual.} =
      ## The code of the shell's command "nishdb" and its subcommands
      ##
      ## * arguments - the arguments entered by the user for the command
      ## * db        - the connection to the shell's database
      ## * list      - the additional data for the command, like id of alias, etc
      ##
      ## Returns QuitSuccess if the selected command was successfully executed,
      ## otherwise QuitFailure.
      body:
        # No subcommand entered, show available options
        if arguments.len == 0:
          return showHelpList(command = "nishdb",
              subcommands = dbCommands)
        # Optimize the shell's database
        if arguments.startsWith(prefix = "optimize"):
          return optimizeDb(arguments = arguments, db = db)
        # Backup the shell's database
        if arguments.startsWith(prefix = "backup"):
          return backupDb(arguments = arguments, db = db)
        # Import data into the shell's database
        if arguments.startsWith(prefix = "import"):
          return importDb(arguments = arguments, db = db)
        try:
          return showUnknownHelp(subCommand = arguments,
              command = initLimitedString(capacity = 6, text = "nishdb"),
                  helpType = initLimitedString(capacity = 6,
                      text = "nishdb"))
        except CapacityError:
          return QuitFailure.ResultCode

    try:
      addCommand(name = initLimitedString(capacity = 6, text = "nishdb"),
          command = dbCommand, commands = commands,
          subCommands = dbCommands)
    except CapacityError, CommandsListError:
      showError(message = "Can't add commands related to the shell's database. Reason: ",
          e = getCurrentException())
