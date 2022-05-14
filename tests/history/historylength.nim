discard """
  exitcode: 0
"""

import std/[db_sqlite]
import ../../src/[constants, history, nish]
import utils/helpers

let (db, amount) = initTest()
if amount == 0:
  if db.tryInsertID(sql"INSERT INTO history (command, amount, lastused) VALUES (?, 1, datetime('now'))", "ls -a") == -1:
    quit("Can't add test command to history.", QuitFailure)
assert historyLength(db) > 0
quitShell(ResultCode(QuitSuccess), db)
