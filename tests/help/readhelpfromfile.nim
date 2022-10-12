discard """
  exitcode: 0
"""

import std/db_sqlite
import ../../src/[help, resultcode]
import utils/helpers

let db = initTest()
db.exec(sql("DELETE FROM help"))
assert readHelpFromFile(db) == QuitSuccess
assert readHelpFromFile(db) == QuitFailure
