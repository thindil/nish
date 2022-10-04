discard """
  exitcode: 0
"""

import ../../src/[help, lstring, resultcode]
import utils/helpers

var (db, _) = initTest()
discard deleteHelpEntry(initLimitedString(capacity = 4, text = "test"), db)
assert addHelpEntry(initLimitedString(capacity = 4, text = "test"),
    initLimitedString(capacity = 10, text = "test topic"), initLimitedString(
    capacity = 4, text = "test"), "test help", db) == QuitSuccess
assert addHelpEntry(initLimitedString(capacity = 4, text = "test"),
    initLimitedString(capacity = 10, text = "test topic"), initLimitedString(
    capacity = 4, text = "test"), "test help", db) == QuitFailure
