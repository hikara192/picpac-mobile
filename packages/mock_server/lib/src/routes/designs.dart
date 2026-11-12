import 'package:api_contract/api_contract.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../context.dart';
import '../errors.dart';
import '../mock_server.dart';
import '../records.dart';
import '../serialization.dart';

void registerDesignRoutes(Router router, MockServer server) {
  router.post('/v1/designs', (Request request) async {
    final ctx = contextOf(request);
    final customer = ctx.requireUser();
    final body = await ctx.jsonBody(maxBytes: 2 << 20);
    final envelope = body.containsKey('document');
    final rawDocument = envelope ? body['document'] : body;
    final document = _parseDocument(rawDocument);
    final now = server.clock.now();
    final id = server.nextId('dsg');
    final title = envelope && body['title'] is String
        ? (body['title']! as String).trim()
        : null;
    final record = DesignRecord(
      id: id,
      ownerId: customer.id,
      revision: 1,
      document: document,
      createdAt: now,
      updatedAt: now,
      title: title == null || title.isEmpty ? null : title,
    );
    server.designs[id] = record;
    ctx.audit(
      action: 'design.create',
      objectType: 'design',
      objectId: id,
      details: <String, Object?>{
        'revision': record.revision,
        'documentRevision': document.revision,
        'spreads': document.spreads.length,
        'photos': document.photoCount,
      },
    );
    return ctx.json(
      record.toDto().toJson(),
      status: 201,
      headers: <String, String>{'etag': designEtag(record.revision)},
    );
  });

  router.get('/v1/designs/<designId>', (Request request, String designId) {
    final ctx = contextOf(request);
    ctx.requireSession();
    final record = _ownedDesign(ctx, designId);
    return ctx.json(
      record.toDto().toJson(),
      headers: <String, String>{'etag': designEtag(record.revision)},
    );
  });

  router.put('/v1/designs/<designId>', (
    Request request,
    String designId,
  ) async {
    final ctx = contextOf(request);
    ctx.requireSession();
    final record = _ownedDesign(ctx, designId);

    final ifMatch = parseRevisionHeader(ctx.header('if-match'));
    if (ifMatch == null) {
      throw ApiException(
        428,
        'precondition_required',
        'send If-Match with the current server revision',
        extra: <String, Object?>{'currentRevision': record.revision},
      );
    }
    if (ifMatch != record.revision) {
      ctx.audit(
        action: 'design.update',
        objectType: 'design',
        objectId: designId,
        result: 'failed',
        details: <String, Object?>{
          'reason': 'conflict_revision',
          'expectedRevision': ifMatch,
          'currentRevision': record.revision,
        },
      );
      throw ApiException(
        409,
        ApiErrorCode.conflictRevision,
        'the design has a newer revision; reload before saving',
        extra: <String, Object?>{
          'currentRevision': record.revision,
          'revision': ifMatch,
        },
      );
    }

    final body = await ctx.jsonBody(maxBytes: 2 << 20);
    final envelope = body.containsKey('document');
    final rawDocument = envelope ? body['document'] : body;
    final document = _parseDocument(rawDocument);

    final previous = record.revision;
    record
      ..document = document
      ..revision = previous + 1
      ..updatedAt = server.clock.now();
    ctx.audit(
      action: 'design.update',
      objectType: 'design',
      objectId: designId,
      details: <String, Object?>{
        'fromRevision': previous,
        'toRevision': record.revision,
        'documentRevision': document.revision,
      },
    );
    return ctx.json(
      record.toDto().toJson(),
      headers: <String, String>{'etag': designEtag(record.revision)},
    );
  });

  router.delete('/v1/designs/<designId>', (Request request, String designId) {
    final ctx = contextOf(request);
    ctx.requireSession();
    final record = _ownedDesign(ctx, designId);
    server.designs.remove(record.id);
    for (final cart in server.carts.values) {
      cart.lines.removeWhere((line) => line.designId == record.id);
    }
    ctx.audit(
      action: 'design.delete',
      objectType: 'design',
      objectId: designId,
    );
    return ctx.noContent();
  });

  router.post('/v1/designs/<designId>/preflight', (
    Request request,
    String designId,
  ) {
    final ctx = contextOf(request);
    ctx.requireSession();
    final record = _ownedDesign(ctx, designId);

    final rawRevision = request.url.queryParameters['revision'];
    if (rawRevision != null && rawRevision.isNotEmpty) {
      final requested = int.tryParse(rawRevision);
      if (requested != record.document.revision) {
        throw ApiException(
          409,
          ApiErrorCode.conflictRevision,
          'the requested revision is not the stored one',
          extra: <String, Object?>{
            'currentRevision': record.document.revision,
            'revision': requested,
          },
        );
      }
    }

    final report = preflightReport(server, record.document);
    return ctx.json(
      PreflightDto.fromReport(
        report,
        revision: record.document.revision,
        canOrder: report.canOrder,
      ).toJson(),
    );
  });
}

PreflightReport preflightReport(MockServer server, DesignDocument document) {
  final product = server.seeds.catalog.productById(document.product.id);
  final format = product?.formatById(document.product.formatId);
  if (product == null || format == null) {
    throw ApiException.validation(
      'the document references a format that is not in the catalogue',
      fieldErrors: const <String, String>{
        'document.product.formatId': 'unknown_format',
      },
    );
  }
  return PreflightProjection.run(
    document: document,
    spec: format.toDto(product).toPrintSpec(),
    templates: format.templateMap(),
  );
}

DesignRecord _ownedDesign(MockContext ctx, String designId) {
  final record = ctx.server.designs[designId];
  if (record == null) throw ApiException.notFound('unknown design');
  if (record.ownerId != ctx.session!.customerId) {
    ctx.audit(
      action: 'design.access',
      objectType: 'design',
      objectId: designId,
      result: 'denied',
      details: const <String, Object?>{'reason': 'foreign_design'},
    );
    throw ApiException.forbidden('the design belongs to another customer');
  }
  return record;
}

DesignDocument _parseDocument(Object? raw) {
  if (raw == null) {
    throw ApiException.validation(
      'a design document is required',
      fieldErrors: const <String, String>{'document': 'missing'},
    );
  }
  final parsed = DesignDocument.fromJson(raw);
  return switch (parsed) {
    Ok<DesignDocument>(:final value) => value,
    Err<DesignDocument>(:final error) => throw ApiException(
      422,
      ApiErrorCode.validationFailed,
      'the design document is invalid: ${error.message}',
      fieldErrors: <String, String>{'document': error.code},
      extra: <String, Object?>{'documentCode': error.code},
    ),
  };
}
