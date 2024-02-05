import unittest2
include ../src/constants

suite "Unit tests for constant module":

  test "Get the current directory":
    checkpoint "Get an existing current directory"
    check:
      getCurrentDirectory() == paths.getCurrentDir()
    let testDir = ospaths2.getCurrentDir() &  DirSep & "test"
    createDir(testDir)
    setCurrentDir(testDir)
    removeDir(testDir)
    checkpoint "Get a non-existing current directory"
    check:
      getCurrentDirectory().string == getHomeDir()
