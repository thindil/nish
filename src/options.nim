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

import std/db_sqlite
import output

func getOption*(name: string; db: DbConn;
    defaultValue: string = ""): string {.gcsafe, locks: 0, raises: [DbError],
    tags: [ReadDbEffect].} =
  ## Get the selected option from the database. If the option doesn't exist,
  ## return the defaultValue
  result = db.getValue(sql"SELECT value FROM options WHERE option=?", name)
  if result == "":
    result = defaultValue

func setOption*(name: string; value, description: string = "";
    db: DbConn) {.gcsafe, locks: 0, raises: [DbError], tags: [ReadDbEffect,
    WriteDbEffect].} =
  ## Set the value and or description of the selected option. If the option
  ## doesn't exist, insert it to the database
  let sqlQuery = "UPDATE options SET " & (if value != "": "value='" & value &
      "'" else: "") & (if value != "" and description != "": ", " else: " ") & (
      if description != "": "description='" & description &
      "' " else: "") & "WHERE option='" & name & "'"
  if db.execAffectedRows(sql(sqlQuery)) == 0:
    db.exec(sql"INSERT INTO options (option, value, description) VALUES (?, ?, ?)",
        name, value, description)

proc showOptions*(db: DbConn) {.gcsafe, sideEffect, locks: 0, raises: [
    DbError, IOError, OSError, ValueError], tags: [ReadDbEffect, WriteDbEffect,
    ReadIOEffect, WriteIOEffect].} =
  ## Show the shell's options
  showOutput("Name Value Description")
  for row in db.fastRows(sql"SELECT option, value, description FROM options"):
    showOutput(row[0] & " " & row[1] & " " & row[2])
