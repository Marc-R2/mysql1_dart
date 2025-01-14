// ignore_for_file: argument_type_not_assignable, return_of_invalid_type, strong_mode_implicit_dynamic_return, strong_mode_implicit_dynamic_variable, invalid_assignment, strong_mode_implicit_dynamic_parameter, strong_mode_implicit_dynamic_type

import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:mysql1/src/blob.dart';
import 'package:mysql1/src/buffer.dart';
import 'package:mysql1/src/constants.dart';
import 'package:mysql1/src/handlers/handler.dart';
import 'package:mysql1/src/handlers/ok_packet.dart';
import 'package:mysql1/src/mysql_client_error.dart';
import 'package:mysql1/src/prepared_statements/binary_data_packet.dart';
import 'package:mysql1/src/prepared_statements/prepared_query.dart';
import 'package:mysql1/src/query/result_set_header_packet.dart';
import 'package:mysql1/src/results/field.dart';
import 'package:mysql1/src/results/results_impl.dart';
import 'package:mysql1/src/results/row.dart';

class ExecuteQueryHandler extends Handler {
  ExecuteQueryHandler(this._preparedQuery, this._executed, this._values)
      : fieldPackets = <Field>[],
        super(Logger('ExecuteQueryHandler'));
  static const int STATE_HEADER_PACKET = 0;
  static const int STATE_FIELD_PACKETS = 1;
  static const int STATE_ROW_PACKETS = 2;

  int _state = STATE_HEADER_PACKET;

  List<Field> fieldPackets;

//  Map<Symbol, int> _fieldIndex;
  StreamController<ResultRow>? _streamController;

  final PreparedQuery? _preparedQuery;
  final List<Object?> _values;
  List<Object?>? preparedValues;
  late OkPacket _okPacket;
  final bool _executed;
  bool _cancelled = false;

  @override
  Buffer createRequest() {
    var length = 0;
    final types = List<int>.filled(_values.length * 2, 0);

    final nullMap = createNullMap();
    preparedValues = List.filled(_values.length, null);
    for (var i = 0; i < _values.length; i++) {
      final value = _values[i];
      final parameterType = _getType(value);
      types[i * 2] = parameterType;
      types[i * 2 + 1] = 0;
      preparedValues![i] = prepareValue(value);
      length += measureValue(value, preparedValues![i]);
    }

    final buffer = writeValuesToBuffer(nullMap, length, types);
    return buffer;
  }

  Object? prepareValue(Object? value) {
    if (value == null) return null;
    if (value is int) return _prepareInt(value);
    if (value is double) return _prepareDouble(value);
    if (value is DateTime) return _prepareDateTime(value);
    if (value is bool) return _prepareBool(value);
    if (value is List<int>) return _prepareList(value);
    if (value is Blob) return _prepareBlob(value);
    return _prepareString(value.toString());
  }

  int measureValue(dynamic value, dynamic preparedValue) {
    if (value == null) return 0;
    if (value is int) return _measureInt(value, preparedValue);
    if (value is double) return _measureDouble(value, preparedValue);
    if (value is DateTime) return _measureDateTime(value, preparedValue);
    if (value is bool) return _measureBool(value, preparedValue);
    if (value is List<int>) return _measureList(value, preparedValue);
    if (value is Blob) return _measureBlob(value, preparedValue);
    return _measureString(value, preparedValue);
  }

  int _getType(Object? value) {
    if (value == null) return FIELD_TYPE_NULL;
    if (value is int) return FIELD_TYPE_LONGLONG;
    if (value is double) return FIELD_TYPE_VARCHAR;
    if (value is DateTime) return FIELD_TYPE_DATETIME;
    if (value is bool) return FIELD_TYPE_TINY;
    if (value is List<int>) return FIELD_TYPE_BLOB;
    if (value is Blob) return FIELD_TYPE_BLOB;

    return FIELD_TYPE_VARCHAR;
  }

