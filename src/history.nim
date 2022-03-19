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
import constants, options, output

proc historyLength*(db: DbConn): int {.gcsafe, sideEffect, raises: [],
    tags: [ReadDbEffect, WriteIOEffect, ReadEnvEffect, TimeEffect].} =
  ## Get the current length of the shell's commmand's history
  try:
    return parseInt(db.getValue(sql"SELECT COUNT(*) FROM history"))
  except DbError, ValueError:
    return showError("Can't get the length of the shell's commands history. Reason: " &
        getCurrentExceptionMsg())

proc initHistory*(db: DbConn; helpContent: var HelpTable): int {.gcsafe,
    sideEffect, raises: [], tags: [ReadDbEffect, WriteIOEffect,
    WriteDbEffect, ReadEnvEffect, TimeEffect].} =
  ## Initialize shell's commands history. Create history table if not exists,
  ## set the current historyIndex, options related to the history and help
  ## related to the history commands
  # Set the history related options
  if getOption("historyLength", db) == "":
    setOption("historyLength", "500", "Max amount of entries in shell commands history.",
        "integer", db)
  if getOption("historyAmount", db) == "":
    setOption("historyAmount", "20", "Amount of entries in shell commands history to show with history show command.",
        "integer", db)
  if getOption("historySaveInvalid", db) == "":
    setOption("historySaveInvalid", "false",
        "Save in shell command history also invalid commands.", "boolean", db)
  # Create history table if not exists
  try:
    db.exec(sql("""CREATE TABLE IF NOT EXISTS history (
                 command     VARCHAR(""" & $maxInputLength &
        """) PRIMARY KEY,
                 lastused    DATETIME NOT NULL DEFAULT 'datetime(''now'')',
                 amount      INTEGER NOT NULL DEFAULT 1
              )"""))
  except DbError as e:
    discard showError("Can't create table for the shell's history. Reason: " & e.msg)
    return -1
  # Set the history related help content
  helpContent["history"] = HelpEntry(usage: "history ?subcommand?",
      content: "If entered without subcommand, show the list of available subcommands for history. Otherwise, execute the selected subcommand.")
  helpContent["history clear"] = HelpEntry(usage: "history clear",
      content: "Clear the shell's commands' history.")
  # Return the current help index set on the last command in the shell's history
  return historyLength(db)

proc updateHistory*(commandToAdd: string; db: DbConn;
    returnCode: int = QuitSuccess): int {.gcsafe, sideEffect, raises: [
        ValueError, DbError], tags: [ReadDbEffect, WriteDbEffect,
        WriteIOEffect, ReadEnvEffect, TimeEffect].} =
  ## Add the selected command to the shell history and increase the current
  ## history index. If there is the command in the shell's history, only update
  ## its amount ond last used timestamp. Remove the oldest entry if there is
  ## maximum allowed amount of history's entries
  result = historyLength(db)
  if returnCode != QuitSuccess and db.getValue(
      sql"SELECT value FROM options WHERE option='historySaveInvalid'") == "false":
    return
  if result == parseInt(db.getValue(sql"SELECT value FROM options where option='historyLength'")):
    db.exec(sql"DELETE FROM history ORDER BY lastused, amount ASC LIMIT 1");
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
    DbError], tags: [ReadIOEffect, WriteIOEffect, ReadDbEffect,
        WriteDbEffect].} =
  ## Clear the shell's history, don't add the command to the history
  db.exec(sql"DELETE FROM history");
  showOutput(message = "Shell's commands' history cleared.", fgColor = fgGreen)
  return 0;

proc helpHistory*(db: DbConn): int {.gcsafe, sideEffect, raises: [
    DbError, ValueError], tags: [ReadDbEffect, WriteDbEffect, ReadIOEffect,
        WriteIOEffect, ReadEnvEffect, TimeEffect].} =
  ## Show short help about available subcommands related to the shell's
  ## commands' history
  showOutput("""Available subcommands are: clear, show

        To see more information about the subcommand, type help history [command],
        for example: help history clear.
""")
  return updateHistory("history", db)

proc showHistory*(db: DbConn): int {.gcsafe, sideEffect, raises: [
    DbError, ValueError], tags: [ReadDbEffect, WriteDbEffect, ReadIOEffect,
        WriteIOEffect, ReadEnvEffect, TimeEffect].} =
  ## Show the last X entries to the shell's history. X can be set in the shell's
  ## options as 'historyAmount' option.
  let
    amount: string = getOption("historyAmount", db)
    spacesAmount: Natural = (terminalWidth() / 12).int
  showFormHeader(message = "The last commands from the shell's history")
  showOutput(message = indent("Last used                Times      Command",
      spacesAmount), fgColor = fgMagenta)
  for row in db.fastRows(sql"SELECT command, lastused, amount FROM history ORDER BY lastused, amount ASC LIMIT ? OFFSET (SELECT COUNT(*)-? from history)",
      amount, amount):
    showOutput(indent(row[1] & "      " & center(row[2], 5) & "      " &
        row[0], spacesAmount))
  return updateHistory("history show", db)
