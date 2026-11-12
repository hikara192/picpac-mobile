// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Belarusian (`be`).
class AppLocalizationsBe extends AppLocalizations {
  AppLocalizationsBe([String locale = 'be']) : super(locale);

  @override
  String get appTitle => 'PicPac';

  @override
  String get navCatalog => 'Каталог';

  @override
  String get navOrders => 'Замовы';

  @override
  String get navSupport => 'Падтрымка';

  @override
  String get navProfile => 'Профіль';

  @override
  String get placeholderTitle => 'Раздзел у распрацоўцы';

  @override
  String get placeholderBody => 'Хутка тут з\'явіцца працоўны экран.';

  @override
  String get actionRetry => 'Паўтарыць';

  @override
  String get actionClose => 'Закрыць';

  @override
  String get actionBack => 'Назад';

  @override
  String get actionCancel => 'Адмена';

  @override
  String get actionContinue => 'Працягнуць';

  @override
  String get actionLogout => 'Выйсці';

  @override
  String get actionLogin => 'Увайсці';

  @override
  String get actionGoCatalog => 'У каталог';

  @override
  String get actionBuild => 'Сабраць';

  @override
  String get actionApply => 'Прымяніць';

  @override
  String get actionRemove => 'Выдаліць';

  @override
  String get actionCheckout => 'Аформіць';

  @override
  String get actionLoadMore => 'Паказаць яшчэ';

  @override
  String get actionFind => 'Знайсці';

  @override
  String get loading => 'Загружаем…';

  @override
  String a11ySliderValue(Object label, Object value) {
    return '$label, $value';
  }

  @override
  String a11yProductCard(Object price, Object title) {
    return '$title, $price';
  }

  @override
  String a11yCartLine(Object quantity, Object title) {
    return '$title, $quantity';
  }

  @override
  String a11yOrderCard(Object number, Object status, Object total) {
    return 'Заказ $number, $status, $total';
  }

  @override
  String a11yTicketCard(Object status, Object subject) {
    return '$subject, $status';
  }

  @override
  String a11ySheetPreview(Object current, Object total) {
    return 'Макет развароту $current з $total';
  }

  @override
  String get startupTitle => 'Не ўдалося запусціць PicPac';

  @override
  String get startupBody => 'Праверце злучэнне і паспрабуйце зноў.';

  @override
  String get startupRetrying => 'Запускаем…';

  @override
  String get errorGeneric => 'Нешта пайшло не так. Паспрабуйце яшчэ раз.';

  @override
  String get errorNetwork =>
      'Няма злучэння. Праверце сетку і паспрабуйце зноў.';

  @override
  String get errorTimeout => 'Сервер не адказаў. Паспрабуйце яшчэ раз.';

  @override
  String get errorUnauthorized => 'Трэба ўвайсці зноў.';

  @override
  String get errorForbidden => 'Недастаткова правоў для гэтага дзеяння.';

  @override
  String get errorConflictRevision =>
      'Праект зменены на іншай прыладзе. Абнавіце чарнавік.';

  @override
  String get errorIdempotencyConflict =>
      'Замова ўжо створана. Адкрыйце гісторыю замоваў.';

  @override
  String get errorValidation => 'Праверце ўведзеныя даныя.';

  @override
  String get errorNotFound => 'Не знайшлі тое, што шукалі.';

  @override
  String routeNotFound(String path) {
    return 'Старонка не знойдзена: $path';
  }

  @override
  String get errorRateLimited => 'Занадта шмат спробаў. Пачакайце хвіліну.';

  @override
  String get errorInvalidData =>
      'Сервер вярнуў нечаканы адказ. Мы ўжо разбіраемся.';

  @override
  String get catalogTitle => 'Каталог';

  @override
  String get catalogLoading => 'Загружаем каталог';

  @override
  String get catalogEmptyTitle => 'Каталог пакуль пусты';

  @override
  String get catalogEmptyBody =>
      'Мы абнаўляем асартымент. Загляніце крыху пазней.';

  @override
  String get catalogOpenCart => 'Кошык';

  @override
  String get catalogCartHint => 'Адкрыць кошык';

  @override
  String priceFrom(String price) {
    return 'ад $price';
  }

  @override
  String get productFormatsTitle => 'Фарматы і цэны';

  @override
  String productSize(String width, String height) {
    return '$width × $height мм';
  }

  @override
  String productEta(int days) {
    return 'гатоўнасць $days сут.';
  }

  @override
  String get productPriceUnavailable => 'Цана па запыце';

  @override
  String get productBuildFailed => 'Не ўдалося стварыць праект';

  @override
  String get productLoginToBuild =>
      'Не ўдалося сабраць праект. Паўтарыце спробу.';

  @override
  String get productChooseFormat => 'Выберыце фармат';

  @override
  String productHeroHint(String title) {
    return 'Выява тавару «$title»';
  }

  @override
  String get cartTitle => 'Кошык';

  @override
  String get cartEmptyTitle => 'Кошык пусты';

  @override
  String get cartEmptyBody => 'Сабярыце праект у каталогу — ён з\'явіцца тут.';

  @override
  String get cartExpiredTitle => 'Кошык састарэў';

  @override
  String get cartExpiredBody =>
      'Пазыцыі захоўваюцца 14 дзён. Сабярыце праект нанова.';

  @override
  String get cartSubtotal => 'Разам';

  @override
  String cartEta(int days) {
    return 'Гатоўнасць праз $days сут.';
  }

  @override
  String get cartQuantity => 'Колькасць';

  @override
  String get cartIncrease => 'Дадаць штуку';

  @override
  String get cartDecrease => 'Прыбраць штуку';

  @override
  String get cartRemoveTitle => 'Выдаліць пазыцыю?';

  @override
  String cartRemoveBody(String title) {
    return '«$title» знікне з кошыка.';
  }

  @override
  String get cartUnavailableItem => 'Праект недаступны';

  @override
  String get cartCannotCheckout =>
      'Частка пазыцый недаступная. Выдаліце іх, каб працягнуць.';

  @override
  String get cartUpdateFailed => 'Не ўдалося абнавіць кошык';

  @override
  String cartExpiresAt(String date) {
    return 'Кошык захоўваецца да $date';
  }

  @override
  String cartItemsCount(int count) {
    return 'Пазыцый: $count';
  }

  @override
  String get checkoutTitle => 'Афармленне';

  @override
  String get checkoutDelivery => 'Атрыманне';

  @override
  String get checkoutPickupPoint => 'Пункт выдачы';

  @override
  String get checkoutPickupSlot => 'Час атрымання';

  @override
  String get checkoutAddress => 'Адрас';

  @override
  String get checkoutAddressHint => 'Вуліца, дом, кватэра';

  @override
  String get checkoutPromo => 'Прамакод';

  @override
  String get checkoutPromoHint => 'Напрыклад, TEST10';

  @override
  String checkoutPromoApplied(String code) {
    return 'Прамакод $code ужыты';
  }

  @override
  String get checkoutPromoUnknown => 'Такога прамакода няма або ён скончыўся';

  @override
  String get checkoutPromoClear => 'Прыбраць прамакод';

