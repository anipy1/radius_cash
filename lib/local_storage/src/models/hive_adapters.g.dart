// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_adapters.dart';

// **************************************************************************
// AdaptersGenerator
// **************************************************************************

class BountyCMAdapter extends TypeAdapter<BountyCM> {
  @override
  final typeId = 0;

  @override
  BountyCM read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BountyCM(
      id: fields[0] as String,
      authorPeerId: fields[1] as String,
      authorSigningKey: fields[2] as Uint8List,
      record: fields[3] as Uint8List,
      title: fields[4] as String,
      details: fields[5] as String,
      amountCents: (fields[6] as num).toInt(),
      createdAt: (fields[7] as num).toInt(),
      expiresAt: (fields[8] as num).toInt(),
      updatedAt: (fields[9] as num).toInt(),
      status: (fields[10] as num).toInt(),
      claimantPeerId: fields[11] as String?,
      geohash: fields[12] == null ? '' : fields[12] as String,
      viaInternet: fields[13] == null ? false : fields[13] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, BountyCM obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.authorPeerId)
      ..writeByte(2)
      ..write(obj.authorSigningKey)
      ..writeByte(3)
      ..write(obj.record)
      ..writeByte(4)
      ..write(obj.title)
      ..writeByte(5)
      ..write(obj.details)
      ..writeByte(6)
      ..write(obj.amountCents)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.expiresAt)
      ..writeByte(9)
      ..write(obj.updatedAt)
      ..writeByte(10)
      ..write(obj.status)
      ..writeByte(11)
      ..write(obj.claimantPeerId)
      ..writeByte(12)
      ..write(obj.geohash)
      ..writeByte(13)
      ..write(obj.viaInternet);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BountyCMAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ClaimCMAdapter extends TypeAdapter<ClaimCM> {
  @override
  final typeId = 1;

  @override
  ClaimCM read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ClaimCM(
      bountyId: fields[0] as String,
      claimantPeerId: fields[1] as String,
      note: fields[2] as String,
      sentAt: (fields[3] as num).toInt(),
      status: (fields[4] as num).toInt(),
      receivedAt: (fields[5] as num?)?.toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, ClaimCM obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.bountyId)
      ..writeByte(1)
      ..write(obj.claimantPeerId)
      ..writeByte(2)
      ..write(obj.note)
      ..writeByte(3)
      ..write(obj.sentAt)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.receivedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClaimCMAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WitnessCMAdapter extends TypeAdapter<WitnessCM> {
  @override
  final typeId = 2;

  @override
  WitnessCM read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WitnessCM(
      bountyId: fields[0] as String,
      claimantPeerId: fields[1] as String,
      witnessPeerId: fields[2] as String,
      record: fields[3] as Uint8List,
      at: (fields[4] as num).toInt(),
      mine: fields[5] == null ? false : fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, WitnessCM obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.bountyId)
      ..writeByte(1)
      ..write(obj.claimantPeerId)
      ..writeByte(2)
      ..write(obj.witnessPeerId)
      ..writeByte(3)
      ..write(obj.record)
      ..writeByte(4)
      ..write(obj.at)
      ..writeByte(5)
      ..write(obj.mine);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WitnessCMAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
