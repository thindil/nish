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
import std/[os, strutils]
# External modules imports
import contracts
import norm/sqlite
# Internal imports
import aliases, directorypath, help, history, lstring, options, output, plugins,
    resultcode, variables

proc closeDb*(returnCode: ResultCode; db: DbConn) {.gcsafe, sideEffect,
    raises: [], tags: [DbEffect, WriteIOEffect, ReadEnvEffect, TimeEffect,
        RootEffect],
    contractual.} =
  ## Close the shell database and quit from the program with the selected return code
  ##
  ## * returnCode - the exit code to return with the end of the program
  ## * db         - the connection to the shell's database
  require:
    db != nil
  body:
    try:
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
    type Option = object
      name: string
      value: string
      description: string
      optionType: ValueType
      readOnly: bool
    const options: array[8, Option] = [Option(name: "dbVersion", value: "4",
        description: "Version of the database schema (read only).",
        optionType: ValueType.natural, readOnly: true), Option(
        name: "promptCommand", value: "built-in",
        description: "The command which output will be used as the prompt of shell.",
        optionType: ValueType.command, readOnly: false), Option(
        name: "setTitle", value: "true",
        description: "Set a terminal title to currently running command.",
        optionType: ValueType.boolean, readOnly: false), Option(
        name: "colorSyntax", value: "true",
        description: "Color the user input with info about invalid commands, quotes, etc.",
        optionType: ValueType.boolean, readOnly: false), Option(
        name: "completionAmount", value: "100",
        description: "The amount of Tab completions to show.",
        optionType: ValueType.natural, readOnly: false), Option(
        name: "outputHeaders", value: "unicode",
        description: "How to present the headers of commands.",
        optionType: ValueType.header, readOnly: false), Option(
        name: "helpColumns", value: "5",
        description: "The amount of columns for help list command.",
        optionType: ValueType.positive, readOnly: false), Option(
        name: "completionColumns", value: "5",
        description: "The amount of columns for Tab completion list.",
        optionType: ValueType.positive, readOnly: false)]
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
      try:
        for option in options:
          setOption(optionName = initLimitedString(capacity = 40,
              text = option.name), value = initLimitedString(capacity = 40,
              text = option.value), description = initLimitedString(
              capacity = 256, text = option.description),
              valueType = option.optionType, db = result, readOnly = (
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
        for option in options:
          setOption(optionName = initLimitedString(capacity = 40,
              text = option.name), value = initLimitedString(capacity = 40,
              text = option.value), description = initLimitedString(
              capacity = 256, text = option.description),
              valueType = option.optionType, db = result, readOnly = (
              if option.readOnly: 1 else: 0))
      of 2:
        if result.updatePluginsDb == QuitFailure:
          return nil
        if result.updateHistoryDb(dbVersion = dbVersion) == QuitFailure:
          return nil
        for i in options.low..options.high:
          if i == 1:
            continue
          setOption(optionName = initLimitedString(capacity = 40,
              text = options[i].name), value = initLimitedString(capacity = 40,
              text = options[i].value), description = initLimitedString(
              capacity = 256, text = options[i].description),
              valueType = options[i].optionType, db = result, readOnly = (
              if options[i].readOnly: 1 else: 0))
      of 3:
        if result.updateOptionsDb(dbVersion = dbVersion) == QuitFailure:
          return nil
        if result.updateHelpDb(dbVersion = dbVersion) == QuitFailure:
          return nil
        if result.updateHistoryDb(dbVersion = dbVersion) == QuitFailure:
          return nil
        setOption(optionName = initLimitedString(capacity = 40,
            text = options[0].name), value = initLimitedString(capacity = 40,
            text = options[0].value), description = initLimitedString(
            capacity = 256, text = options[0].description),
            valueType = options[0].optionType, db = result, readOnly = (
            if options[0].readOnly: 1 else: 0))
      of 4:
        discard
      else:
        showError(message = "Invalid version of database.")
        return nil
    except CapacityError, DbError, ValueError:
      showError(message = "Can't update database. Reason: ",
          e = getCurrentException())
      return nil
