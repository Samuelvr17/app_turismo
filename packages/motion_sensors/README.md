# motion_sensors (vendored)

This directory contains a vendored copy of the `motion_sensors` plugin (version 0.1.0)
used by the application. The package has been checked into source control so that we
can apply Android namespace fixes required by recent versions of the Android Gradle
Plugin.

Only the Android implementation is included because the project currently targets
Android builds. If additional platforms are required in the future, bring in the
corresponding implementations from the upstream repository.
