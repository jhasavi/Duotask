import 'package:flutter/material.dart';
import 'task_service.dart';
import 'clean_pairing_service.dart';
import 'handoff_service.dart';
import 'presence_service.dart';

/// Centralized dependency injection for the app
class AppDependencies extends InheritedWidget {
  final TaskService tasks;
  final CleanPairingService pairing;
  final HandoffService handoffs;
  final PresenceService presence;

  AppDependencies({super.key, required super.child})
      : tasks = TaskService(),
        pairing = CleanPairingService(),
        handoffs = HandoffService(),
        presence = PresenceService();

  static AppDependencies of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppDependencies>()!;
  }

  @override
  bool updateShouldNotify(AppDependencies oldWidget) {
    return tasks != oldWidget.tasks || 
           pairing != oldWidget.pairing ||
           handoffs != oldWidget.handoffs ||
           presence != oldWidget.presence;
  }
}
