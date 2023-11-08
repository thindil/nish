import ../src/nish
import unittest2

suite "Unit tests for nish module":

  test "Showing the list of available options for the shell":
    showCommandLineHelp()

  test "Showing the shell's version":
    showProgramVersion()
