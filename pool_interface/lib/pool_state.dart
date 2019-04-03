import 'package:flutter/material.dart';

class PoolState {
  PoolState(
      {this.waterTemp,
      this.airTemp,
      this.thermostat,
      this.pumpManual,
      this.heaterManual,
      this.pumpStatus,
      this.heaterStatus});

  int waterTemp;
  int airTemp;
  int thermostat;
  DateTime pumpTimestamp;
  DateTime heaterTimestamp;
  bool pumpManual;
  bool heaterManual;
  bool pumpStatus;
  bool heaterStatus;
  bool pumpAuto;
  bool heaterAuto;
  TimeOfDay pumpOnTime;
  TimeOfDay pumpOffTime;
  TimeOfDay heaterOnTime;
  TimeOfDay heaterOffTime;
}
