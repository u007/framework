library angel_framework.http.service;

import 'dart:async';
import 'package:angel_http_exception/angel_http_exception.dart';
import 'package:merge_map/merge_map.dart';
import '../util.dart';
import 'angel_base.dart';
import 'hooked_service.dart' show HookedService;
import 'metadata.dart';
import 'request_context.dart';
import 'response_context.dart';
import 'routable.dart';

/// Indicates how the service was accessed.
///
/// This will be passed to the `params` object in a service method.
/// When requested on the server side, this will be null.
class Providers {
  /// The transport through which the client is accessing this service.
  final String via;

  const Providers(String this.via);

  static const String viaRest = "rest";
  static const String viaWebsocket = "websocket";
  static const String viaGraphQL = "graphql";

  /// Represents a request via REST.
  static const Providers rest = const Providers(viaRest);

  /// Represents a request over WebSockets.
  static const Providers websocket = const Providers(viaWebsocket);

  /// Represents a request parsed from GraphQL.
  static const Providers graphql = const Providers(viaGraphQL);

  @override
  bool operator ==(other) => other is Providers && other.via == via;

  @override
  String toString() {
    return 'via:$via';
  }
}

/// A front-facing interface that can present data to and operate on data on behalf of the user.
///
/// Heavily inspired by FeathersJS. <3
class Service extends Routable {
  /// A [List] of keys that services should ignore, should they see them in the query.
  static const List<String> specialQueryKeys = const [
    r'$limit',
    r'$sort',
    'page',
    'token'
  ];

  /// Handlers that must run to ensure this service's functionality.
  List get bootstrappers => [];

  /// The [Angel] app powering this service.
  AngelBase app;

  /// Closes this service, including any database connections or stream controllers.
  void close() {}

  /// Retrieves all resources.
  Future index([Map params]) {
    throw new AngelHttpException.methodNotAllowed();
  }

  /// Retrieves the desired resource.
  Future read(id, [Map params]) {
    throw new AngelHttpException.methodNotAllowed();
  }

  /// Creates a resource.
  Future create(data, [Map params]) {
    throw new AngelHttpException.methodNotAllowed();
  }

  /// Modifies a resource.
  Future modify(id, data, [Map params]) {
    throw new AngelHttpException.methodNotAllowed();
  }

  /// Overwrites a resource.
  Future update(id, data, [Map params]) {
    throw new AngelHttpException.methodNotAllowed();
  }

  /// Removes the given resource.
  Future remove(id, [Map params]) {
    throw new AngelHttpException.methodNotAllowed();
  }

  /// Transforms an [id] string into one acceptable by a service.
  toId<T>(T id) {
    if (id == 'null' || id == null)
      return null;
    else
      return id;
  }

  /// Generates RESTful routes pointing to this class's methods.
  void addRoutes([Service service]) {
    _addRoutesInner(service ?? this, bootstrappers);
  }

  void _addRoutesInner(Service service,
      List handlers) {
    Map restProvider = {'provider': Providers.rest};

    // Add global middleware if declared on the instance itself
    Middleware before = getAnnotation(service, Middleware);

    if (before != null) handlers.addAll(before.handlers);

    Middleware indexMiddleware = getAnnotation(service.index, Middleware);
    get('/', (req, res) {
      return this.index(mergeMap([
        {'query': req.query},
        restProvider,
        req.serviceParams
      ]));
    },
        middleware: []
          ..addAll(handlers)
          ..addAll((indexMiddleware == null) ? [] : indexMiddleware.handlers));

    Middleware createMiddleware = getAnnotation(service.create, Middleware);
    post('/', (RequestContext req, ResponseContext res) {
      return req.lazyBody().then((body) {
        return this
            .create(
                body,
                mergeMap([
                  {'query': req.query},
                  restProvider,
                  req.serviceParams
                ]))
            .then((r) {
          res.statusCode = 201;
          return r;
        });
      });
    },
        middleware: []
          ..addAll(handlers)
          ..addAll(
              (createMiddleware == null) ? [] : createMiddleware.handlers));

    Middleware readMiddleware = getAnnotation(service.read, Middleware);

    get(
        '/:id',
        (req, res) => this.read(
            toId(req.params['id']),
            mergeMap([
              {'query': req.query},
              restProvider,
              req.serviceParams
            ])),
        middleware: []
          ..addAll(handlers)
          ..addAll((readMiddleware == null) ? [] : readMiddleware.handlers));

    Middleware modifyMiddleware = getAnnotation(service.modify, Middleware);
    patch(
        '/:id',
        (RequestContext req, res) => req.lazyBody().then((body) => this.modify(
            toId(req.params['id']),
            body,
            mergeMap([
              {'query': req.query},
              restProvider,
              req.serviceParams
            ]))),
        middleware: []
          ..addAll(handlers)
          ..addAll(
              (modifyMiddleware == null) ? [] : modifyMiddleware.handlers));

    Middleware updateMiddleware = getAnnotation(service.update, Middleware);
    post(
        '/:id',
        (RequestContext req, res) => req.lazyBody().then((body) => this.update(
            toId(req.params['id']),
            body,
            mergeMap([
              {'query': req.query},
              restProvider,
              req.serviceParams
            ]))),
        middleware: []
          ..addAll(handlers)
          ..addAll(
              (updateMiddleware == null) ? [] : updateMiddleware.handlers));
    put(
        '/:id',
        (RequestContext req, res) => req.lazyBody().then((body) => this.update(
            toId(req.params['id']),
            body,
            mergeMap([
              {'query': req.query},
              restProvider,
              req.serviceParams
            ]))),
        middleware: []
          ..addAll(handlers)
          ..addAll(
              (updateMiddleware == null) ? [] : updateMiddleware.handlers));

    Middleware removeMiddleware = getAnnotation(service.remove, Middleware);
    delete(
        '/',
        (req, res) => this.remove(
            null,
            mergeMap([
              {'query': req.query},
              restProvider,
              req.serviceParams
            ])),
        middleware: []
          ..addAll(handlers)
          ..addAll(
              (removeMiddleware == null) ? [] : removeMiddleware.handlers));
    delete(
        '/:id',
        (req, res) => this.remove(
            toId(req.params['id']),
            mergeMap([
              {'query': req.query},
              restProvider,
              req.serviceParams
            ])),
        middleware: []
          ..addAll(handlers)
          ..addAll(
              (removeMiddleware == null) ? [] : removeMiddleware.handlers));

    // REST compliance
    put('/', () => throw new AngelHttpException.notFound());
    patch('/', () => throw new AngelHttpException.notFound());
  }

  /// Invoked when this service is wrapped within a [HookedService].
  void onHooked(HookedService hookedService) {}
}