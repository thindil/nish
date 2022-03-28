discard """
  exitcode: 0
"""

import db_sqlite, os
import ../../src/nish

let db = startDb("test.db")
assert fileExists("test.db")
db.exec(sql"INSERT INTO aliases (name, path, recursive, commands, description) VALUES (?, ?, ?, ?, ?)",
    "testalias", "/", 1, "ls -a", "Test alias.")
quitShell(QuitSuccess, db)
