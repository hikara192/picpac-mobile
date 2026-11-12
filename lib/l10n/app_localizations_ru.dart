// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'PicPac';

  @override
  String get navCatalog => 'Каталог';

  @override
  String get navOrders => 'Заказы';

  @override
  String get navSupport => 'Поддержка';

  @override
  String get navProfile => 'Профиль';

  @override
  String get placeholderTitle => 'Раздел в разработке';

  @override
  String get placeholderBody => 'Скоро здесь появится рабочий экран.';

  @override
  String get actionRetry => 'Повторить';

  @override
  String get actionClose => 'Закрыть';

  @override
  String get actionBack => 'Назад';

  @override
  String get actionCancel => 'Отмена';

  @override
  String get actionContinue => 'Продолжить';

  @override
  String get actionLogout => 'Выйти';

  @override
  String get actionLogin => 'Войти';

  @override
  String get actionGoCatalog => 'В каталог';

  @override
  String get actionBuild => 'Собрать';

  @override
  String get actionApply => 'Применить';

  @override
  String get actionRemove => 'Удалить';

  @override
  String get actionCheckout => 'Оформить';

  @override
  String get actionLoadMore => 'Показать ещё';

  @override
  String get actionFind => 'Найти';

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
    return 'Макет разворота $current из $total';
  }

  @override
  String get startupTitle => 'Не удалось запустить PicPac';

  @override
  String get startupBody => 'Проверьте подключение и попробуйте снова.';

  @override
  String get startupRetrying => 'Запускаем…';

  @override
  String get errorGeneric => 'Что-то пошло не так. Попробуйте ещё раз.';

  @override
  String get errorNetwork =>
      'Нет соединения. Проверьте сеть и попробуйте снова.';

  @override
  String get errorTimeout => 'Сервер не ответил. Попробуйте ещё раз.';

  @override
  String get errorUnauthorized => 'Нужно войти снова.';

  @override
  String get errorForbidden => 'Недостаточно прав для этого действия.';

  @override
  String get errorConflictRevision =>
      'Проект изменён на другом устройстве. Обновите черновик.';

  @override
  String get errorIdempotencyConflict =>
      'Заказ уже создан. Откройте историю заказов.';

  @override
  String get errorValidation => 'Проверьте введённые данные.';

  @override
  String get errorNotFound => 'Не нашли то, что искали.';

  @override
  String routeNotFound(String path) {
    return 'Страница не найдена: $path';
  }

  @override
  String get errorRateLimited => 'Слишком много попыток. Подождите минуту.';

  @override
  String get errorInvalidData =>
      'Сервер вернул неожиданный ответ. Мы уже разбираемся.';

  @override
  String get catalogTitle => 'Каталог';

  @override
  String get catalogLoading => 'Загружаем каталог';

  @override
  String get catalogEmptyTitle => 'Каталог пока пуст';

  @override
  String get catalogEmptyBody =>
      'Мы обновляем ассортимент. Загляните чуть позже.';

  @override
  String get catalogOpenCart => 'Корзина';

  @override
  String get catalogCartHint => 'Открыть корзину';

  @override
  String priceFrom(String price) {
    return 'от $price';
  }

  @override
  String get productFormatsTitle => 'Форматы и цены';

  @override
  String productSize(String width, String height) {
    return '$width × $height мм';
  }

  @override
  String productEta(int days) {
    return 'готовность $days дн.';
  }

  @override
  String get productPriceUnavailable => 'Цена по запросу';

  @override
  String get productBuildFailed => 'Не удалось создать проект';

  @override
  String get productLoginToBuild =>
      'Не удалось собрать проект. Повторите попытку.';

  @override
  String get productChooseFormat => 'Выберите формат';

  @override
  String productHeroHint(String title) {
    return 'Изображение товара «$title»';
  }

  @override
  String get cartTitle => 'Корзина';

  @override
  String get cartEmptyTitle => 'Корзина пуста';

  @override
  String get cartEmptyBody => 'Соберите проект в каталоге — он появится здесь.';

  @override
  String get cartExpiredTitle => 'Корзина истекла';

  @override
  String get cartExpiredBody =>
      'Позиции хранятся 14 дней. Соберите проект заново.';

  @override
  String get cartSubtotal => 'Итого';

  @override
  String cartEta(int days) {
    return 'Готовность через $days дн.';
  }

  @override
  String get cartQuantity => 'Количество';

  @override
  String get cartIncrease => 'Добавить штуку';

  @override
  String get cartDecrease => 'Убрать штуку';

  @override
  String get cartRemoveTitle => 'Удалить позицию?';

  @override
  String cartRemoveBody(String title) {
    return '«$title» пропадёт из корзины.';
  }

  @override
  String get cartUnavailableItem => 'Проект недоступен';

  @override
  String get cartCannotCheckout =>
      'Часть позиций недоступна. Удалите их, чтобы продолжить.';

  @override
  String get cartUpdateFailed => 'Не удалось обновить корзину';

  @override
  String cartExpiresAt(String date) {
    return 'Корзина хранится до $date';
  }

  @override
  String cartItemsCount(int count) {
    return 'Позиций: $count';
  }

  @override
  String get checkoutTitle => 'Оформление';

  @override
  String get checkoutDelivery => 'Получение';

  @override
  String get checkoutPickupPoint => 'Пункт выдачи';

  @override
  String get checkoutPickupSlot => 'Время получения';

  @override
  String get checkoutAddress => 'Адрес';

  @override
  String get checkoutAddressHint => 'Улица, дом, квартира';

  @override
  String get checkoutPromo => 'Промокод';

  @override
  String get checkoutPromoHint => 'Например, TEST10';

  @override
  String checkoutPromoApplied(String code) {
    return 'Промокод $code применён';
  }

  @override
  String get checkoutPromoUnknown => 'Такого промокода нет или он истёк';

  @override
  String get checkoutPromoClear => 'Убрать промокод';

  @override
  String get checkoutContacts => 'Контакты';

  @override
  String get checkoutName => 'Имя';

  @override
  String get checkoutPhone => 'Телефон';

  @override
  String get checkoutNameRequired => 'Укажите имя';

  @override
  String get checkoutPhoneRequired => 'Укажите телефон';

  @override
  String get checkoutPhoneInvalid =>
      'Проверьте номер: +375 (29) 123-45-67 или +7 999 123-45-67';

  @override
  String get checkoutSubmit => 'Оформить заказ';

  @override
  String get checkoutSubmitting => 'Оформляем…';

  @override
  String get checkoutLoginRequired => 'Войти и оформить';

  @override
  String get checkoutSummary => 'Итог';

  @override
  String get checkoutPreliminary =>
      'Предварительно: точную сумму подтвердит сервер при оформлении.';

  @override
  String get checkoutDeliveryRequired => 'Выберите способ получения';

  @override
  String get checkoutSlotRequired => 'Выберите время получения';

  @override
  String get checkoutAddressRequired => 'Укажите адрес доставки';

  @override
  String get checkoutFailed => 'Не удалось оформить заказ';

  @override
  String get checkoutEmptyCart =>
      'Корзина пуста — добавьте проект из каталога.';

  @override
  String get checkoutNoSlots => 'Свободных слотов нет. Выберите другой пункт.';

  @override
  String get checkoutPhoneHint => '+375 29 123 45 67';

  @override
  String get priceProduct => 'Товары';

  @override
  String get priceOptions => 'Опции';

  @override
  String get pricePromo => 'Скидка';

  @override
  String get priceDelivery => 'Доставка';

  @override
  String get deliveryPickup => 'Самовывоз';

  @override
  String get deliveryEuropochta => 'Европочта';

  @override
  String get deliveryBelpochta => 'Белпочта';

  @override
  String get deliveryEms => 'EMS';

  @override
  String get deliveryCourierMinsk => 'Курьер по Минску';

  @override
  String get deliveryCourierBelarus => 'Курьер по Беларуси';

  @override
  String deliveryDays(int days) {
    return '$days дн.';
  }

  @override
  String deliveryFreeFrom(String price) {
    return 'бесплатно от $price';
  }

  @override
  String get deliveryKindPickup => 'Самовывоз';

  @override
  String get deliveryKindPost => 'Почта';

  @override
  String get deliveryKindEms => 'EMS';

  @override
  String get deliveryKindCourier => 'Курьер';

  @override
  String get deliveryKindUnknown => 'Получение';

  @override
  String get ordersTitle => 'Заказы';

  @override
  String get ordersEmptyTitle => 'Заказов пока нет';

  @override
  String get ordersEmptyBody => 'Оформите первый заказ — он появится здесь.';

  @override
  String get ordersLoginRequired => 'Заказы хранятся в аккаунте.';

  @override
  String get ordersStale => 'Данные могут быть устаревшими';

  @override
  String get ordersLookup => 'Найти заказ по номеру';

  @override
  String ordersOpenOrder(String number) {
    return 'Открыть заказ $number';
  }

  @override
  String ordersItemsCount(int count) {
    return 'Позиций: $count';
  }

  @override
  String get statusUpdating => 'обновляется';

  @override
  String get orderTitle => 'Заказ';

  @override
  String orderHeading(String number) {
    return 'Заказ $number';
  }

  @override
  String orderCreatedAt(String date) {
    return 'Оформлен $date';
  }

  @override
  String get orderItemsTitle => 'Состав';

  @override
  String orderItemQuantity(int quantity, String price) {
    return '$quantity × $price';
  }

  @override
  String get orderTotalsTitle => 'Сумма';

  @override
  String get orderSubtotal => 'Товары';

  @override
  String get orderDiscount => 'Скидка';

  @override
  String get orderDeliveryCost => 'Доставка';

  @override
  String get orderTotal => 'Итого';

  @override
  String get orderDeliveryTitle => 'Получение';

  @override
  String get orderPayCta => 'Оплатить заказ';

  @override
  String get orderPaymentTitle => 'Оплата';

  @override
  String get orderFulfillmentTitle => 'Готовность';

  @override
  String orderEta(String date) {
    return 'Готово к $date';
  }

  @override
  String get orderTimelineTitle => 'Статусы';

  @override
  String orderTracking(String number) {
    return 'Трек-номер $number';
  }

  @override
  String get orderPickupCode => 'Код самовывоза';

  @override
  String get orderPickupCodeHint => 'Назовите код на пункте выдачи';

  @override
  String get orderProblem => 'Проблема с заказом';

  @override
  String get orderNotFound => 'Заказ не найден';

  @override
  String get orderOfflineUnavailable =>
      'Заказ не сохранён на устройстве. Проверьте соединение.';

  @override
  String get orderStatusDraft => 'Черновик';

  @override
  String get orderStatusPlaced => 'Оформлен';

  @override
  String get orderStatusAccepted => 'Принят';

  @override
  String get orderStatusModeration => 'На модерации';

  @override
  String get orderStatusProduction => 'В производстве';

  @override
  String get orderStatusReady => 'Готов';

  @override
  String get orderStatusReadyForPickup => 'Готов к выдаче';

  @override
  String get orderStatusShipped => 'Передан в доставку';

  @override
  String get orderStatusCompleted => 'Завершён';

  @override
  String get orderStatusCanceled => 'Отменён';

  @override
  String get orderStatusReturned => 'Возврат';

  @override
  String get paymentStatusCreated => 'Ожидает оплаты';

  @override
  String get paymentStatusRequiresAction => 'Нужно подтверждение';

  @override
  String get paymentStatusPendingUser => 'Ожидает оплаты';

  @override
  String get paymentStatusProcessing => 'Платёж обрабатывается';

  @override
  String get paymentStatusSucceeded => 'Оплачен';

  @override
  String get paymentStatusFailed => 'Оплата не прошла';

  @override
  String get paymentStatusExpired => 'Срок оплаты истёк';

  @override
  String get paymentStatusCanceled => 'Оплата отменена';

  @override
  String get paymentStatusRefunded => 'Возврат';

  @override
  String get paymentStatusPartiallyRefunded => 'Частичный возврат';

  @override
  String get paymentStatusPendingOnDelivery => 'Оплата при получении';

  @override
  String get lookupTitle => 'Найти заказ';

  @override
  String get lookupBody =>
      'Введите номер заказа и последние 4 цифры телефона из заказа.';

  @override
  String get lookupNumber => 'Номер заказа';

  @override
  String get lookupPhoneLast4 => 'Последние 4 цифры телефона';

  @override
  String get lookupPhoneLast4Invalid => 'Нужны 4 цифры';

  @override
  String get lookupNotFound => 'Заказ с таким номером и телефоном не найден';

  @override
  String get mediaHeicUnsupported =>
      'HEIC пока не поддерживается. Сохраните фото как JPEG или PNG и попробуйте снова.';

  @override
  String mediaTooLarge(int limit) {
    return 'Файл больше $limit МБ. Уменьшите фото и попробуйте снова.';
  }

  @override
  String get mediaUnsupported =>
      'Этот формат не печатается. Нужны JPEG или PNG.';

  @override
  String mediaTooSmallPixels(int width, int height) {
    return 'Фото $width×$height px слишком маленькое для печати.';
  }

  @override
  String get mediaUnreadable =>
      'Не удалось прочитать файл. Выберите другое фото.';

  @override
  String get mediaPermissionTitle => 'Нет доступа к фотографиям';

  @override
  String get mediaPermissionBody =>
      'Разрешите PicPac доступ к фотографиям в настройках телефона и повторите выбор.';

  @override
  String get mediaPermissionRetry => 'Повторить выбор';

  @override
  String get mediaRejectedTitle => 'Не добавлено';

  @override
  String mediaDuplicatesSkipped(int count) {
    return 'Уже есть в проекте: $count';
  }

  @override
  String get createTitle => 'Проект';

  @override
  String get createPhotosTitle => 'Фотографии';

  @override
  String createPhotosCount(int count, int max) {
    return '$count из $max';
  }

  @override
  String get createAddPhotos => 'Добавить фото';

  @override
  String createLimitReached(int max) {
    return 'На лист помещается $max фото. Уберите лишние, чтобы добавить новые.';
  }

  @override
  String createMinPhotos(int min) {
    return 'Нужно минимум $min фото.';
  }

  @override
  String get createEmptyTitle => 'Пока нет фотографий';

  @override
  String get createEmptyBody =>
      'Добавьте фото с устройства — оригиналы останутся у вас.';

  @override
  String get createDeleteTitle => 'Удалить фото?';

  @override
  String createDeleteBody(String name) {
    return 'Фото «$name» пропадёт из проекта. Оригинал на устройстве не изменится.';
  }

  @override
  String get createReorderHint =>
      'Удерживайте фото и перетащите, чтобы изменить порядок.';

  @override
  String get createOfflineBanner =>
      'Нет сети. Изменения сохранятся на устройстве и уйдут на сервер позже.';

  @override
  String get createSyncSaving => 'Сохраняем…';

  @override
  String get createSyncSaved => 'Сохранено';

  @override
  String get createSyncPending => 'Ждёт сети';

  @override
  String get createDraftRestored => 'Черновик восстановлен с устройства';

  @override
  String get createConflictTitle => 'Проект изменён на другом устройстве';

  @override
  String get createConflictBody =>
      'Версия на сервере новее. Загрузите её или оставьте свои правки — они перезапишут серверные.';

  @override
  String get createConflictLoadServer => 'Загрузить с сервера';

  @override
  String get createConflictKeepLocal => 'Оставить мои правки';

  @override
  String get createOrder => 'Оформить заказ';

  @override
  String get createEditSheets => 'Изменить листы';

  @override
  String createPreviewTitle(int index, int total) {
    return 'Лист $index из $total';
  }

  @override
  String createPhotoUploading(int index) {
    return 'Загружаем фото $index';
  }

  @override
  String createCancelUpload(int index) {
    return 'Отменить загрузку фото $index';
  }

  @override
  String createUploadRetry(int index) {
    return 'Повторить загрузку фото $index';
  }

  @override
  String get createUploadFailed => 'Фото не загрузилось';

  @override
  String get createLocalCopy => 'Локальная копия';

  @override
  String get createLocalCopyHint =>
      'Проект на сервере недоступен — открыта копия с устройства.';

  @override
  String get createOrderNeedsPhotos =>
      'Добавьте хотя бы одно фото — тогда можно оформить заказ.';

  @override
  String get createUndo => 'Отменить';

  @override
  String get createRedo => 'Вернуть';

  @override
  String createPhotoNumber(int index) {
    return 'Фото $index';
  }

  @override
  String createMovePhoto(int index) {
    return 'Переставить фото $index';
  }

  @override
  String createRemovePhoto(int index) {
    return 'Удалить фото $index';
  }

  @override
  String get createFormatMissing =>
      'Формат недоступен без сети. Откройте проект при подключении.';

  @override
  String get createEnhanceAll => 'Улучшить все';

  @override
  String createEnhanceApplied(int count) {
    return 'Улучшено $count фото';
  }

  @override
  String get createEnhanceAlready => 'Всё уже улучшено';

  @override
  String get createEnhanceFailed =>
      'Не получилось улучшить. Попробуйте ещё раз.';

  @override
  String get createEnhanceUndo => 'Вернуть';

  @override
  String get createEnhancePreviewBefore => 'До';

  @override
  String get createEnhancePreviewAfter => 'После';

  @override
  String get createEnhancePreviewHint =>
      'Свет и тепло подстроятся под каждое фото';

  @override
  String get createResetToImported => 'Вернуть как было';

  @override
  String get createResetToImportedHint =>
      'Сбросить кадры, свет и стиль. Фото останутся.';

  @override
  String get createLayoutTitle => 'Можно плотнее';

  @override
  String createLayoutBody(int sheets, int current) {
    String _temp0 = intl.Intl.pluralLogic(
      sheets,
      locale: localeName,
      other: '$sheets листа',
      many: '$sheets листов',
      few: '$sheets листа',
      one: '$sheets лист',
    );
    return '$_temp0 вместо $current';
  }

  @override
  String get createLayoutHint => 'Кадры и обрезка сохранятся.';

  @override
  String get createLayoutAccept => 'Так лучше';

  @override
  String get createLayoutKeep => 'Оставить по одному';

  @override
  String get createLayoutApplied => 'Раскладка готова';

  @override
  String get editorTitle => 'Кадрирование';

  @override
  String get editorZoom => 'Масштаб';

  @override
  String get editorCenter => 'По центру';

  @override
  String get editorDone => 'Готово';

  @override
  String editorSheetOf(int index, int total) {
    return 'Лист $index из $total';
  }

  @override
  String get editorPrevSheet => 'Предыдущий лист';

  @override
  String get editorNextSheet => 'Следующий лист';

  @override
  String get editorEmptySlot => 'Добавьте фото';

  @override
  String get editorSlotEmpty => 'пусто';

  @override
  String get editorSlotSelected => 'выбрано';

  @override
  String editorCropHandle(String corner) {
    return 'Изменить кадр, угол $corner';
  }

  @override
  String get editorCornerTopLeft => 'левый верхний';

  @override
  String get editorCornerTopRight => 'правый верхний';

  @override
  String get editorCornerBottomLeft => 'левый нижний';

  @override
  String get editorCornerBottomRight => 'правый нижний';

  @override
  String get editorGestureHint =>
      'Тяните фото, чтобы сдвинуть кадр. Двумя пальцами — масштаб.';

  @override
  String get editorSelectSlotHint => 'Коснитесь кадра, чтобы выбрать его';

  @override
  String get editorNoSlotSelected => 'Выберите кадр на листе';

  @override
  String editorSlotSemantic(int index, int total, String state) {
    return 'Кадр $index из $total, $state';
  }

  @override
  String get editorToolFrame => 'Кадр';

  @override
  String get editorToolLight => 'Свет';

  @override
  String get editorToolWarmth => 'Тепло';

  @override
  String get editorToolStyle => 'Стиль';

  @override
  String get editorToolRotate => 'Повернуть';

  @override
  String get editorToolReplace => 'Заменить';

  @override
  String get editorToolSwap => 'Обменять';

  @override
  String get editorToolBackground => 'Фон';

  @override
  String get editorToolPending => 'Скоро: ждёт обновления редактора';

  @override
  String editorLightValue(String value) {
    return '$value EV';
  }

  @override
  String get editorLightHint => 'Светлее или темнее';

  @override
  String editorWarmthValue(String value) {
    return '$value';
  }

  @override
  String get editorWarmthHint => 'Теплее или холоднее';

  @override
  String editorZoomValue(String value) {
    return '$value×';
  }

  @override
  String get editorStyleStrength => 'Сила';

  @override
  String get editorStyleApplyAll => 'Применим ко всем фото';

  @override
  String get lookAsIs => 'Как есть';

  @override
  String get lookWarm => 'Тепло';

  @override
  String get lookFilm => 'Плёнка';

  @override
  String get lookBright => 'Ярче';

  @override
  String get lookSoft => 'Мягко';

  @override
  String get lookMono => 'Ч/Б';

  @override
  String get editorRotateHint => 'Если фото лежит на боку';

  @override
  String get editorRotateCw => 'Повернуть на 90°';

  @override
  String get editorFlip => 'Отразить';

  @override
  String get editorSwapPickFirst =>
      'Коснитесь кадра, с которым хотите поменяться';

  @override
  String editorSwapPickSecond(int index) {
    return 'Поменяем с фото $index. Коснитесь второго кадра.';
  }

  @override
  String get editorReplaceTitle => 'Фото в кадре';

  @override
  String get editorBackgroundTitle => 'Цвет листа';

  @override
  String get editorBackgroundPaper => 'Как бумага';

  @override
  String get editorBackgroundCream => 'Кремовый';

  @override
  String get editorBackgroundMint => 'Мята';

  @override
  String get editorBackgroundBeige => 'Бежевый';

  @override
  String get editorNoPhotoSelected => 'Сначала выберите фото на листе';

  @override
  String get preflightTitle => 'Проверка макета';

  @override
  String get preflightStatusClean => 'Замечаний нет';

  @override
  String preflightStatusWarnings(int count) {
    return 'Замечания: $count';
  }

  @override
  String preflightStatusBlocking(int count) {
    return 'Нельзя продолжить: $count';
  }

  @override
  String get preflightOpenIssues => 'Открыть замечания';

  @override
  String get preflightAckAndOrder => 'Подтвердить и оформить';

  @override
  String get preflightRunning => 'Проверяем макет…';

  @override
  String get preflightCleanTitle => 'Можно печатать';

  @override
  String get preflightCleanBody => 'Все кадры заполнены, разрешения хватает.';

  @override
  String preflightIssuesTitle(int count) {
    return 'Замечания: $count';
  }

  @override
  String get preflightBlockingNote =>
      'Пока есть блокирующие замечания, заказ недоступен.';

  @override
  String get preflightEmptySlot => 'Добавьте фото';

  @override
  String preflightEmptySlotHint(int sheet, String slot) {
    return 'Лист $sheet, кадр $slot пуст.';
  }

  @override
  String preflightLowDpi(String photo, String size, String required) {
    return 'Это фото $photo px, для $size нужно $required — станет мыльным.';
  }

  @override
  String preflightUnsupported(String mime) {
    return 'Формат $mime не печатается. Нужны JPEG или PNG.';
  }

  @override
  String preflightSafeZone(String mm) {
    return 'Контент ближе $mm мм к краю — может обрезаться.';
  }

  @override
  String get preflightTextOverflow => 'Текст не помещается в блок.';

  @override
  String get preflightFaceAtEdge =>
      'Лицо слишком близко к краю — может обрезаться.';

  @override
  String preflightSheetBadge(int sheet) {
    return 'Лист $sheet';
  }

  @override
  String preflightServerMismatch(int count) {
    return 'Сервер нашёл отличий: $count. Показываем проверку сервера.';
  }

  @override
  String get preflightOffline =>
      'Серверная проверка недоступна — показываем локальную.';

  @override
  String get preflightOverride => 'Продолжить всё равно';

  @override
  String get preflightOverrideTitle => 'Продолжить с замечаниями?';

  @override
  String get preflightOverrideBody =>
      'Заказ уйдёт в производство с текущими замечаниями. Подтверждение сохраним в журнале.';

  @override
  String get preflightOverrideConfirm => 'Продолжить';

  @override
  String get preflightOverrideRecorded => 'Подтверждение записано';

  @override
  String get preflightToCart => 'В корзину';

  @override
  String get preflightAdding => 'Добавляем…';

  @override
  String get preflightFix => 'Исправить';

  @override
  String get preflightAddFailed => 'Не удалось добавить в корзину';

  @override
  String get preflightFixHint => 'Открыть кадр в редакторе';

  @override
  String get preflightWaitPhotos =>
      'Дождитесь загрузки фото — заказ станет доступен.';

  @override
  String get preflightSharePdf => 'Поделиться PDF';

  @override
  String preflightSharePreparing(int done, int total) {
    return 'Готовим PDF: $done из $total';
  }

  @override
  String get preflightShareOpening => 'Открываем…';

  @override
  String get preflightShareBlocked =>
      'Исправьте замечания или подтвердите их, чтобы поделиться PDF.';

  @override
  String get preflightShareFailed => 'Не удалось подготовить PDF';

  @override
  String get preflightShareNotLoaded =>
      'Проект ещё загружается — попробуйте через пару секунд.';

  @override
  String get preflightShareNothing => 'В проекте нет листов для экспорта.';

  @override
  String get preflightShareRenderFailed =>
      'Не удалось отрисовать макет. Попробуйте ещё раз.';

  @override
  String get preflightShareOpenFailed =>
      'Не удалось открыть «Поделиться». Попробуйте ещё раз.';

  @override
  String get loginRegisterAction => 'Создать аккаунт';

  @override
  String get loginTitle => 'Вход в PicPac';

  @override
  String get loginPromise => 'Храните воспоминания красиво';

  @override
  String get loginGuestNote => 'Каталог и сборка — без входа';

  @override
  String get loginPasswordMode => 'По паролю';

  @override
  String get loginCodeMode => 'По коду';

  @override
  String get loginEmailLabel => 'Email';

  @override
  String get loginEmailHint => 'name@example.com';

  @override
  String get loginEmailInvalid => 'Проверьте адрес: нужен вид name@example.com';

  @override
  String get loginPasswordLabel => 'Пароль';

  @override
  String get loginPasswordRequired => 'Введите пароль';

  @override
  String get loginPasswordHidden => 'Показать пароль';

  @override
  String get loginPasswordShown => 'Скрыть пароль';

  @override
  String get loginSubmit => 'Войти';

  @override
  String get loginInvalidCredentials => 'Неверный email или пароль';

  @override
  String get loginSendCode => 'Получить код';

  @override
  String get loginCodeLabel => 'Код из письма';

  @override
  String get loginCodeHint => '4 цифры';

  @override
  String loginCodeSent(String email) {
    return 'Код отправлен на $email. Демо-код: 0000.';
  }

  @override
  String get loginCodeDemo => 'Демо-код: 0000';

  @override
  String get loginCodeInvalid => 'Код не подошёл. Проверьте цифры.';

  @override
  String get loginCodeExpired => 'Код истёк. Запросите новый.';

  @override
  String get loginDemoTitle => 'Демо-доступ';

  @override
  String get loginDemoCustomer => 'Клиент: customer@picpac.test / Test1234';

  @override
  String get loginDemoSupport => 'Поддержка: support@picpac.test / Test1234';

  @override
  String get loginDemoHint => 'Нажмите, чтобы подставить данные.';

  @override
  String get loginGuestContinue => 'Продолжить без входа';

  @override
  String get loginLookup => 'Найти заказ по номеру';

  @override
  String get loginSupportWelcome => 'Вы вошли как агент поддержки.';

  @override
  String get loginRoleFailed =>
      'Сервер не сообщил роль. Вход отменён — попробуйте ещё раз.';

  @override
  String get logoutTitle => 'Выйти из аккаунта?';

  @override
  String get logoutBody =>
      'Черновики и фото останутся на устройстве. Кеш заказов и очередь отправки будут очищены.';

  @override
  String get logoutConfirm => 'Выйти из аккаунта';

  @override
  String get logoutDone => 'Вы вышли из аккаунта';

  @override
  String get supportTitle => 'Поддержка';

  @override
  String get supportAgentMode => 'Режим поддержки';

  @override
  String get supportAgentModeHint =>
      'Вы видите все обращения клиентов. Заказы клиентов только для чтения.';

  @override
  String get supportNewTicket => 'Новое обращение';

  @override
  String get supportCreate => 'Создать обращение';

  @override
  String get supportEmptyTitle => 'Обращений пока нет';

  @override
  String get supportEmptyBody =>
      'Если что-то пошло не так с заказом, напишите нам — ответим здесь же.';

  @override
  String get supportEmptyAgentTitle => 'Обращений нет';

  @override
  String get supportEmptyAgentBody =>
      'Клиенты ещё не писали в поддержку. Обновите список позже.';

  @override
  String get supportLoginRequired => 'Обращения хранятся в аккаунте.';

  @override
  String get supportTicketCreated => 'Обращение создано';

  @override
  String get supportSubjectLabel => 'Тема';

  @override
  String get supportSubjectHint => 'Коротко: что случилось';

  @override
  String get supportSubjectRequired => 'Опишите тему в двух словах';

  @override
  String get supportMessageLabel => 'Сообщение';

  @override
  String get supportMessageHint => 'Что не так и что вы ожидали?';

  @override
  String get supportMessageRequired => 'Напишите сообщение';

  @override
  String get supportTypeLabel => 'Причина';

  @override
  String get supportTypeQuestion => 'Вопрос';

  @override
  String get supportTypeDefect => 'Брак или перепечатка';

  @override
  String get supportTypeRefund => 'Возврат';

  @override
  String get supportTypeDelivery => 'Доставка';

  @override
  String get supportTypeOther => 'Другое';

  @override
  String get supportTypeUnknown => 'Другое';

  @override
  String get supportOrderLabel => 'Заказ';

  @override
  String get supportOrderNone => 'Без заказа';

  @override
  String get supportOrderUnknown => 'Заказ недоступен';

  @override
  String supportOrderAttached(String number) {
    return 'Заказ $number';
  }

  @override
  String get supportSend => 'Отправить';

  @override
  String get supportReplyHint => 'Сообщение в поддержку';

  @override
  String get supportReplyHintAgent => 'Ответ клиенту';

  @override
  String get supportAuthorYou => 'Вы';

  @override
  String get supportAuthorCustomer => 'Клиент';

  @override
  String get supportAuthorSupport => 'Поддержка';

  @override
  String get supportQueued =>
      'Нет сети. Сообщение сохранено и уйдёт автоматически.';

  @override
  String get supportMessageQueued => 'В очереди';

  @override
  String get supportTicketClosed =>
      'Обращение закрыто. Новые сообщения недоступны.';

  @override
  String get supportForeignTicket => 'Это обращение другого клиента';

  @override
  String get supportForeignTicketBody =>
      'Показать его могут только автор и поддержка.';

  @override
  String get supportStatusOpen => 'Открыто';

  @override
  String get supportStatusPending => 'Ответ поддержки';

  @override
  String get supportStatusResolved => 'Решено';

  @override
  String get supportStatusClosed => 'Закрыто';

  @override
  String get supportStatusUnknown => 'Статус обновляется';

  @override
  String supportUpdatedAt(String date) {
    return 'Обновлено $date';
  }

  @override
  String supportMessagesCount(int count) {
    return 'Сообщений: $count';
  }

  @override
  String get supportSending => 'Отправляем…';

  @override
  String get supportSendFailed => 'Не удалось отправить сообщение';

  @override
  String get profileTitle => 'Профиль';

  @override
  String get profileGuestTitle => 'Вы не вошли';

  @override
  String get profileLanguageTitle => 'Язык';

  @override
  String get profileLanguageSystem => 'Системный';

  @override
  String get profileLanguageRu => 'Русский';

  @override
  String get profileLanguageBe => 'Беларуская';

  @override
  String get profileLanguageHint =>
      'Интерфейс переключается сразу, без перезапуска приложения.';

  @override
  String get profileDataTitle => 'Данные';

  @override
  String get profileCustomerSinceLabel => 'С нами с';

  @override
  String get profilePhoneLabel => 'Телефон';

  @override
  String get profilePhoneHint => 'Сервер отдаёт только маску номера.';

  @override
  String get profileSupportOnlyHint =>
      'В режиме поддержки доступны только обращения клиентов.';

  @override
  String get profileQueueTitle => 'Очередь отправки';

  @override
  String get profileQueueEmpty => 'Все действия отправлены.';

  @override
  String get profileQueueEmptyHint =>
      'Здесь появятся заказы и сообщения, которые не удалось отправить без сети.';

  @override
  String get profileQueueItemCheckout => 'Оформление заказа';

  @override
  String get profileQueueItemTicket => 'Обращение в поддержку';

  @override
  String get profileQueueItemMessage => 'Сообщение в поддержку';

  @override
  String get profileQueueItemUnknown => 'Действие';

  @override
  String profileQueueAttempts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count попытки',
      many: '$count попыток',
      few: '$count попытки',
      one: '$count попытка',
    );
    return '$_temp0';
  }

  @override
  String get profileQueueQueued => 'В очереди';

  @override
  String get profileQueueFailed => 'Не отправлено';

  @override
  String get profileQueueRetry => 'Повторить';

  @override
  String get profileQueueRetryAll => 'Повторить все';

  @override
  String profileQueueSent(int count) {
    return 'Отправлено: $count';
  }

  @override
  String profileQueueStillQueued(int count) {
    return 'Осталось в очереди: $count';
  }

  @override
  String profileQueueOrderSent(String number) {
    return 'Заказ $number отправлен';
  }

  @override
  String get profileTestData => 'Тестовые данные';

  @override
  String get profileTestDataHint =>
      'Черновики, копии фото и кеш заказов на этом устройстве.';

  @override
  String get profileDeleteTestData => 'Удалить черновики и кеш';

  @override
  String get profileDeleteTestDataTitle => 'Удалить тестовые данные?';

  @override
  String get profileDeleteTestDataBody =>
      'Черновики, скачанные копии фото и кеш заказов на этом устройстве будут удалены. Аккаунт и заказы на сервере останутся.';

  @override
  String profileDeleteTestDataDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Удалено $count черновика',
      many: 'Удалено $count черновиков',
      few: 'Удалено $count черновика',
      one: 'Удалён $count черновик',
    );
    return '$_temp0. Кеш очищен.';
  }

  @override
  String get profileDangerTitle => 'Удаление данных';

  @override
  String get profileDeleteAccount => 'Удалить аккаунт';

  @override
  String get profileDeleteAccountStep1Title => 'Удалить аккаунт и все данные?';

  @override
  String get profileDeleteAccountStep1Body =>
      'Вместе с аккаунтом удалятся заказы, обращения в поддержку, черновики и загруженные фото. Восстановить данные нельзя.';

  @override
  String get profileDeleteAccountStep2Title => 'Последнее подтверждение';

  @override
  String profileDeleteAccountStep2Body(String email) {
    return 'Аккаунт $email и все связанные данные будут удалены безвозвратно. Продолжить?';
  }

  @override
  String get profileDeleteAccountConfirm => 'Удалить безвозвратно';

  @override
  String get profileDeleteAccountDone => 'Аккаунт и данные удалены';

  @override
  String get profileDeleteAccountFailed =>
      'Не удалось удалить аккаунт. Попробуйте ещё раз.';

  @override
  String get profileDeletedEmail => 'ваш аккаунт';

  @override
  String cartSheetsUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count листа',
      many: '$count листов',
      few: '$count листа',
      one: '$count лист',
    );
    return '$_temp0';
  }

  @override
  String cartBooksUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count книги',
      many: '$count книг',
      few: '$count книги',
      one: '$count книга',
    );
    return '$_temp0';
  }

  @override
  String cartSpreadsUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count разворота',
      many: '$count разворотов',
      few: '$count разворота',
      one: '$count разворот',
    );
    return '$_temp0';
  }

  @override
  String get cartQuantityDerived => 'По макету';

  @override
  String get cartRecalculated => 'Корзина пересчитана по текущему макету';

  @override
  String get checkoutGuestWorkTitle => 'Проект собран как гость';

  @override
  String get checkoutGuestWorkBody =>
      'Проект собран как гость. После входа его нужно будет собрать заново.';

  @override
  String get checkoutGuestWorkConfirm => 'Понятно, войти';

  @override
  String get checkoutPreflightBlocked =>
      'Заказ нельзя оформить, пока не исправлены замечания проверки макета.';

  @override
  String get checkoutPreflightBlockedTitle => 'Заказ заблокирован проверкой';

  @override
  String get checkoutPreflightBlockedBody =>
      'Пока есть блокирующие замечания, заказ не оформляется. Исправьте их или подтвердите, что заказываете как есть.';

  @override
  String get productOptionsTitle => 'Опции';

  @override
  String get productOptionsTotal => 'Цена с опциями';

  @override
  String productOptionsMore(String amount) {
    return 'дороже на $amount';
  }

  @override
  String productOptionsLess(String amount) {
    return 'дешевле на $amount';
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
  String get projectsTitle => 'Мои проекты';

  @override
  String get projectsEmptyTitle => 'Проектов пока нет';

  @override
  String get projectsEmptyBody =>
      'Соберите проект в каталоге — он сохранится на устройстве.';

  @override
  String projectsPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count фото',
      many: '$count фото',
      few: '$count фото',
      one: '$count фото',
    );
    return '$_temp0';
  }

  @override
  String projectsUpdatedAt(String date) {
    return 'Изменён $date';
  }

  @override
  String get projectsDelete => 'Удалить проект';

  @override
  String get projectsDeleteTitle => 'Удалить проект?';

  @override
  String get projectsDeleteBody =>
      'Проект и его копии фото удалятся с устройства. Оригиналы останутся в галерее.';

  @override
  String get projectsGuestTitle => 'Проект принадлежит гостевой сессии';

  @override
  String get projectsGuestBody =>
      'Проект собран без входа в аккаунт, и перенести его в аккаунт пока нельзя. Соберите проект заново из каталога.';

  @override
  String get projectsGuestBodySnapshot =>
      'Проект собран без входа в аккаунт, и перенести его в аккаунт пока нельзя. Фотографии сохранены на устройстве — можно собрать проект заново с тем же выбором.';

  @override
  String get projectsRestart => 'Собрать заново';

  @override
  String get projectsRestarting => 'Собираем…';

  @override
  String get projectsRestartFailed => 'Не удалось собрать проект заново';

  @override
  String get orderDemoPush => 'Demo push';

  @override
  String orderDemoPushBody(String number, String status) {
    return 'Push: заказ $number — $status';
  }

  @override
  String get orderDemoTitle => 'Управление статусом';

  @override
  String get orderDemoHint =>
      'Доступно только поддержке. Меняет статус заказа на сервере.';

  @override
  String get orderDemoAdvance => 'Следующий статус';

  @override
  String get orderDemoCancel => 'Отменить заказ';

  @override
  String get orderDemoNeedsSupport => 'Этот переход делает поддержка.';

  @override
  String get orderDemoPay => 'Оплатить';

  @override
  String get orderDemoPaid => 'Оплата подтверждена сервером';

  @override
  String get orderDemoFailed => 'Не удалось выполнить действие';

  @override
  String get orderDemoTooltip => 'Контролы mock-сервера (только debug)';

  @override
  String get paymentPanelTitle => 'Оплата заказа';

  @override
  String paymentAmountDue(String amount) {
    return 'К оплате $amount';
  }

  @override
  String get paymentRegionLabel => 'Страна оплаты';

  @override
  String get paymentRegionBy => 'Беларусь';

  @override
  String get paymentRegionRu => 'Россия';

  @override
  String get paymentMethodCard => 'Картой онлайн';

  @override
  String get paymentMethodSbp => 'СБП';

  @override
  String get paymentMethodCod => 'При получении';

  @override
  String get paymentMethodWallet => 'Кошелёк';

  @override
  String get paymentMethodUnknown => 'Способ оплаты';

  @override
  String get paymentPay => 'Оплатить';

  @override
  String get paymentPreparing => 'Готовим платёж…';

  @override
  String get paymentAwaitingUser =>
      'Оплатите на странице банка и вернитесь в приложение';

  @override
  String get paymentHostedPageFailed =>
      'Не удалось открыть страницу оплаты. Попробуйте ещё раз.';

  @override
  String get paymentHostedPageAgain => 'Открыть страницу оплаты';

  @override
  String get paymentChecking => 'Проверяем оплату…';

  @override
  String get paymentUncertain => 'Уточняем статус оплаты…';

  @override
  String get paymentPaid => 'Заказ оплачен';

  @override
  String get paymentFailed => 'Оплата не прошла';

  @override
  String get paymentRetry => 'Попробовать снова';

  @override
  String get paymentExpired => 'Срок оплаты истёк';

  @override
  String get paymentCreateNew => 'Создать новую';

  @override
  String get paymentCanceled => 'Оплата отменена';

  @override
  String get paymentOnDelivery => 'Оплата при получении';

  @override
  String get paymentOnDeliveryHint =>
      'Способ выбран. Деньги — при получении заказа.';

  @override
  String get paymentReceipt => 'Чек';

  @override
  String get paymentReceiptTitle => 'Чек';

  @override
  String get paymentReceiptFiscal => 'Фискальный номер';

  @override
  String get paymentReceiptAmount => 'Сумма';

  @override
  String get paymentReceiptDate => 'Дата';

  @override
  String get paymentReceiptShare => 'Поделиться';

  @override
  String get paymentReceiptSubject => 'Чек PicPac';

  @override
  String get paymentReceiptUnavailable => 'Чек ещё не готов';

  @override
  String get paymentReceiptVat => 'В том числе НДС';

  @override
  String get paymentShareFailed => 'Не удалось поделиться чеком';

  @override
  String get paymentEripCode => 'Код ЕРИП';

  @override
  String get paymentSbpHint =>
      'Откройте страницу оплаты и подтвердите перевод в банке';

  @override
  String get paymentNoMethods => 'Нет доступных способов оплаты';

  @override
  String get paymentMethodsFailed => 'Не удалось загрузить способы оплаты';

  @override
  String get paymentCheckFailed => 'Не удалось проверить оплату';

  @override
  String get paymentCheckAgain => 'Проверить ещё раз';

  @override
  String get paymentAlreadyPaid => 'Заказ уже оплачен — новый платёж не нужен';

  @override
  String get paymentNotRequired => 'Заказ не требует оплаты';

  @override
  String get paymentNotPayable => 'Этот заказ нельзя оплатить';

  @override
  String get paymentStatusUnknown => 'Уточняем статус';

  @override
  String get assistantButton => 'Подсказать';

  @override
  String get assistantTitle => 'Что улучшить?';

  @override
  String get assistantHint => 'Например: «сделай теплее»';

  @override
  String get assistantAsk => 'Спросить';

  @override
  String get assistantThinking => 'Смотрим на листы…';

  @override
  String get assistantBefore => 'Было';

  @override
  String get assistantAfter => 'Станет';

  @override
  String get assistantApply => 'Применить';

  @override
  String get assistantRetry => 'Попробовать ещё';

  @override
  String get assistantOffline => 'Для свободного запроса нужен интернет';

  @override
  String get assistantQuickMode => 'Быстрый режим: правила на устройстве';

  @override
  String get assistantRemoteMode => 'Предложение модели';

  @override
  String get assistantRejected => 'Модель предложила несовместимое изменение';

  @override
  String get assistantNoChange => 'Менять нечего — всё уже так';

  @override
  String get assistantApplied => 'Готово. Отменить можно кнопкой «Отменить»';

  @override
  String get assistantChangesTitle => 'Что изменится';

  @override
  String get assistantWarningsTitle => 'Стоит знать';

  @override
  String assistantPreviewLabel(Object side) {
    return 'Предпросмотр листа: $side';
  }

  @override
  String assistantPhotoCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count фото',
      many: '$count фото',
      few: '$count фото',
      one: '$count фото',
    );
    return '$_temp0';
  }

  @override
  String assistantSheetCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count листа',
      many: '$count листов',
      few: '$count листа',
      one: '$count лист',
    );
    return '$_temp0';
  }

  @override
  String assistantSlotCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count кадра',
      many: '$count кадров',
      few: '$count кадра',
      one: '$count кадр',
    );
    return '$_temp0';
  }

  @override
  String get assistantChipWarmer => 'Сделай теплее';

  @override
  String get assistantChipBrighter => 'Ярче';

  @override
  String get assistantChipMono => 'Ч/б';

  @override
  String get assistantChipFill => 'Заполни пустые места';

  @override
  String get assistantChipDenser => 'Плотнее';

  @override
  String get assistantChipAlign => 'Выровняй кадры';

  @override
  String assistantChangeTone(Object details) {
    return 'Свет и цвет: $details';
  }

  @override
  String assistantChangeLook(Object details) {
    return 'Стиль: $details';
  }

  @override
  String assistantChangeFraming(Object details) {
    return 'Кадрирование: $details';
  }

  @override
  String assistantChangeAssign(Object details) {
    return 'Фото в кадрах: $details';
  }

  @override
  String assistantChangeReplace(Object details) {
    return 'Замена фото: $details';
  }

  @override
  String assistantChangeClearSlot(Object details) {
    return 'Фото убирается: $details';
  }

  @override
  String assistantChangeBackground(Object details) {
    return 'Цвет листа: $details';
  }

  @override
  String assistantChangeLayout(Object details) {
    return 'Шаблон листа: $details';
  }

  @override
  String assistantChangeSwap(Object details) {
    return 'Обмен фото: $details';
  }

  @override
  String assistantChangeMore(Object count) {
    return 'и ещё $count';
  }

  @override
  String get assistantAdjustOther => 'Другое';

  @override
  String get editorAdjustContrast => 'Контраст';

  @override
  String get editorAdjustTint => 'Оттенок';

  @override
  String get editorAdjustSaturation => 'Насыщенность';

  @override
  String get editorAdjustVibrance => 'Сочность';

  @override
  String assistantResultReady(Object count, Object intent) {
    return '$intent: изменений — $count';
  }

  @override
  String get assistantDisabled => 'Свободные запросы сейчас недоступны';

  @override
  String get navIdeas => 'Идеи';

  @override
  String get inspirationTitle => 'Идеи';

  @override
  String get inspirationTagAll => 'Все';

  @override
  String get inspirationShowAll => 'Показать все идеи';

  @override
  String get inspirationFilterFavorites => 'Избранное';

  @override
  String get inspirationTagBarLabel => 'Фильтр по тегам';

  @override
  String inspirationCardLabel(String title, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count фото',
      many: '$count фото',
      few: '$count фото',
      one: '$count фото',
    );
    return 'Шаблон: $title, $_temp0';
  }

  @override
  String inspirationPreviewLabel(String title, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count фото',
      many: '$count фото',
      few: '$count фото',
      one: '$count фото',
    );
    return 'Макет шаблона «$title», $_temp0';
  }

  @override
  String inspirationSaveTitle(String title) {
    return 'Сохранить «$title» в избранное';
  }

  @override
  String inspirationRemoveTitle(String title) {
    return 'Убрать «$title» из избранного';
  }

  @override
  String get inspirationSaveToFavorites => 'В избранное';

  @override
  String get inspirationRemoveFromFavorites => 'В избранном';

  @override
  String get inspirationFavoriteFailed =>
      'Не удалось обновить избранное. Проверьте связь и попробуйте ещё раз.';

  @override
  String get inspirationEmptyFavoritesTitle => 'Здесь пока пусто';

  @override
  String get inspirationEmptyFavoritesBody =>
      'Сохраняйте идеи — они появятся здесь';

  @override
  String get inspirationEmptyTagTitle => 'Ничего не нашлось';

  @override
  String get inspirationEmptyTagBody =>
      'Попробуйте другой тег или покажите все идеи';

  @override
  String get inspirationEmptyTitle => 'Идей пока нет';

  @override
  String get inspirationEmptyBody =>
      'Шаблоны появятся здесь, как только сервер их отдаст';

  @override
  String get inspirationLoading => 'Загружаем идеи';

  @override
  String get inspirationLoadMore => 'Показать ещё';

  @override
  String get inspirationLoadMoreFailed =>
      'Не удалось загрузить ещё. Попробуйте ещё раз.';

  @override
  String get inspirationDetailTitle => 'Идея';

  @override
  String inspirationSupportsLabel(String formats) {
    return 'Подходит для: $formats';
  }

  @override
  String get inspirationNoSupports =>
      'Этот шаблон пока не подходит ни одному формату';

  @override
  String get inspirationApply => 'Применить';

  @override
  String get inspirationApplying => 'Применяем…';

  @override
  String get inspirationApplyProblemTitle => 'Шаблон не подошёл';

  @override
  String get inspirationApplyNotSupported =>
      'Этот шаблон не подходит для формата открытого проекта. Выберите другой шаблон.';

  @override
  String inspirationApplyNotEnoughPhotos(int slots, int photos) {
    return 'В шаблоне $slots кадров, а в проекте $photos фото. Добавьте фото или выберите шаблон по количеству снимков.';
  }

  @override
  String get inspirationApplyCommandFailed =>
      'Не удалось разложить фото по шаблону. Попробуйте ещё раз.';

  @override
  String get inspirationApplyNoFormat =>
      'Подходящий формат сейчас недоступен. Проверьте связь и попробуйте ещё раз.';

  @override
  String get inspirationApplyReady => 'Шаблон применён';

  @override
  String get inspirationApplyFailed =>
      'Не удалось применить шаблон. Проверьте связь и попробуйте ещё раз.';

  @override
  String get inspirationTagFamily => 'Семья';

  @override
  String get inspirationTagWedding => 'Свадьба';

  @override
  String get inspirationTagGraduation => 'Выпускной';

  @override
  String get inspirationTagTravel => 'Путешествие';

  @override
  String get inspirationTagMinimal => 'Минимализм';

  @override
  String get inspirationTagKids => 'Детское';

  @override
  String get inspirationTemplateDuoSplit => 'Две истории';

  @override
  String get inspirationTemplateTrioHero => 'Большой кадр и два маленьких';

  @override
  String get inspirationTemplateQuadGrid => 'Сетка 2×2';

  @override
  String get inspirationTemplatePolaroid => 'Полароид';

  @override
  String get inspirationTemplatePanorama => 'Панорама';

  @override
  String get inspirationTemplateStrip3 => 'Три кадра в столбик';

  @override
  String get inspirationTemplatePolaroidLarge => 'Большой полароид';

  @override
  String get inspirationTemplatePanoramaWide => 'Широкая панорама';

  @override
  String get inspirationTemplateBookSingle => 'Одно фото на разворот';

  @override
  String get inspirationTemplateBookDuo => 'Два фото на разворот';

  @override
  String get inspirationTemplateBookTrio => 'Разворот с акцентом';

  @override
  String get inspirationTemplateBookQuad => 'Разворот 2×2';

  @override
  String get inspirationTemplateBookSix => 'Шесть фото на разворот';

  @override
  String get inspirationTemplateBookPanorama => 'Панорама на разворот';

  @override
  String get inspirationTemplateFallback => 'Шаблон';
}
