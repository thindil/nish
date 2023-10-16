import std/os
import ../src/constants
import unittest2

suite "Unit tests for constant module":

  test "getCurrentDirectory":
    check:
      getCurrentDirectory() == getCurrentDir()
    let testDir = getCurrentDir() &  DirSep & "test"
    createDir(testDir)
    setCurrentDir(testDir)
    removeDir(testDir)
    check:
      getCurrentDirectory() == getHomeDir()
