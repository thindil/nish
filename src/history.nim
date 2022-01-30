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

import std/[db_sqlite, strutils]
import constants, options, output

proc initHistory*(db: DbConn): int =
  ## Initialize shell's commands history. Create history table if not exists,
  ## set the current historyIndex and options related to the history
  if getOption("historyLength", db) == "":
    setOption("historyLength", "500", "Max amount of entries in shell commands history.", db)
  db.exec(sql("""CREATE TABLE IF NOT EXISTS history (
               command     VARCHAR(""" & $maxInputLength &
      """) PRIMARY KEY,
               lastused    DATETIME NOT NULL DEFAULT 'datetime(''now'')',
               amount      INTEGER NOT NULL DEFAULT 1
            )"""))
  return parseInt(db.getValue(sql"SELECT COUNT(*) FROM history"))

func historyLength*(db: DbConn): int {.gcsafe, locks: 0, raises: [ValueError,
    DbError], tags: [ReadDbEffect].} =
  ## Get the current length of the shell's commmand's history
  return parseInt(db.getValue(sql"SELECT COUNT(*) FROM history"))

func updateHistory*(commandToAdd: string; db: DbConn): int {.gcsafe, raises: [
    ValueError, DbError], tags: [ReadDbEffect, WriteDbEffect].} =
  ## Add the selected command to the shell history and increase the current
  ## history index. If there is the command in the shell's history, only update
  ## its amount ond last used timestamp. Remove the oldest entry if there is
  ## maximum allowed amount of history's entries
  result = historyLength(db)
  if result == parseInt(db.getValue(sql"SELECT value FROM options where option='historyLength'")):
    db.exec(sql"DELETE FROM history ORDER BY command ASC LIMIT(1)");
    result.dec()
  if db.execAffectedRows(sql"UPDATE history SET amount=amount+1, lastused=datetime('now') WHERE command=?",
      commandToAdd) == 0:
    db.exec(sql"INSERT INTO history (command, amount, lastused) VALUES (?, 1, datetime('now'))", commandToAdd)
    result.inc()

func getHistory*(historyIndex: int; db: DbConn): string {.gcsafe, locks: 0,
    raises: [DbError], tags: [ReadDbEffect].} =
  ## Get the command with the selected index from the shell history
  return db.getValue(sql"SELECT command FROM history ORDER BY lastused, amount ASC LIMIT 1 OFFSET ?",
      $(historyIndex - 1));

proc clearHistory*(db: DbConn): int {.gcsafe, sideEffect, locks: 0, raises: [
    DbError, IOError, OSError, ValueError], tags: [ReadIOEffect, WriteIOEffect,
    ReadDbEffect, WriteDbEffect].} =
  ## Clear the shell's history, don't add the command to the history
  db.exec(sql"DELETE FROM history");
  showOutput("Shell's commands' history cleared.")
  return 0;

proc helpHistory*(db: DbConn): int {.gcsafe, sideEffect, locks: 0, raises: [
    DbError, OSError, IOError, ValueError], tags: [ReadDbEffect, WriteDbEffect,
    ReadIOEffect, WriteIOEffect].} =
  ## Show short help about available subcommands related to the shell's
  ## commands' history
  showOutput("""Available subcommands are: clear, show

        To see more information about the subcommand, type help history [command],
        for example: help history clear.
""")
  return updateHistory("history", db)

proc showHistory*(db: DbConn): int {.gcsafe, sideEffect, locks: 0, raises: [
    DbError, IOError, OSError, ValueError], tags: [ReadDbEffect, WriteDbEffect,
    ReadIOEffect, WriteIOEffect].} =
  ## Show the last Amount of entries to the shell's history
  showOutput("The last commands from the shell's history")
  showOutput("Last used           Times Command")
  for row in db.fastRows(sql"SELECT command, lastused, amount FROM history ORDER BY lastused ASC LIMIT 20"):
    showOutput(row[1] & " " & row[2] & " " & row[0])
  return updateHistory("history show", db)
