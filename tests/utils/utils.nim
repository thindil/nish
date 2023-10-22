import ../../src/[db, directorypath]
import norm/sqlite
import unittest2

proc initDb*(dbName: string): DbConn =
  result = startDb(dbName.DirectoryPath)
  require:
    result != nil