  @override
  String get checkoutContacts => 'Кантакты';

  @override
  String get checkoutName => 'Імя';

  @override
  String get checkoutPhone => 'Тэлефон';

  @override
  String get checkoutNameRequired => 'Укажыце імя';

  @override
  String get checkoutPhoneRequired => 'Укажыце тэлефон';

  @override
  String get checkoutPhoneInvalid =>
      'Праверце нумар: +375 (29) 123-45-67 або +7 999 123-45-67';

  @override
  String get checkoutSubmit => 'Аформіць замову';

  @override
  String get checkoutSubmitting => 'Афармляем…';

  @override
  String get checkoutLoginRequired => 'Увайсці і аформіць';

  @override
  String get checkoutSummary => 'Вынік';

  @override
  String get checkoutPreliminary =>
      'Папярэдне: дакладную суму пацвердзіць сервер пры афармленні.';

  @override
  String get checkoutDeliveryRequired => 'Выберыце спосаб атрымання';

  @override
  String get checkoutSlotRequired => 'Выберыце час атрымання';

  @override
  String get checkoutAddressRequired => 'Укажыце адрас дастаўкі';

  @override
  String get checkoutFailed => 'Не ўдалося аформіць замову';

  @override
  String get checkoutEmptyCart => 'Кошык пусты — дадайце праект з каталога.';

  @override
  String get checkoutNoSlots => 'Вольных слотаў няма. Выберыце іншы пункт.';

  @override
  String get checkoutPhoneHint => '+375 29 123 45 67';

  @override
  String get priceProduct => 'Тавары';

  @override
  String get priceOptions => 'Опцыі';

  @override
  String get pricePromo => 'Зніжка';

  @override
  String get priceDelivery => 'Дастаўка';

  @override
  String get deliveryPickup => 'Самавываз';

  @override
  String get deliveryEuropochta => 'Еўрапошта';

  @override
  String get deliveryBelpochta => 'Белпошта';

  @override
  String get deliveryEms => 'EMS';

  @override
  String get deliveryCourierMinsk => 'Кур\'ер па Мінску';

  @override
  String get deliveryCourierBelarus => 'Кур\'ер па Беларусі';

  @override
  String deliveryDays(int days) {
    return '$days сут.';
  }

  @override
  String deliveryFreeFrom(String price) {
    return 'бясплатна ад $price';
  }

  @override
  String get deliveryKindPickup => 'Самавываз';

  @override
  String get deliveryKindPost => 'Пошта';

  @override
  String get deliveryKindEms => 'EMS';

  @override
  String get deliveryKindCourier => 'Кур\'ер';

  @override
  String get deliveryKindUnknown => 'Атрыманне';

  @override
  String get ordersTitle => 'Замовы';

  @override
  String get ordersEmptyTitle => 'Замоваў пакуль няма';

  @override
  String get ordersEmptyBody => 'Аформіце першую замову — яна з\'явіцца тут.';

  @override
  String get ordersLoginRequired => 'Заказы захоўваюцца ў акаўнце.';

  @override
  String get ordersStale => 'Даныя могуць быць састарэлымі';

  @override
  String get ordersLookup => 'Знайсці замову па нумары';

  @override
  String ordersOpenOrder(String number) {
    return 'Адкрыць замову $number';
  }

  @override
  String ordersItemsCount(int count) {
    return 'Пазыцый: $count';
  }

  @override
  String get statusUpdating => 'абнаўляецца';

  @override
  String get orderTitle => 'Замова';

  @override
  String orderHeading(String number) {
    return 'Замова $number';
  }

  @override
  String orderCreatedAt(String date) {
    return 'Аформлена $date';
  }

  @override
  String get orderItemsTitle => 'Склад';

  @override
  String orderItemQuantity(int quantity, String price) {
    return '$quantity × $price';
  }

  @override
  String get orderTotalsTitle => 'Сума';

  @override
  String get orderSubtotal => 'Тавары';

  @override
  String get orderDiscount => 'Зніжка';

  @override
  String get orderDeliveryCost => 'Дастаўка';

  @override
  String get orderTotal => 'Разам';

  @override
  String get orderDeliveryTitle => 'Атрыманне';

  @override
  String get orderPayCta => 'Аплаціць замову';

  @override
  String get orderPaymentTitle => 'Аплата';

  @override
  String get orderFulfillmentTitle => 'Гатоўнасць';

  @override
  String orderEta(String date) {
    return 'Будзе гатова да $date';
  }

  @override
  String get orderTimelineTitle => 'Статусы';

  @override
  String orderTracking(String number) {
    return 'Трэк-нумар $number';
  }

  @override
  String get orderPickupCode => 'Код самавывазу';

  @override
  String get orderPickupCodeHint => 'Назавіце код у пункце выдачы';

  @override
  String get orderProblem => 'Праблема з замовай';

  @override
  String get orderNotFound => 'Замова не знойдзена';

  @override
  String get orderOfflineUnavailable =>
      'Замова не захавана на прыладзе. Праверце злучэнне.';

  @override
  String get orderStatusDraft => 'Чарнавік';

  @override
  String get orderStatusPlaced => 'Аформлены';

  @override
  String get orderStatusAccepted => 'Прыняты';

  @override
  String get orderStatusModeration => 'На мадэрацыі';

  @override
  String get orderStatusProduction => 'У вытворчасці';

  @override
  String get orderStatusReady => 'Гатовы';

  @override
  String get orderStatusReadyForPickup => 'Гатовы да выдачы';

  @override
  String get orderStatusShipped => 'Перададзены ў дастаўку';

  @override
  String get orderStatusCompleted => 'Завершаны';

  @override
  String get orderStatusCanceled => 'Адменены';

  @override
  String get orderStatusReturned => 'Вяртанне';

  @override
  String get paymentStatusCreated => 'Чакае аплаты';

  @override
  String get paymentStatusRequiresAction => 'Патрэбна пацверджанне';

  @override
  String get paymentStatusPendingUser => 'Чакае аплаты';

  @override
  String get paymentStatusProcessing => 'Платёж апрацоўваецца';

  @override
  String get paymentStatusSucceeded => 'Аплачаны';

  @override
  String get paymentStatusFailed => 'Аплата не прайшла';

  @override
  String get paymentStatusExpired => 'Тэрмін аплаты скончыўся';

  @override
  String get paymentStatusCanceled => 'Аплата адменена';

  @override
  String get paymentStatusRefunded => 'Вяртанне';

  @override
  String get paymentStatusPartiallyRefunded => 'Частковае вяртанне';

  @override
  String get paymentStatusPendingOnDelivery => 'Аплата пры атрыманні';

  @override
  String get lookupTitle => 'Знайсці замову';

  @override
  String get lookupBody =>
      'Увядзіце нумар замовы і апошнія 4 лічбы тэлефона з замовы.';

  @override
  String get lookupNumber => 'Нумар замовы';

  @override
  String get lookupPhoneLast4 => 'Апошнія 4 лічбы тэлефона';

  @override
  String get lookupPhoneLast4Invalid => 'Патрэбны 4 лічбы';

