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
import std/[os, osproc, strutils]
# External modules imports
import ansiparse, contracts, nancy, termstyle
import norm/[model, pragmas, sqlite]
# Internal imports
import commandslist, constants, help, lstring, output, resultcode, theme

const optionsCommands: seq[string] = @["list", "set", "reset"]
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
  db: DbConn # Connection to the shell's database
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
    try:
      parseEnum[ValueType](s = dbVal.s)
    except:
      none

proc getOption*(optionName; db; defaultValue: OptionValue = emptyLimitedString(
    capacity = maxInputLength)): OptionValue {.sideEffect, raises: [], tags: [
    ReadDbEffect, WriteIOEffect, ReadEnvEffect, TimeEffect, RootEffect],
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
    type LocalOption = ref object
      value: string
    try:
      if not db.exists(T = Option, cond = "option=?", params = $optionName):
        return defaultValue
      var option: LocalOption = LocalOption()
      db.rawSelect(qry = "SELECT value FROM options WHERE option=?",
          obj = option, params = $optionName)
      result = initLimitedString(capacity = (if option.value.len ==
          0: 1 else: option.value.len), text = option.value)
    except:
      showError(message = "Can't get value for option '" & optionName &
          "' from database. Reason: ", e = getCurrentException(), db = db)
      return defaultValue
    if result == "":
      result = defaultValue

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

proc setOption*(optionName; value: OptionValue = emptyLimitedString(
    capacity = maxInputLength); description: UserInput = emptyLimitedString(
    capacity = maxInputLength); valueType: ValueType = none; db;
    readOnly: BooleanInt = 0) {.sideEffect, raises: [], tags: [ReadDbEffect,
    WriteDbEffect, WriteIOEffect, ReadEnvEffect, TimeEffect, RootEffect],
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
    var option: Option = newOption(name = $optionName, readOnly = readOnly == 1)
    try:
      if db.exists(T = Option, cond = "option=?", params = $optionName):
        db.select(obj = option, cond = "option=?", params = $optionName)
    except:
      showError(message = "Can't check existence of the option '" & optionName &
          "'. Reason: ", e = getCurrentException(), db = db)
    if value != "":
      option.value = $value
    if description != "":
      option.description = $description
    if valueType != none:
      option.valueType = valueType
    try:
      if db.exists(T = Option, cond = "option=?", params = $optionName):
        db.update(obj = option)
      else:
        option.defaultValue = option.value
        db.insert(obj = option)
    except:
      showError(message = "Can't set value for option '" & optionName &
          "'. Reason: ", e = getCurrentException(), db = db)

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
          e = getCurrentException(), db = db)
    showFormHeader(message = "Available options are:", db = db)
    try:
      var options: seq[Option] = @[newOption()]
      db.rawSelect(qry = "SELECT * FROM options ORDER BY option ASC",
          objs = options)
      for option in options:
        table.add(parts = [yellow(ss = option.option), green(ss = option.value),
            option.defaultValue, $option.valueType, option.description])
    except:
      return showError(message = "Can't show the shell's options. Reason: ",
          e = getCurrentException(), db = db)
    try:
      table.echoTable
    except IOError, Exception:
      return showError(message = "Can't show the list of shell's options. Reason: ",
          e = getCurrentException(), db = db)
    return QuitSuccess.ResultCode

proc setOptions*(arguments; db): ResultCode {.sideEffect, raises: [], tags: [
    ReadIOEffect, WriteIOEffect, WriteDbEffect, ReadDbEffect, ReadEnvEffect,
    TimeEffect, RootEffect], contractual.} =
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
      return showError(message = "Please enter name of the option and its new value.", db = db)
    if setting.len < 3:
      return showError(message = "Please enter a new value for the selected option.", db = db)
    let optionName: OptionName = try:
        initLimitedString(capacity = setting[1].len, text = setting[1])
      except CapacityError:
        return showError(message = "Can't get the option's name from command: '" &
            arguments & "'.", db = db)
    let stringValue: string = setting[2 .. ^1].join(sep = " ")
    var value: OptionValue = try:
        initLimitedString(capacity = stringValue.len, text = stringValue)
      except CapacityError:
        return showError(message = "Can't get the option's value from command: '" &
            arguments & "'.", db = db)
    try:
      if not db.exists(T = Option, cond = "option=?", params = $optionName):
        return showError(message = "Shell's option with name '" & optionName &
          "' doesn't exists. Please use command 'options list' to see all available shell's options.", db = db)
      var option: Option = newOption(name = $optionName)
      db.select(obj = option, cond = "option=?", params = $optionName)
      if option.readOnly:
        return showError(message = "You can't set a new value for the selected option because it is read-only.", db = db)
      # Check correctness of the option's value
      case option.valueType
      of integer:
        try:
          discard ($value).parseInt
        except:
          return showError(message = "Value for option '" & optionName &
              "' should be integer type.", db = db)
      of float:
        try:
          discard ($value).parseFloat
        except:
          return showError(message = "Value for option '" & optionName & "' should be float type.", db = db)
      of boolean:
        try:
          value.text = ($value).toLowerAscii
        except CapacityError:
          return showError(message = "Can't set a new value for option '" &
              optionName & "'. Reason: ", e = getCurrentException(), db = db)
        if value != "true" and value != "false":
          return showError(message = "Value for option '" & optionName & "' should be true or false (case insensitive).", db = db)
      of historysort:
        try:
          value.text = ($value).toLowerAscii
        except CapacityError:
          return showError(message = "Can't set a new value for option '" &
              optionName & "'. Reason: ", e = getCurrentException(), db = db)
        if $value notin ["recent", "amount", "name", "recentamount"]:
          return showError(message = "Value for option '" & optionName & "' should be 'recent', 'amount', 'name' or 'recentamount' (case insensitive)", db = db)
      of natural:
        try:
          if ($value).parseInt < 0:
            return showError(message = "Value for option '" & optionName &
                "' should be a natural integer, zero or more.", db = db)
        except:
          return showError(message = "Value for option '" & optionName &
              "' should be integer type.", db = db)
      of text:
        discard
      of command:
        try:
          let (_, exitCode) = execCmdEx(command = $value)
          if exitCode != QuitSuccess:
            return showError(message = "Value for option '" & optionName & "' should be valid command.", db = db)
        except:
          return showError(message = "Can't check the existence of command '" &
              value & "'. Reason: ", e = getCurrentException(), db = db)
      of header:
        try:
          value.text = ($value).toLowerAscii
        except CapacityError:
          return showError(message = "Can't set a new value for option '" &
              optionName & "'. Reason: ", e = getCurrentException(), db = db)
        if $value notin ["unicode", "ascii", "none", "hidden"]:
          return showError(message = "Value for option '" & optionName & "' should be 'unicode', 'ascii', 'none' or 'hidden' (case insensitive)", db = db)
      of positive:
        try:
          if ($value).parseInt < 1:
            return showError(message = "Value for option '" & optionName &
                "' should be a positive integer, one or more.", db = db)
        except:
          return showError(message = "Value for option '" & optionName &
              "' should be integer type.", db = db)
      of none:
        return showError(message = "Shell's option with name '" & optionName &
          "' doesn't exists. Please use command 'options list' to see all available shell's options.", db = db)
      # Set the option
      setOption(optionName = optionName, value = value, db = db)
      showOutput(message = "Value for option '" & optionName &
          "' was set to '" & value & "'", color = success, db = db);
      return QuitSuccess.ResultCode
    except:
      return showError(message = "Can't set the value for the option '" &
          optionName & "'. Reason: ", e = getCurrentException(), db = db)

proc resetOptions*(arguments; db): ResultCode {.sideEffect, raises: [], tags: [
    ReadIOEffect, WriteIOEffect, WriteDbEffect, ReadDbEffect, ReadEnvEffect,
    TimeEffect, RootEffect], contractual.} =
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
      return showError(message = "Please enter name of the option to reset or 'all' to reset all options.", db = db)
    let optionName: OptionName = arguments[6 .. ^1]
    # Reset all options
    if optionName == "all":
      try:
        db.exec(query = sql(query = "UPDATE options SET value=defaultvalue WHERE readonly=0"))
        showOutput(message = "All shell's options are reseted to their default values.", db = db)
      except DbError:
        return showError(message = "Can't reset the shell's options to their default values. Reason: ",
            e = getCurrentException(), db = db)
    # Reset the selected option
    else:
      try:
        if not db.exists(T = Option, cond = "option=?", params = $optionName):
          return showError(message = "Shell's option with name '" & optionName &
            "' doesn't exists. Please use command 'options list' to see all available shell's options.", db = db)
        var option: Option = newOption(name = $optionName)
        db.select(obj = option, cond = "option=?", params = $optionName)
        if option.readOnly:
          return showError(message = "You can't reset option '" & optionName & "' because it is read-only option.", db = db)
        option.value = option.defaultValue
        db.update(obj = option)
        showOutput(message = "The shell's option '" & optionName &
            "' reseted to its default value.", color = success, db = db)
      except:
        return showError(message = "Can't reset option '" & optionName &
            "' to its default value. Reason: ", e = getCurrentException(), db = db)
    return QuitSuccess.ResultCode

proc updateOptionsDb*(db; dbVersion: Natural): ResultCode {.sideEffect,
    raises: [], tags: [WriteDbEffect, ReadDbEffect, WriteIOEffect, RootEffect],
    contractual.} =
  ## Update the table options to the new version if needed
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
      if dbVersion < 3:
        db.exec(query = sql(query = """ALTER TABLE options ADD readonly BOOLEAN DEFAULT 0"""))
      if dbVersion < 4:
        db.exec(query = sql(query = """ALTER TABLE options ADD id INTEGER NOT NULL DEFAULT 1"""))
        db.exec(query = sql(query = """UPDATE options SET id=rowid"""))
    except DbError:
      return showError(message = "Can't update table for the shell's options. Reason: ",
          e = getCurrentException(), db = db)
    return QuitSuccess.ResultCode

proc createOptionsDb*(db): ResultCode {.sideEffect, raises: [], tags: [
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
      db.createTables(obj = newOption())
    except:
      return showError(message = "Can't create 'options' table. Reason: ",
          e = getCurrentException(), db = db)
    return QuitSuccess.ResultCode

proc deleteOption*(optionName; db): ResultCode {.sideEffect, raises: [], tags: [
    WriteDbEffect, ReadDbEffect, WriteIOEffect, RootEffect], contractual.} =
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
      if not db.exists(T = Option, cond = "option=?", params = $optionName):
        return showError(message = "Can't delete the selected option '" &
            optionName & "' because there is no that option.", db = db)
      var option: Option = newOption(name = $optionName)
      db.select(obj = option, cond = "option=?", params = $optionName)
      db.delete(obj = option)
    except:
      return showError(message = "Can't delete the selected option. Reason: ",
          e = getCurrentException(), db = db)
    return QuitSuccess.ResultCode

proc initOptions*(commands: ref CommandsList; db) {.sideEffect,
    raises: [], tags: [WriteDbEffect, WriteIOEffect, ReadDbEffect, ReadIOEffect,
    ReadEnvEffect, TimeEffect, RootEffect], contractual.} =
  ## Initialize the shell's options. At this moment only set the shell's commands
  ## related to the shell's options
  ##
  ## * commands - the list of the shell's commands
  ## * db       - the connection to the shell's database
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
        # No subcommand entered, show available options
        if arguments.len == 0:
          return showHelpList(command = "options",
              subcommands = optionsCommands, db = db)
        # Show the list of available options
        if arguments == "list":
          return showOptions(db = db)
        if arguments.startsWith(prefix = "set"):
          result = setOptions(arguments = arguments, db = db)
          return
        if arguments.startsWith(prefix = "reset"):
          result = resetOptions(arguments = arguments, db = db)
          return
        try:
          return showUnknownHelp(subCommand = arguments,
              command = initLimitedString(capacity = 7, text = "options"),
              helpType = initLimitedString(capacity = 7, text = "options"), db = db)
        except CapacityError:
          return QuitFailure.ResultCode

    try:
      addCommand(name = initLimitedString(capacity = 7, text = "options"),
          command = optionsCommand, commands = commands,
          subCommands = optionsCommands)
    except CapacityError, CommandsListError:
      showError(message = "Can't add commands related to the shell's options. Reason: ",
          e = getCurrentException(), db = db)
