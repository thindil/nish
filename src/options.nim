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

## This module contains code related to the shell's configuration options, like
## adding, removing, updating or showing the options.

# Standard library imports
import std/[os, osproc, strutils, terminal]
# Database library import, depends on version of Nim
when (NimMajor, NimMinor, NimPatch) >= (1, 7, 3):
  import db_connector/db_sqlite
else:
  import std/db_sqlite
# External modules imports
import ansiparse, contracts, nancy, nimalyzer, termstyle
import norm/[model, pragmas, sqlite]
# Internal imports
import commandslist, constants, help, lstring, output, resultcode

const optionsCommands*: array[3, string] = ["list", "set", "reset"]
  ## The list of available subcommands for command options

type
  OptionName* = LimitedString
    ## Used to store options names in the database.
  OptionValue* = LimitedString
    ## Used to set or get the option's values
  ValueType* = enum
    ## Used to set the type of option's value
    integer, float, boolean, none, historysort, natural, text, command, header, positive
  Option* {.tableName: "options".} = ref object of Model
    ## Data structure for the shell's option
    ##
    ## * option       - the name of the option
    ## * value        - the value of the option
    ## * description  - the description of the option
    ## * valueType    - the type of the option's value
    ## * defaultValue - the default value for the option
    ## * readOnly     - if true, the option can be only read by the user, not set
    option*: string
    value*: string
    description*: string
    valueType*: ValueType
    defaultValue*: string
    readOnly*: bool

using
  db: db_sqlite.DbConn # Connection to the shell's database
  optionName: OptionName # The name of option to get or set
  arguments: UserInput # The user entered agruments for set or reset option

proc dbType*(T: typedesc[ValueType]): string {.raises: [], tags: [],
    contractual.} =
  ## Set the type of field in the database
  ##
  ## * T - the type for which the field will be set
  ##
  ## Returns the type of the field in the database
  body:
    "TEXT"

proc dbValue*(val: ValueType): DbValue {.raises: [], tags: [], contractual.} =
  ## Convert the type of the option's value to database field
  ##
  ## * val - the value to convert
  ##
  ## Returns the converted val parameter
  body:
    dbValue(v = $val)

proc to*(dbVal: DbValue, T: typedesc[ValueType]): T {.raises: [], tags: [],
    contractual.} =
  ## Convert the value from the database to enumeration
  ##
  ## * dbVal - the value to convert
  ## * T     - the type to which the value will be converted
  ##
  ## Returns the converted dbVal parameter
  body:
    parseEnum[ValueType](s = dbVal.s)

proc getOption*(optionName; db; defaultValue: OptionValue = emptyLimitedString(
    capacity = maxInputLength)): OptionValue {.gcsafe, sideEffect, raises: [],
    tags: [ReadDbEffect, WriteIOEffect, ReadEnvEffect, TimeEffect, RootEffect],
    contractual.} =
  ## Get the selected option from the database. If the option doesn't exist,
  ## return the defaultValue
  ##
  ## * optionName   - the name of the option which value will be get
  ## * db           - the connection to the shell's database
  ## * defaultValue - the default value for option if the is no that option in
  ##                  the database. Default value is empty string ""
  ##
  ## Returns the value of the selected option or empty string if there is no that
  ## option in the database.
  require:
    optionName.len > 0
    db != nil
  body:
    try:
      let value: string = db.getValue(query = sql(
          query = "SELECT value FROM options WHERE option=?"),
          args = optionName)
      result = initLimitedString(capacity = (if value.len ==
          0: 1 else: value.len), text = value)
    except DbError, CapacityError:
      showError(message = "Can't get value for option '" & optionName &
          "' from database. Reason: ", e = getCurrentException())
      return defaultValue
    if result == "":
      result = defaultValue