  @override
  String get lookupNotFound =>
      'Замова з такім нумарам і тэлефонам не знойдзена';

  @override
  String get mediaHeicUnsupported =>
      'HEIC пакуль не падтрымліваецца. Захавайце фота як JPEG або PNG і паспрабуйце зноў.';

  @override
  String mediaTooLarge(int limit) {
    return 'Файл большы за $limit МБ. Паменшыце фота і паспрабуйце зноў.';
  }

  @override
  String get mediaUnsupported =>
      'Гэты фармат не друкуецца. Патрэбны JPEG або PNG.';

  @override
  String mediaTooSmallPixels(int width, int height) {
    return 'Фота $width×$height px занадта малое для друку.';
  }

  @override
  String get mediaUnreadable =>
      'Не ўдалося прачытаць файл. Выберыце іншае фота.';

  @override
  String get mediaPermissionTitle => 'Няма доступу да фотаздымкаў';

  @override
  String get mediaPermissionBody =>
      'Дазвольце PicPac доступ да фотаздымкаў у наладах тэлефона і паўтарыце выбар.';

  @override
  String get mediaPermissionRetry => 'Паўтарыць выбар';

  @override
  String get mediaRejectedTitle => 'Не дададзена';

  @override
  String mediaDuplicatesSkipped(int count) {
    return 'Ужо ёсць у праекце: $count';
  }

  @override
  String get createTitle => 'Праект';

  @override
  String get createPhotosTitle => 'Фотаздымкі';

  @override
  String createPhotosCount(int count, int max) {
    return '$count з $max';
  }

  @override
  String get createAddPhotos => 'Дадаць фота';

  @override
  String createLimitReached(int max) {
    return 'На ліст змяшчаецца $max фота. Прыбярыце лішнія, каб дадаць новыя.';
  }

  @override
  String createMinPhotos(int min) {
    return 'Патрэбна мінімум $min фота.';
  }

  @override
  String get createEmptyTitle => 'Пакуль няма фотаздымкаў';

  @override
  String get createEmptyBody =>
      'Дадайце фота з прылады — арыгіналы застануцца ў вас.';

  @override
  String get createDeleteTitle => 'Выдаліць фота?';

  @override
  String createDeleteBody(String name) {
    return 'Фота «$name» знікне з праекта. Арыгінал на прыладзе не зменіцца.';
  }

  @override
  String get createReorderHint =>
      'Утрымлівайце фота і перацягніце, каб змяніць парадак.';

  @override
  String get createOfflineBanner =>
      'Няма сеткі. Змены захаваюцца на прыладзе і пайдуць на сервер пазней.';

  @override
  String get createSyncSaving => 'Захоўваем…';

  @override
  String get createSyncSaved => 'Захавана';

  @override
  String get createSyncPending => 'Чакае сеткі';

  @override
  String get createDraftRestored => 'Чарнавік адноўлены з прылады';

  @override
  String get createConflictTitle => 'Праект зменены на іншай прыладзе';

  @override
  String get createConflictBody =>
      'Версія на серверы навейшая. Загрузіце яе або пакіньце свае праўкі — яны перазапішуць серверныя.';

  @override
  String get createConflictLoadServer => 'Загрузіць з сервера';

  @override
  String get createConflictKeepLocal => 'Пакінуць мае праўкі';

  @override
  String get createOrder => 'Аформіць замову';

  @override
  String get createEditSheets => 'Змяніць лісты';

  @override
  String createPreviewTitle(int index, int total) {
    return 'Ліст $index з $total';
  }

  @override
  String createPhotoUploading(int index) {
    return 'Загружаем фота $index';
  }

  @override
  String createCancelUpload(int index) {
    return 'Адмяніць загрузку фота $index';
  }

  @override
  String createUploadRetry(int index) {
    return 'Паўтарыць загрузку фота $index';
  }

  @override
  String get createUploadFailed => 'Фота не загрузілася';

  @override
  String get createLocalCopy => 'Лакальная копія';

  @override
  String get createLocalCopyHint =>
      'Праект на серверы недаступны — адкрыта копія з прылады.';

  @override
  String get createOrderNeedsPhotos =>
      'Дадайце хоць адно фота — тады можна аформіць замову.';

  @override
  String get createUndo => 'Адмяніць';

  @override
  String get createRedo => 'Вярнуць';

  @override
  String createPhotoNumber(int index) {
    return 'Фота $index';
  }

  @override
  String createMovePhoto(int index) {
    return 'Пераставіць фота $index';
  }

  @override
  String createRemovePhoto(int index) {
    return 'Выдаліць фота $index';
  }

  @override
  String get createFormatMissing =>
      'Фармат недаступны без сеткі. Адкрыйце праект пры злучэнні.';

  @override
  String get createEnhanceAll => 'Палепшыць усе';

  @override
  String createEnhanceApplied(int count) {
    return 'Палепшана $count фота';
  }

  @override
  String get createEnhanceAlready => 'Усё ўжо палепшана';

  @override
  String get createEnhanceFailed =>
      'Не атрымалася палепшыць. Паспрабуйце яшчэ раз.';

  @override
  String get createEnhanceUndo => 'Вярнуць';

  @override
  String get createEnhancePreviewBefore => 'Да';

  @override
  String get createEnhancePreviewAfter => 'Пасля';

  @override
  String get createEnhancePreviewHint =>
      'Святло і цеплыня падладзяцца пад кожнае фота';

  @override
  String get createResetToImported => 'Вярнуць як было';

  @override
  String get createResetToImportedHint =>
      'Скінуць кадры, святло і стыль. Фота застануцца.';

  @override
  String get createLayoutTitle => 'Можна шчыльней';

  @override
  String createLayoutBody(int sheets, int current) {
    String _temp0 = intl.Intl.pluralLogic(
      sheets,
      locale: localeName,
      other: '$sheets ліста',
      many: '$sheets лістоў',
      few: '$sheets лісты',
      one: '$sheets ліст',
    );
    return '$_temp0 замест $current';
  }

  @override
  String get createLayoutHint => 'Кадры і абрэзка захаваюцца.';

  @override
  String get createLayoutAccept => 'Так лепш';

  @override
  String get createLayoutKeep => 'Пакінуць па адным';

  @override
  String get createLayoutApplied => 'Раскладка гатовая';

  @override
  String get editorTitle => 'Кадраванне';

  @override
  String get editorZoom => 'Маштаб';

  @override
  String get editorCenter => 'Па цэнтры';

  @override
  String get editorDone => 'Гатова';

  @override
  String editorSheetOf(int index, int total) {
    return 'Ліст $index з $total';
  }

  @override
  String get editorPrevSheet => 'Папярэдні ліст';

  @override
  String get editorNextSheet => 'Наступны ліст';

  @override
  String get editorEmptySlot => 'Дадайце фота';

  @override
  String get editorSlotEmpty => 'пуста';

  @override
  String get editorSlotSelected => 'выбрана';

  @override
  String editorCropHandle(String corner) {
    return 'Змяніць кадр, кут $corner';
  }

  @override
  String get editorCornerTopLeft => 'левы верхні';

  @override
  String get editorCornerTopRight => 'правы верхні';

