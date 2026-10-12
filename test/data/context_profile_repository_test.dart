import 'package:flutter_test/flutter_test.dart';
import 'package:almanac/data/profiles/context_profile_repository.dart';
import 'package:almanac/data/profiles/profile_kind.dart';

void main() {
  group('ContextProfileRepository', () {
    late InMemoryContextProfileRepository repo;

    setUp(() {
      repo = InMemoryContextProfileRepository();
    });

    test('starts with one default profile', () {
      expect(repo.getAll().length, 1);
      expect(repo.getActive().name, 'Личный');
    });

    test('creates unlimited profiles', () {
      repo.createProfile(name: 'Работа');
      repo.createProfile(name: 'Учёба');
      repo.createProfile(name: 'Проект X');

      expect(repo.getAll().length, 4);
    });

    test('createProfile stores kind and role', () {
      final booking = repo.createProfile(
        name: 'Салон',
        kind: ProfileKind.booking,
      );
      expect(booking.kind, ProfileKind.booking);
      expect(booking.role, ProfileRole.owner);
    });

    test('joinProfile reuses owner id as member', () {
      final joined = repo.joinProfile(
        id: 'shared-work',
        name: 'Работа',
        kind: ProfileKind.collaborative,
      );
      expect(joined.id, 'shared-work');
      expect(joined.role, ProfileRole.member);
      expect(joined.kind, ProfileKind.collaborative);
    });

    test('joinProfile rejects duplicate id', () {
      repo.joinProfile(
        id: 'shared-work',
        name: 'Работа',
        kind: ProfileKind.collaborative,
      );
      expect(
        () => repo.joinProfile(
          id: 'shared-work',
          name: 'Ещё',
          kind: ProfileKind.collaborative,
        ),
        throwsStateError,
      );
    });

    test('rejects empty profile name on create', () {
      expect(() => repo.createProfile(name: '   '), throwsArgumentError);
    });

    test('renames profile', () {
      final created = repo.createProfile(name: 'Temp');
      repo.renameProfile(id: created.id, name: 'Переименованный');

      expect(repo.getById(created.id)?.name, 'Переименованный');
    });

    test('rejects empty name on rename', () {
      final created = repo.createProfile(name: 'Temp');
      expect(
        () => repo.renameProfile(id: created.id, name: ''),
        throwsArgumentError,
      );
    });

    test('deletes profile and switches active if needed', () {
      final work = repo.createProfile(name: 'Работа');
      repo.setActive(work.id);

      repo.deleteProfile(work.id);

      expect(repo.getAll().any((p) => p.id == work.id), isFalse);
      expect(repo.getActive().id, isNot(work.id));
    });

    test('cannot delete last profile', () {
      final only = repo.getActive();
      expect(() => repo.deleteProfile(only.id), throwsStateError);
      expect(repo.getAll().length, 1);
    });

    test('toggle visibility keeps at least one profile visible', () {
      final work = repo.createProfile(name: 'Работа');
      repo.toggleProfileVisibility('default');

      expect(repo.getVisibleProfileIds(), {work.id});

      repo.toggleProfileVisibility(work.id);
      expect(repo.getVisibleProfileIds(), {work.id});

      repo.toggleProfileVisibility('default');
      expect(repo.getVisibleProfileIds(), {'default', work.id});
    });
  });
}
