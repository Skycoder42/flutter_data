// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'family.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Family _$FamilyFromJson(Map<String, dynamic> json) {
  return Family(
    id: json['id'] as String,
    surname: json['surname'] as String,
    persons: json['persons'] == null
        ? null
        : HasMany.fromJson(json['persons'] as Map<String, dynamic>),
    cottage: json['cottage'] == null
        ? null
        : BelongsTo.fromJson(json['cottage'] as Map<String, dynamic>),
    residence: json['residence'] == null
        ? null
        : BelongsTo.fromJson(json['residence'] as Map<String, dynamic>),
    dogs: json['dogs'] == null
        ? null
        : HasMany.fromJson(json['dogs'] as Map<String, dynamic>),
  );
}

Map<String, dynamic> _$FamilyToJson(Family instance) => <String, dynamic>{
      'id': instance.id,
      'surname': instance.surname,
      'persons': instance.persons?.toJson(),
      'cottage': instance.cottage?.toJson(),
      'residence': instance.residence?.toJson(),
      'dogs': instance.dogs?.toJson(),
    };

// **************************************************************************
// RepositoryGenerator
// **************************************************************************

// ignore_for_file: unused_local_variable, always_declare_return_types, non_constant_identifier_names, invalid_use_of_protected_member

mixin $FamilyLocalAdapter on LocalAdapter<Family> {
  @override
  Map<String, Map<String, Object>> relationshipsFor([Family model]) => {
        'persons': {
          'inverse': 'family',
          'type': 'people',
          'kind': 'HasMany',
          'instance': model?.persons
        },
        'cottage': {
          'inverse': 'owner',
          'type': 'houses',
          'kind': 'BelongsTo',
          'instance': model?.cottage
        },
        'residence': {
          'inverse': 'owner',
          'type': 'houses',
          'kind': 'BelongsTo',
          'instance': model?.residence
        },
        'dogs': {'type': 'dogs', 'kind': 'HasMany', 'instance': model?.dogs}
      };

  @override
  deserialize(map) {
    for (final key in relationshipsFor().keys) {
      map[key] = {
        '_': [map[key], !map.containsKey(key)],
      };
    }
    return _$FamilyFromJson(map);
  }

  @override
  serialize(model) => _$FamilyToJson(model);
}

// ignore: must_be_immutable
class $FamilyHiveLocalAdapter = HiveLocalAdapter<Family>
    with $FamilyLocalAdapter;

class $FamilyRemoteAdapter = RemoteAdapter<Family> with NothingMixin;

//

final familiesLocalAdapterProvider = Provider<LocalAdapter<Family>>((ref) =>
    $FamilyHiveLocalAdapter(
        ref.read(hiveLocalStorageProvider), ref.read(graphProvider)));

final familiesRemoteAdapterProvider = Provider<RemoteAdapter<Family>>(
    (ref) => $FamilyRemoteAdapter(ref.read(familiesLocalAdapterProvider)));

final familiesRepositoryProvider =
    Provider<Repository<Family>>((_) => Repository<Family>());

extension FamilyX on Family {
  Family init([owner]) {
    if (owner == null && debugGlobalServiceLocatorInstance != null) {
      return debugInit(
          debugGlobalServiceLocatorInstance.get<Repository<Family>>());
    }
    return debugInit(owner.ref.read(familiesRepositoryProvider));
  }
}

extension FamilyRepositoryX on Repository<Family> {}