  @override
  String get editorCornerBottomLeft => 'левы ніжні';

  @override
  String get editorCornerBottomRight => 'правы ніжні';

  @override
  String get editorGestureHint =>
      'Цягніце фота, каб зрушыць кадр. Двума пальцамі — маштаб.';

  @override
  String get editorSelectSlotHint => 'Дакраніцеся да кадра, каб выбраць яго';

  @override
  String get editorNoSlotSelected => 'Выберыце кадр на лісце';

  @override
  String editorSlotSemantic(int index, int total, String state) {
    return 'Кадр $index з $total, $state';
  }

  @override
  String get editorToolFrame => 'Кадр';

  @override
  String get editorToolLight => 'Святло';

  @override
  String get editorToolWarmth => 'Цеплыня';

  @override
  String get editorToolStyle => 'Стыль';

  @override
  String get editorToolRotate => 'Павярнуць';

  @override
  String get editorToolReplace => 'Замяніць';

  @override
  String get editorToolSwap => 'Абмяняць';

  @override
  String get editorToolBackground => 'Фон';

  @override
  String get editorToolPending => 'Хутка: чакае абнаўлення рэдактара';

  @override
  String editorLightValue(String value) {
    return '$value EV';
  }

  @override
  String get editorLightHint => 'Святлей або цямней';

  @override
  String editorWarmthValue(String value) {
    return '$value';
  }

  @override
  String get editorWarmthHint => 'Цяплей або халадней';

  @override
  String editorZoomValue(String value) {
    return '$value×';
  }

  @override
  String get editorStyleStrength => 'Сіла';

  @override
  String get editorStyleApplyAll => 'Прымяніць да ўсіх фота';

  @override
  String get lookAsIs => 'Як ёсць';

  @override
  String get lookWarm => 'Цеплыня';

  @override
  String get lookFilm => 'Плёнка';

  @override
  String get lookBright => 'Ярчэй';

  @override
  String get lookSoft => 'Мякка';

  @override
  String get lookMono => 'Ч/Б';

  @override
  String get editorRotateHint => 'Калі фота ляжыць на баку';

  @override
  String get editorRotateCw => 'Павярнуць на 90°';

  @override
  String get editorFlip => 'Адлюстраваць';

  @override
  String get editorSwapPickFirst =>
      'Дакраніцеся да кадра, з якім хочаце абмяняцца';

  @override
  String editorSwapPickSecond(int index) {
    return 'Абмяняем з фота $index. Дакраніцеся да другога кадра.';
  }

  @override
  String get editorReplaceTitle => 'Фота ў кадры';

  @override
  String get editorBackgroundTitle => 'Колер ліста';

  @override
  String get editorBackgroundPaper => 'Як папера';

  @override
  String get editorBackgroundCream => 'Крэмавы';

  @override
  String get editorBackgroundMint => 'Мята';

  @override
  String get editorBackgroundBeige => 'Бэжавы';

  @override
  String get editorNoPhotoSelected => 'Спачатку выберыце фота на лісце';

  @override
  String get preflightTitle => 'Праверка макета';

  @override
  String get preflightStatusClean => 'Заўваг няма';

  @override
  String preflightStatusWarnings(int count) {
    return 'Заўвагі: $count';
  }

  @override
  String preflightStatusBlocking(int count) {
    return 'Нельга працягнуць: $count';
  }

  @override
  String get preflightOpenIssues => 'Адкрыць заўвагі';

  @override
  String get preflightAckAndOrder => 'Пацвердзіць і аформіць';

  @override
  String get preflightRunning => 'Правяраем макет…';

  @override
  String get preflightCleanTitle => 'Можна друкаваць';

  @override
  String get preflightCleanBody => 'Усе кадры запоўнены, разрознення хапае.';

  @override
  String preflightIssuesTitle(int count) {
    return 'Заўвагі: $count';
  }

  @override
  String get preflightBlockingNote =>
      'Пакуль ёсць блакуючыя заўвагі, замова недаступная.';

  @override
  String get preflightEmptySlot => 'Дадайце фота';

  @override
  String preflightEmptySlotHint(int sheet, String slot) {
    return 'Ліст $sheet, кадр $slot пусты.';
  }

  @override
  String preflightLowDpi(String photo, String size, String required) {
    return 'Гэта фота $photo px, для $size патрэбна $required — будзе мыльным.';
  }

  @override
  String preflightUnsupported(String mime) {
    return 'Фармат $mime не друкуецца. Патрэбны JPEG або PNG.';
  }

  @override
  String preflightSafeZone(String mm) {
    return 'Кантэнт бліжэй за $mm мм да краю — можа абрэзацца.';
  }

  @override
  String get preflightTextOverflow => 'Тэкст не змяшчаецца ў блок.';

  @override
  String get preflightFaceAtEdge =>
      'Твар занадта блізка да краю — можа абрэзацца.';

  @override
  String preflightSheetBadge(int sheet) {
    return 'Ліст $sheet';
  }

  @override
  String preflightServerMismatch(int count) {
    return 'Сервер знайшоў адрозненняў: $count. Паказваем праверку сервера.';
  }

  @override
  String get preflightOffline =>
      'Серверная праверка недаступная — паказваем лакальную.';

  @override
  String get preflightOverride => 'Працягнуць усё адно';

  @override
  String get preflightOverrideTitle => 'Працягнуць з заўвагамі?';

  @override
  String get preflightOverrideBody =>
      'Замова пойдзе ў вытворчасць з бягучымі заўвагамі. Пацверджанне захаваем у журнале.';

  @override
  String get preflightOverrideConfirm => 'Працягнуць';

  @override
  String get preflightOverrideRecorded => 'Пацверджанне запісана';

  @override
  String get preflightToCart => 'У кошык';

  @override
  String get preflightAdding => 'Дадаем…';

  @override
  String get preflightFix => 'Выправіць';

  @override
  String get preflightAddFailed => 'Не ўдалося дадаць у кошык';

  @override
  String get preflightFixHint => 'Адкрыць кадр у рэдактары';

  @override
  String get preflightWaitPhotos =>
      'Дачакайцеся загрузкі фота — замова стане даступнай.';

  @override
  String get preflightSharePdf => 'Падзяліцца PDF';

  @override
  String preflightSharePreparing(int done, int total) {
    return 'Гатуем PDF: $done з $total';
  }

  @override
  String get preflightShareOpening => 'Адкрываем…';

  @override
  String get preflightShareBlocked =>
      'Выпраўце заўвагі або пацвердзіце іх, каб падзяліцца PDF.';

  @override
  String get preflightShareFailed => 'Не ўдалося падрыхтаваць PDF';

  @override
  String get preflightShareNotLoaded =>
      'Праект яшчэ загружаецца — паспрабуйце праз пару секунд.';

  @override
  String get preflightShareNothing => 'У праекце няма лістоў для экспарту.';

  @override
  String get preflightShareRenderFailed =>
      'Не ўдалося адмаляваць макет. Паспрабуйце яшчэ раз.';

  @override
  String get preflightShareOpenFailed =>
      'Не ўдалося адкрыць «Падзяліцца». Паспрабуйце яшчэ раз.';