  void _writeValue(Object? value, Object preparedValue, Buffer buffer) {
    if (value == null) return;
    if (value is int) return _writeInt(value, preparedValue, buffer);
    if (value is double) return _writeDouble(value, preparedValue, buffer);
    if (value is DateTime) return _writeDateTime(value, preparedValue, buffer);
    if (value is bool) return _writeBool(value, preparedValue, buffer);
    if (value is List<int>) return _writeList(value, preparedValue, buffer);
    if (value is Blob) return _writeBlob(value, preparedValue, buffer);
    return _writeString(value.toString(), preparedValue, buffer);
  }

  int _prepareInt(int value) => value;

  int _measureInt(value, preparedValue) => 8;

  void _writeInt(int value, preparedValue, Buffer buffer) {
    log.fine('LONG: $value');
    buffer.writeByte(value >> 0x00 & 0xFF);
    buffer.writeByte(value >> 0x08 & 0xFF);
    buffer.writeByte(value >> 0x10 & 0xFF);
    buffer.writeByte(value >> 0x18 & 0xFF);
    buffer.writeByte(value >> 0x20 & 0xFF);
    buffer.writeByte(value >> 0x28 & 0xFF);
    buffer.writeByte(value >> 0x30 & 0xFF);
    buffer.writeByte(value >> 0x38 & 0xFF);
//          }
  }

  List<int> _prepareDouble(double value) => utf8.encode(value.toString());

  int _measureDouble(double value, dynamic preparedValue) {
    return Buffer.measureLengthCodedBinary(preparedValue.length) +
        (preparedValue.length as int);
  }

  void _writeDouble(double value, dynamic preparedValue, Buffer buffer) {
    log.fine('DOUBLE: $value');

    buffer.writeLengthCodedBinary(preparedValue.length);
    buffer.writeList(preparedValue);

    // TODO: if you send a double value for a decimal field, it doesn't like it
//          types.add(FIELD_TYPE_FLOAT);
//          types.add(0);
//          values.addAll(doubleToList(value));
  }

  DateTime _prepareDateTime(DateTime value) {
    // The driver requires DateTime values to be in UTC and will always give back a UTC DateTime.
    if (!value.isUtc) throw MySqlClientError('DateTime value is not in UTC');
    return value;
  }

  int _measureDateTime(value, preparedValue) => 8;

  void _writeDateTime(DateTime value, preparedValue, Buffer buffer) {
    // TODO remove Date eventually
    log.fine('DATE: $value');
    buffer.writeByte(7);
    buffer.writeByte(value.year >> 0x00 & 0xFF);
    buffer.writeByte(value.year >> 0x08 & 0xFF);
    buffer.writeByte(value.month);
    buffer.writeByte(value.day);
    buffer.writeByte(value.hour);
    buffer.writeByte(value.minute);
    buffer.writeByte(value.second);
  }

  bool _prepareBool(bool value) => value;

  int _measureBool(value, preparedValue) => 1;

  void _writeBool(bool value, preparedValue, Buffer buffer) {
    log.fine('BOOL: $value');
    buffer.writeByte(value ? 1 : 0);
  }

  List<int> _prepareList(List<int> value) => value;

  int _measureList(List<int> value, dynamic preparedValue) {
    return Buffer.measureLengthCodedBinary(value.length) + value.length;
  }

  void _writeList(List<int> value, preparedValue, Buffer buffer) {
    log.fine('LIST: $value');
    buffer.writeLengthCodedBinary(value.length);
    buffer.writeList(value);
  }

  List<int> _prepareBlob(Blob value) => value.toBytes();

  int _measureBlob(Blob value, preparedValue) {
    return Buffer.measureLengthCodedBinary(preparedValue.length) +
        (preparedValue.length as int);
  }

  void _writeBlob(Blob value, preparedValue, Buffer buffer) {
    log.fine('BLOB: $value');
    buffer.writeLengthCodedBinary(preparedValue.length);
    buffer.writeList(preparedValue);
  }

  List<int> _prepareString(String value) => utf8.encode(value);

