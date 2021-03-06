import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared/html_model.dart';

import 'common.dart';
import 'routes.dart';

class PushRouter {
  final BuildContext context;

  PushRouter(this.context) {
    _setUpPushNotifications();
  }

  Future _setUpPushNotifications() async {
    final firebaseMessaging = FirebaseMessaging();
    await firebaseMessaging.requestNotificationPermissions();
    await firebaseMessaging.subscribeToTopic('new-content');
    firebaseMessaging.configure(
      onLaunch: _onNotification,
      onResume: _onNotification,
    );
    print('Push notifications have been set up');
  }

  Future<dynamic> _onNotification(Map<String, dynamic> message) async {
    final link =
        LinkData.fromMap(Platform.isAndroid ? message['data'] : message);
    print('Opening link from push notification: $link');
    safePushNamed(context, Routes.read, link);
  }
}