proc setOption*(optionName; value: OptionValue = emptyLimitedString(
    capacity = maxInputLength); description: UserInput = emptyLimitedString(
    capacity = maxInputLength); valueType: ValueType = none; db;
    readOnly: BooleanInt = 0) {.gcsafe, sideEffect, raises: [], tags: [
    ReadDbEffect, WriteDbEffect, WriteIOEffect, ReadEnvEffect, TimeEffect,
        RootEffect],
    contractual.} =
  ## Set the value and or description of the selected option. If the option
  ## doesn't exist, insert it to the database
  ##
  ## * optionName  - the name of the option which will be set
  ## * value       - the value of the option to set
  ## * description - the description of the option to set
  ## * valuetype   - the type of the option to set
  ## * db          - the connection to the shell's database
  require:
    optionName.len > 0
    db != nil
  body:
    var sqlQuery: string = "UPDATE options SET "
    if value != "":
      sqlQuery.add(y = "value='" & value & "'")
    if description != "":
      if sqlQuery.len > 21:
        sqlQuery.add(y = ", ")
      sqlQuery.add(y = "description='" & description & "'")
    if valueType != none:
      if sqlQuery.len > 21:
        sqlQuery.add(y = ", ")
      sqlQuery.add(y = "valuetype='" & $valueType & "'")
    sqlQuery.add(y = " WHERE option='" & optionName & "'")
    try:
      if db_sqlite.execAffectedRows(db = db, query = sql(query = sqlQuery)) == 0:
        db.exec(query = sql(query = "INSERT INTO options (option, value, description, valuetype, defaultvalue, readonly) VALUES (?, ?, ?, ?, ?, ?)"),
            args = [$optionName, $value, $description, $valueType, $value, $readOnly])
    except DbError:
      showError(message = "Can't set value for option '" & optionName &
          "'. Reason: ", e = getCurrentException())

proc showOptions*(db): ResultCode {.sideEffect, raises: [], tags: [
    ReadDbEffect, WriteDbEffect, ReadIOEffect, WriteIOEffect, ReadEnvEffect,
    TimeEffect, RootEffect], contractual.} =
  ## Show the shell's options
  ##
  ## * db - the connection to the shell's database
  require:
    db != nil
  body:
    var table: TerminalTable = TerminalTable()
    try:
      table.add(parts = [magenta(ss = "Name"), magenta(ss = "Value"), magenta(
          ss = "Default"), magenta(ss = "Type"), magenta(ss = "Description")])
    except UnknownEscapeError, InsufficientInputError, FinalByteError:
      return showError(message = "Can't show options list. Reason: ",
          e = getCurrentException())
    showFormHeader(message = "Available options are:", db = db)
    try:
      for row in db_sqlite.fastRows(db = db, query = sql(
          query = "SELECT option, value, defaultvalue, valuetype, description FROM options ORDER BY option ASC")):
        table.add(parts = row)
    except DbError, UnknownEscapeError, InsufficientInputError, FinalByteError:
      return showError(message = "Can't show the shell's options. Reason: ",
          e = getCurrentException())
    try:
      table.echoTable
    except IOError, Exception:
      return showError(message = "Can't show the list of shell's options. Reason: ",
          e = getCurrentException())
    return QuitSuccess.ResultCode

