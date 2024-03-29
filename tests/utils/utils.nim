import std/paths
import ../../src/[aliases, db, types]
import norm/sqlite
import unittest2

proc initDb*(dbName: string): DbConn =
  result = startDb(dbName.Path)
  require:
    result != nil

proc addAliases*(db: DbConn) =
  if db.count(Alias) == 0:
    var alias = newAlias(name = "tests", path = "/".Path, recursive = true,
          commands = "ls -a", description = "Test alias.", output = "output")
    db.insert(alias)
    var testAlias2 = newAlias(name = "tests2", path = "/".Path, recursive = false,
        commands = "ls -a", description = "Test alias 2.", output = "output")
    db.insert(testAlias2)
