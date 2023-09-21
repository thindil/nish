discard """
  exitcode: 0
"""

import std/os
import ../../src/constants

assert getCurrentDirectory() == getCurrentDir()
let testDir = getCurrentDir() &  DirSep & "test"
createDir(testDir)
setCurrentDir(testDir)
removeDir(testDir)
assert getCurrentDirectory() == getHomeDir()
