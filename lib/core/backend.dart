import 'dart:convert';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

abstract interface class Backend {
  Future<dynamic> call(String action, [Map<String, dynamic> args = const {}]);
}

class BackendException implements Exception {
  const BackendException(this.code, this.message);
  final String code, message;
  @override
  String toString() => '$code: $message';
}

class RustBackend implements Backend {
  @override
  Future<dynamic> call(
    String action, [
    Map<String, dynamic> args = const {},
  ]) async {
    final result = await compute(
      _callRust,
      jsonEncode({'action': action, ...args}),
    );
    if (result['ok'] != true) {
      final error = result['error'] as Map<String, dynamic>;
      throw BackendException(
        error['code'] as String,
        error['message'] as String,
      );
    }
    return result['data'];
  }
}

// Root commands and JNI work run on worker isolates, keeping the UI thread free.
Map<String, dynamic> _callRust(String request) {
  final library = DynamicLibrary.open('libsysleaf_core.so');
  final invoke = library
      .lookupFunction<
        Pointer<Utf8> Function(Pointer<Utf8>),
        Pointer<Utf8> Function(Pointer<Utf8>)
      >('sysleaf_call');
  final free = library
      .lookupFunction<
        Void Function(Pointer<Utf8>),
        void Function(Pointer<Utf8>)
      >('sysleaf_free');
  final input = request.toNativeUtf8();
  Pointer<Utf8> output = nullptr;
  try {
    output = invoke(input);
    if (output == nullptr) throw StateError('Rust returned a null response.');
    return jsonDecode(output.toDartString()) as Map<String, dynamic>;
  } finally {
    calloc.free(input);
    if (output != nullptr) free(output);
  }
}
