import 'package:flutter/material.dart';
import 'package:pool_interface/bluetooth.dart';

void main() => runApp(PoolControllerApp());

class PoolControllerApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pool Controller',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: DefaultTabController(length: 2, child: Bluetooth()),
    );
  }
}
