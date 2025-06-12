# carrier (development version)

* `crate()` gains a `.parent_env` argument. The default is `baseenv()` in order
  to isolate the crate from the global search path. You can now set it to
  another environment. For instance, set it to `globalenv()` to make your crate
  inherit from the search path. Note that, as the global environment is
  serialized by name rather than by value, the crate is still isolated from
  objects in the global environment (#16).

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
