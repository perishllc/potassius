// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'receivable_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReceivableResponse _$ReceivableResponseFromJson(Map<String, dynamic> json) {
  return ReceivableResponse(
    blocks: (json['blocks'] as Map<String, dynamic>?)?.map(
      (k, e) => MapEntry(k, /*e == null ? null : */ReceivableResponseItem.fromJson(e as Map<String, dynamic>)),
    ),
  );
}

Map<String, dynamic> _$ReceivableResponseToJson(ReceivableResponse instance) => <String, dynamic>{
      'blocks': instance.blocks,
    };
