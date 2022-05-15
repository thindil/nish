discard """
  exitcode: 0
"""

import std/[db_sqlite, strutils, tables]
import ../../src/[aliases, constants, nish]
import utils/helpers

var (db, helpContent, _, myaliases) = initTest()
if parseInt(db.getValue(sql"SELECT COUNT(*) FROM aliases")) == 0:
    if db.tryInsertID(sql"INSERT INTO aliases (name, path, recursive, commands, description) VALUES (?, ?, ?, ?, ?)",
        "tests", "/", 1, "ls -a", "Test alias.") == -1:
      quit("Can't add test alias.", QuitFailure)
    if db.tryInsertID(sql"INSERT INTO aliases (name, path, recursive, commands, description) VALUES (?, ?, ?, ?, ?)",
        "tests2", "/", 0, "ls -a", "Test alias 2.") == -1:
      quit("Can't add test2 alias.", QuitFailure)
myaliases = initAliases(helpContent, db)
assert myaliases.len() == 1
assert helpContent.len() == 6
quitShell(ResultCode(QuitSuccess), db)
