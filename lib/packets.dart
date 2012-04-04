interface SendablePacket {
  Buffer get buffer();
}

class ClientAuthPacket implements SendablePacket {
  Buffer _buffer;
  
  ClientAuthPacket(bool newProtocol, int clientFlags, int maxPacketSize, int collation,
      String user, String password, List<int> scrambleBuffer) {
    if (!newProtocol) {
      throw "4.0 protocol not supported";
    }
    
    print("creating packet");
    List<int> hash;
    if (password == null) {
      hash = new List<int>(0);
    } else {
      hash:Hash x = new Sha1();
      x.updateString(password);
      List<int> digest = x.digest();
      
      hash:Hash x2 = new Sha1();
      x2.update(scrambleBuffer);
      x2.update(digest);
      
      List<int> newdigest = x2.digest();
      List<int> hash = new List<int>(newdigest.length);
      for (int i = 0; i < hash.length; i++) {
        hash[i] = digest[i] ^ newdigest[i];
      }
      print("got digest");
    }
    
    int size = hash.length + user.length + 2 + 32;;
    
    _buffer = new Buffer(size);
    _buffer.seekWrite(0);
    _buffer.writeInt32(clientFlags);
    _buffer.writeInt32(maxPacketSize);
    _buffer.writeByte(collation);
    _buffer.fill(23, 0);
    _buffer.writeNullTerminatedString(user);
    _buffer.writeByte(hash.length);
    _buffer.writeList(hash);
    
    print("made packet ${_buffer._list}");
  }
  
  Buffer get buffer() {
    return _buffer;
  }
}

class HandshakePacket {
  int protocolVersion;
  String serverVersion;
  int threadId;
  List<int> scrambleBuffer;
  List<int> restOfScrambleBuffer;
  int serverCapabilities;
  int serverLanguage;
  int serverStatus;
  int scrambleLength;
  
  HandshakePacket(Buffer buffer) {
    buffer.seek(0);
    protocolVersion = buffer.readByte();
    serverVersion = buffer.readNullTerminatedString();
    threadId = buffer.readInt32();
    scrambleBuffer = buffer.readList(8);
    buffer.skip(1);
    serverCapabilities = buffer.readInt16();
    serverLanguage = buffer.readByte();
    serverStatus = buffer.readInt16();
//    serverCapabilities += buffer.readInt16() << 16;
//    restOfScrambleBuffer = buffer.readNullTerminatedList();
  }
  
  bool isNewProtocol() {
    return (serverCapabilities & CLIENT_PROTOCOL_41) > 0;
  }
  
  void show() {
    print("protocol version $protocolVersion");
    print("server version $serverVersion");
    print("thread id $threadId");
    print("scramble buffer $scrambleBuffer");
    print("server capabilities $serverCapabilities");
    print("server language $serverLanguage");
    print("server status $serverStatus");
    if (isNewProtocol()) {
      print("new protocol");
    }
  }
}