proc setOptions*(arguments; db): ResultCode {.gcsafe, sideEffect, raises: [],
    tags: [ReadIOEffect, WriteIOEffect, WriteDbEffect, ReadDbEffect,
    ReadEnvEffect, TimeEffect, RootEffect], contractual.} =
  ## Set the selected option's value
  ##
  ## * arguments - the user entered text with arguments for the variable, its
  ##               name and a new value
  ## * db        - the connection to the shell's database
  ##
  ## Returns QuitSuccess if the variable was correctly set, otherwise QuitFailure.
  require:
    arguments.len > 0
    db != nil
  body:
    let setting: seq[string] = ($arguments).split()
    if setting.len < 2:
      return showError(message = "Please enter name of the option and its new value.")
    if setting.len < 3:
      return showError(message = "Please enter a new value for the selected option.")
    let optionName: OptionName = try:
        initLimitedString(capacity = setting[1].len, text = setting[1])
      except CapacityError:
        return showError(message = "Can't get the option's name from command: '" &
            arguments & "'.")
    try:
      if db.getValue(query = sql(query = "SELECT readonly FROM options WHERE option=?"),
          args = optionName) == "1":
        return showError(message = "You can't set a new value for the selected option because it is read-only.")
    except DbError:
      return showError(message = "Can't check if the selected option is read only. Reason: ",
          e = getCurrentException())
    let stringValue: string = setting[2 .. ^1].join(sep = " ")
    var value: OptionValue = try:
        initLimitedString(capacity = stringValue.len, text = stringValue)
      except CapacityError:
        return showError(message = "Can't get the option's value from command: '" &
            arguments & "'.")
    # Check correctness of the option's value
    try:
      case db.getValue(query = sql(query = "SELECT valuetype FROM options WHERE option=?"),
          args = optionName)
      of "integer":
        try:
          discard parseInt(s = $value)
        except:
          return showError(message = "Value for option '" & optionName &
              "' should be integer type.")
      of "float":
        try:
          discard parseFloat(s = $value)
        except:
          return showError(message = "Value for option '" & optionName & "' should be float type.")
      of "boolean":
        try:
          value.text = toLowerAscii(s = $value)
        except CapacityError:
          return showError(message = "Can't set a new value for option '" &
              optionName & "'. Reason: ", e = getCurrentException())
        if value != "true" and value != "false":
          return showError(message = "Value for option '" & optionName & "' should be true or false (case insensitive).")
      of "historysort":
        try:
          value.text = toLowerAscii(s = $value)
        except CapacityError:
          return showError(message = "Can't set a new value for option '" &
              optionName & "'. Reason: ", e = getCurrentException())
        if $value notin ["recent", "amount", "name", "recentamount"]:
          return showError(message = "Value for option '" & optionName & "' should be 'recent', 'amount', 'name' or 'recentamount' (case insensitive)")
      of "natural":
        try:
          if parseInt(s = $value) < 0:
            return showError(message = "Value for option '" & optionName &
                "' should be a natural integer, zero or more.")
        except:
          return showError(message = "Value for option '" & optionName &
              "' should be integer type.")
      of "text":
        discard
      of "command":
        try:
          let (_, exitCode) = execCmdEx(command = $value)
          if exitCode != QuitSuccess:
            return showError(message = "Value for option '" & optionName & "' should be valid command.")
        except:
          return showError(message = "Can't check the existence of command '" &
              value & "'. Reason: ", e = getCurrentException())
      of "header":
        try:
          value.text = toLowerAscii(s = $value)
        except CapacityError:
          return showError(message = "Can't set a new value for option '" &
              optionName & "'. Reason: ", e = getCurrentException())
        if $value notin ["unicode", "ascii", "none", "hidden"]:
          return showError(message = "Value for option '" & optionName & "' should be 'unicode', 'ascii', 'none' or 'hidden' (case insensitive)")
      of "positive":
        try:
          if parseInt(s = $value) < 1:
            return showError(message = "Value for option '" & optionName &
                "' should be a positive integer, one or more.")
        except:
          return showError(message = "Value for option '" & optionName &
              "' should be integer type.")
      of "":
        return showError(message = "Shell's option with name '" & optionName &
          "' doesn't exists. Please use command 'options list' to see all available shell's options.")
    except DbError:
      return showError(message = "Can't get type of value for option '" &
          optionName & "'. Reason: ", e = getCurrentException())
    # Set the option
    setOption(optionName = optionName, value = value, db = db)
    showOutput(message = "Value for option '" & optionName & "' was set to '" &
        value & "'", fgColor = fgGreen);
    return QuitSuccess.ResultCode

