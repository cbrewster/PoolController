import 'package:flutter/material.dart';
import 'package:pool_interface/indicator.dart';
import 'package:pool_interface/control_unit.dart';
import 'package:pool_interface/pool_state.dart';
import 'package:pool_interface/schedule.dart';
import 'dart:async';

class Dashboard extends StatelessWidget {
  Dashboard({this.controlUnit, this.disconnect});

  final ControlUnit controlUnit;
  final VoidCallback disconnect;

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
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.cancel),
              onPressed: () => disconnect(),
            )
          ],
        ),
        body: StreamBuilder(
          stream: controlUnit.poolState(),
          builder: (context, poolState) {
            // If loading or poolState is null, show loading indicator.
            if (poolState.data == null || controlUnit.loading) {
              return Center(
                child: CircularProgressIndicator(),
              );
            }
            return TabBarView(
              children: <Widget>[
                PoolStatus(
                  controlUnit: controlUnit,
                  poolState: poolState.data,
                ),
                ScheduleWidget(
                  poolState: poolState.data,
                  controlUnit: controlUnit,
                )
              ],
            );
          },
        ));
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
      this.status,
      this.name,
      this.onStatusChange,
      this.onModeChange,
      this.timestamp});

  final bool auto;
  final bool enabled;
  final bool status;
  final String name;
  final DateTime timestamp;

  final ValueChanged<bool> onStatusChange;
  final ValueChanged<bool> onModeChange;

  String _twoDigits(int n) {
    if (n >= 10) return "$n";
    return "0$n";
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final timeOn = now.difference(timestamp);
    final hours = timeOn.inHours;
    final minutes = timeOn.inMinutes % 60;
    final seconds = timeOn.inSeconds % 60;

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
            Container(
                width: 95,
                child: Row(
                  children: [
                    Padding(
                        padding: EdgeInsets.all(5.0),
                        child: CustomPaint(
                          size: Size(14.0, 14.0),
                          foregroundPainter: new Indicator(
                              color: status ? Colors.green : Colors.red),
                        )),
                    Text(
                      status ? "ENABLED" : "DISABLED",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ))
          ])),
      Flex(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        direction: Axis.horizontal,
        children: [
          Container(
            padding: EdgeInsets.all(5),
            width: 80,
            decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.all(Radius.circular(4))),
            child: Text(
              "${_twoDigits(hours)}:${_twoDigits(minutes)}:${_twoDigits(seconds)}",
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
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

class PoolStatus extends StatelessWidget {
  PoolStatus({Key key, this.poolState, this.controlUnit}) : super(key: key);

  final PoolState poolState;
  final ControlUnit controlUnit;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ControllerStatus(
        auto: poolState.pumpAuto,
        enabled: poolState.pumpManual,
        status: poolState.pumpStatus,
        timestamp: poolState.pumpTimestamp,
        name: "Water Pump",
        onStatusChange: (_value) => controlUnit.togglePump(),
        onModeChange: (_value) => controlUnit.togglePumpAuto(),
      ),
      ControllerStatus(
        auto: poolState.heaterAuto,
        enabled: poolState.heaterManual,
        status: poolState.heaterStatus,
        timestamp: poolState.heaterTimestamp,
        name: "Water Heater",
        onStatusChange: (_value) => controlUnit.toggleHeater(),
        onModeChange: (_value) => controlUnit.toggleHeaterAuto(),
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
                              onPressed: () => controlUnit.decreaseThermostat(),
                            ),
                            Text(
                              "${poolState.thermostat} ºF",
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            RaisedButton(
                              child: const Icon(Icons.add),
                              onPressed: () => controlUnit.increaseThermostat(),
                            ),
                          ],
                        )),
                  ]))),
      Flexible(
          child: DataDisplay(
        label: "Water Temperature",
        value: "${poolState.waterTemp != null ? poolState.waterTemp : "?"} ºF",
      )),
      Flexible(
          child: DataDisplay(
        label: "Air Temperature",
        value: "${poolState.airTemp != null ? poolState.airTemp : "?"} ºF",
      )),
    ]);
  }
}

class ScheduleWidget extends StatelessWidget {
  ScheduleWidget({this.poolState, this.controlUnit});

  final PoolState poolState;
  final ControlUnit controlUnit;

  Future<Null> _selectPumpOnTime(BuildContext context) async {
    final TimeOfDay picked = await showTimePicker(
      context: context,
      initialTime: poolState.pumpOnTime ?? TimeOfDay.now(),
    );

    if (picked != null) {
      controlUnit.setPumpOnTime(picked);
    }
  }

  Future<Null> _selectPumpOffTime(BuildContext context) async {
    final TimeOfDay picked = await showTimePicker(
      context: context,
      initialTime: poolState.pumpOffTime ?? TimeOfDay.now(),
    );

    if (picked != null) {
      controlUnit.setPumpOffTime(picked);
    }
  }

  Future<Null> _selectHeaterOnTime(BuildContext context) async {
    final TimeOfDay picked = await showTimePicker(
      context: context,
      initialTime: poolState.heaterOnTime ?? TimeOfDay.now(),
    );

    if (picked != null) {
      controlUnit.setHeaterOnTime(picked);
    }
  }

  Future<Null> _selectHeaterOffTime(BuildContext context) async {
    final TimeOfDay picked = await showTimePicker(
      context: context,
      initialTime: poolState.heaterOffTime ?? TimeOfDay.now(),
    );

    if (picked != null) {
      controlUnit.setHeaterOffTime(picked);
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
              poolState.pumpOnTime == null
                  ? "Not Set"
                  : "${poolState.pumpOnTime.format(context)}",
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
              poolState.pumpOffTime == null
                  ? "Not Set"
                  : "${poolState.pumpOffTime.format(context)}",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            RaisedButton(
              child: const Text("Select Time"),
              onPressed: () => _selectPumpOffTime(context),
            )
          ],
        ),
        Center(
            child: new Schedule(
                onTime: poolState.pumpOnTime, offTime: poolState.pumpOffTime)),
        Padding(
            padding: EdgeInsets.all(10),
            child: Text(
              "Heater Schedule",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
            )),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Text("Heater On:"),
            Text(
              poolState.heaterOnTime == null
                  ? "Not Set"
                  : "${poolState.heaterOnTime.format(context)}",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            RaisedButton(
              child: const Text("Select Time"),
              onPressed: () => _selectHeaterOnTime(context),
            )
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Text("Heater Off:"),
            Text(
              poolState.heaterOffTime == null
                  ? "Not Set"
                  : "${poolState.heaterOffTime.format(context)}",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            RaisedButton(
              child: const Text("Select Time"),
              onPressed: () => _selectHeaterOffTime(context),
            )
          ],
        ),
        Center(
            child: Schedule(
                onTime: poolState.heaterOnTime,
                offTime: poolState.heaterOffTime))
      ],
    );
  }
}
