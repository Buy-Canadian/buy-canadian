import 'package:flutter/widgets.dart';

/// A simple utility to handle app lifecycle events.
void handleAppLifecycleState(
  AppLifecycleState state, {
  required VoidCallback onResume,
  required VoidCallback onInactive,
}) {
  if (state == AppLifecycleState.resumed) {
    onResume();
  } else if (state == AppLifecycleState.inactive) {
    onInactive();
  }
}
