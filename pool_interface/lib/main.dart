import 'package:flutter/material.dart';
import 'package:pool_interface/search.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pool Controller',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: DefaultTabController(
          length: 2,
          child: Search(
            title: "Select Controller",
          )),
    );
  }
}
