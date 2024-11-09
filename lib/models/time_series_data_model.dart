class TimeSeriesDataModel {
  TimeSeriesDataFormat? instantaneousPower;
  TimeSeriesDataFormat? batteryChargeLevel;
  TimeSeriesDataFormat? batteryTemperature;

  TimeSeriesDataModel(
      {this.instantaneousPower,
      this.batteryChargeLevel,
      this.batteryTemperature});

  TimeSeriesDataModel.fromJson(Map<String, dynamic> json) {
    instantaneousPower = json['instantaneousPower'] != null
        ? TimeSeriesDataFormat.fromJson(json['instantaneousPower'])
        : null;
    batteryChargeLevel = json['batteryChargeLevel'] != null
        ? TimeSeriesDataFormat.fromJson(json['batteryChargeLevel'])
        : null;
    batteryTemperature = json['batteryTemperature'] != null
        ? TimeSeriesDataFormat.fromJson(json['batteryTemperature'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (instantaneousPower != null) {
      data['instantaneousPower'] = instantaneousPower!.toJson();
    }
    if (batteryChargeLevel != null) {
      data['batteryChargeLevel'] = batteryChargeLevel!.toJson();
    }
    if (batteryTemperature != null) {
      data['batteryTemperature'] = batteryTemperature!.toJson();
    }
    return data;
  }
}

class TimeSeriesDataFormat {
  double? value;
  int? timestamp;

  TimeSeriesDataFormat({this.value, this.timestamp});

  TimeSeriesDataFormat.fromJson(Map<String, dynamic> json) {
    value = json['value'];
    timestamp = json['timestamp'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['value'] = value;
    data['timestamp'] = timestamp;
    return data;
  }
}
