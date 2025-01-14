// ignore_for_file: strong_mode_implicit_dynamic_variable

import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:mysql1/src/buffer.dart';
import 'package:mysql1/src/constants.dart';
import 'package:mysql1/src/handlers/handler.dart';
import 'package:mysql1/src/mysql_protocol_error.dart';
import 'package:mysql1/src/prepared_statements/prepare_ok_packet.dart';
import 'package:mysql1/src/prepared_statements/prepared_query.dart';
import 'package:mysql1/src/results/field.dart';

class PrepareHandler extends Handler {
  PrepareHandler(this._sql) : super(Logger('PrepareHandler'));
  final String _sql;
  late PrepareOkPacket _okPacket;
  int? _parametersToRead;
  int? _columnsToRead;
  List<Field?>? _parameters;
  List<Field?>? _columns;

  String get sql => _sql;
  PrepareOkPacket get okPacket => _okPacket;
  List<Field?>? get parameters => _parameters;
  List<Field?>? get columns => _columns;

  @override
  Buffer createRequest() {
    final encoded = utf8.encode(_sql);
    final buffer = Buffer(encoded.length + 1);
    buffer.writeByte(COM_STMT_PREPARE);
    buffer.writeList(encoded);
    return buffer;
  }

  @override
  HandlerResponse processResponse(Buffer response) {
    log.fine('Prepare processing response');
    final packet = checkResponse(response, prepareStmt: true);
    if (packet == null) {
      log.fine('Not an OK packet, params to read: $_parametersToRead');
      if (_parametersToRead != null &&
          _parameters != null &&
          _parametersToRead! > -1) {
        if (response[0] == PACKET_EOF) {
          log.fine('EOF');
          if (_parametersToRead != 0) {
            throw createMySqlProtocolError(
              'Unexpected EOF packet; was expecting another $_parametersToRead parameter(s)',
            );
          }
        } else {
          final fieldPacket = Field(response);
          log.fine('field packet: $fieldPacket');
          _parameters![_okPacket.parameterCount - _parametersToRead!] =
              fieldPacket;
        }
        _parametersToRead = _parametersToRead! - 1;
      } else if (_columnsToRead != null &&
          _columns != null &&
          _columnsToRead! > -1) {
        if (response[0] == PACKET_EOF) {
          log.fine('EOF');
          if (_columnsToRead != 0) {
            throw createMySqlProtocolError(
              'Unexpected EOF packet; was expecting another $_columnsToRead column(s)',
            );
          }
        } else {
          final fieldPacket = Field(response);
          log.fine('field packet (column): $fieldPacket');
          _columns![_okPacket.columnCount - _columnsToRead!] = fieldPacket;
        }
        _columnsToRead = _columnsToRead! - 1;
      }
    } else if (packet is PrepareOkPacket) {
      log.fine(packet.toString());
      _okPacket = packet;
      _parametersToRead = packet.parameterCount;
      _columnsToRead = packet.columnCount;
      _parameters = List<Field?>.filled(_parametersToRead!, null);
      _columns = List<Field?>.filled(_columnsToRead!, null);
      if (_parametersToRead == 0) {
        _parametersToRead = -1;
      }
      if (_columnsToRead == 0) {
        _columnsToRead = -1;
      }
    }

    if (_parametersToRead == -1 && _columnsToRead == -1) {
      log.fine('finished');
      return HandlerResponse(finished: true, result: PreparedQuery(this));
    }
    return HandlerResponse.notFinished;
  }
}
