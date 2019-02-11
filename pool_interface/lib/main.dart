import 'package:flutter/material.dart';
import 'indicator.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pool Controller',
      theme:
          ThemeData(primarySwatch: Colors.blue, accentColor: Colors.blueAccent),
      home: MyHomePage(title: 'Pool Controller Dashboard'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class DataDisplay extends StatelessWidget {
  DataDisplay({this.label, this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).accentColor,
      width: double.infinity,
      margin: EdgeInsets.only(top: 5, bottom: 5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class ControllerStatus extends StatelessWidget {
  ControllerStatus(
      {this.auto,
      this.enabled,
      this.name,
      this.onStatusChange,
      this.onModeChange});

  final bool auto;
  final bool enabled;
  final String name;

  final ValueChanged<bool> onStatusChange;
  final ValueChanged<bool> onModeChange;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
        child: Column(children: [
      Container(
          width: double.infinity,
          padding: EdgeInsets.only(top: 20, left: 10, right: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Text(
              name,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
            ),
            Spacer(),
            Padding(
                padding: EdgeInsets.all(5.0),
                child: CustomPaint(
                  size: Size(14.0, 14.0),
                  foregroundPainter:
                      new Indicator(color: enabled ? Colors.green : Colors.red),
                )),
            Text(
              enabled ? "ENABLED" : "DISABLED",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ])),
      Flex(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        direction: Axis.horizontal,
        children: [
          Text("Enable:"),
          Switch(
            value: enabled,
            onChanged: auto ? null : this.onStatusChange,
          ),
          Text("Auto:"),
          Switch(
            value: auto,
            onChanged: this.onModeChange,
          )
        ],
      )
    ]));
  }
}

class _MyHomePageState extends State<MyHomePage> {
  bool _pumpAuto = true;
  bool _pumpOn = true;
  bool _heaterAuto = true;
  bool _heaterOn = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: Column(children: [
          ControllerStatus(
            auto: _pumpAuto,
            enabled: _pumpOn,
            name: "Water Pump",
            onStatusChange: (value) {
              setState(() {
                _pumpOn = value;
              });
            },
            onModeChange: (value) {
              setState(() {
                _pumpAuto = value;
              });
            },
          ),
          ControllerStatus(
            auto: _heaterAuto,
            enabled: _heaterOn,
            name: "Water Heater",
            onStatusChange: (value) {
              setState(() {
                _heaterOn = value;
              });
            },
            onModeChange: (value) {
              setState(() {
                _heaterAuto = value;
              });
            },
          ),
          Flexible(
              child: DataDisplay(
            label: "Water Temperature",
            value: "68 ºF",
          )),
          Flexible(
              child: DataDisplay(
            label: "Air Temperature",
            value: "72 ºF",
          )),
          Flexible(
              child: DataDisplay(
            label: "Water Depth",
            value: "10 ft",
          )),
        ]));
  }
}
