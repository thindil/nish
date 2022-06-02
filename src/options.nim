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
import constants, input, lstring, output

type
  OptionName* = LimitedString # Used to store options names in the database.
  OptionValue* = LimitedString # Used to set or get the option's values
  ValueType* = enum # Used to set the type of option's value
    integer, float, boolean, none

using
  db: DbConn # Connection to the shell's database
  optionName: OptionName # The name of option to get or set
  arguments: UserInput # The user entered agruments for set or reset option

proc getOption*(optionName; db; defaultValue: OptionValue = emptyLimitedString(
    capacity = maxInputLength)): OptionValue {.gcsafe, sideEffect, raises: [],
        tags: [ReadDbEffect, WriteIOEffect, ReadEnvEffect,
    TimeEffect].} =
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
  try:
    let value = db.getValue(query = sql(
        query = "SELECT value FROM options WHERE option=?"), optionName)
    result = initLimitedString(capacity = (if value.len() ==
        0: 1 else: value.len()), text = value)
  except DbError, CapacityError:
    discard showError(message = "Can't get value for option '" & optionName &
        "' from database. Reason: " & getCurrentExceptionMsg())
    result = defaultValue
  if result == "":
    result = defaultValue

proc setOption*(optionName; value: OptionValue = emptyLimitedString(
    capacity = maxInputLength); description: UserInput = emptyLimitedString(
        capacity = maxInputLength); valuetype: ValueType = none; db) {.gcsafe,
            sideEffect, raises: [], tags: [ReadDbEffect,

WriteDbEffect, WriteIOEffect, ReadEnvEffect, TimeEffect].} =
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
  var sqlQuery: string = "UPDATE options SET "
  if value != "":
    sqlQuery.add(y = "value='" & value & "'")
  if description != "":
    if sqlQuery.len() > 21:
      sqlQuery.add(y = ", ")
    sqlQuery.add(y = "description='" & description & "'")
  if valuetype != none:
    if sqlQuery.len() > 21:
      sqlQuery.add(y = ", ")
    sqlQuery.add(y = "valuetype='" & $valuetype & "'")
  sqlQuery.add(y = " WHERE option='" & optionName & "'")
  try:
    if db.execAffectedRows(query = sql(query = sqlQuery)) == 0:
      db.exec(query = sql(query = "INSERT INTO options (option, value, description, valuetype, defaultvalue) VALUES (?, ?, ?, ?, ?)"),
          optionName, value, description, valuetype, value)
  except DbError as e:
    discard showError(message = "Can't set value for option '" & optionName &
        "'. Reason: " & e.msg)

proc showOptions*(db) {.gcsafe, sideEffect, raises: [],
    tags: [ReadDbEffect, WriteDbEffect, ReadIOEffect, WriteIOEffect,
    ReadEnvEffect, TimeEffect].} =
  ## FUNCTION
  ##
  ## Show the shell's options
  ##
  ## PARAMETERS
  ##
  ## * db - the connection to the shell's database
  let spacesAmount: ColumnAmount = try:
      ColumnAmount(terminalWidth()) / 12
    except ValueError:
      ColumnAmount(4)
  showFormHeader(message = "Available options are:")
  showOutput(message = indent(s = "Name               Value   Default Type    Description",
      count = int(spacesAmount)), fgColor = fgMagenta)
  try:
    for row in db.fastRows(query = sql(query = "SELECT option, value, defaultvalue, valuetype, description FROM options")):
      showOutput(message = indent(s = alignLeft(s = row[0], count = 18) & " " &
          alignLeft(s = row[1], count = 7) & " " & alignLeft(s = row[2],
              count = 7) & " " & alignLeft(s = row[3], count = 7) & " " & row[
                  4], count = int(spacesAmount)))
  except DbError as e:
    discard showError(message = "Can't show the shell's options. Reason: " & e.msg)

proc helpOptions*(db) {.gcsafe, sideEffect, locks: 0, raises: [],
    tags: [ReadIOEffect, WriteIOEffect].} =
  ## FUNCTION
  ##
  ## Show short help about available subcommands related to the shell's
  ## options
  ##
  ## PARAMETERS
  ##
  ## * db - the connection to the shell's database
  showOutput(message = """Available subcommands are: show, set, reset

        To see more information about the subcommand, type help options [command],
        for example: help options show.
""")

