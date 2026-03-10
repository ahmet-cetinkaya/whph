import 'package:flutter/material.dart';

/// A mixin to handle the state and logic for collapsible list groups.
///
/// This mixin provides:
/// - A set of collapsed group names.
/// - Methods to check if a group is collapsed.
/// - Methods to toggle the collapsed state of a group.
/// - A hook [onGroupCollapseChanged] to handle side effects (e.g., clearing caches).
mixin ListGroupCollapseMixin<T extends StatefulWidget> on State<T> {
  /// The set of group names that are currently collapsed.
  final Set<String> collapsedGroups = {};

  /// Checks if the given [groupName] is currently collapsed.
  bool isGroupCollapsed(String groupName) => collapsedGroups.contains(groupName);

  /// Toggles the collapsed state of the given [groupName].
  ///
  /// If the group is collapsed, it will be expanded.
  /// If the group is expanded, it will be collapsed.
  ///
  /// This method calls calls [setState] and triggers [onGroupCollapseChanged].
  void toggleGroupCollapse(String groupName) {
    setState(() {
      if (collapsedGroups.contains(groupName)) {
        collapsedGroups.remove(groupName);
      } else {
        collapsedGroups.add(groupName);
      }
      onGroupCollapseChanged();
    });
  }

  /// specific logic to execute after the group collapse state changes.
  ///
  /// Override this method to perform additional actions, such as invalidating caches
  /// or rebuilding specific widgets.
  void onGroupCollapseChanged() {}
}
