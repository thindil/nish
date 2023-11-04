import ../src/logger
import unittest2
when defined(debug):
  import std/os

suite "Unit tests for logger module":

  test "Starting logging":
    startLogging()
    when defined(debug):
      check:
        fileExists("nish.log")

  test "Writing a message to log":
    log("test message")