  @override
  String get loginRegisterAction => 'Стварыць акаўнт';

  @override
  String get loginTitle => 'Уваход у PicPac';

  @override
  String get loginPromise => 'Захоўвайце ўспаміны прыгожа';

  @override
  String get loginGuestNote => 'Каталог і зборка — без уваходу';

  @override
  String get loginPasswordMode => 'Па паролі';

  @override
  String get loginCodeMode => 'Па кодзе';

  @override
  String get loginEmailLabel => 'Email';

  @override
  String get loginEmailHint => 'name@example.com';

  @override
  String get loginEmailInvalid =>
      'Праверце адрас: патрэбны выгляд name@example.com';

  @override
  String get loginPasswordLabel => 'Пароль';

  @override
  String get loginPasswordRequired => 'Увядзіце пароль';

  @override
  String get loginPasswordHidden => 'Паказаць пароль';

  @override
  String get loginPasswordShown => 'Схаваць пароль';

  @override
  String get loginSubmit => 'Увайсці';

  @override
  String get loginInvalidCredentials => 'Няправільны email або пароль';

  @override
  String get loginSendCode => 'Атрымаць код';

  @override
  String get loginCodeLabel => 'Код з ліста';

  @override
  String get loginCodeHint => '4 лічбы';

  @override
  String loginCodeSent(String email) {
    return 'Код адпраўлены на $email. Дэма-код: 0000.';
  }

  @override
  String get loginCodeDemo => 'Дэма-код: 0000';

  @override
  String get loginCodeInvalid => 'Код не падышоў. Праверце лічбы.';

  @override
  String get loginCodeExpired => 'Код скончыўся. Запытайце новы.';

  @override
  String get loginDemoTitle => 'Дэма-доступ';

  @override
  String get loginDemoCustomer => 'Кліент: customer@picpac.test / Test1234';

  @override
  String get loginDemoSupport => 'Падтрымка: support@picpac.test / Test1234';

  @override
  String get loginDemoHint => 'Націсніце, каб падставіць даныя.';

  @override
  String get loginGuestContinue => 'Працягнуць без уваходу';

  @override
  String get loginLookup => 'Знайсці замову па нумары';

  @override
  String get loginSupportWelcome => 'Вы ўвайшлі як агент падтрымкі.';

  @override
  String get loginRoleFailed =>
      'Сервер не паведаміў ролю. Уваход адменены — паспрабуйце яшчэ раз.';

  @override
  String get logoutTitle => 'Выйсці з акаўнта?';

  @override
  String get logoutBody =>
      'Чарнавікі і фота застануцца на прыладзе. Кэш замоваў і чарга адпраўкі будуць ачышчаны.';

  @override
  String get logoutConfirm => 'Выйсці з акаўнта';

  @override
  String get logoutDone => 'Вы выйшлі з акаўнта';

  @override
  String get supportTitle => 'Падтрымка';

  @override
  String get supportAgentMode => 'Рэжым падтрымкі';

  @override
  String get supportAgentModeHint =>
      'Вы бачыце ўсе звароты кліентаў. Замовы кліентаў толькі для чытання.';

  @override
  String get supportNewTicket => 'Новы зварот';

  @override
  String get supportCreate => 'Стварыць зварот';

  @override
  String get supportEmptyTitle => 'Зваротаў пакуль няма';

  @override
  String get supportEmptyBody =>
      'Калі нешта пайшло не так з замовай, напішыце нам — адкажам тут жа.';

  @override
  String get supportEmptyAgentTitle => 'Зваротаў няма';

  @override
  String get supportEmptyAgentBody =>
      'Кліенты яшчэ не пісалі ў падтрымку. Абнавіце спіс пазней.';

  @override
  String get supportLoginRequired => 'Звароты захоўваюцца ў акаўнце.';

  @override
  String get supportTicketCreated => 'Зварот створаны';

  @override
  String get supportSubjectLabel => 'Тэма';

  @override
  String get supportSubjectHint => 'Коратка: што здарылася';

  @override
  String get supportSubjectRequired => 'Апішыце тэму ў двух словах';

  @override
  String get supportMessageLabel => 'Паведамленне';

  @override
  String get supportMessageHint => 'Што не так і што вы чакалі?';

  @override
  String get supportMessageRequired => 'Напішыце паведамленне';

  @override
  String get supportTypeLabel => 'Прычына';

  @override
  String get supportTypeQuestion => 'Пытанне';

  @override
  String get supportTypeDefect => 'Брак або перадрук';

  @override
  String get supportTypeRefund => 'Вяртанне';

  @override
  String get supportTypeDelivery => 'Дастаўка';

  @override
  String get supportTypeOther => 'Іншае';

  @override
  String get supportTypeUnknown => 'Іншае';

  @override
  String get supportOrderLabel => 'Замова';

  @override
  String get supportOrderNone => 'Без замовы';

  @override
  String get supportOrderUnknown => 'Замова недаступная';

  @override
  String supportOrderAttached(String number) {
    return 'Замова $number';
  }

  @override
  String get supportSend => 'Адправіць';

  @override
  String get supportReplyHint => 'Паведамленне ў падтрымку';

  @override
  String get supportReplyHintAgent => 'Адказ кліенту';

  @override
  String get supportAuthorYou => 'Вы';

  @override
  String get supportAuthorCustomer => 'Кліент';

  @override
  String get supportAuthorSupport => 'Падтрымка';

  @override
  String get supportQueued =>
      'Няма сеткі. Паведамленне захавана і пойдзе аўтаматычна.';

  @override
  String get supportMessageQueued => 'У чарзе';

  @override
  String get supportTicketClosed =>
      'Зварот закрыты. Новыя паведамленні недаступныя.';

  @override
  String get supportForeignTicket => 'Гэта зварот іншага кліента';

  @override
  String get supportForeignTicketBody =>
      'Паказаць яго могуць толькі аўтар і падтрымка.';

  @override
  String get supportStatusOpen => 'Адкрыты';

  @override
  String get supportStatusPending => 'Адказ падтрымкі';

  @override
  String get supportStatusResolved => 'Вырашаны';

  @override
  String get supportStatusClosed => 'Закрыты';

  @override
  String get supportStatusUnknown => 'Статус абнаўляецца';

  @override
  String supportUpdatedAt(String date) {
    return 'Абноўлена $date';
  }

  @override
  String supportMessagesCount(int count) {
    return 'Паведамленняў: $count';
  }

  @override
  String get supportSending => 'Адпраўляем…';

  @override
  String get supportSendFailed => 'Не ўдалося адправіць паведамленне';

  @override
  String get profileTitle => 'Профіль';

  @override
  String get profileGuestTitle => 'Вы не ўвайшлі';

  @override
  String get profileLanguageTitle => 'Мова';

  @override
  String get profileLanguageSystem => 'Сістэмная';

  @override
  String get profileLanguageRu => 'Руская';

  @override
  String get profileLanguageBe => 'Беларуская';

  @override
  String get profileLanguageHint =>
      'Інтэрфейс мяняецца адразу, без перазапуску праграмы.';

