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

# Standard library imports
import std/[db_sqlite, os, osproc, strutils, terminal]
# External modules imports
import contracts
# Internal imports
import columnamount, commandslist, constants, help, input, lstring, output, resultcode

const optionsCommands* = ["list", "set", "reset"]
  ## FUNCTION
  ##
  ## The list of available subcommands for command options

type
  OptionName* = LimitedString
    ## FUNCTION
    ##
    ## Used to store options names in the database.
  OptionValue* = LimitedString
    ## FUNCTION
    ##
    ## Used to set or get the option's values
  ValueType* = enum
    ## FUNCTION
    ##
    ## Used to set the type of option's value
    integer, float, boolean, none, historysort, natural, text, command

using
  db: DbConn # Connection to the shell's database
  optionName: OptionName # The name of option to get or set
  arguments: UserInput # The user entered agruments for set or reset option

proc getOption*(optionName; db; defaultValue: OptionValue = emptyLimitedString(
    capacity = maxInputLength)): OptionValue {.gcsafe, sideEffect, raises: [],
    tags: [ReadDbEffect, WriteIOEffect, ReadEnvEffect, TimeEffect], locks: 0,
    contractual.} =
  ## FUNCTION
  ##
  ## Get the selected option from the database. If the option doesn't exist,
  ## return the defaultValue
  ##
  ## PARAMETERS
  ##
  ## * optionName   - the name of the option which value will be get
  ## * db           - the connection to the shell's database
  ## * defaultValue - the default value for option if the is no that option in
  ##                  the database. Default value is empty string ""
  ##
  ## RETURNS
  ##
  ## The value of the selected option or empty string if there is no that
  ## option in the database.
  require:
    optionName.len() > 0
    db != nil
  body:
    try:
      let value = db.getValue(query = sql(
          query = "SELECT value FROM options WHERE option=?"), optionName)
      result = initLimitedString(capacity = (if value.len() ==
          0: 1 else: value.len()), text = value)
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
    ReadDbEffect, WriteDbEffect, WriteIOEffect, ReadEnvEffect, TimeEffect],
    locks: 0, contractual.} =
  ## FUNCTIONS
  ##
  ## Set the value and or description of the selected option. If the option
  ## doesn't exist, insert it to the database
  ##
  ## PARAMETERS
  ##
  ## * optionName  - the name of the option which will be set
  ## * value       - the value of the option to set
  ## * description - the description of the option to set
  ## * valuetype   - the type of the option to set
  ## * db          - the connection to the shell's database
  require:
    optionName.len() > 0
    db != nil
  body:
    var sqlQuery: string = "UPDATE options SET "
    if value != "":
      sqlQuery.add(y = "value='" & value & "'")
    if description != "":
      if sqlQuery.len() > 21:
        sqlQuery.add(y = ", ")
      sqlQuery.add(y = "description='" & description & "'")
    if valueType != none:
      if sqlQuery.len() > 21:
        sqlQuery.add(y = ", ")
      sqlQuery.add(y = "valuetype='" & $valueType & "'")
    sqlQuery.add(y = " WHERE option='" & optionName & "'")
    try:
      if db.execAffectedRows(query = sql(query = sqlQuery)) == 0:
        db.exec(query = sql(query = "INSERT INTO options (option, value, description, valuetype, defaultvalue, readonly) VALUES (?, ?, ?, ?, ?, ?)"),
            optionName, value, description, valueType, value, readOnly)
    except DbError:
      showError(message = "Can't set value for option '" & optionName &
          "'. Reason: ", e = getCurrentException())

proc showOptions*(db): ResultCode {.gcsafe, sideEffect, raises: [], tags: [
    ReadDbEffect, WriteDbEffect, ReadIOEffect, WriteIOEffect, ReadEnvEffect,
    TimeEffect], locks: 0, contractual.} =
  ## FUNCTION
  ##
  ## Show the shell's options
  ##
  ## PARAMETERS
  ##
  ## * db - the connection to the shell's database
  require:
    db != nil
  body:
    let spacesAmount: ColumnAmount = 2.ColumnAmount
    showFormHeader(message = "Available options are:", spaces = spacesAmount)
    showOutput(message = indent(s = "Name               Value        Default      Type        Description",
        count = spacesAmount.int), fgColor = fgMagenta)
    try:
      for row in db.fastRows(query = sql(
          query = "SELECT option, value, defaultvalue, valuetype, description FROM options")):
        showOutput(message = indent(s = alignLeft(s = row[0], count = 18) &
            " " & alignLeft(s = row[1], count = 12) & " " & alignLeft(s = row[
                2], count = 12) & " " & alignLeft(s = row[3], count = 11) &
                    " " & row[4], count = spacesAmount.int))
    except DbError:
      return showError(message = "Can't show the shell's options. Reason: ",
          e = getCurrentException())
    return QuitSuccess.ResultCode