proc setOptions*(arguments; db): ResultCode {.gcsafe, sideEffect, raises: [],
    tags: [ReadIOEffect, WriteIOEffect, WriteDbEffect, ReadDbEffect,
        ReadEnvEffect, TimeEffect].} =
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
  if arguments.len() < 5:
    return showError(message = "Please enter name of the option and its new value.")
  let separatorIndex: ExtendedNatural = arguments.find(sub = ' ', start = 4)
  if separatorIndex == -1:
    return showError(message = "Please enter a new value for the selected option.")
  let optionName: OptionName = arguments[4 .. (separatorIndex - 1)]
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
        return showError(message = "Value for option '" & optionName & "' should be true or false (case insensitive).")
      if value != "true" and value != "false":
        return showError(message = "Value for option '" & optionName & "' should be true or false (case insensitive).")
    of "":
      return showError(message = "Shell's option with name '" & optionName &
        "' doesn't exists. Please use command 'options show' to see all available shell's options.")
  except DbError as e:
    return showError(message = "Can't get type of value for option '" &
        optionName & "'. Reason: " & e.msg)
  setOption(optionName = optionName, value = value, db = db)
  showOutput(message = "Value for option '" & optionName & "' was set to '" &
      value & "'", fgColor = fgGreen);
  return ResultCode(QuitSuccess)

proc resetOptions*(arguments; db): ResultCode {.gcsafe, sideEffect, raises: [],
    tags: [ReadIOEffect, WriteIOEffect, WriteDbEffect, ReadDbEffect,
        ReadEnvEffect, TimeEffect].} =
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
  if arguments.len() < 7:
    return showError("Please enter name of the option to reset or 'all' to reset all options.")
  let optionName: OptionName = arguments[6 .. ^1]
  if optionName == "all":
    try:
      db.exec(query = sql(query = "UPDATE options SET value=defaultvalue"))
      showOutput(message = "All shell's options are reseted to their default values.")
    except DbError as e:
      return showError(message = "Can't reset the shell's options to their default values. Reason: " & e.msg)
  else:
    try:
      if db.getValue(query = sql(query = "SELECT value FROM options WHERE option=?"),
          optionName) == "":
        return showError(message = "Shell's option with name '" & optionName &
          "' doesn't exists. Please use command 'options show' to see all available shell's options.")
    except DbError as e:
      return showError(message = "Can't get value for option '" & optionName &
          "'. Reason: " & e.msg)
    try:
      db.exec(query = sql(query = "UPDATE options SET value=defaultvalue WHERE option=?"), optionName)
      showOutput(message = "The shell's option '" & optionName &
          "' reseted to its default value.", fgColor = fgGreen)
    except DbError as e:
      return showError(message = "Can't reset option '" & optionName &
          "' to its default value. Reason: " & e.msg)
  return ResultCode(QuitSuccess)

func initOptions*(helpContent: var HelpTable) {.gcsafe, locks: 0,
    raises: [], tags: [].} =
  ## FUNCTION
  ##
  ## Initialize the shell's options. At this moment only set help related to
  ## the options
  ##
  ## PARAMETERS
  ##
  ## * helpContent - the HelpTable with help content of the shell
  helpContent["options"] = HelpEntry(usage: "options ?subcommand?",
      content: "If entered without subcommand, show the list of available subcommands for options. Otherwise, execute the selected subcommand.")
  helpContent["options show"] = HelpEntry(usage: "options show",
      content: "Show the list of all available shell's options with detailed information about them.")
  helpContent["options set"] = HelpEntry(usage: "options set [name] [value]",
      content: "Set the selected shell's option with name to the selected value. The value can't contain new line character.")
  helpContent["options reset"] = HelpEntry(usage: "options reset [name or all]",
      content: "Reset the selected shell's option with name to the default value. If the name parameter is set to 'all', reset all shell's options to their default values.")
