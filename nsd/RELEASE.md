# Release Workflow

1. Push all changes
2. Wait for [CI](https://github.com/sebastianhaberey/nsd/actions) to complete successfully
3. Run additional integration tests manually (if applicable)
4. Do versioning in all projects
   1. Update all changelogs
   2. Update all version numbers
   3. Change dependencies in project _nsd_ back to proper versions, update version numbers
   4. Disable `publish_to: none` in project _nsd_
5. Commit locally with message "versioning (x.y.z)"
6. Publish with `flutter pub publish` starting with lowest in dependency tree
7. Push versioning changes, wait for CI to complete successfully