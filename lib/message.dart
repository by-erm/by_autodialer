import 'dart:convert';
import "package:intl/intl.dart";
import 'package:mqtt_client/mqtt_client.dart';

class Message {
   String topic;
   String raw;
   MqttQos qos;
   Map<String, dynamic> payload;
   DateTime timestamp;
   String key;

  Message(this.topic, this.raw, this.qos, this.timestamp)
      : payload = json.decode(raw),
        key = DateFormat("y-M-d H:m:s").format(timestamp);
}
