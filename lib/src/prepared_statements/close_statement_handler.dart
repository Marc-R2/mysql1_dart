import 'package:logging/logging.dart';
import 'package:mysql1/src/buffer.dart';
import 'package:mysql1/src/constants.dart';
import 'package:mysql1/src/handlers/handler.dart';

class CloseStatementHandler extends Handler {
  CloseStatementHandler(this._handle) : super(Logger('CloseStatementHandler'));
  final int _handle;

  @override
  Buffer createRequest() {
    final buffer = Buffer(5);
    buffer.writeByte(COM_STMT_CLOSE);
    buffer.writeUint32(_handle);
    return buffer;
  }
}
