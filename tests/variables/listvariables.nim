discard """
  outputsub: Test variable.
"""

import ../../src/[lstring, nish, variables, resultcode]
import utils/helpers

var (db, _) = initTest()
assert setTestVariables(db) == QuitSuccess
assert listVariables(initLimitedString(capacity = 4, text = "list"), db) == QuitSuccess
assert listVariables(initLimitedString(capacity = 8, text = "list all"), db) == QuitSuccess
assert listVariables(initLimitedString(capacity = 8, text = "werwerew"), db) == QuitSuccess
quitShell(ResultCode(QuitSuccess), db)
