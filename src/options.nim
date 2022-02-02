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

import std/[db_sqlite, parseopt, strutils]
import output

func getOption*(name: string; db: DbConn;
    defaultValue: string = ""): string {.gcsafe, locks: 0, raises: [DbError],
    tags: [ReadDbEffect].} =
  ## Get the selected option from the database. If the option doesn't exist,
  ## return the defaultValue
  result = db.getValue(sql"SELECT value FROM options WHERE option=?", name)
  if result == "":
    result = defaultValue

func setOption*(name: string; value, description, valuetype: string = "";
    db: DbConn) {.gcsafe, locks: 0, raises: [DbError], tags: [ReadDbEffect,
    WriteDbEffect].} =
  ## Set the value and or description of the selected option. If the option
  ## doesn't exist, insert it to the database
  let sqlQuery = "UPDATE options SET " & (if value != "": "value='" & value &
      "'" else: "") & (if value != "" and description != "" and valuetype !=
          "": ", " else: " ") & (if description != "": "description='" &
              description & "' " else: "") & (if valuetype !=
      "": "valuetype='" & valuetype &
      "' " else: "") & "WHERE option='" & name & "'"
  if db.execAffectedRows(sql(sqlQuery)) == 0:
    db.exec(sql"INSERT INTO options (option, value, description, valuetype) VALUES (?, ?, ?)",
        name, value, description, valuetype)

proc showOptions*(db: DbConn) {.gcsafe, sideEffect, locks: 0, raises: [
    DbError, IOError, OSError, ValueError], tags: [ReadDbEffect, WriteDbEffect,
    ReadIOEffect, WriteIOEffect].} =
  ## Show the shell's options
  showOutput("Name Value Type Description")
  for row in db.fastRows(sql"SELECT option, value, valuetype, description FROM options"):
    showOutput(row[0] & " " & row[1] & " " & row[2] & " " & row[3])

proc helpOptions*(db: DbConn) {.gcsafe, sideEffect, locks: 0, raises: [
    OSError, IOError, ValueError], tags: [ReadIOEffect, WriteIOEffect].} =
  ## Show short help about available subcommands related to the shell's
  ## options
  showOutput("""Available subcommands are: show

        To see more information about the subcommand, type help options [command],
        for example: help options show.
""")

proc setOptions*(userInput: var OptParser; db: DbConn): int =
  ## Set the selected option's value
  userInput.next()
  if userInput.kind == cmdEnd:
    return showError("Please enter name of the option and its new value.")
  let
    name = userInput.key
    value = join(userInput.remainingArgs(), " ")
  if value.len() == 0:
    return showError("Please enter a new value for the selected option.")
  case db.getValue(sql"SELECT valuetype FROM options WHERE option=?", name)
  of "integer":
    try:
      discard parseInt(value)
    except:
      return showError("Value for option '" & name &
          "' should be integer type.");
  of "float":
    try:
      discard parseFloat(value)
    except:
      return showError("Value for option '" & name & "' should be float type.");
  of "":
    return showError("Shell's option with name '" & name &
      "' doesn't exists. Please use command 'options show' to see all available shell's options.")
  setOption(name = name, value = value, db = db)
  showOutput("Value for option '" & name & "' was set to '" & value & "'");
  return QuitSuccess

