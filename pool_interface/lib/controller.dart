import 'package:flutter/material.dart';
import 'package:pool_interface/indicator.dart';
import 'dart:math';
import 'dart:async';

class PoolInfo {
  PoolInfo({this.waterTemp});

  int waterTemp;
  int airTemp;
}

class PoolController extends StatelessWidget {
  PoolController({this.poolInfo});

  final PoolInfo poolInfo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        bottom: TabBar(
          tabs: <Widget>[
            Tab(
              text: "Dashboard",
            ),
            Tab(
              text: "Schedule",
            )
          ],
        ),
        title: const Text("Pool Controller"),
      ),
      body: TabBarView(
        children: <Widget>[
          Dashboard(
            poolInfo: poolInfo,
          ),
          ScheduleWidget()
        ],
      ),
    );
  }
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

class Dashboard extends StatefulWidget {
  Dashboard({Key key, this.poolInfo}) : super(key: key);

  final PoolInfo poolInfo;

  @override
  _DashboardState createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  bool _pumpAuto = true;
  bool _pumpOn = true;
  bool _heaterAuto = true;
  bool _heaterOn = true;
  int _thermostat = 75;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
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
          child: Container(
              color: Theme.of(context).accentColor,
              width: double.infinity,
              margin: EdgeInsets.only(top: 5, bottom: 5),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Thermostat"),
                    Padding(
                        padding: EdgeInsets.only(left: 20, right: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            RaisedButton(
                              child: const Icon(Icons.remove),
                              onPressed: _thermostat <= 70 || _heaterAuto
                                  ? null
                                  : () {
                                      setState(() {
                                        _thermostat = max(_thermostat - 1, 70);
                                      });
                                    },
                            ),
                            Text(
                              "$_thermostat ºF",
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            RaisedButton(
                              child: const Icon(Icons.add),
                              onPressed: _thermostat >= 84 || _heaterAuto
                                  ? null
                                  : () {
                                      setState(() {
                                        _thermostat = min(_thermostat + 1, 84);
                                      });
                                    },
                            ),
                          ],
                        )),
                  ]))),
      Flexible(
          child: DataDisplay(
        label: "Water Temperature",
        value:
            "${widget.poolInfo.waterTemp != null ? widget.poolInfo.waterTemp : "?"} ºF",
      )),
      Flexible(
          child: DataDisplay(
        label: "Air Temperature",
        value:
            "${widget.poolInfo.airTemp != null ? widget.poolInfo.airTemp : "?"} ºF",
      )),
    ]);
  }
}

class ScheduleWidget extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _ScheduleWidgetState();
}

class _ScheduleWidgetState extends State<ScheduleWidget> {
  TimeOfDay _pumpOn;
  TimeOfDay _pumpOff;

  Future<Null> _selectPumpOnTime(BuildContext context) async {
    final TimeOfDay picked = await showTimePicker(
      context: context,
      initialTime: _pumpOn ?? TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        _pumpOn = picked;
      });
    }
  }

  Future<Null> _selectPumpOffTime(BuildContext context) async {
    final TimeOfDay picked = await showTimePicker(
      context: context,
      initialTime: _pumpOff ?? TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        _pumpOff = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
            padding: EdgeInsets.all(10),
            child: Text(
              "Water Pump Schedule",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
            )),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Text("Pump On:"),
            Text(
              _pumpOn == null ? "Not Set" : "${_pumpOn.format(context)}",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            RaisedButton(
              child: const Text("Select Time"),
              onPressed: () => _selectPumpOnTime(context),
            )
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Text("Pump Off:"),
            Text(
              _pumpOff == null ? "Not Set" : "${_pumpOff.format(context)}",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            RaisedButton(
              child: const Text("Select Time"),
              onPressed: () => _selectPumpOffTime(context),
            )
          ],
        )
      ],
    );
  }
}
