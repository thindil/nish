discard """
  exitcode: 0
"""

import ../../src/[help, resultcode]
import utils/helpers

let db = initTest()
assert updateHelp(db) == QuitSuccess
