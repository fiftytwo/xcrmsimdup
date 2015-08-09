# xcrmsimdup

###### Usage: `xcrmsimdup [options]`

Find duplicated simulator records from the active developer directory listed by command `xcrun simctl list` and remove duplicates using `xcrun simctl delete`.

The active developer directory can be set using `xcode-select`, or via the DEVELOPER_DIR environment variable. See the xcrun and xcode-select manual pages for more information.

###### Options:
```
  -h, --help      show this help message and exit
  -d, --delete    delete duplicates
  -s, --show      just show duplicates, but don't touch them
```
