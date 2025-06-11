# carrier (development version)

* `crate()` gains argument `.parent_env` to govern whether a crate environment
  should be isolated from the search path, as it is by default (#16).

# carrier 0.1.1

* Crated functions no longer carry source references (#6).

* Fixed issue that prevented crate sizes to be printed in
  human-readable format (r-lib/lobstr#60).


# carrier 0.1.0

Initial release. The package currently only contains a single method
for creating crates that requires users to be explicit about what data
to pack in the crate. A future release will provide a method to figure
out automatically what objects the crate depends on (with inevitable
false positives and negatives).
