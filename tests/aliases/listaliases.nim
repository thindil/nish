discard """
  outputsub: Test alias.
"""

import std/[db_sqlite, os, strutils]
import ../../src/[aliases, constants, nish]
import utils/helpers

var (db, _, historyIndex, myaliases) = initTest()
assert setTestAliases(db) == QuitSuccess
myaliases.setAliases(getCurrentDir(), db)
assert parseInt(db.getValue(sql"SELECT COUNT(*) FROM aliases")) == 2
listAliases("list", historyIndex, myaliases, db)
listAliases("list all", historyIndex, myaliases, db)
listAliases("werwerew", historyIndex, myaliases, db)
quitShell(ResultCode(QuitSuccess), db)