proc setOptions*(arguments; db): ResultCode {.gcsafe, sideEffect, raises: [],
    tags: [ReadIOEffect, WriteIOEffect, WriteDbEffect, ReadDbEffect,
    ReadEnvEffect, TimeEffect, RootEffect], contractual.} =
  ## FUNCTION
  ##
  ## Set the selected option's value
  ##
  ## PARAMETERS
  ##
  ## * arguments - the user entered text with arguments for the variable, its
  ##               name and a new value
  ## * db        - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## QuitSuccess if the variable was correctly set, otherwise QuitFailure.
  require:
    arguments.len() > 0
    db != nil
  body:
    if arguments.len() < 5:
      return showError(message = "Please enter name of the option and its new value.")
    let separatorIndex: ExtendedNatural = arguments.find(sub = ' ', start = 4)
    if separatorIndex == -1:
      return showError(message = "Please enter a new value for the selected option.")
    let optionName: OptionName = arguments[4 .. (separatorIndex - 1)]
    try:
      if db.getValue(query = sql(query = "SELECT readonly FROM options WHERE option=?"),
          optionName) == "1":
        return showError(message = "You can't set a new value for the selected option because it is read-only.")
    except DbError:
      return showError(message = "Can't check if the selected option is read only. Reason: ",
          e = getCurrentException())
    var value: OptionValue = arguments[(separatorIndex + 1) .. ^1]
    try:
      case db.getValue(query = sql(query = "SELECT valuetype FROM options WHERE option=?"), optionName)
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
          value.setString(text = toLowerAscii(s = $value))
        except CapacityError:
          return showError(message = "Can't set a new value for option '" &
              optionName & "'. Reason: ", e = getCurrentException())
        if value != "true" and value != "false":
          return showError(message = "Value for option '" & optionName & "' should be true or false (case insensitive).")
      of "historysort":
        try:
          value.setString(text = toLowerAscii(s = $value))
        except CapacityError:
          return showError(message = "Can't set a new value for option '" &
              optionName & "'. Reason: ", e = getCurrentException())
        if $value notin ["recent", "amount", "name", "recentamount"]:
          return showError(message = "Value for option '" & optionName & "' should be 'recent', 'amount', 'name' or 'recentamount' (case insensitive)")
      of "natural":
        try:
          if parseInt(s = $value) < 0:
            return showError(message = "Value for option '" & optionName &
                "' should be integer type and greater than zero.")
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
      of "":
        return showError(message = "Shell's option with name '" & optionName &
          "' doesn't exists. Please use command 'options list' to see all available shell's options.")
    except DbError:
      return showError(message = "Can't get type of value for option '" &
          optionName & "'. Reason: ", e = getCurrentException())
    setOption(optionName = optionName, value = value, db = db)
    showOutput(message = "Value for option '" & optionName & "' was set to '" &
        value & "'", fgColor = fgGreen);
    return QuitSuccess.ResultCode

