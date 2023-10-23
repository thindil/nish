import ../../src/[aliases, db, directorypath]
import norm/sqlite
import unittest2

proc initDb*(dbName: string): DbConn =
  result = startDb(dbName.DirectoryPath)
  require:
    result != nil

proc addAliases*(db: DbConn) =
  if db.count(Alias) == 0:
    var alias = newAlias(name = "tests", path = "/", recursive = true,
          commands = "ls -a", description = "Test alias.", output = "output")
    db.insert(alias)
    var testAlias2 = newAlias(name = "tests2", path = "/", recursive = false,
        commands = "ls -a", description = "Test alias 2.", output = "output")
    db.insert(testAlias2)
