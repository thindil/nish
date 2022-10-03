discard """
  exitcode: 0
"""

import ../../src/[help, lstring, resultcode]
import utils/helpers

var (db, _) = initTest()
assert addHelpEntry(initLimitedString(capacity = 4, text = "test"),
    initLimitedString(capacity = 10, text = "test topic"), initLimitedString(
    capacity = 4, text = "test"), "test help", db) == QuitSuccess
assert updateHelpEntry(initLimitedString(capacity = 4, text = "test"),
    initLimitedString(capacity = 10, text = "test topic"), initLimitedString(
    capacity = 4, text = "test"), "test help2", db) == QuitSuccess
assert updateHelpEntry(initLimitedString(capacity = 4, text = "asdd"),
    initLimitedString(capacity = 10, text = "test topic"), initLimitedString(
    capacity = 4, text = "test"), "test help2", db) == QuitFailure