proc resetOptions*(arguments; db): ResultCode {.gcsafe, sideEffect, raises: [],
    tags: [ReadIOEffect, WriteIOEffect, WriteDbEffect, ReadDbEffect,
    ReadEnvEffect, TimeEffect], locks: 0, contractual.} =
  ## FUNCTION
  ##
  ## Reset the selected option's value to default value. If name of the option
  ## is set to "all", reset all options to their default values
  ##
  ## PARAMETERS
  ##
  ## * arguments - the user entered text with arguments for the variable, its
  ##               name or all
  ## * db        - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## QuitSuccess if the variable(s) correctly reseted, otherwise QuitFailure.
  require:
    arguments.len() > 0
    db != nil
  body:
    if arguments.len() < 7:
      return showError("Please enter name of the option to reset or 'all' to reset all options.")
    let optionName: OptionName = arguments[6 .. ^1]
    if optionName == "all":
      try:
        db.exec(query = sql(query = "UPDATE options SET value=defaultvalue WHERE readonly=0"))
        showOutput(message = "All shell's options are reseted to their default values.")
      except DbError:
        return showError(message = "Can't reset the shell's options to their default values. Reason: ",
            e = getCurrentException())
    else:
      try:
        if db.getValue(query = sql(query = "SELECT readonly FROM options WHERE option=?"),
            optionName) == "1":
          return showError(message = "You can't reset option '" & optionName & "' because it is read-only option.")
        if db.getValue(query = sql(query = "SELECT value FROM options WHERE option=?"),
            optionName) == "":
          return showError(message = "Shell's option with name '" & optionName &
            "' doesn't exists. Please use command 'options list' to see all available shell's options.")
      except DbError:
        return showError(message = "Can't get value for option '" & optionName &
            "'. Reason: ", e = getCurrentException())
      try:
        db.exec(query = sql(query = "UPDATE options SET value=defaultvalue WHERE option=?"), optionName)
        showOutput(message = "The shell's option '" & optionName &
            "' reseted to its default value.", fgColor = fgGreen)
      except DbError:
        return showError(message = "Can't reset option '" & optionName &
            "' to its default value. Reason: ", e = getCurrentException())
    return QuitSuccess.ResultCode

proc updateOptionsDb*(db): ResultCode {.gcsafe, sideEffect, raises: [], tags: [
    WriteDbEffect, ReadDbEffect, WriteIOEffect], locks: 0, contractual.} =
  ## FUNCTION
  ##
  ## Update the table options to the new version if needed
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
      db.exec(query = sql(query = """ALTER TABLE options ADD readonly BOOLEAN DEFAULT 0"""))
    except DbError:
      return showError(message = "Can't update table for the shell's options. Reason: ",
          e = getCurrentException())
    return QuitSuccess.ResultCode

proc createOptionsDb*(db): ResultCode {.gcsafe, sideEffect, raises: [], tags: [
    WriteDbEffect, ReadDbEffect, WriteIOEffect], locks: 0, contractual.} =
  ## FUNCTION
  ##
  ## Create the table options
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
      db.exec(query = sql(query = """CREATE TABLE options (
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
    tags: [WriteDbEffect, ReadDbEffect, WriteIOEffect], locks: 0,
    contractual.} =
  ## FUNCTION
  ##
  ## Delete the selected option from the table
  ##
  ## PARAMETERS
  ##
  ## * optionName - the name of the option which will be deleted
  ## * db         - the connection to the shell's database
  ##
  ## RETURNS
  ##
  ## QuitSuccess if deletion was successfull, otherwise QuitFailure and
  ## show message what wrong
  require:
    optionName.len() > 0
    db != nil
  body:
    try:
      if db.execAffectedRows(query = sql(
          query = "DELETE FROM options WHERE option=?"), optionName) == 0:
        return QuitFailure.ResultCode
    except DbError:
      return showError(message = "Can't delete the selected option. Reason: ",
          e = getCurrentException())
    return QuitSuccess.ResultCode

proc initOptions*(commands: ref CommandsList) {.gcsafe, sideEffect, locks: 0,
    raises: [], tags: [WriteDbEffect, WriteIOEffect, ReadDbEffect, ReadIOEffect,
    ReadEnvEffect, TimeEffect, RootEffect], contractual.} =
  ## FUNCTION
  ##
  ## Initialize the shell's options. At this moment only set help related to
  ## the options
  ##
  ## PARAMETERS
  ##
  ## * helpContent - the HelpTable with help content of the shell
  ## * commands    - the list of the shell's commands
  body:
    # Add commands related to the shell's options
    proc optionsCommand(arguments: UserInput; db: DbConn;
        list: CommandLists): ResultCode {.gcsafe, raises: [], contractual.} =
      ## FUNCTION
      ##
      ## The code of the shell's command "options" and its subcommands
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
        if arguments.len() == 0:
          return showHelpList(command = "options",
              subcommands = optionsCommands)
        # Show the list of available options
        elif arguments == "list":
          return showOptions(db = db)
        elif arguments.startsWith(prefix = "set"):
          result = setOptions(arguments = arguments, db = db)
          updateHelp(helpContent = list.help, db = db)
          return
        elif arguments.startsWith(prefix = "reset"):
          result = resetOptions(arguments = arguments, db = db)
          updateHelp(helpContent = list.help, db = db)
          return
        else:
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
