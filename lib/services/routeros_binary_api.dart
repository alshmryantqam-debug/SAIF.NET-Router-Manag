import 'dart:io';
/// TCP reachability check only. RouterOS v6 API authentication/commands are not implemented.
class RouterOsBinaryApi {Future<bool> testPort(String host,int port) async {Socket? s;try{s=await Socket.connect(host,port,timeout:const Duration(seconds:3));return true;}catch(_){return false;}finally{s?.destroy();}}}
