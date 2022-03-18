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
import constants, output

proc getOption*(name: string; db: DbConn;
    defaultValue: string = ""): string {.gcsafe, sideEffect, raises: [], tags: [
        ReadDbEffect, WriteIOEffect, ReadEnvEffect, TimeEffect].} =
  ## Get the selected option from the database. If the option doesn't exist,
  ## return the defaultValue
  try:
    result = db.getValue(sql"SELECT value FROM options WHERE option=?", name)
  except DbError as e:
    discard showError("Can't get value for option '" & name &
        "' from database. Reason: " & e.msg)
    result = defaultValue
  if result == "":
    result = defaultValue

proc setOption*(name: string; value, description, valuetype: string = "";
    db: DbConn) {.gcsafe, sideEffect, raises: [], tags: [ReadDbEffect,
    WriteDbEffect, WriteIOEffect, ReadEnvEffect, TimeEffect].} =
  ## Set the value and or description of the selected option. If the option
  ## doesn't exist, insert it to the database
  var sqlQuery: string = "UPDATE options SET "
  if value != "":
    sqlQuery.add("value='" & value & "'")
  if description != "":
    if sqlQuery.len() > 21:
      sqlQuery.add(", ")
    sqlQuery.add("description='" & description & "'")
  if valuetype != "":
    if sqlQuery.len() > 21:
      sqlQuery.add(", ")
    sqlQuery.add("valuetype='" & valuetype & "'")
  sqlQuery.add(" WHERE option='" & name & "'")
  try:
    if db.execAffectedRows(sql(sqlQuery)) == 0:
      db.exec(sql"INSERT INTO options (option, value, description, valuetype, defaultvalue) VALUES (?, ?, ?, ?, ?)",
          name, value, description, valuetype, value)
  except DbError as e:
    discard showError("Can't set value for option '" & name & "'. Reason: " & e.msg)

proc showOptions*(db: DbConn) {.gcsafe, sideEffect, locks: 0, raises: [
    DbError, ValueError], tags: [ReadDbEffect, WriteDbEffect, ReadIOEffect,
        WriteIOEffect].} =
  ## Show the shell's options
  let spacesAmount: Natural = (terminalWidth() / 12).int
  showFormHeader("Available options are:")
  showOutput(message = indent("Name               Value   Default Type    Description",
      spacesAmount), fgColor = fgMagenta)
  for row in db.fastRows(sql"SELECT option, value, defaultvalue, valuetype, description FROM options"):
    showOutput(indent(alignLeft(row[0], 18) & " " & alignLeft(row[1], 7) & " " &
        alignLeft(row[2], 7) & " " & alignLeft(row[3], 7) & " " & row[4], spacesAmount))

proc helpOptions*(db: DbConn) {.gcsafe, sideEffect, locks: 0, raises: [],
    tags: [ReadIOEffect, WriteIOEffect].} =
  ## Show short help about available subcommands related to the shell's
  ## options
  showOutput("""Available subcommands are: show, set, reset

        To see more information about the subcommand, type help options [command],
        for example: help options show.
""")

proc setOptions*(arguments: string; db: DbConn): int {.gcsafe,
    sideEffect, raises: [DbError], tags: [ReadIOEffect, WriteIOEffect,
        WriteDbEffect, ReadDbEffect, ReadEnvEffect, TimeEffect].} =
  ## Set the selected option's value
  if arguments.len() < 5:
    return showError("Please enter name of the option and its new value.")
  let separatorIndex = arguments.find(' ', 4)
  if separatorIndex == -1:
    return showError("Please enter a new value for the selected option.")
  let name = arguments[4 .. (separatorIndex - 1)]
  var value = arguments[(separatorIndex + 1) .. ^1]
  case db.getValue(sql"SELECT valuetype FROM options WHERE option=?", name)
  of "integer":
    try:
      discard parseInt(value)
    except:
      return showError("Value for option '" & name &
          "' should be integer type.")
  of "float":
    try:
      discard parseFloat(value)
    except:
      return showError("Value for option '" & name & "' should be float type.")
  of "boolean":
    value = toLowerAscii(value)
    if value != "true" and value != "false":
      return showError("Value for option '" & name & "' should be true or false (case insensitive).")
  of "":
    return showError("Shell's option with name '" & name &
      "' doesn't exists. Please use command 'options show' to see all available shell's options.")
  setOption(name = name, value = value, db = db)
  showOutput(message = "Value for option '" & name & "' was set to '" & value &
      "'", fgColor = fgGreen);
  return QuitSuccess

proc resetOptions*(arguments: string; db: DbConn): int {.gcsafe,
    sideEffect, raises: [DbError], tags: [ReadIOEffect, WriteIOEffect,
        WriteDbEffect, ReadDbEffect, ReadEnvEffect, TimeEffect].} =
  ## Reset the selected option's value to default value. If name of the option
  ## is set to "all", reset all options to their default values
  if arguments.len() < 7:
    return showError("Please enter name of the option to reset or 'all' to reset all options.")
  let name: string = arguments[6 .. ^1]
  if name == "all":
    db.exec(sql"UPDATE options SET value=defaultvalue")
    showOutput("All shell's options are reseted to their default values.")
  else:
    if db.getValue(sql"SELECT value FROM options WHERE option=?",
        name) == "":
      return showError("Shell's option with name '" & name &
        "' doesn't exists. Please use command 'options show' to see all available shell's options.")
    db.exec(sql"UPDATE options SET value=defaultvalue WHERE option=?", name)
    showOutput(message = "The shell's option '" & name &
        "' reseted to its default value.", fgColor = fgGreen)
  return QuitSuccess

func initOptions*(helpContent: var HelpTable) {.gcsafe, locks: 0,
    raises: [], tags: [].} =
  ## Initialize the shell's options. At this moment only set help related to
  ## the options
  helpContent["options"] = HelpEntry(usage: "options ?subcommand?",
      content: "If entered without subcommand, show the list of available subcommands for options. Otherwise, execute the selected subcommand.")
  helpContent["options show"] = HelpEntry(usage: "options show",
      content: "Show the list of all available shell's options with detailed information about them.")
  helpContent["options set"] = HelpEntry(usage: "options set [name] [value]",
      content: "Set the selected shell's option with name to the selected value. The value can't contain new line character.")
  helpContent["options reset"] = HelpEntry(usage: "options reset [name or all]",
      content: "Reset the selected shell's option with name to the default value. If the name parameter is set to 'all', reset all shell's options to their default values.")
