import 'package:flutter_data/flutter_data.dart';
import 'package:json_annotation/json_annotation.dart';

part 'pet.g.dart';

abstract class Pet<T extends Pet<T>> with DataModel<T> {
  @override
  final String? id;
  Pet(this.id);
}

@DataRepository([])
@JsonSerializable()
class Dog extends Pet<Dog> {
  final String name;
  // NOTE: do not add BelongsTo<Familia>, we are testing that
  // one-way relationship (Familia: HasMany<Dog>)
  Dog({String? id, required this.name}) : super(id);
  factory Dog.fromJson(Map<String, dynamic> json) => _$DogFromJson(json);
  Map<String, dynamic> toJson() => _$DogToJson(this);

  @override
  String toString() {
    return '{ id: $id, name: $name }';
  }
}

@DataRepository([])
@JsonSerializable()
class Cat extends Pet<Cat> {
  final bool meow;

  Cat({String? id, required this.meow}) : super(id);
  factory Cat.fromJson(Map<String, dynamic> json) => _$CatFromJson(json);
  Map<String, dynamic> toJson() => _$CatToJson(this);
}