proc resetOptions*(arguments; db): ResultCode {.gcsafe, sideEffect, raises: [],
    tags: [ReadIOEffect, WriteIOEffect, WriteDbEffect, ReadDbEffect,
    ReadEnvEffect, TimeEffect, RootEffect], contractual.} =
  ## Reset the selected option's value to default value. If name of the option
  ## is set to "all", reset all options to their default values
  ##
  ## * arguments - the user entered text with arguments for the variable, its
  ##               name or all
  ## * db        - the connection to the shell's database
  ##
  ## Returns QuitSuccess if the variable(s) correctly reseted, otherwise QuitFailure.
  require:
    arguments.len > 0
    db != nil
  body:
    if arguments.len < 7:
      return showError(message = "Please enter name of the option to reset or 'all' to reset all options.")
    let optionName: OptionName = arguments[6 .. ^1]
    # Reset all options
    if optionName == "all":
      try:
        db_sqlite.exec(db = db, query = sql(
            query = "UPDATE options SET value=defaultvalue WHERE readonly=0"))
        showOutput(message = "All shell's options are reseted to their default values.")
      except DbError:
        return showError(message = "Can't reset the shell's options to their default values. Reason: ",
            e = getCurrentException())
    # Reset the selected option
    else:
      try:
        if db.getValue(query = sql(query = "SELECT readonly FROM options WHERE option=?"),
            args = optionName) == "1":
          return showError(message = "You can't reset option '" & optionName & "' because it is read-only option.")
        if db.getValue(query = sql(query = "SELECT value FROM options WHERE option=?"),
            args = optionName) == "":
          return showError(message = "Shell's option with name '" & optionName &
            "' doesn't exists. Please use command 'options list' to see all available shell's options.")
      except DbError:
        return showError(message = "Can't get value for option '" & optionName &
            "'. Reason: ", e = getCurrentException())
      try:
        db.exec(query = sql(query = "UPDATE options SET value=defaultvalue WHERE option=?"),
            args = optionName)
        showOutput(message = "The shell's option '" & optionName &
            "' reseted to its default value.", fgColor = fgGreen)
      except DbError:
        return showError(message = "Can't reset option '" & optionName &
            "' to its default value. Reason: ", e = getCurrentException())
    return QuitSuccess.ResultCode

proc updateOptionsDb*(db): ResultCode {.gcsafe, sideEffect, raises: [], tags: [
    WriteDbEffect, ReadDbEffect, WriteIOEffect, RootEffect], contractual.} =
  ## Update the table options to the new version if needed
  ##
  ## * db - the connection to the shell's database
  ##
  ## Returns QuitSuccess if update was successfull, otherwise QuitFailure and
  ## show message what wrong
  require:
    db != nil
  body:
    try:
      db_sqlite.exec(db = db, query = sql(
          query = """ALTER TABLE options ADD readonly BOOLEAN DEFAULT 0"""))
    except DbError:
      return showError(message = "Can't update table for the shell's options. Reason: ",
          e = getCurrentException())
    return QuitSuccess.ResultCode

proc newOption*(name: string = ""; value: string = ""; description: string = "";
    valueType: ValueType = none; defaultValue: string = "";
    readOnly: bool = false): Option {.raises: [], tags: [], contractual.} =
  ## Create a new data structure for the shell's option.
  ##
  ## * name         - the name of the option
  ## * value        - the value of the option
  ## * description  - the description of the option
  ## * valueType    - the type of the option's value
  ## * defaultValue - the default value for the option
  ## * readOnly     - if true, the option can be only read by the user, not set
  ##
  ## Returns the new data structure for the selected shell's option.
  body:
    Option(option: name, value: value, description: description,
        valueType: valueType, defaultValue: defaultValue, readOnly: readOnly)

