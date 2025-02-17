import 'dart:convert';
import 'dart:io';

import 'package:flutter_data/flutter_data.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import '../_support/book.dart';
import '../_support/familia.dart';
import '../_support/setup.dart';
import '../mocks.dart';

void main() async {
  setUp(setUpFn);
  tearDown(tearDownFn);

  test('watchAllNotifier/findAll and findOne', () async {
    // cause network issue
    container.read(responseProvider.notifier).state = TestResponse(text: (_) {
      throw HandshakeException('Connection terminated during handshake');
    });

    final listener = Listener<DataState<List<BookAuthor>>?>();

    // watch
    final notifier =
        bookAuthorRepository.remoteAdapter.watchAllNotifier(remote: true);
    dispose = notifier.addListener(listener, fireImmediately: true);

    await oneMs();

    // the internal findAll should trigger an offline operation
    expect(
        bookAuthorRepository.offlineOperations.first.offlineKey, 'bookAuthors');
    expect(bookAuthorRepository.offlineOperations.first.requestType,
        DataRequestType.findAll);

    // now try to findOne
    await bookAuthorRepository.findOne(
      19,
      remote: true,
      // ignore: missing_return
      onError: (e) async {
        notifier.updateWith(exception: e);
        return null;
      },
    );

    // and verify onError does capture the `OfflineException`
    verify(listener(argThat(
      isA<DataState>().having((s) => s.exception!.toString(), 'exception',
          startsWith('OfflineException:')),
    ))).called(1); // one call per updateWith(e)

    // retry and assert there is one queued operation for findOne
    await bookAuthorRepository.offlineOperations.retry();
    await oneMs();
    expect(bookAuthorRepository.offlineOperations.only(DataRequestType.findOne),
        hasLength(1));

    // now make the response a success
    container.read(responseProvider.notifier).state =
        TestResponse.text('{"id": 19, "name": "Author Saved"}');

    // retry and assert queue is empty
    await bookAuthorRepository.offlineOperations.retry();
    await oneMs();
    expect(bookAuthorRepository.offlineOperations, isEmpty);

    // try findOne again this time without errors
    final model = await bookAuthorRepository.findOne(19, remote: true);
    expect(model!.name, equals('Author Saved'));
    await oneMs();
    expect(familiaRepository.offlineOperations, isEmpty);
  });

  test('save', () async {
    final listener = Listener<DataState<List<Familia>>?>();
    // listening to local changes enough
    final notifier =
        familiaRepository.remoteAdapter.watchAllNotifier(remote: false);

    dispose = notifier.addListener(listener, fireImmediately: true);

    // sample familia
    final familia = Familia(id: '1', surname: 'Smith');

    // network issue persisting familia
    container.read(responseProvider.notifier).state =
        TestResponse(text: (_) => throw SocketException('unreachable'));

    // must specify remote=true as repo's default is remote=false
    await familiaRepository.save(
      familia,
      // override headers & params
      headers: {'X-Override-Name': 'Mantego'},
      params: {'overrideSecondName': 'Zorrilla'},
      // ignore: missing_return
      onError: (e) async {
        // supply onError for exception to show up in notifier
        await oneMs();
        notifier.updateWith(exception: e);
        return null;
      },
      onSuccess: (model) {
        // the surname follows `X-Override-Name` + `overrideSecondName`
        // as the save has been replayed with the original headers/params
        expect(model, equals(Familia(id: '1', surname: 'Mantego Zorrilla')));
        return model as Familia;
      },
    );
    await oneMs();

    // assert it's an OfflineException
    verify(
      listener(
        argThat(
          isA<DataState>()
              .having((s) => s.exception, 'exception', isA<OfflineException>()),
        ),
      ),
    ).called(1);

    // familia is remembered as failed to persist
    expect(
        familiaRepository.offlineOperations
            .only(DataRequestType.save)
            .map((o) => o.offlineKey)
            .toList(),
        [keyFor(familia)]);

    // try with familia2
    final familia2 = Familia(id: '2', surname: 'Montewicz');
    try {
      await familiaRepository.save(familia2);
    } catch (_) {
      // without onError, ignore exception
    }
    await oneMs();

    // now two familia failed to persist
    expect(
        familiaRepository.offlineOperations
            .only(DataRequestType.save)
            .map((o) => o.offlineKey)
            .toList(),
        [keyFor(familia), keyFor(familia2)]);

    // retry saving both
    await familiaRepository.offlineOperations.retry();
    // await 1ms for each familia
    await oneMs();
    await oneMs();

    // none of them could be saved upon retry
    expect(familiaRepository.offlineOperations.map((o) => o.model),
        equals([familia, familia2]));

    // change the response to: success for familia, failure for familia2
    container.read(responseProvider.notifier).state = TestResponse(
      text: (req) {
        if (req.url.pathSegments.last == '1') {
          return '{"id": "1", "surname": "${req.headers['X-Override-Name']} ${req.url.queryParameters['overrideSecondName']}"}';
        }
        throw SocketException('unreachable');
      },
    );

    // retry
    await familiaRepository.offlineOperations.retry();
    await oneMs();
    await oneMs();

    // familia2 failed on retry, operation still pending
    expect(familiaRepository.offlineOperations.map((o) => o.model),
        equals([familia2]));

    // change response to success for both familia and familia2
    container.read(responseProvider.notifier).state = TestResponse(text: (req) {
      return '{"id": "${req.url.pathSegments.last}", "surname": "Jones ${req.url.pathSegments.last}"}';
    });

    // retry
    await familiaRepository.offlineOperations.retry();
    await oneMs();
    await oneMs();

    // should be empty as all saves succeeded
    expect(familiaRepository.offlineOperations.map((o) => o.model), isEmpty);

    // simulate a network issue once again for familia3
    container.read(responseProvider.notifier).state =
        TestResponse(text: (_) => throw SocketException('unreachable'));

    final familia3 = Familia(id: '3', surname: 'Zweck').init(container.read);
    try {
      await familia3.save(remote: true);
    } catch (_) {
      // without onError, ignore exception
    }
    await oneMs();

    // assert familia3 hasn't been persisted
    expect(
        familiaRepository.offlineOperations
            .only(DataRequestType.save)
            .map((o) => o.model),
        [familia3]);

    // use `reset` to forget/ignore failed to save models
    familiaRepository.offlineOperations.reset();

    // so it's empty again
    expect(
        familiaRepository.offlineOperations
            .only(DataRequestType.save)
            .map((o) => o.model),
        isEmpty);
  });

  test('delete', () async {
    final listener = Listener<DataState<List<Familia>>?>();
    // listening to local changes enough
    final notifier =
        familiaRepository.remoteAdapter.watchAllNotifier(remote: false);

    dispose = notifier.addListener(listener, fireImmediately: true);

    // init a familia
    final familia = Familia(id: '1', surname: 'Smith').init(container.read);
    await oneMs();

    // should show up through watchAllNotifier
    verify(listener(
      argThat(isA<DataState>().having((s) => s.model, 'model', [familia])),
    )).called(1);

    // network issue deleting familia
    container.read(responseProvider.notifier).state = TestResponse(text: (_) {
      throw SocketException('unreachable');
    });

    // delete familia and send offline exception to notifier
    await familia.delete(
      remote: true,
      onError: (e) async {
        notifier.updateWith(exception: e);
      },
    );

    // verify the model in local storage has been deleted
    verify(listener(
      argThat(isA<DataState>().having((s) => s.model, 'model', isEmpty)),
    )).called(1);

    // and that we actually got an OfflineException
    verify(listener(argThat(
      isA<DataState>()
          .having((s) => s.exception, 'exception', isA<OfflineException>()),
    ))).called(1);

    // familia is remembered as failed to persist
    expect(
        familiaRepository.offlineOperations
            .only(DataRequestType.delete)
            .map((o) => o.offlineKey),
        ['familia#1']);

    // retry
    await familiaRepository.offlineOperations.retry();
    await oneMs();

    // could not be deleted upon retry
    expect(
        familiaRepository.offlineOperations
            .only(DataRequestType.delete)
            .map((o) => o.offlineKey),
        ['familia#1']);

    // change the response to success
    container.read(responseProvider.notifier).state = TestResponse.text('');

    // retry
    await familiaRepository.offlineOperations.retry();
    await oneMs();

    // now offline queue is empty
    expect(familiaRepository.offlineOperations, isEmpty);
  });

  test('save & delete combined', () async {
    final listener = Listener<DataState<List<Familia>>?>();
    // listening to local changes enough
    final notifier =
        familiaRepository.remoteAdapter.watchAllNotifier(remote: false);

    dispose = notifier.addListener(listener, fireImmediately: true);

    // setup familia
    final familia = Familia(id: '19', surname: 'Ko').init(container.read);
    await oneMs();

    // network issues
    container.read(responseProvider.notifier).state = TestResponse(text: (_) {
      throw SocketException('unreachable');
    });

    // save...
    await familia.save(
      remote: true,
      headers: {'X-Override-Name': 'Johnson'},
      // ignore: missing_return
      onError: (e) async {
        notifier.updateWith(exception: e);
        return null;
      },
    );

    await oneMs();

    // ...and immediately delete
    await familia.delete(
      remote: true,
      onError: (e) async {
        notifier.updateWith(exception: e);
      },
    );

    await oneMs();

    // assert it's an OfflineException, TWICE (one call per updateWith(e))
    verify(listener(argThat(
      isA<DataState>()
          .having((s) => s.exception, 'exception', isA<OfflineException>()),
    ))).called(2);

    // should see the failed save queued
    expect(
        familiaRepository.offlineOperations
            .only(DataRequestType.save)
            .map((o) => o.offlineKey)
            .toList(),
        [keyFor(familia)]);

    // clearly the local model was deleted, so the associated
    // model should be null
    expect(
        familiaRepository.offlineOperations
            .only(DataRequestType.save)
            .map((o) => o.model)
            .toList(),
        [null]);

    // should see the failed delete queued
    expect(
        familiaRepository.offlineOperations
            .only(DataRequestType.delete)
            .map((o) => o.offlineKey)
            .toList(),
        ['familia#19']);

    // retry
    await familiaRepository.offlineOperations.retry();
    await oneMs();
    // same result...
    expect(familiaRepository.offlineOperations, hasLength(2));

    // change the response to success
    container.read(responseProvider.notifier).state = TestResponse.text('');

    // retry
    await familiaRepository.offlineOperations.retry();
    await oneMs();
    // done
    expect(familiaRepository.offlineOperations, isEmpty);
  });

  test('ad-hoc request with body', () async {
    // network issue
    container.read(responseProvider.notifier).state = TestResponse(text: (_) {
      throw SocketException('unreachable');
    });

    // random endpoint with random headers
    familiaRepository.remoteAdapter.sendRequest(
      '/fam'.asUri,
      method: DataRequestMethod.POST,
      headers: {'X-Sats': '9389173717732'},
      body: json.encode({'a': 2}),
      onSuccess: (_) {
        expect(
            _,
            equals([
              {'id': '19', 'surname': 'Ko Saved'}
            ]));
      },
    );
    await oneMs();
    // fails to go through
    expect(familiaRepository.offlineOperations, hasLength(1));

    // return a success response
    container.read(responseProvider.notifier).state = TestResponse(
      text: (req) {
        // assert headers are included in the retry
        expect(req.headers['X-Sats'], equals('9389173717732'));
        expect(json.decode(req.body), {'a': 2});
        return '[{"id": "19", "surname": "Ko Saved"}]';
      },
    );

    // retry
    await familiaRepository.offlineOperations.retry();
    await oneMs();
    // done
    expect(familiaRepository.offlineOperations, isEmpty);
  });

  test('another non-offline error should resolve the operation', () async {
    // network issue
    container.read(responseProvider.notifier).state = TestResponse(text: (_) {
      throw SocketException('unreachable');
    });
    familiaRepository.remoteAdapter.sendRequest('/fam'.asUri);

    await oneMs();
    // fails to go through
    expect(familiaRepository.offlineOperations, hasLength(1));

    // return a 404
    container.read(responseProvider.notifier).state =
        TestResponse(text: (_) => 'not found', statusCode: 404);

    // retry
    await familiaRepository.offlineOperations.retry();
    await oneMs();
    // done
    expect(familiaRepository.offlineOperations, isEmpty);
  });

  test('operation equality', () {
    final o1 = OfflineOperation<Familia>(
      requestType: DataRequestType.findAll,
      offlineKey: 'familia',
      request: 'GET /familia',
      headers: {'X-Header': 'chupala'},
      adapter: familiaRemoteAdapter,
    );

    final o2 = OfflineOperation<Familia>(
      requestType: DataRequestType.findAll,
      offlineKey: 'familia',
      request: 'GET /familia',
      headers: {'X-Header': 'chupala'},
      adapter: familiaRemoteAdapter,
    );

    expect(o1, equals(o2));
    expect(o1.hash, equals(o2.hash));
  });

  test('findOne scenario issue #118', () async {
    // cause network issue
    container.read(responseProvider.notifier).state = TestResponse(text: (_) {
      throw HandshakeException('Connection terminated during handshake');
    });

    final familia1 = await familiaRepository.findOne('1', remote: false);
    expect(familia1, isNull);

    container.read(responseProvider.notifier).state = TestResponse.text('''
        { "id": "1", "surname": "Smith" }
      ''');
    await familiaRepository.findOne('1', remote: true);

    // cause network issue
    container.read(responseProvider.notifier).state = TestResponse(text: (_) {
      throw HandshakeException('Connection terminated during handshake');
    });

    final familia2 = await familiaRepository.findOne('1', remote: false);
    expect(familia2, isNotNull);
  });
}
