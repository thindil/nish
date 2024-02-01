import unittest2
include ../src/logger
when defined(debug):
  import std/os

suite "Unit tests for logger module":

  test "Starting logging":
    startLogging()
    when defined(debug):
      check:
        fileExists("nish.log")

  test "Writing a message to log":
    logToFile("test message")
