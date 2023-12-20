import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:path_provider/path_provider.dart';

class WebService {
  const API_URL = '3.67.227.198:5002';

  Future<dynamic> supportedLanguages() async {
    var response = await http.get(Uri.http(API_URL, 'supported_language'));
    // response.statusCode
    var data = jsonDecode(response.body)['data'];
    return data;
  }

  Future<void> download(String filename) async {
    var response = await http.get(Uri.http(API_URL, 'download/$filename'));
    await convertUint8ArrayToWav(response.bodyBytes, filename);
    // await save(response.bodyBytes, filename);
    return;
  }

  Future<dynamic> ask(String language, String filepath) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.http(API_URL, 'ask/$language'),
      );
      request.files.add(await http.MultipartFile.fromPath('audio', filepath));
      var response = await request.send().timeout(Duration(seconds: 90));
      if(response.statusCode != 200){
        return response.statusCode;
      }
      var respStr = await response.stream.bytesToString();
      var res = json.decode(respStr)['data'];
      return res;
    } catch(e) {
      if (e is TimeoutException) {
        return 600;
      } else {
        return 700;
      }
    }
  }

  Future<void> convertUint8ArrayToWav(Uint8List uint8Array, String filename) async {
    File file = File((await getExternalStorageDirectory())!.path + '/' + filename);
    await file.writeAsBytes(uint8Array.toList());
  }

}