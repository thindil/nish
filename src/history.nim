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
import output

const maxHistoryLength = 500

func historyLength*(db: DbConn): int {.gcsafe, locks: 0, raises: [ValueError,
    DbError], tags: [ReadDbEffect].} =
  ## Get the current length of the shell's commmand's history
  return parseInt(db.getValue(sql"SELECT COUNT(*) FROM history"))

func updateHistory*(commandToAdd: string; db: DbConn): int {.gcsafe, raises: [
    ValueError, DbError], tags: [ReadDbEffect, WriteDbEffect].} =
  ## Add the selected command to the shell history and increase the current
  ## history index
  result = historyLength(db)
  if result == maxHistoryLength:
    db.exec(sql"DELETE FROM history ORDER BY command ASC LIMIT(1)");
    result.dec()
  db.exec(sql"INSERT INTO history (command) VALUES (?)", commandToAdd)
  result.inc()

func getHistory*(historyIndex: int; db: DbConn): string {.gcsafe, locks: 0,
    raises: [DbError], tags: [ReadDbEffect].} =
  ## Get the command with the selected index from the shell history
  return db.getValue(sql"SELECT command FROM history LIMIT 1 OFFSET ?",
      $(historyIndex - 1));

proc clearHistory*(db: DbConn): int =
  ## Clear the shell's history, don't add the command to the history
  db.exec(sql"DELETE FROM history");
  showOutput("Shell's commands' history cleared.", true, false, "", QuitSuccess)
  return 0;