  @override
  String get profileDataTitle => 'Даныя';

  @override
  String get profileCustomerSinceLabel => 'З намі з';

  @override
  String get profilePhoneLabel => 'Тэлефон';

  @override
  String get profilePhoneHint => 'Сервер аддае толькі маску нумара.';

  @override
  String get profileSupportOnlyHint =>
      'У рэжыме падтрымкі даступныя толькі звароты кліентаў.';

  @override
  String get profileQueueTitle => 'Чарга адпраўкі';

  @override
  String get profileQueueEmpty => 'Усе дзеянні адпраўлены.';

  @override
  String get profileQueueEmptyHint =>
      'Тут з\'явяцца замовы і паведамленні, якія не ўдалося адправіць без сеткі.';

  @override
  String get profileQueueItemCheckout => 'Афармленне замовы';

  @override
  String get profileQueueItemTicket => 'Зварот у падтрымку';

  @override
  String get profileQueueItemMessage => 'Паведамленне ў падтрымку';

  @override
  String get profileQueueItemUnknown => 'Дзеянне';

  @override
  String profileQueueAttempts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count спробы',
      many: '$count спроб',
      few: '$count спробы',
      one: '$count спроба',
    );
    return '$_temp0';
  }

  @override
  String get profileQueueQueued => 'У чарзе';

  @override
  String get profileQueueFailed => 'Не адпраўлена';

  @override
  String get profileQueueRetry => 'Паўтарыць';

  @override
  String get profileQueueRetryAll => 'Паўтарыць усе';

  @override
  String profileQueueSent(int count) {
    return 'Адпраўлена: $count';
  }

  @override
  String profileQueueStillQueued(int count) {
    return 'Засталося ў чарзе: $count';
  }

  @override
  String profileQueueOrderSent(String number) {
    return 'Замова $number адпраўлена';
  }

  @override
  String get profileTestData => 'Тэставыя даныя';

  @override
  String get profileTestDataHint =>
      'Чарнавікі, копіі фота і кэш замоваў на гэтай прыладзе.';

  @override
  String get profileDeleteTestData => 'Выдаліць чарнавікі і кэш';

  @override
  String get profileDeleteTestDataTitle => 'Выдаліць тэставыя даныя?';

  @override
  String get profileDeleteTestDataBody =>
      'Чарнавікі, спампаваныя копіі фота і кэш замоваў на гэтай прыладзе будуць выдалены. Акаўнт і замовы на серверы застануцца.';

  @override
  String profileDeleteTestDataDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Выдалена $count чарнавіка',
      many: 'Выдалена $count чарнавікоў',
      few: 'Выдалена $count чарнавікі',
      one: 'Выдалены $count чарнавік',
    );
    return '$_temp0. Кэш ачышчаны.';
  }

  @override
  String get profileDangerTitle => 'Выдаленне даных';

  @override
  String get profileDeleteAccount => 'Выдаліць акаўнт';

  @override
  String get profileDeleteAccountStep1Title => 'Выдаліць акаўнт і ўсе даныя?';

  @override
  String get profileDeleteAccountStep1Body =>
      'Разам з акаўнтам выдаляюцца замовы, звароты ў падтрымку, чарнавікі і загружаныя фота. Аднавіць даныя немагчыма.';

  @override
  String get profileDeleteAccountStep2Title => 'Апошняе пацверджанне';

  @override
  String profileDeleteAccountStep2Body(String email) {
    return 'Акаўнт $email і ўсе звязаныя даныя будуць выдалены беззваротна. Працягнуць?';
  }

  @override
  String get profileDeleteAccountConfirm => 'Выдаліць беззваротна';

  @override
  String get profileDeleteAccountDone => 'Акаўнт і даныя выдалены';

  @override
  String get profileDeleteAccountFailed =>
      'Не ўдалося выдаліць акаўнт. Паспрабуйце яшчэ раз.';

  @override
  String get profileDeletedEmail => 'ваш акаўнт';

  @override
  String cartSheetsUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ліста',
      many: '$count лістоў',
      few: '$count лісты',
      one: '$count ліст',
    );
    return '$_temp0';
  }

  @override
  String cartBooksUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count кнігі',
      many: '$count кніг',
      few: '$count кнігі',
      one: '$count кніга',
    );
    return '$_temp0';
  }

  @override
  String cartSpreadsUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count разварота',
      many: '$count разваротаў',
      few: '$count развароты',
      one: '$count разварот',
    );
    return '$_temp0';
  }

  @override
  String get cartQuantityDerived => 'Па макеце';

  @override
  String get cartRecalculated => 'Кошык пералічаны па бягучым макеце';

  @override
  String get checkoutGuestWorkTitle => 'Праект сабраны як госць';

  @override
  String get checkoutGuestWorkBody =>
      'Праект сабраны як госць. Пасля ўваходу яго давядзецца сабраць нанова.';

  @override
  String get checkoutGuestWorkConfirm => 'Зразумела, увайсці';

  @override
  String get checkoutPreflightBlocked =>
      'Замову нельга аформіць, пакуль не выпраўлены заўвагі праверкі макета.';

  @override
  String get checkoutPreflightBlockedTitle => 'Замова заблакавана праверкай';

  @override
  String get checkoutPreflightBlockedBody =>
      'Пакуль ёсць блакуючыя заўвагі, замова не афармляецца. Выпраўце іх або пацвердзіце, што замаўляеце як ёсць.';

  @override
  String get productOptionsTitle => 'Опцыі';

  @override
  String get productOptionsTotal => 'Цана з опцыямі';

  @override
  String productOptionsMore(String amount) {
    return 'даражэй на $amount';
  }

  @override
  String productOptionsLess(String amount) {
    return 'танней на $amount';
  }

  @override
  String productOptionCheaper(String amount) {
    return '−$amount';
  }

  @override
  String productOptionDearer(String amount) {
    return '+$amount';
  }

  @override
  String get projectsTitle => 'Мае праекты';

  @override
  String get projectsEmptyTitle => 'Праектаў пакуль няма';

  @override
  String get projectsEmptyBody =>
      'Сабярыце праект у каталогу — ён захаваецца на прыладзе.';

  @override
  String projectsPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count фота',
      many: '$count фота',
      few: '$count фота',
      one: '$count фота',
    );
    return '$_temp0';
  }

  @override
  String projectsUpdatedAt(String date) {
    return 'Зменены $date';
  }

  @override
  String get projectsDelete => 'Выдаліць праект';

  @override
  String get projectsDeleteTitle => 'Выдаліць праект?';

  @override
  String get projectsDeleteBody =>
      'Праект і яго копіі фота выдаляцца з прылады. Арыгіналы застануцца ў галерэі.';

  @override
  String get projectsGuestTitle => 'Праект належыць гасцявой сесіі';

  @override
  String get projectsGuestBody =>
      'Праект сабраны без уваходу ў акаўнт, і перанесці яго ў акаўнт пакуль нельга. Сабярыце праект нанова з каталога.';

  @override
  String get projectsGuestBodySnapshot =>
      'Праект сабраны без уваходу ў акаўнт, і перанесці яго ў акаўнт пакуль нельга. Фотаздымкі захаваны на прыладзе — можна сабраць праект нанова з тым жа выбарам.';

  @override
  String get projectsRestart => 'Сабраць нанова';

  @override
  String get projectsRestarting => 'Сабіраем…';

  @override
  String get projectsRestartFailed => 'Не ўдалося сабраць праект нанова';

  @override
  String get orderDemoPush => 'Demo push';

  @override
  String orderDemoPushBody(String number, String status) {
    return 'Push: заказ $number — $status';
  }

  @override
  String get orderDemoTitle => 'Кіраванне статусам';

  @override
  String get orderDemoHint =>
      'Даступна толькі падтрымцы. Змяняе статус замовы на серверы.';

  @override
  String get orderDemoAdvance => 'Наступны статус';

  @override
  String get orderDemoCancel => 'Адмяніць замову';

  @override
  String get orderDemoNeedsSupport => 'Гэты пераход робіць падтрымка.';

  @override
  String get orderDemoPay => 'Аплаціць';

  @override
  String get orderDemoPaid => 'Аплата пацверджана серверам';

  @override
  String get orderDemoFailed => 'Не ўдалося выканаць дзеянне';

  @override
  String get orderDemoTooltip => 'Кантролі mock-сервера (толькі debug)';

  @override
  String get paymentPanelTitle => 'Аплата замовы';

  @override
  String paymentAmountDue(String amount) {
    return 'Да аплаты $amount';
  }

  @override
  String get paymentRegionLabel => 'Краіна аплаты';

  @override
  String get paymentRegionBy => 'Беларусь';

  @override
  String get paymentRegionRu => 'Расія';

  @override
  String get paymentMethodCard => 'Картай анлайн';

  @override
  String get paymentMethodSbp => 'СБП';

  @override
  String get paymentMethodCod => 'Пры атрыманні';

  @override
  String get paymentMethodWallet => 'Кашалёк';

  @override
  String get paymentMethodUnknown => 'Спосаб аплаты';

  @override
  String get paymentPay => 'Аплаціць';

  @override
  String get paymentPreparing => 'Гатуем плацёж…';

  @override
  String get paymentAwaitingUser =>
      'Аплаціце на старонцы банка і вярніцеся ў праграму';

  @override
  String get paymentHostedPageFailed =>
      'Не ўдалося адкрыць старонку аплаты. Паспрабуйце яшчэ раз.';

  @override
  String get paymentHostedPageAgain => 'Адкрыць старонку аплаты';

  @override
  String get paymentChecking => 'Правяраем аплату…';

  @override
  String get paymentUncertain => 'Удакладняем статус аплаты…';

  @override
  String get paymentPaid => 'Замова аплачана';

  @override
  String get paymentFailed => 'Аплата не прайшла';

  @override
  String get paymentRetry => 'Паспрабаваць зноў';

  @override
  String get paymentExpired => 'Тэрмін аплаты скончыўся';

  @override
  String get paymentCreateNew => 'Стварыць новую';

  @override
  String get paymentCanceled => 'Аплата адменена';

  @override
  String get paymentOnDelivery => 'Аплата пры атрыманні';

  @override
  String get paymentOnDeliveryHint =>
      'Спосаб выбраны. Грошы — пры атрыманні замовы.';

  @override
  String get paymentReceipt => 'Чэк';

  @override
  String get paymentReceiptTitle => 'Чэк';

  @override
  String get paymentReceiptFiscal => 'Фіскальны нумар';

  @override
  String get paymentReceiptAmount => 'Сума';

  @override
  String get paymentReceiptDate => 'Дата';

  @override
  String get paymentReceiptShare => 'Падзяліцца';

  @override
  String get paymentReceiptSubject => 'Чэк PicPac';

  @override
  String get paymentReceiptUnavailable => 'Чэк яшчэ не гатовы';

  @override
  String get paymentReceiptVat => 'У тым ліку ПДВ';

  @override
  String get paymentShareFailed => 'Не ўдалося падзяліцца чэкам';

  @override
  String get paymentEripCode => 'Код АРІП';

  @override
  String get paymentSbpHint =>
      'Адкрыйце старонку аплаты і пацвердзіце перавод у банку';

  @override
  String get paymentNoMethods => 'Няма даступных спосабаў аплаты';

  @override
  String get paymentMethodsFailed => 'Не ўдалося загрузіць спосабы аплаты';

  @override
  String get paymentCheckFailed => 'Не ўдалося праверыць аплату';

  @override
  String get paymentCheckAgain => 'Праверыць яшчэ раз';

  @override
  String get paymentAlreadyPaid =>
      'Замова ўжо аплачана — новы плацёж не патрэбны';

  @override
  String get paymentNotRequired => 'Замова не патрабуе аплаты';

  @override
  String get paymentNotPayable => 'Гэтую замову нельга аплаціць';

  @override
  String get paymentStatusUnknown => 'Удакладняем статус';

  @override
  String get assistantButton => 'Падказаць';

  @override
  String get assistantTitle => 'Што палепшыць?';

  @override
  String get assistantHint => 'Напрыклад: «зрабі цяплей»';

  @override
  String get assistantAsk => 'Спытаць';

  @override
  String get assistantThinking => 'Глядзім на аркушы…';

  @override
  String get assistantBefore => 'Было';

  @override
  String get assistantAfter => 'Станет';

  @override
  String get assistantApply => 'Прымяніць';

  @override
  String get assistantRetry => 'Паспрабаваць яшчэ';

  @override
  String get assistantOffline => 'Для свабоднага запыту патрэбен інтэрнэт';

  @override
  String get assistantQuickMode => 'Хуткі рэжым: правілы на прыладзе';

  @override
  String get assistantRemoteMode => 'Прапанова мадэлі';

  @override
  String get assistantRejected => 'Мадэль прапанавала несумяшчальную змену';

  @override
  String get assistantNoChange => 'Змяняць няма чаго — усё ўжо так';

  @override
  String get assistantApplied => 'Гатова. Адкаціць можна кнопкай «Адкаціць»';

  @override
  String get assistantChangesTitle => 'Што зменіцца';

  @override
  String get assistantWarningsTitle => 'Варта ведаць';

  @override
  String assistantPreviewLabel(Object side) {
    return 'Перадпрагляд аркуша: $side';
  }

  @override
  String assistantPhotoCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count фота',
      many: '$count фота',
      few: '$count фота',
      one: '$count фота',
    );
    return '$_temp0';
  }

  @override
  String assistantSheetCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count аркуша',
      many: '$count аркушаў',
      few: '$count аркушы',
      one: '$count аркуш',
    );
    return '$_temp0';
  }

  @override
  String assistantSlotCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count кадра',
      many: '$count кадраў',
      few: '$count кадры',
      one: '$count кадр',
    );
    return '$_temp0';
  }

  @override
  String get assistantChipWarmer => 'Зрабі цяплей';

  @override
  String get assistantChipBrighter => 'Ярчэй';

  @override
  String get assistantChipMono => 'Ч/б';

  @override
  String get assistantChipFill => 'Запоўні пустыя месцы';

  @override
  String get assistantChipDenser => 'Шчыльней';

  @override
  String get assistantChipAlign => 'Выраўняй кадры';

  @override
  String assistantChangeTone(Object details) {
    return 'Святло і колер: $details';
  }

  @override
  String assistantChangeLook(Object details) {
    return 'Стыль: $details';
  }

  @override
  String assistantChangeFraming(Object details) {
    return 'Кадраванне: $details';
  }

  @override
  String assistantChangeAssign(Object details) {
    return 'Фота ў кадрах: $details';
  }

  @override
  String assistantChangeReplace(Object details) {
    return 'Замяна фота: $details';
  }

  @override
  String assistantChangeClearSlot(Object details) {
    return 'Фота прыбіраецца: $details';
  }

  @override
  String assistantChangeBackground(Object details) {
    return 'Колер аркуша: $details';
  }

  @override
  String assistantChangeLayout(Object details) {
    return 'Шаблон аркуша: $details';
  }

  @override
  String assistantChangeSwap(Object details) {
    return 'Абмен фота: $details';
  }

  @override
  String assistantChangeMore(Object count) {
    return 'і яшчэ $count';
  }

  @override
  String get assistantAdjustOther => 'Іншае';

  @override
  String get editorAdjustContrast => 'Кантраст';

  @override
  String get editorAdjustTint => 'Адценне';

  @override
  String get editorAdjustSaturation => 'Насычанасць';

  @override
  String get editorAdjustVibrance => 'Скачнасць';

  @override
  String assistantResultReady(Object count, Object intent) {
    return '$intent: зменаў — $count';
  }

  @override
  String get assistantDisabled => 'Свабодныя запыты зараз недаступныя';

  @override
  String get navIdeas => 'Ідэі';

  @override
  String get inspirationTitle => 'Ідэі';

  @override
  String get inspirationTagAll => 'Усе';

  @override
  String get inspirationShowAll => 'Паказаць усе ідэі';

  @override
  String get inspirationFilterFavorites => 'Выбранае';

  @override
  String get inspirationTagBarLabel => 'Фільтр па тэгах';

  @override
  String inspirationCardLabel(String title, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count фота',
      many: '$count фота',
      few: '$count фота',
      one: '$count фота',
    );
    return 'Шаблон: $title, $_temp0';
  }

  @override
  String inspirationPreviewLabel(String title, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count фота',
      many: '$count фота',
      few: '$count фота',
      one: '$count фота',
    );
    return 'Макет шаблона «$title», $_temp0';
  }

  @override
  String inspirationSaveTitle(String title) {
    return 'Захаваць «$title» у выбранае';
  }

  @override
  String inspirationRemoveTitle(String title) {
    return 'Прыбраць «$title» з выбранага';
  }

  @override
  String get inspirationSaveToFavorites => 'У выбранае';

  @override
  String get inspirationRemoveFromFavorites => 'У выбраным';

  @override
  String get inspirationFavoriteFailed =>
      'Не ўдалося абнавіць выбранае. Праверце сувязь і паспрабуйце яшчэ раз.';

  @override
  String get inspirationEmptyFavoritesTitle => 'Тут пакуль пуста';

  @override
  String get inspirationEmptyFavoritesBody =>
      'Захоўвайце ідэі — яны з\'явяцца тут';

  @override
  String get inspirationEmptyTagTitle => 'Нічога не знайшлося';

  @override
  String get inspirationEmptyTagBody =>
      'Паспрабуйце іншы тэг або пакажыце ўсе ідэі';

  @override
  String get inspirationEmptyTitle => 'Ідэй пакуль няма';

  @override
  String get inspirationEmptyBody =>
      'Шаблоны з\'явяцца тут, як толькі сервер іх аддасць';

  @override
  String get inspirationLoading => 'Загружаем ідэі';

  @override
  String get inspirationLoadMore => 'Паказаць яшчэ';

  @override
  String get inspirationLoadMoreFailed =>
      'Не ўдалося загрузіць яшчэ. Паспрабуйце яшчэ раз.';

  @override
  String get inspirationDetailTitle => 'Ідэя';

  @override
  String inspirationSupportsLabel(String formats) {
    return 'Падыходзіць для: $formats';
  }

  @override
  String get inspirationNoSupports =>
      'Гэты шаблон пакуль не падыходзіць ні аднаму фармату';

  @override
  String get inspirationApply => 'Прымяніць';

  @override
  String get inspirationApplying => 'Прымяняем…';

  @override
  String get inspirationApplyProblemTitle => 'Шаблон не падышоў';

  @override
  String get inspirationApplyNotSupported =>
      'Гэты шаблон не падыходзіць для фармату адкрытага праекта. Выберыце іншы шаблон.';

  @override
  String inspirationApplyNotEnoughPhotos(int slots, int photos) {
    return 'У шаблоне $slots кадраў, а ў праекце $photos фота. Дадайце фота або выберыце шаблон па колькасці здымкаў.';
  }

  @override
  String get inspirationApplyCommandFailed =>
      'Не ўдалося раскласці фота па шаблоне. Паспрабуйце яшчэ раз.';

  @override
  String get inspirationApplyNoFormat =>
      'Адпаведны фармат зараз недаступны. Праверце сувязь і паспрабуйце яшчэ раз.';

  @override
  String get inspirationApplyReady => 'Шаблон ужыты';

  @override
  String get inspirationApplyFailed =>
      'Не ўдалося ўжыць шаблон. Праверце сувязь і паспрабуйце яшчэ раз.';

  @override
  String get inspirationTagFamily => 'Сям\'я';

  @override
  String get inspirationTagWedding => 'Вяселле';

  @override
  String get inspirationTagGraduation => 'Выпускны';

  @override
  String get inspirationTagTravel => 'Падарожжа';

  @override
  String get inspirationTagMinimal => 'Мінімалізм';

  @override
  String get inspirationTagKids => 'Дзіцячае';

  @override
  String get inspirationTemplateDuoSplit => 'Дзве гісторыі';

  @override
  String get inspirationTemplateTrioHero => 'Вялікі кадр і два маленькія';

  @override
  String get inspirationTemplateQuadGrid => 'Сетка 2×2';

  @override
  String get inspirationTemplatePolaroid => 'Палароід';

  @override
  String get inspirationTemplatePanorama => 'Панарама';

  @override
  String get inspirationTemplateStrip3 => 'Тры кадры слупком';

  @override
  String get inspirationTemplatePolaroidLarge => 'Вялікі палароід';

  @override
  String get inspirationTemplatePanoramaWide => 'Шырокая панарама';

  @override
  String get inspirationTemplateBookSingle => 'Адно фота на разварот';

  @override
  String get inspirationTemplateBookDuo => 'Два фота на разварот';

  @override
  String get inspirationTemplateBookTrio => 'Разварот з акцэнтам';

  @override
  String get inspirationTemplateBookQuad => 'Разварот 2×2';

  @override
  String get inspirationTemplateBookSix => 'Шэсць фота на разварот';

  @override
  String get inspirationTemplateBookPanorama => 'Панарама на разварот';

  @override
  String get inspirationTemplateFallback => 'Шаблон';
}
