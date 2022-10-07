import std/[db_sqlite]
import ../../../src/[directorypath, nish]

proc initTest*(): DbConn =
  result = startDb("test.db".DirectoryPath)
  assert result != nil
