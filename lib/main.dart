import 'dart:async';

// import 'package:device_id/device_id.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import "package:intl/intl.dart";
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock/wakelock.dart';

import './message.dart';

// const String broker = 'test.mosquitto.org';
final client = MqttServerClient('www.by-zx.com', '');

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isConnected = false;

  // String _deviceid = 'Unknown';
  StreamSubscription? subscription;

  var username = '';

  List<Message> messages = <Message>[];
  ScrollController messageController = ScrollController();

  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    IconData connectionStateIcon;
    var state = client.connectionStatus!.state;
    switch (state) {
      case MqttConnectionState.connected:
        connectionStateIcon = Icons.cloud_done;
        break;
      case MqttConnectionState.disconnected:
        connectionStateIcon = Icons.cloud_off;
        break;
      case MqttConnectionState.connecting:
        connectionStateIcon = Icons.cloud_upload;
        break;
      case MqttConnectionState.disconnecting:
        connectionStateIcon = Icons.cloud_download;
        break;
      case MqttConnectionState.faulted:
        connectionStateIcon = Icons.error;
        break;
      default:
        connectionStateIcon = Icons.cloud_off;
    }

    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      title: '伯阳咨询',
      builder: BotToastInit(),
      //1. call BotToastInit
      navigatorObservers: [BotToastNavigatorObserver()],
      //2. registered route observer
      home: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(isConnected ? _controller.text : ''),
              const SizedBox(
                width: 8.0,
              ),
              Icon(connectionStateIcon),
            ],
          ),
        ),
        body: Container(
          child: _buildBrokerPage(connectionStateIcon),
        ),
      ),
    );
  }

  Column _buildBrokerPage(IconData connectionStateIcon) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            isConnected
                ? const SizedBox.shrink()
                : Flexible(
                    child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: '用户名',
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 20.0, vertical: 10.0),
                    ),
                  )),
            const SizedBox(width: 8.0),
            ElevatedButton(
              child: Text(isConnected ? '断开' : '连接'),
              onPressed: () {
                isConnected ? _logout() : _login();
              },
            ),
            const SizedBox(width: 8.0),
            isConnected
                ? ElevatedButton(
                    child: const Text('清空'),
                    onPressed: () {
                      setState(() {
                        messages.clear();
                      });
                    },
                  )
                : const SizedBox.shrink(),
          ],
        ),
        Expanded(
          child: ListView(
            controller: messageController,
            children: _buildMessageList(),
          ),
        ),
      ],
    );
  }

  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      username = prefs.getString('username') ?? '';
      print('===last name: $username');
      _controller.text = username;
    });
  }

  // Future<void> initDeviceId() async {
  //   String deviceid;
  //
  //   deviceid = await DeviceId.getID;
  //
  //   if (!mounted) return;
  //
  //   setState(() {
  //     _deviceid = deviceid;
  //   });
  // }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Wakelock.enable();
    // initDeviceId();
    _loadUsername();
  }

  List<Widget> _buildMessageList() {
    return messages
        .map((Message message) => Card(
              color: Colors.white70,
              child: ListTile(
                title: Text(
                  message.payload['phone'],
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                subtitle:
                    Text(DateFormat("y-M-d H:m:s").format(message.timestamp)),
                trailing: TextButton.icon(
                  icon: const Icon(Icons.phone_forwarded),
                  label: const Text('重拨'),
                  onPressed: () async {
                    await FlutterPhoneDirectCaller.callNumber(
                        message.payload['phone']);
                  },
                ),
                dense: true,
              ),
            ))
        .toList()
        .reversed
        .toList();
  }

  void _login() async {
    String username = _controller.text;
    if (username == '') {
      return;
    }

    void _onConnected() async {
      // print('连接成功: $username');
      BotToast.showText(text: "连接成功");

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', username);
      // FIXME: the listener will not be removed when disconnected.
      print('=====================> create subscription $username');
      subscription = client.updates!.listen(_onMessage);
      String cleanTopic = username.trim();
      print('Subscribing to $cleanTopic');
      client.subscribe(username, MqttQos.atMostOnce);
      setState(() {
        isConnected = true;
      });
    }

    /// First create a client, the client is constructed with a broker name, client identifier
    /// and port if needed. The client identifier (short ClientId) is an identifier of each MQTT
    /// client connecting to a MQTT broker. As the word identifier already suggests, it should be unique per broker.
    /// The broker uses it for identifying the client and the current state of the client. If you don’t need a state
    /// to be hold by the broker, in MQTT 3.1.1 you can set an empty ClientId, which results in a connection without any state.
    /// A condition is that clean session connect flag is true, otherwise the connection will be rejected.
    /// The client identifier can be a maximum length of 23 characters. If a port is not specified the standard port
    /// of 1883 is used.
    /// If you want to use websockets rather than TCP see below.

    // client = MqttServerClient(broker, _username);
    // print('====================!$username');

    /// A websocket URL must start with ws:// or wss:// or Dart will throw an exception, consult your websocket MQTT broker
    /// for details.
    /// To use websockets add the following lines -:
    /// client.useWebSocket = true;
    /// client.port = 80;  ( or whatever your WS port is)
    /// Note do not set the secure flag if you are using wss, the secure flags is for TCP sockets only.

    /// Set logging on if needed, defaults to off
    // client.logging(on: true);

    /// Set the correct MQTT protocol for mosquito
    // client.setProtocolV311();

    /// If you intend to use a keep alive value in your connect message that is not the default(60s)
    /// you must set it here
    client.keepAlivePeriod = 30;

    /// Add the unsolicited disconnection callback
    client.onConnected = _onConnected;
    client.onDisconnected = _onDisconnected;

    /// Create a connection message to use or use the default one. The default one sets the
    /// client identifier, any supplied username/password and clean session,
    /// an example of a specific one below.
    final connMess = MqttConnectMessage()
        .withClientIdentifier(username)
        .startClean() // Non persistent session for testing
        .withWillQos(MqttQos.atMostOnce);
    client.connectionMessage = connMess;

    // print('MQTT client connecting....');

    /// Connect the client, any errors here are communicated by raising of the appropriate exception. Note
    /// in some circumstances the broker will just disconnect us, see the spec about this, we however will
    /// never send malformed messages.
    try {
      await client.connect();
    } catch (e) {
      print(e.toString());
      BotToast.showText(text: e.toString());
      // client.disconnect();
      return;
    }
  }

  void _logout() {
    client.disconnect();
  }

  void _onDisconnected() {
    // print('断开连接');
    BotToast.showText(text: "断开连接");
    setState(() {
      // subscription?.cancel();
      // subscription = null;
      isConnected = false;
    });
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage?>> event) async {
    final MqttPublishMessage recMess = event[0].payload as MqttPublishMessage;
    // print('================ message: $recMess');
    final String message =
        MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

    /// The above may seem a little convoluted for users only interested in the
    /// payload, some users however may be interested in the received publish message,
    /// lets not constrain ourselves yet until the package has been in the wild
    /// for a while.
    /// The payload is a byte buffer, this will be specific to the topic
    final Message msg = Message(
        event[0].topic, message, recMess.payload.header!.qos, DateTime.now());
    // print('MQTT Message: topic: [${msg.topic}] - ${msg.payload.toString()}');
    await FlutterPhoneDirectCaller.callNumber(msg.payload['phone']);
    setState(() {
      messages.add(msg);
      try {
        messageController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      } catch (_) {
        // ScrollController not attached to any scroll views.
      }
    });
  }

// void _unsubscribeFromTopic(String topic) {
//   print('=======>${topic.trim()}');
//   if (isConnected) {
//     setState(() {
//       print('Unsubscribing from ${topic.trim()}');
//       client.unsubscribe(topic);
//     });
//   }
// }
}

class User {
  String name;

  User(this.name);
}
