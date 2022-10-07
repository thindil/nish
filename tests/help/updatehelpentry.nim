discard """
  exitcode: 0
"""

import ../../src/[help, lstring, resultcode]
import utils/helpers

let db = initTest()
discard deleteHelpEntry(initLimitedString(capacity = 4, text = "test"), db)
assert addHelpEntry(initLimitedString(capacity = 4, text = "test"),
    initLimitedString(capacity = 10, text = "test topic"), initLimitedString(
    capacity = 4, text = "test"), "test help", false, db) == QuitSuccess
assert updateHelpEntry(initLimitedString(capacity = 4, text = "test"),
    initLimitedString(capacity = 10, text = "test topic"), initLimitedString(
    capacity = 4, text = "test"), "test help2", db, false) == QuitSuccess
assert updateHelpEntry(initLimitedString(capacity = 4, text = "asdd"),
    initLimitedString(capacity = 10, text = "test topic"), initLimitedString(
    capacity = 4, text = "test"), "test help2", db, false) == QuitFailure
