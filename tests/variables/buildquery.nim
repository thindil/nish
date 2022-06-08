discard """
  exitcode: 0
"""

import ../../src/[directorypath, variables]

assert buildQuery("/".DirectoryPath, "name") == "SELECT name FROM variables WHERE path='/' ORDER BY id ASC"