  int _measureString(String value, preparedValue) {
    return Buffer.measureLengthCodedBinary(preparedValue.length) +
        (preparedValue.length as int);
  }

  void _writeString(String value, preparedValue, Buffer buffer) {
    log.fine('STRING: $value');
    buffer.writeLengthCodedBinary(preparedValue.length);
    buffer.writeList(preparedValue);
  }

  List<int> createNullMap() {
    final bytes = ((_values.length + 7) / 8).floor();
    final nullMap = List<int>.filled(bytes, 0);
    var byte = 0;
    var bit = 0;
    for (var i = 0; i < _values.length; i++) {
      if (_values[i] == null) nullMap[byte] = nullMap[byte] + (1 << bit);
      bit++;
      if (bit > 7) {
        bit = 0;
        byte++;
      }
    }
    return nullMap;
  }

  Buffer writeValuesToBuffer(List<int> nullMap, int length, List<int> types) {
    final buffer = Buffer(10 + nullMap.length + 1 + types.length + length);
    buffer.writeByte(COM_STMT_EXECUTE);
    buffer.writeUint32(_preparedQuery!.statementHandlerId);
    buffer.writeByte(0);
    buffer.writeUint32(1);
    buffer.writeList(nullMap);
    if (!_executed) {
      buffer.writeByte(1);
      buffer.writeList(types);
      for (var i = 0; i < _values.length; i++) {
        _writeValue(_values[i], preparedValues![i]!, buffer);
      }
    } else {
      buffer.writeByte(0);
    }
    return buffer;
  }

  @override
  HandlerResponse processResponse(Buffer response) {
    var packet;
    if (_cancelled) {
      _streamController?.close();
      return HandlerResponse(finished: true);
    }
    if (_state == STATE_HEADER_PACKET) {
      packet = checkResponse(response);
    }
    if (packet == null) {
      if (response[0] == PACKET_EOF) {
        log.fine('Got an EOF');
        if (_state == STATE_FIELD_PACKETS) {
          return _handleEndOfFields();
        } else if (_state == STATE_ROW_PACKETS) {
          return _handleEndOfRows();
        }
      } else {
        switch (_state) {
          case STATE_HEADER_PACKET:
            _handleHeaderPacket(response);
            break;
          case STATE_FIELD_PACKETS:
            _handleFieldPacket(response);
            break;
          case STATE_ROW_PACKETS:
            _handleRowPacket(response);
            break;
        }
      }
    } else if (packet is OkPacket) {
      _okPacket = packet;
      if ((packet.serverStatus & SERVER_MORE_RESULTS_EXISTS) == 0) {
        return HandlerResponse(
          finished: true,
          result: ResultsStream(
            _okPacket.insertId,
            _okPacket.affectedRows,
            null,
          ),
        );
      }
    }
    return HandlerResponse.notFinished;
  }

  HandlerResponse _handleEndOfFields() {
    _state = STATE_ROW_PACKETS;
    _streamController = StreamController<ResultRow>();
    _streamController!.onCancel = () {
      _cancelled = true;
    };
    return HandlerResponse(
      result: ResultsStream(
        null,
        null,
        fieldPackets,
        stream: _streamController?.stream,
      ),
    );
  }

  HandlerResponse _handleEndOfRows() {
    _streamController?.close();
    return HandlerResponse(finished: true);
  }

  void _handleHeaderPacket(Buffer response) {
    log.fine('Got a header packet');
    final resultSetHeaderPacket = ResultSetHeaderPacket(response);
    log.fine(resultSetHeaderPacket.toString());
    _state = STATE_FIELD_PACKETS;
  }

  void _handleFieldPacket(Buffer response) {
    log.fine('Got a field packet');
    final fieldPacket = Field(response);
    log.fine(fieldPacket.toString());
    fieldPackets.add(fieldPacket);
  }

  void _handleRowPacket(Buffer response) {
    log.fine('Got a row packet');
    final dataPacket = BinaryDataPacket(response, fieldPackets);
    log.fine(dataPacket.toString());
    _streamController?.add(dataPacket);
  }
}
