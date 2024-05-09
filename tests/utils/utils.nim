import std/paths
import ../../src/[aliases, db, types]
import norm/sqlite
import unittest2, contracts

proc initDb*(dbName: string): DbConn {.raises: [], tags: [RootEffect],
    contractual.} =
  body:
    result = startDb(dbPath = dbName.Path)
    unittest2.require:
      result != nil

proc addAliases*(db: DbConn) {.raises: [DbError, ValueError], tags: [
    ReadDbEffect, WriteDbEffect], contractual.} =
  if db.count(T = Alias) == 0:
    var alias: Alias = newAlias(name = "tests", path = "/".Path, recursive = true,
          commands = "ls -a", description = "Test alias.", output = "output")
    db.insert(obj = alias)
    var testAlias2: Alias = newAlias(name = "tests2", path = "/".Path,
        recursive = false, commands = "ls -a", description = "Test alias 2.",
            output = "output")
    db.insert(obj = testAlias2)
