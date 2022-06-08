discard """
  outputsub: Test alias.
"""

import std/[db_sqlite, os, strutils]
import ../../src/[aliases, directorypath, lstring, nish, resultcode]
import utils/helpers

var (db, _, historyIndex, myaliases) = initTest()
assert setTestAliases(db) == QuitSuccess
myaliases.setAliases(getCurrentDir().DirectoryPath, db)
assert parseInt(db.getValue(sql"SELECT COUNT(*) FROM aliases")) == 2
listAliases(initLimitedString(capacity = 4, text = "list"), historyIndex,
    myaliases, db)
listAliases(initLimitedString(capacity = 8, text = "list all"), historyIndex,
    myaliases, db)
listAliases(initLimitedString(capacity = 8, text = "werwerew"), historyIndex,
    myaliases, db)
quitShell(ResultCode(QuitSuccess), db)
