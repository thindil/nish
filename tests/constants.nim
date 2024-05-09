import unittest2
include ../src/constants

suite "Unit tests for constant module":

  test "Get the current directory":
    checkpoint "Get an existing current directory"
    check:
      getCurrentDirectory() == paths.getCurrentDir()
    let testDir: string = ospaths2.getCurrentDir() &  DirSep & "test"
    createDir(dir = testDir)
    setCurrentDir(newDir = testDir)
    removeDir(dir = testDir)
    checkpoint "Get a non-existing current directory"
    check:
      getCurrentDirectory().string == getHomeDir()
