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

import std/[db_sqlite, os, parseopt, strutils, tables]
import history, output

func setAliases*(aliases: var OrderedTable[string, int]; directory: string;
    db: DbConn) {.gcsafe, raises: [ValueError, DbError], tags: [
    ReadDbEffect].} =
  ## Set the available aliases in the selected directory
  aliases.clear()
  var
    dbQuery: string = "SELECT id, name FROM aliases WHERE path='" & directory & "'"
    remainingDirectory: string = parentDir(directory)

  # Construct SQL querry, search for aliases also defined in parent directories
  # if they are recursive
  while remainingDirectory != "":
    dbQuery.add(" OR (path='" & remainingDirectory & "' AND recursive=1)")
    remainingDirectory = parentDir(remainingDirectory)

  dbQuery.add(" ORDER BY id ASC")
  for dbResult in db.fastRows(sql(dbQuery)):
    aliases[dbResult[1]] = parseInt(dbResult[0])

proc listAliases*(userInput: var OptParser; historyIndex: var int;
    aliases: OrderedTable[string, int]; db: DbConn) {.gcsafe, sideEffect,
        locks: 0, raises: [IOError, OSError, ValueError], tags: [ReadIOEffect,
        WriteIOEffect, ReadDbEffect, WriteDbEffect].} =
  ## List available aliases, if entered command was "alias list all" list all
  ## declared aliases then
  showOutput("Available aliases are:", true, false, "", QuitSuccess)
  showOutput("ID Name Description", true, false, "",
    QuitSuccess)
  userInput.next()
  if userInput.kind == cmdEnd:
    historyIndex = updateHistory("alias list", db)
    for alias in aliases.values:
      let row = db.getRow(sql"SELECT id, name, description FROM aliases WHERE id=?",
        alias)
      showOutput(row[0] & " " & row[1] & " " & row[2], true, false, "",
        QuitSuccess)
  elif userInput.key == "all":
    historyIndex = updateHistory("alias list all", db)
    for row in db.fastRows(sql"SELECT id, name, description FROM aliases"):
      showOutput(row[0] & " " & row[1] & " " & row[2], true, false, "",
        QuitSuccess)

