import 'dart:math';
import 'dart:io' as io;

import 'package:assistant/WebService.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

late final String filesDirectory;

void main(){
  runApp(MyApp());
}

class MyApp extends StatelessWidget{
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'BarkTalk',
        theme: ThemeData(
          colorScheme: ColorScheme.light(
          primary: Colors.indigo,
          secondary: Colors.indigo,
        )),
      debugShowCheckedModeBanner: false,
      home: Home(),
    );
  }
}

class Home extends StatefulWidget{
  @override
  _HomeState createState() => _HomeState();
}

TextDirection appDirection = TextDirection.ltr;
double appWidth = 0;
String lastFilePath = '';
bool isPlaying = false;


class _HomeState extends State<Home> {
  late WebService webService;
  _HomeState() {
    webService = WebService();
  }

  TextEditingController editingController = TextEditingController();

  int maxduration = 100;
  final stopwatch = Stopwatch();

  AudioPlayer player = AudioPlayer();

  String selectedValue = 'en';
  bool record = false;
  List<Map<String, dynamic>> messages = [];

  String currentfilename = '';

  final _soundRecorder = Record();

  late final dynamic langs;
  dynamic items = List<String>.empty();

  bool waitingForRes = false;
  int hasPermission = 0;


  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    initializer();
    // updateFilesList();
    removeFiles();
  }

  checkMicPermission() async {

  }

  void _startRecording() async {
    var per = false;
    if(hasPermission == 0){
      per = await Permission.microphone.isGranted;
      if(per)
        hasPermission = 1;
    }
    if(hasPermission == 0) {
      await Permission.microphone.request();
    } else {
      if(!waitingForRes){
        currentfilename = Random().nextDouble().toString();
        var path = '${(await getExternalStorageDirectory())?.path}/${currentfilename}.wav';
        lastFilePath = path;
        await _soundRecorder.start(
          path: path,
          encoder: AudioEncoder.wav,
        );
      }
    }
  }

  void _endRecording() async {
      if(!waitingForRes && hasPermission == 1){
        await _soundRecorder.stop();
        setState(() {
          waitingForRes = true;
        });
        var res = await webService.ask(selectedValue, lastFilePath);
        if(res is int){
          var errorText = '';
          switch (res) {
            case 400:
              errorText = 'Can not recognize voice.';
            case 500:
              errorText = 'Server error.';
            case 600:
              errorText = 'Connection Timeout.';
            default:
              errorText = 'Unknown error.';
          }
          showToast(context, '$errorText Try again...');
          setState(() {
            waitingForRes = false;
          });
          return;
        }
        await webService.download(res['answer']['file_name']);
        _newRes(res);
      }
  }

  void _newRes(res) async {
    setState(() {
      waitingForRes = false;
      messages.add(
      {
        "fromApp": false,
        'text': res['prompt'],
        'promptLang': langs[res['prompt_language']],
      });
      messages.add(
      {
        "fromApp": true,
        'text': res['answer']['text'],
        'filename': res['answer']['file_name'],
        'path': res['answer']['voice_path'],
        'localpath': '$filesDirectory/${res['answer']['file_name']}',
        'promptLang': langs[res['answer']['answer_language']],
      });
    });
    player.play(DeviceFileSource(messages.last['localpath']));
    isPlaying = true;
    player.onPlayerComplete.listen((event) {
      isPlaying = false;
    });
  }

  void initializer() async {
    filesDirectory = (await getExternalStorageDirectory())!.path;
    var data = await webService.supportedLanguages();

    setState(() {
      langs = data;
    });
  }

  void removeFiles() async {
    var directory = (await getExternalStorageDirectory())!.path;
    var files = io.Directory(directory).listSync();
    files.forEach((element) {
      element.delete();
    });
  }

  void updateFilesList() async {
  }

  void showModal(BuildContext context){
    items = langs;
    showModalBottomSheet(
        context: context,
        builder: (context){
          return StatefulBuilder(builder: (BuildContext context, StateSetter mystate) {
          return Container(
            padding: EdgeInsets.all(8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(50)),
            ),
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    onChanged: (value) {
                      var temp = langs.entries.where((e) => e.value.toString().toLowerCase().startsWith(value.toLowerCase()));
                      var res = { for (var v in temp) v.key: v.value };
                      mystate(() {
                        items = res;
                      });
                    },
                    controller: editingController,
                    decoration: InputDecoration(
                        labelText: "Language",
                        hintText: "Language",
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(25.0)))
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: items.entries.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: TextButton(child: Text('${items.entries.elementAt(index).value}', style: TextStyle(color: Colors.black),),
                        onPressed: () {
                          Navigator.of(context).pop('${items.entries.elementAt(index).key}');
                        },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        });
        }
    ).then((value) {
      setState(() {
        selectedValue = value;
      });
    });
  }

  void showToast(BuildContext context, String txt, {bool isError = true}) {
    FToast fToast = FToast();
    fToast.init(context);
    Widget toast = Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration:
        BoxDecoration(borderRadius: BorderRadius.circular(24.0), color: isError ? Colors.red : Colors.indigo),
        child: Text(txt, style: TextStyle(color: Colors.white)));
    fToast.showToast(child: toast, gravity: ToastGravity.BOTTOM, toastDuration: Duration(seconds: 2));
  }

  @override
  Widget build(BuildContext context) {
    appWidth = MediaQuery.of(context).size.width;

    return SafeArea(child: Scaffold(
      backgroundColor: Color(0xffdddded),
      appBar: AppBar(
        centerTitle: true,
        title: Text('Bark Talk'),
      ),
      floatingActionButton: GestureDetector(
        onLongPress: () {
          _startRecording();
        },
        onLongPressEnd: (details) async {
          _endRecording();
        },
        child:
          FloatingActionButton( //Floating action button on Scaffold
          onPressed: (){

          },
          child: waitingForRes ? SpinKitDoubleBounce(
            color: Colors.white,
            size: 50,
          ) : Icon(Icons.mic, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      bottomNavigationBar: BottomAppBar( //bottom navigation bar on scaffold
        color: Colors.indigoAccent,
        shape: CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row( //children inside bottom appbar
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            GestureDetector(
              onTap: () {
                showModal(context);
              },
              child: Padding(
                padding: EdgeInsets.only(left: 20, top: 15, bottom: 15),
                child: Row(
                  children: [
                    Padding(
                        child: Icon(Icons.language, color: Colors.white),
                        padding: EdgeInsets.symmetric(horizontal: 5)),
                    Text("${selectedValue[0].toUpperCase()}${selectedValue.substring(1).toLowerCase()}", style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
      body: messages.isEmpty
          ? Center(child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Hold '),
          Icon(Icons.mic),
          Text(' To Record')
        ],
      ))
          : Padding(
              child: ListView(
                children: messages.map((e) => bubble(ChatEntry(sent: e['fromApp'], text: e['text'], promptLang: e['promptLang']))).toList(),
              ),
              padding: EdgeInsets.only(bottom: 0, top: 5, left: 5, right: 5),
      ),
    ));
  }
}


class ChatEntry {
  final String text;
  final bool sent;
  final String promptLang;

  ChatEntry({
    this.text = '',
    this.sent = false,
    this.promptLang = '',
  });
}



Widget bubble(ChatEntry entry) {
  final kSentColor = Color(0xff02ab83);
  final kReceivedColor = Color(0xff0251d6);
  final kBorderRadius = 15.0;
  final kBubblePadding = const EdgeInsets.symmetric(
    horizontal: 15.0,
    vertical: 10.0,
  );
  final kBubbleTextStyle = const TextStyle(
    color: Color(0xffeeeeee),
    fontSize: 16.0,
    fontWeight: FontWeight.w600,
  );

    return Align(
      alignment: entry.sent ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(top: 5, bottom: !entry.sent ? 0 : 15),
        child: Container(
          padding: kBubblePadding,
          decoration: BoxDecoration(
            color: (entry.sent ? kSentColor : kReceivedColor)
                .withOpacity(1),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(kBorderRadius),
              topRight: Radius.circular(kBorderRadius),
              bottomRight: Radius.circular(entry.sent ? 0.0 : kBorderRadius),
              bottomLeft: Radius.circular(entry.sent ? kBorderRadius : 0.0),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
            entry.sent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: <Widget>[
               Text(entry.text, style: kBubbleTextStyle),
                Text(entry.promptLang, style: TextStyle(color: Colors.white60))
            ],
          ),
        ),
      ),
    );
}

