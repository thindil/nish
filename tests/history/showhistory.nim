discard """
  exitcode: 0
"""

import std/[db_sqlite]
import ../../src/[constants, history, nish]
import utils/helpers

let (db, amount) = initTest()
if amount == 0:
  if db.tryInsertID(sql"INSERT INTO history (command, amount, lastused) VALUES (?, 1, datetime('now'))", "alias delete") == -1:
    quit("Can't add test command to history.", QuitFailure)
assert showHistory(db) >= amount
quitShell(ResultCode(QuitSuccess), db)
