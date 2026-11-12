import 'package:api_contract/api_contract.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  group('designs', () {
    test('round-trips a design with a real DesignDocument', () {
      final design = DesignDto(
        id: 'd1',
        revision: 7,
        document: designDocument(),
        updatedAt: DateTime.utc(2026, 11, 11, 10),
        title: '10×15',
        serverSnapshots: <DesignSnapshot>[
          DesignSnapshot(
            revision: 7,
            createdAt: DateTime.utc(2026, 11, 11, 10),
          ),
        ],
      );
      final decoded = roundTrip(design.toJson(), DesignDto.fromJson);
      expect(decoded, design);
      expect(decoded.document.photoCount, 1);
      expect(decoded.document.slotById('s0', 'main')!.photoId, 'p0');
      expect(decoded.document.toJson(), design.document.toJson());
      expect(decoded.hasSnapshots, isTrue);
      expect(decoded.revision, 7);
    });

    test('a newer document schema is reported as invalid_response', () {
      final json = DesignDto(
        id: 'd1',
        revision: 1,
        document: designDocument(),
        updatedAt: DateTime.utc(2026, 11, 11),
      ).toJson();
      (json['document']! as Map<String, Object?>)['schema'] = 99;
      final result = decodeJson(json, DesignDto.fromJson);
      expect(result.failureOrNull!.args['documentCode'], 'schema_too_new');
      expect(result.failureOrNull!.args['path'], r'$.document');
    });

    test('round-trips a server preflight report', () {
      final dto = PreflightDto(
        revision: 3,
        canOrder: false,
        issues: const <PreflightIssue>[
          PreflightIssue(
            code: PreflightCode.lowDpi,
            severity: PreflightSeverity.warning,
            targetId: 'main',
            messageKey: PreflightMessageKeys.lowDpi,
            args: <String, Object?>{
              'photoPx': '800×600',
              'requiredPx': '1181×1772',
              'effectiveDpi': 203,
              'requiredDpi': 300,
            },
            fixAction: PreflightFixAction.replacePhoto,
            spreadId: 's0',
            slotId: 'main',
            photoId: 'p0',
          ),
        ],
      );
      final decoded = roundTrip(dto.toJson(), PreflightDto.fromJson);
      expect(decoded, dto);
      expect(decoded.hasBlockingIssues, isFalse);
      expect(decoded.issues.single.messageKey, PreflightMessageKeys.lowDpi);
      expect(decoded.issues.single.args['requiredPx'], '1181×1772');
    });

    test('builds PreflightDto from a local report', () {
      final report = PreflightReport(<PreflightIssue>[
        const PreflightIssue(
          code: PreflightCode.emptySlot,
          severity: PreflightSeverity.error,
          targetId: 'main',
          messageKey: PreflightMessageKeys.emptySlot,
        ),
      ]);
      final dto = PreflightDto.fromReport(report, revision: 2, canOrder: false);
      expect(dto.canOrder, isFalse);
      expect(dto.hasBlockingIssues, isTrue);
      expect(dto.issues.single.targetId, 'main');
    });
  });

  group('cart', () {
    test('round-trips a cart with quoted items', () {
      final cart = Cart(
        id: 'c1',
        items: <CartItem>[
          CartItem(
            id: 'ci1',
            designId: 'd1',
            quantity: 10,
            quote: priceQuote(),
          ),
        ],
        expiresAt: DateTime.utc(2026, 11, 25),
        subtotal: const Money(amountMinor: 1300, currency: 'BYN'),
        promoCode: 'TEST10',
        canCheckout: true,
      );
      final decoded = roundTrip(cart.toJson(), Cart.fromJson);
      expect(decoded, cart);
      expect(decoded.unitCount, 10);
      expect(decoded.items.single.quote.currency, 'BYN');
      expect(decoded.isEmpty, isFalse);
    });

    test('round-trips cart mutations', () {
      const add = AddCartItemRequest(designId: 'd1', quantity: 10);
      expect(roundTrip(add.toJson(), AddCartItemRequest.fromJson), add);

      const update = UpdateCartItemRequest(
        itemId: 'ci1',
        quantity: 5,
        promoCode: 'FREE100',
      );
      expect(
        roundTrip(update.toJson(), UpdateCartItemRequest.fromJson),
        update,
      );
    });

    test('an empty cart is representable', () {
      final cart = Cart(
        id: 'c1',
        items: const <CartItem>[],
        expiresAt: DateTime.utc(2026, 11, 25),
        subtotal: const Money(amountMinor: 0, currency: 'BYN'),
      );
      expect(roundTrip(cart.toJson(), Cart.fromJson).isEmpty, isTrue);
    });
  });

  group('support and audit', () {
    test('round-trips a ticket with a thread', () {
      final ticket = SupportTicket(
        id: 't1',
        subject: 'Перепечатка',
        type: TicketType.defect,
        status: TicketStatus.open,
        createdAt: DateTime.utc(2026, 11, 12, 8),
        updatedAt: DateTime.utc(2026, 11, 12, 9),
        orderId: 'o1',
        messages: <TicketMessage>[
          TicketMessage(
            id: 'm1',
            authorRole: UserRole.customer,
            body: 'На фото полоса',
            createdAt: DateTime.utc(2026, 11, 12, 8),
            attachments: const <String>['https://cdn.example/1.jpg'],
          ),
        ],
        slaDueAt: DateTime.utc(2026, 11, 13, 8),
      );
      final decoded = roundTrip(ticket.toJson(), SupportTicket.fromJson);
      expect(decoded, ticket);
      expect(decoded.isOrderRelated, isTrue);
      expect(decoded.messages.single.isFromCustomer, isTrue);
      expect(decoded.status.isOpen, isTrue);
      expect(decoded.status.messageKey, 'ticket.status.open');
    });

    test('round-trips ticket requests', () {
      const create = CreateTicketRequest(
        subject: 'Вопрос',
        body: 'Когда будет готово?',
        type: TicketType.question,
        orderId: 'o1',
      );
      expect(roundTrip(create.toJson(), CreateTicketRequest.fromJson), create);

      const post = PostTicketMessageRequest(ticketId: 't1', body: 'Спасибо');
      expect(roundTrip(post.toJson(), PostTicketMessageRequest.fromJson), post);
    });

    test('round-trips an audit record', () {
      final record = AuditRecord(
        id: 'a1',
        at: DateTime.utc(2026, 11, 12, 9),
        action: 'order.create',
        objectType: 'order',
        objectId: 'o1',
        result: 'success',
        actorRole: ActorRole.customer,
        actorId: 'u1',
        details: const <String, Object?>{'items': 1},
      );
      final decoded = roundTrip(record.toJson(), AuditRecord.fromJson);
      expect(decoded, record);
      expect(decoded.isSuccess, isTrue);
      expect(decoded.details['items'], 1);
    });
  });

  group('auth and uploads', () {
    test('round-trips a guest session with an embedded customer', () {
      final session = AuthSession(
        token: 'token',
        refreshToken: 'refresh',
        role: UserRole.guest,
        customerId: 'u1',
        expiresAt: DateTime.utc(2026, 11, 18),
        customer: Customer(
          id: 'u1',
          createdAt: DateTime.utc(2026, 11, 11),
          isGuest: true,
        ),
      );
      final decoded = roundTrip(session.toJson(), AuthSession.fromJson);
      expect(decoded, session);
      expect(decoded.isGuest, isTrue);
      expect(decoded.isExpiredAt(DateTime.utc(2026, 11, 19)), isTrue);
      expect(decoded.isExpiredAt(DateTime.utc(2026, 11, 12)), isFalse);
      expect(decoded.customer!.phoneMasked, isNull);
    });

    test('round-trips auth and upload requests', () {
      const anonymous = AnonymousSessionRequest(locale: 'ru', deviceId: 'dev');
      expect(
        roundTrip(anonymous.toJson(), AnonymousSessionRequest.fromJson),
        anonymous,
      );
      const login = LoginRequest(email: 'qa@example.test', password: 'secret');
      expect(roundTrip(login.toJson(), LoginRequest.fromJson), login);

      final presign = PresignUploadRequest(
        fileName: 'IMG_0001.JPG',
        mimeType: 'image/jpeg',
        bytes: 1024,
        sha256: shaFor('p0'),
      );
      expect(
        roundTrip(presign.toJson(), PresignUploadRequest.fromJson),
        presign,
      );
    });

    test('upload ticket and completed upload convert to a photo asset', () {
      final ticket = UploadTicket(
        uploadId: 'u1',
        url: 'https://storage.example/u1',
        headers: const <String, String>{'x-signature': 'abc'},
        expiresAt: DateTime.utc(2026, 11, 11, 9, 10),
        maxBytes: 20000000,
      );
      final decoded = roundTrip(ticket.toJson(), UploadTicket.fromJson);
      expect(decoded, ticket);
      expect(decoded.method, 'PUT');

      final completed = CompletedUpload(
        uploadId: 'u1',
        sha256: shaFor('p0'),
        widthPx: 3000,
        heightPx: 2000,
        mimeType: 'image/jpeg',
        bytes: 1024,
      );
      final decodedCompleted = roundTrip(
        completed.toJson(),
        CompletedUpload.fromJson,
      );
      final asset = decodedCompleted.toPhotoAsset('p0');
      expect(asset.id, 'p0');
      expect(asset.sha256, completed.sha256);
      expect(asset.widthPx, 3000);
      expect(asset.mimeType, 'image/jpeg');
    });
  });
}
