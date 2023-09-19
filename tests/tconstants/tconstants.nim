discard """
  exitcode: 0
"""

import std/os
import ../../src/[constants, lstring]
import norm/sqlite

assert getCurrentDirectory() == getCurrentDir()
let testDir = getCurrentDir() &  DirSep & "test"
createDir(testDir)
setCurrentDir(testDir)
removeDir(testDir)
assert getCurrentDirectory() == getHomeDir()
assert dbType(LimitedString) == "TEXT"
let testString = initLimitedString(capacity = 4, text = "test")
assert dbValue(testString) == "test".dbValue
assert to("test".dbValue, LimitedString) == testString
