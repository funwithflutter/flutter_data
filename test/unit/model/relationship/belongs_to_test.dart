import 'package:flutter_data/flutter_data.dart';
import 'package:test/test.dart';

import '../../../models/family.dart';
import '../../../models/house.dart';
import '../../../models/person.dart';
import '../../setup.dart';

void main() async {
  setUpAll(setUpAllFn);
  tearDownAll(tearDownAllFn);

  test('constructor', () {
    var manager = injection.locator<DataManager>();
    var rel = BelongsTo<Person>(null, manager);
    expect(rel.key, isNull);
    rel = BelongsTo<Person>(Person(id: '1', name: 'zzz', age: 7), manager);
    expect(rel.key, manager.dataId<Person>('1').key);
  });

  test('deserialize with included BelongsTo', () async {
    // exceptionally uses this repo so we can supply included models
    var repo = injection.locator<FamilyRepositoryWithStandardJSONAdapter>();
    var houseRepo = injection.locator<Repository<House>>();

    var house = {'id': '432337', 'address': 'Ozark Lake, MO'};
    var familyJson = {'surname': 'Byrde', 'house': house};
    repo.deserialize(familyJson);

    expect(await houseRepo.findOne('432337'),
        predicate((p) => p.address == 'Ozark Lake, MO'));
  });

  test('fromJson', () {
    var repo = injection.locator<Repository<Person>>();
    var manager = repo.manager;

    var rel = BelongsTo<Person>.fromJson({
      '_': [manager.dataId<Person>('1').key, manager]
    });
    var person = Person(id: '1', name: 'zzz', age: 7);
    repo.save(person);

    expect(rel, BelongsTo<Person>(person, manager));
    expect(rel.key, manager.dataId<Person>('1').key);
    expect(rel.value, person);
  });

  test('set owner in relationships', () {
    var adapter = injection.locator<Repository<Family>>();
    var person = Person(id: '1', name: 'John', age: 37);
    var house = House(id: '31', address: '123 Main St');
    var family = Family(
        id: '1',
        surname: 'Smith',
        house: BelongsTo<House>(house),
        persons: HasMany<Person>({person}));

    // no dataId associated to family or relationships
    expect(family.house.key, isNull);
    expect(family.persons.keys, isEmpty);

    adapter.syncRelationships(family);

    // relationships are now associated to a dataId
    expect(family.house.key, adapter.manager.dataId<House>('31'));
    expect(family.persons.keys.first, adapter.manager.dataId<Person>('1'));
  });

  test('watch', () {
    var repository = injection.locator<Repository<Family>>();
    var family = Family(
      id: '1',
      surname: 'Smith',
      house: BelongsTo<House>(),
    ).init(repository);

    var notifier = family.house.watch();
    for (var i = 0; i < 3; i++) {
      if (i == 1) family.house.value = House(id: '31', address: '123 Main St');
      if (i == 2) family.house.value = null;
      var dispose = notifier.addListener((state) {
        if (i == 0) expect(state.model, null);
        if (i == 1) expect(state.model, family.house.value);
        if (i == 2) expect(state.model, null);
      });
      dispose();
    }
  });
}