proc createOptionsDb*(db): ResultCode {.gcsafe, sideEffect, raises: [], tags: [
    WriteDbEffect, ReadDbEffect, WriteIOEffect, RootEffect], contractual.} =
  ## Create the table options
  ##
  ## * db - the connection to the shell's database
  ##
  ## Returns QuitSuccess if creation was successfull, otherwise QuitFailure and
  ## show message what wrong
  require:
    db != nil
  body:
    try:
      db_sqlite.exec(db = db, query = sql(query = """CREATE TABLE options (
                  option VARCHAR(""" & $ aliasNameLength &
            """) NOT NULL PRIMARY KEY,
                  value	 VARCHAR(""" & $maxInputLength &
            """) NOT NULL,
                  description VARCHAR(""" & $maxInputLength &
            """) NOT NULL,
                  valuetype VARCHAR(""" & $maxInputLength &
            """) NOT NULL,
                  defaultvalue VARCHAR(""" & $maxInputLength &
            """) NOT NULL,
                  readonly BOOLEAN DEFAULT 0)"""))
    except DbError, CapacityError:
      return showError(message = "Can't create 'options' table. Reason: ",
          e = getCurrentException())
    return QuitSuccess.ResultCode

proc deleteOption*(optionName; db): ResultCode {.gcsafe, sideEffect, raises: [],
    tags: [WriteDbEffect, ReadDbEffect, WriteIOEffect, RootEffect],
    contractual.} =
  ## Delete the selected option from the table
  ##
  ## * optionName - the name of the option which will be deleted
  ## * db         - the connection to the shell's database
  ##
  ## Returns QuitSuccess if deletion was successfull, otherwise QuitFailure and
  ## show message what wrong
  require:
    optionName.len > 0
    db != nil
  body:
    try:
      if db.execAffectedRows(query = sql(
          query = "DELETE FROM options WHERE option=?"), args = optionName) == 0:
        return QuitFailure.ResultCode
    except DbError:
      return showError(message = "Can't delete the selected option. Reason: ",
          e = getCurrentException())
    return QuitSuccess.ResultCode

proc initOptions*(commands: ref CommandsList) {.sideEffect,
    raises: [], tags: [WriteDbEffect, WriteIOEffect, ReadDbEffect, ReadIOEffect,
    ReadEnvEffect, TimeEffect, RootEffect], contractual.} =
  ## Initialize the shell's options. At this moment only set the shell's commands
  ## related to the shell's options
  ##
  ## * commands    - the list of the shell's commands
  body:
    # Add commands related to the shell's options
    proc optionsCommand(arguments: UserInput; db;
        list: CommandLists): ResultCode {.raises: [], tags: [WriteIOEffect,
        WriteDbEffect, TimeEffect, ReadDbEffect, ReadIOEffect, ReadEnvEffect,
        Rooteffect], contractual.} =
      ## The code of the shell's command "options" and its subcommands
      ##
      ## * arguments - the arguments entered by the user for the command
      ## * db        - the connection to the shell's database
      ## * list      - the additional data for the command, like list of help
      ##               entries, etc
      ##
      ## Returns QuitSuccess if the selected command was successfully executed,
      ## otherwise QuitFailure.
      body:
        {.ruleOff: "ifStatements".}
        # No subcommand entered, show available options
        if arguments.len == 0:
          return showHelpList(command = "options",
              subcommands = optionsCommands)
        # Show the list of available options
        elif arguments == "list":
          return showOptions(db = db)
        elif arguments.startsWith(prefix = "set"):
          result = setOptions(arguments = arguments, db = db)
          return
        elif arguments.startsWith(prefix = "reset"):
          result = resetOptions(arguments = arguments, db = db)
          return
        {.ruleOn: "ifStatements".}
        try:
          return showUnknownHelp(subCommand = arguments,
              command = initLimitedString(capacity = 7, text = "options"),
              helpType = initLimitedString(capacity = 7, text = "options"))
        except CapacityError:
          return QuitFailure.ResultCode

    try:
      addCommand(name = initLimitedString(capacity = 7, text = "options"),
          command = optionsCommand, commands = commands)
    except CapacityError, CommandsListError:
      showError(message = "Can't add commands related to the shell's options. Reason: ",
          e = getCurrentException())
