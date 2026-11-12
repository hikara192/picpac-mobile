import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_be.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('be'),
    Locale('ru'),
  ];

  /// Название приложения
  ///
  /// In ru, this message translates to:
  /// **'PicPac'**
  String get appTitle;

  /// No description provided for @navCatalog.
  ///
  /// In ru, this message translates to:
  /// **'Каталог'**
  String get navCatalog;

  /// No description provided for @navOrders.
  ///
  /// In ru, this message translates to:
  /// **'Заказы'**
  String get navOrders;

  /// No description provided for @navSupport.
  ///
  /// In ru, this message translates to:
  /// **'Поддержка'**
  String get navSupport;

  /// No description provided for @navProfile.
  ///
  /// In ru, this message translates to:
  /// **'Профиль'**
  String get navProfile;

  /// No description provided for @placeholderTitle.
  ///
  /// In ru, this message translates to:
  /// **'Раздел в разработке'**
  String get placeholderTitle;

  /// No description provided for @placeholderBody.
  ///
  /// In ru, this message translates to:
  /// **'Скоро здесь появится рабочий экран.'**
  String get placeholderBody;

  /// No description provided for @actionRetry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get actionRetry;

  /// No description provided for @actionClose.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть'**
  String get actionClose;

  /// No description provided for @actionBack.
  ///
  /// In ru, this message translates to:
  /// **'Назад'**
  String get actionBack;

  /// No description provided for @actionCancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get actionCancel;

  /// No description provided for @actionContinue.
  ///
  /// In ru, this message translates to:
  /// **'Продолжить'**
  String get actionContinue;

  /// No description provided for @actionLogout.
  ///
  /// In ru, this message translates to:
  /// **'Выйти'**
  String get actionLogout;

  /// No description provided for @actionLogin.
  ///
  /// In ru, this message translates to:
  /// **'Войти'**
  String get actionLogin;

  /// No description provided for @actionGoCatalog.
  ///
  /// In ru, this message translates to:
  /// **'В каталог'**
  String get actionGoCatalog;

  /// No description provided for @actionBuild.
  ///
  /// In ru, this message translates to:
  /// **'Собрать'**
  String get actionBuild;

  /// No description provided for @actionApply.
  ///
  /// In ru, this message translates to:
  /// **'Применить'**
  String get actionApply;

  /// No description provided for @actionRemove.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get actionRemove;

  /// No description provided for @actionCheckout.
  ///
  /// In ru, this message translates to:
  /// **'Оформить'**
  String get actionCheckout;

  /// No description provided for @actionLoadMore.
  ///
  /// In ru, this message translates to:
  /// **'Показать ещё'**
  String get actionLoadMore;

  /// No description provided for @actionFind.
  ///
  /// In ru, this message translates to:
  /// **'Найти'**
  String get actionFind;

  /// No description provided for @loading.
  ///
  /// In ru, this message translates to:
  /// **'Загружаем…'**
  String get loading;

  /// Значение слайдера для экранного диктора: «Свет, +0.3» — сначала название параметра, затем человеческое значение
  ///
  /// In ru, this message translates to:
  /// **'{label}, {value}'**
  String a11ySliderValue(Object label, Object value);

  /// Карточка товара читается одним элементом: название и цена «от»
  ///
  /// In ru, this message translates to:
  /// **'{title}, {price}'**
  String a11yProductCard(Object price, Object title);

  /// Строка корзины одним элементом: название и количество
  ///
  /// In ru, this message translates to:
  /// **'{title}, {quantity}'**
  String a11yCartLine(Object quantity, Object title);

  /// Карточка заказа в истории: номер, статус и сумма
  ///
  /// In ru, this message translates to:
  /// **'Заказ {number}, {status}, {total}'**
  String a11yOrderCard(Object number, Object status, Object total);

  /// Карточка обращения: тема и статус
  ///
  /// In ru, this message translates to:
  /// **'{subject}, {status}'**
  String a11yTicketCard(Object status, Object subject);

  /// Превью макета в редакторе — изображение, а не набор слоёв
  ///
  /// In ru, this message translates to:
  /// **'Макет разворота {current} из {total}'**
  String a11ySheetPreview(Object current, Object total);

  /// No description provided for @startupTitle.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось запустить PicPac'**
  String get startupTitle;

  /// No description provided for @startupBody.
  ///
  /// In ru, this message translates to:
  /// **'Проверьте подключение и попробуйте снова.'**
  String get startupBody;

  /// Кнопка повтора на экране ошибки старта, пока идёт новая попытка
  ///
  /// In ru, this message translates to:
  /// **'Запускаем…'**
  String get startupRetrying;

  /// No description provided for @errorGeneric.
  ///
  /// In ru, this message translates to:
  /// **'Что-то пошло не так. Попробуйте ещё раз.'**
  String get errorGeneric;

  /// No description provided for @errorNetwork.
  ///
  /// In ru, this message translates to:
  /// **'Нет соединения. Проверьте сеть и попробуйте снова.'**
  String get errorNetwork;

  /// No description provided for @errorTimeout.
  ///
  /// In ru, this message translates to:
  /// **'Сервер не ответил. Попробуйте ещё раз.'**
  String get errorTimeout;

  /// No description provided for @errorUnauthorized.
  ///
  /// In ru, this message translates to:
  /// **'Нужно войти снова.'**
  String get errorUnauthorized;

  /// No description provided for @errorForbidden.
  ///
  /// In ru, this message translates to:
  /// **'Недостаточно прав для этого действия.'**
  String get errorForbidden;

  /// No description provided for @errorConflictRevision.
  ///
  /// In ru, this message translates to:
  /// **'Проект изменён на другом устройстве. Обновите черновик.'**
  String get errorConflictRevision;

  /// No description provided for @errorIdempotencyConflict.
  ///
  /// In ru, this message translates to:
  /// **'Заказ уже создан. Откройте историю заказов.'**
  String get errorIdempotencyConflict;

  /// No description provided for @errorValidation.
  ///
  /// In ru, this message translates to:
  /// **'Проверьте введённые данные.'**
  String get errorValidation;

  /// No description provided for @errorNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Не нашли то, что искали.'**
  String get errorNotFound;

  /// Экран ошибки маршрутизатора для неизвестного адреса
  ///
  /// In ru, this message translates to:
  /// **'Страница не найдена: {path}'**
  String routeNotFound(String path);

  /// No description provided for @errorRateLimited.
  ///
  /// In ru, this message translates to:
  /// **'Слишком много попыток. Подождите минуту.'**
  String get errorRateLimited;

  /// No description provided for @errorInvalidData.
  ///
  /// In ru, this message translates to:
  /// **'Сервер вернул неожиданный ответ. Мы уже разбираемся.'**
  String get errorInvalidData;

  /// No description provided for @catalogTitle.
  ///
  /// In ru, this message translates to:
  /// **'Каталог'**
  String get catalogTitle;

  /// No description provided for @catalogLoading.
  ///
  /// In ru, this message translates to:
  /// **'Загружаем каталог'**
  String get catalogLoading;

  /// No description provided for @catalogEmptyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Каталог пока пуст'**
  String get catalogEmptyTitle;

  /// No description provided for @catalogEmptyBody.
  ///
  /// In ru, this message translates to:
  /// **'Мы обновляем ассортимент. Загляните чуть позже.'**
  String get catalogEmptyBody;

  /// No description provided for @catalogOpenCart.
  ///
  /// In ru, this message translates to:
  /// **'Корзина'**
  String get catalogOpenCart;

  /// No description provided for @catalogCartHint.
  ///
  /// In ru, this message translates to:
  /// **'Открыть корзину'**
  String get catalogCartHint;

  /// No description provided for @priceFrom.
  ///
  /// In ru, this message translates to:
  /// **'от {price}'**
  String priceFrom(String price);

  /// No description provided for @productFormatsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Форматы и цены'**
  String get productFormatsTitle;

  /// No description provided for @productSize.
  ///
  /// In ru, this message translates to:
  /// **'{width} × {height} мм'**
  String productSize(String width, String height);

  /// No description provided for @productEta.
  ///
  /// In ru, this message translates to:
  /// **'готовность {days} дн.'**
  String productEta(int days);

  /// No description provided for @productPriceUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Цена по запросу'**
  String get productPriceUnavailable;

  /// No description provided for @productBuildFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось создать проект'**
  String get productBuildFailed;

  /// No description provided for @productLoginToBuild.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось собрать проект. Повторите попытку.'**
  String get productLoginToBuild;

  /// No description provided for @productChooseFormat.
  ///
  /// In ru, this message translates to:
  /// **'Выберите формат'**
  String get productChooseFormat;

  /// No description provided for @productHeroHint.
  ///
  /// In ru, this message translates to:
  /// **'Изображение товара «{title}»'**
  String productHeroHint(String title);

  /// No description provided for @cartTitle.
  ///
  /// In ru, this message translates to:
  /// **'Корзина'**
  String get cartTitle;

  /// No description provided for @cartEmptyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Корзина пуста'**
  String get cartEmptyTitle;

  /// No description provided for @cartEmptyBody.
  ///
  /// In ru, this message translates to:
  /// **'Соберите проект в каталоге — он появится здесь.'**
  String get cartEmptyBody;

  /// No description provided for @cartExpiredTitle.
  ///
  /// In ru, this message translates to:
  /// **'Корзина истекла'**
  String get cartExpiredTitle;

  /// No description provided for @cartExpiredBody.
  ///
  /// In ru, this message translates to:
  /// **'Позиции хранятся 14 дней. Соберите проект заново.'**
  String get cartExpiredBody;

  /// No description provided for @cartSubtotal.
  ///
  /// In ru, this message translates to:
  /// **'Итого'**
  String get cartSubtotal;

  /// No description provided for @cartEta.
  ///
  /// In ru, this message translates to:
  /// **'Готовность через {days} дн.'**
  String cartEta(int days);

  /// No description provided for @cartQuantity.
  ///
  /// In ru, this message translates to:
  /// **'Количество'**
  String get cartQuantity;

  /// No description provided for @cartIncrease.
  ///
  /// In ru, this message translates to:
  /// **'Добавить штуку'**
  String get cartIncrease;

  /// No description provided for @cartDecrease.
  ///
  /// In ru, this message translates to:
  /// **'Убрать штуку'**
  String get cartDecrease;

  /// No description provided for @cartRemoveTitle.
  ///
  /// In ru, this message translates to:
  /// **'Удалить позицию?'**
  String get cartRemoveTitle;

  /// No description provided for @cartRemoveBody.
  ///
  /// In ru, this message translates to:
  /// **'«{title}» пропадёт из корзины.'**
  String cartRemoveBody(String title);

  /// No description provided for @cartUnavailableItem.
  ///
  /// In ru, this message translates to:
  /// **'Проект недоступен'**
  String get cartUnavailableItem;

  /// No description provided for @cartCannotCheckout.
  ///
  /// In ru, this message translates to:
  /// **'Часть позиций недоступна. Удалите их, чтобы продолжить.'**
  String get cartCannotCheckout;

  /// No description provided for @cartUpdateFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось обновить корзину'**
  String get cartUpdateFailed;

  /// No description provided for @cartExpiresAt.
  ///
  /// In ru, this message translates to:
  /// **'Корзина хранится до {date}'**
  String cartExpiresAt(String date);

  /// No description provided for @cartItemsCount.
  ///
  /// In ru, this message translates to:
  /// **'Позиций: {count}'**
  String cartItemsCount(int count);

  /// No description provided for @checkoutTitle.
  ///
  /// In ru, this message translates to:
  /// **'Оформление'**
  String get checkoutTitle;

  /// No description provided for @checkoutDelivery.
  ///
  /// In ru, this message translates to:
  /// **'Получение'**
  String get checkoutDelivery;

  /// No description provided for @checkoutPickupPoint.
  ///
  /// In ru, this message translates to:
  /// **'Пункт выдачи'**
  String get checkoutPickupPoint;

  /// No description provided for @checkoutPickupSlot.
  ///
  /// In ru, this message translates to:
  /// **'Время получения'**
  String get checkoutPickupSlot;

  /// No description provided for @checkoutAddress.
  ///
  /// In ru, this message translates to:
  /// **'Адрес'**
  String get checkoutAddress;

  /// No description provided for @checkoutAddressHint.
  ///
  /// In ru, this message translates to:
  /// **'Улица, дом, квартира'**
  String get checkoutAddressHint;

  /// No description provided for @checkoutPromo.
  ///
  /// In ru, this message translates to:
  /// **'Промокод'**
  String get checkoutPromo;

  /// No description provided for @checkoutPromoHint.
  ///
  /// In ru, this message translates to:
  /// **'Например, TEST10'**
  String get checkoutPromoHint;

  /// No description provided for @checkoutPromoApplied.
  ///
  /// In ru, this message translates to:
  /// **'Промокод {code} применён'**
  String checkoutPromoApplied(String code);

  /// No description provided for @checkoutPromoUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Такого промокода нет или он истёк'**
  String get checkoutPromoUnknown;

  /// No description provided for @checkoutPromoClear.
  ///
  /// In ru, this message translates to:
  /// **'Убрать промокод'**
  String get checkoutPromoClear;

  /// No description provided for @checkoutContacts.
  ///
  /// In ru, this message translates to:
  /// **'Контакты'**
  String get checkoutContacts;

  /// No description provided for @checkoutName.
  ///
  /// In ru, this message translates to:
  /// **'Имя'**
  String get checkoutName;

  /// No description provided for @checkoutPhone.
  ///
  /// In ru, this message translates to:
  /// **'Телефон'**
  String get checkoutPhone;

  /// No description provided for @checkoutNameRequired.
  ///
  /// In ru, this message translates to:
  /// **'Укажите имя'**
  String get checkoutNameRequired;

  /// No description provided for @checkoutPhoneRequired.
  ///
  /// In ru, this message translates to:
  /// **'Укажите телефон'**
  String get checkoutPhoneRequired;

  /// No description provided for @checkoutPhoneInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Проверьте номер: +375 (29) 123-45-67 или +7 999 123-45-67'**
  String get checkoutPhoneInvalid;

  /// No description provided for @checkoutSubmit.
  ///
  /// In ru, this message translates to:
  /// **'Оформить заказ'**
  String get checkoutSubmit;

  /// No description provided for @checkoutSubmitting.
  ///
  /// In ru, this message translates to:
  /// **'Оформляем…'**
  String get checkoutSubmitting;

  /// No description provided for @checkoutLoginRequired.
  ///
  /// In ru, this message translates to:
  /// **'Войти и оформить'**
  String get checkoutLoginRequired;

  /// No description provided for @checkoutSummary.
  ///
  /// In ru, this message translates to:
  /// **'Итог'**
  String get checkoutSummary;

  /// No description provided for @checkoutPreliminary.
  ///
  /// In ru, this message translates to:
  /// **'Предварительно: точную сумму подтвердит сервер при оформлении.'**
  String get checkoutPreliminary;

  /// No description provided for @checkoutDeliveryRequired.
  ///
  /// In ru, this message translates to:
  /// **'Выберите способ получения'**
  String get checkoutDeliveryRequired;

  /// No description provided for @checkoutSlotRequired.
  ///
  /// In ru, this message translates to:
  /// **'Выберите время получения'**
  String get checkoutSlotRequired;

  /// No description provided for @checkoutAddressRequired.
  ///
  /// In ru, this message translates to:
  /// **'Укажите адрес доставки'**
  String get checkoutAddressRequired;

  /// No description provided for @checkoutFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось оформить заказ'**
  String get checkoutFailed;

  /// No description provided for @checkoutEmptyCart.
  ///
  /// In ru, this message translates to:
  /// **'Корзина пуста — добавьте проект из каталога.'**
  String get checkoutEmptyCart;

  /// No description provided for @checkoutNoSlots.
  ///
  /// In ru, this message translates to:
  /// **'Свободных слотов нет. Выберите другой пункт.'**
  String get checkoutNoSlots;

  /// No description provided for @checkoutPhoneHint.
  ///
  /// In ru, this message translates to:
  /// **'+375 29 123 45 67'**
  String get checkoutPhoneHint;

  /// No description provided for @priceProduct.
  ///
  /// In ru, this message translates to:
  /// **'Товары'**
  String get priceProduct;

  /// No description provided for @priceOptions.
  ///
  /// In ru, this message translates to:
  /// **'Опции'**
  String get priceOptions;

  /// No description provided for @pricePromo.
  ///
  /// In ru, this message translates to:
  /// **'Скидка'**
  String get pricePromo;

  /// No description provided for @priceDelivery.
  ///
  /// In ru, this message translates to:
  /// **'Доставка'**
  String get priceDelivery;

  /// No description provided for @deliveryPickup.
  ///
  /// In ru, this message translates to:
  /// **'Самовывоз'**
  String get deliveryPickup;

  /// No description provided for @deliveryEuropochta.
  ///
  /// In ru, this message translates to:
  /// **'Европочта'**
  String get deliveryEuropochta;

  /// No description provided for @deliveryBelpochta.
  ///
  /// In ru, this message translates to:
  /// **'Белпочта'**
  String get deliveryBelpochta;

  /// No description provided for @deliveryEms.
  ///
  /// In ru, this message translates to:
  /// **'EMS'**
  String get deliveryEms;

  /// No description provided for @deliveryCourierMinsk.
  ///
  /// In ru, this message translates to:
  /// **'Курьер по Минску'**
  String get deliveryCourierMinsk;

  /// No description provided for @deliveryCourierBelarus.
  ///
  /// In ru, this message translates to:
  /// **'Курьер по Беларуси'**
  String get deliveryCourierBelarus;

  /// No description provided for @deliveryDays.
  ///
  /// In ru, this message translates to:
  /// **'{days} дн.'**
  String deliveryDays(int days);

  /// No description provided for @deliveryFreeFrom.
  ///
  /// In ru, this message translates to:
  /// **'бесплатно от {price}'**
  String deliveryFreeFrom(String price);

  /// No description provided for @deliveryKindPickup.
  ///
  /// In ru, this message translates to:
  /// **'Самовывоз'**
  String get deliveryKindPickup;

  /// No description provided for @deliveryKindPost.
  ///
  /// In ru, this message translates to:
  /// **'Почта'**
  String get deliveryKindPost;

  /// No description provided for @deliveryKindEms.
  ///
  /// In ru, this message translates to:
  /// **'EMS'**
  String get deliveryKindEms;

  /// No description provided for @deliveryKindCourier.
  ///
  /// In ru, this message translates to:
  /// **'Курьер'**
  String get deliveryKindCourier;

  /// No description provided for @deliveryKindUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Получение'**
  String get deliveryKindUnknown;

  /// No description provided for @ordersTitle.
  ///
  /// In ru, this message translates to:
  /// **'Заказы'**
  String get ordersTitle;

  /// No description provided for @ordersEmptyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Заказов пока нет'**
  String get ordersEmptyTitle;

  /// No description provided for @ordersEmptyBody.
  ///
  /// In ru, this message translates to:
  /// **'Оформите первый заказ — он появится здесь.'**
  String get ordersEmptyBody;

  /// No description provided for @ordersLoginRequired.
  ///
  /// In ru, this message translates to:
  /// **'Заказы хранятся в аккаунте.'**
  String get ordersLoginRequired;

  /// No description provided for @ordersStale.
  ///
  /// In ru, this message translates to:
  /// **'Данные могут быть устаревшими'**
  String get ordersStale;

  /// No description provided for @ordersLookup.
  ///
  /// In ru, this message translates to:
  /// **'Найти заказ по номеру'**
  String get ordersLookup;

  /// No description provided for @ordersOpenOrder.
  ///
  /// In ru, this message translates to:
  /// **'Открыть заказ {number}'**
  String ordersOpenOrder(String number);

  /// No description provided for @ordersItemsCount.
  ///
  /// In ru, this message translates to:
  /// **'Позиций: {count}'**
  String ordersItemsCount(int count);

  /// No description provided for @statusUpdating.
  ///
  /// In ru, this message translates to:
  /// **'обновляется'**
  String get statusUpdating;

  /// No description provided for @orderTitle.
  ///
  /// In ru, this message translates to:
  /// **'Заказ'**
  String get orderTitle;

  /// No description provided for @orderHeading.
  ///
  /// In ru, this message translates to:
  /// **'Заказ {number}'**
  String orderHeading(String number);

  /// No description provided for @orderCreatedAt.
  ///
  /// In ru, this message translates to:
  /// **'Оформлен {date}'**
  String orderCreatedAt(String date);

  /// No description provided for @orderItemsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Состав'**
  String get orderItemsTitle;

  /// No description provided for @orderItemQuantity.
  ///
  /// In ru, this message translates to:
  /// **'{quantity} × {price}'**
  String orderItemQuantity(int quantity, String price);

  /// No description provided for @orderTotalsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Сумма'**
  String get orderTotalsTitle;

  /// No description provided for @orderSubtotal.
  ///
  /// In ru, this message translates to:
  /// **'Товары'**
  String get orderSubtotal;

  /// No description provided for @orderDiscount.
  ///
  /// In ru, this message translates to:
  /// **'Скидка'**
  String get orderDiscount;

  /// No description provided for @orderDeliveryCost.
  ///
  /// In ru, this message translates to:
  /// **'Доставка'**
  String get orderDeliveryCost;

  /// No description provided for @orderTotal.
  ///
  /// In ru, this message translates to:
  /// **'Итого'**
  String get orderTotal;

  /// No description provided for @orderDeliveryTitle.
  ///
  /// In ru, this message translates to:
  /// **'Получение'**
  String get orderDeliveryTitle;

  /// Кнопка оплаты на экране заказа
  ///
  /// In ru, this message translates to:
  /// **'Оплатить заказ'**
  String get orderPayCta;

  /// No description provided for @orderPaymentTitle.
  ///
  /// In ru, this message translates to:
  /// **'Оплата'**
  String get orderPaymentTitle;

  /// No description provided for @orderFulfillmentTitle.
  ///
  /// In ru, this message translates to:
  /// **'Готовность'**
  String get orderFulfillmentTitle;

  /// No description provided for @orderEta.
  ///
  /// In ru, this message translates to:
  /// **'Готово к {date}'**
  String orderEta(String date);

  /// No description provided for @orderTimelineTitle.
  ///
  /// In ru, this message translates to:
  /// **'Статусы'**
  String get orderTimelineTitle;

  /// No description provided for @orderTracking.
  ///
  /// In ru, this message translates to:
  /// **'Трек-номер {number}'**
  String orderTracking(String number);

  /// No description provided for @orderPickupCode.
  ///
  /// In ru, this message translates to:
  /// **'Код самовывоза'**
  String get orderPickupCode;

  /// No description provided for @orderPickupCodeHint.
  ///
  /// In ru, this message translates to:
  /// **'Назовите код на пункте выдачи'**
  String get orderPickupCodeHint;

  /// No description provided for @orderProblem.
  ///
  /// In ru, this message translates to:
  /// **'Проблема с заказом'**
  String get orderProblem;

  /// No description provided for @orderNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Заказ не найден'**
  String get orderNotFound;

  /// No description provided for @orderOfflineUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Заказ не сохранён на устройстве. Проверьте соединение.'**
  String get orderOfflineUnavailable;

  /// No description provided for @orderStatusDraft.
  ///
  /// In ru, this message translates to:
  /// **'Черновик'**
  String get orderStatusDraft;

  /// No description provided for @orderStatusPlaced.
  ///
  /// In ru, this message translates to:
  /// **'Оформлен'**
  String get orderStatusPlaced;

  /// No description provided for @orderStatusAccepted.
  ///
  /// In ru, this message translates to:
  /// **'Принят'**
  String get orderStatusAccepted;

  /// No description provided for @orderStatusModeration.
  ///
  /// In ru, this message translates to:
  /// **'На модерации'**
  String get orderStatusModeration;

  /// No description provided for @orderStatusProduction.
  ///
  /// In ru, this message translates to:
  /// **'В производстве'**
  String get orderStatusProduction;

  /// No description provided for @orderStatusReady.
  ///
  /// In ru, this message translates to:
  /// **'Готов'**
  String get orderStatusReady;

  /// No description provided for @orderStatusReadyForPickup.
  ///
  /// In ru, this message translates to:
  /// **'Готов к выдаче'**
  String get orderStatusReadyForPickup;

  /// No description provided for @orderStatusShipped.
  ///
  /// In ru, this message translates to:
  /// **'Передан в доставку'**
  String get orderStatusShipped;

  /// No description provided for @orderStatusCompleted.
  ///
  /// In ru, this message translates to:
  /// **'Завершён'**
  String get orderStatusCompleted;

  /// No description provided for @orderStatusCanceled.
  ///
  /// In ru, this message translates to:
  /// **'Отменён'**
  String get orderStatusCanceled;

  /// No description provided for @orderStatusReturned.
  ///
  /// In ru, this message translates to:
  /// **'Возврат'**
  String get orderStatusReturned;

  /// No description provided for @paymentStatusCreated.
  ///
  /// In ru, this message translates to:
  /// **'Ожидает оплаты'**
  String get paymentStatusCreated;

  /// No description provided for @paymentStatusRequiresAction.
  ///
  /// In ru, this message translates to:
  /// **'Нужно подтверждение'**
  String get paymentStatusRequiresAction;

  /// No description provided for @paymentStatusPendingUser.
  ///
  /// In ru, this message translates to:
  /// **'Ожидает оплаты'**
  String get paymentStatusPendingUser;

  /// No description provided for @paymentStatusProcessing.
  ///
  /// In ru, this message translates to:
  /// **'Платёж обрабатывается'**
  String get paymentStatusProcessing;

  /// No description provided for @paymentStatusSucceeded.
  ///
  /// In ru, this message translates to:
  /// **'Оплачен'**
  String get paymentStatusSucceeded;

  /// No description provided for @paymentStatusFailed.
  ///
  /// In ru, this message translates to:
  /// **'Оплата не прошла'**
  String get paymentStatusFailed;

  /// No description provided for @paymentStatusExpired.
  ///
  /// In ru, this message translates to:
  /// **'Срок оплаты истёк'**
  String get paymentStatusExpired;

  /// No description provided for @paymentStatusCanceled.
  ///
  /// In ru, this message translates to:
  /// **'Оплата отменена'**
  String get paymentStatusCanceled;

  /// No description provided for @paymentStatusRefunded.
  ///
  /// In ru, this message translates to:
  /// **'Возврат'**
  String get paymentStatusRefunded;

  /// No description provided for @paymentStatusPartiallyRefunded.
  ///
  /// In ru, this message translates to:
  /// **'Частичный возврат'**
  String get paymentStatusPartiallyRefunded;

  /// No description provided for @paymentStatusPendingOnDelivery.
  ///
  /// In ru, this message translates to:
  /// **'Оплата при получении'**
  String get paymentStatusPendingOnDelivery;

  /// No description provided for @lookupTitle.
  ///
  /// In ru, this message translates to:
  /// **'Найти заказ'**
  String get lookupTitle;

  /// No description provided for @lookupBody.
  ///
  /// In ru, this message translates to:
  /// **'Введите номер заказа и последние 4 цифры телефона из заказа.'**
  String get lookupBody;

  /// No description provided for @lookupNumber.
  ///
  /// In ru, this message translates to:
  /// **'Номер заказа'**
  String get lookupNumber;

  /// No description provided for @lookupPhoneLast4.
  ///
  /// In ru, this message translates to:
  /// **'Последние 4 цифры телефона'**
  String get lookupPhoneLast4;

  /// No description provided for @lookupPhoneLast4Invalid.
  ///
  /// In ru, this message translates to:
  /// **'Нужны 4 цифры'**
  String get lookupPhoneLast4Invalid;

  /// No description provided for @lookupNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Заказ с таким номером и телефоном не найден'**
  String get lookupNotFound;

  /// No description provided for @mediaHeicUnsupported.
  ///
  /// In ru, this message translates to:
  /// **'HEIC пока не поддерживается. Сохраните фото как JPEG или PNG и попробуйте снова.'**
  String get mediaHeicUnsupported;

  /// No description provided for @mediaTooLarge.
  ///
  /// In ru, this message translates to:
  /// **'Файл больше {limit} МБ. Уменьшите фото и попробуйте снова.'**
  String mediaTooLarge(int limit);

  /// No description provided for @mediaUnsupported.
  ///
  /// In ru, this message translates to:
  /// **'Этот формат не печатается. Нужны JPEG или PNG.'**
  String get mediaUnsupported;

  /// No description provided for @mediaTooSmallPixels.
  ///
  /// In ru, this message translates to:
  /// **'Фото {width}×{height} px слишком маленькое для печати.'**
  String mediaTooSmallPixels(int width, int height);

  /// No description provided for @mediaUnreadable.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось прочитать файл. Выберите другое фото.'**
  String get mediaUnreadable;

  /// No description provided for @mediaPermissionTitle.
  ///
  /// In ru, this message translates to:
  /// **'Нет доступа к фотографиям'**
  String get mediaPermissionTitle;

  /// No description provided for @mediaPermissionBody.
  ///
  /// In ru, this message translates to:
  /// **'Разрешите PicPac доступ к фотографиям в настройках телефона и повторите выбор.'**
  String get mediaPermissionBody;

  /// No description provided for @mediaPermissionRetry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить выбор'**
  String get mediaPermissionRetry;

  /// No description provided for @mediaRejectedTitle.
  ///
  /// In ru, this message translates to:
  /// **'Не добавлено'**
  String get mediaRejectedTitle;

  /// No description provided for @mediaDuplicatesSkipped.
  ///
  /// In ru, this message translates to:
  /// **'Уже есть в проекте: {count}'**
  String mediaDuplicatesSkipped(int count);

  /// No description provided for @createTitle.
  ///
  /// In ru, this message translates to:
  /// **'Проект'**
  String get createTitle;

  /// No description provided for @createPhotosTitle.
  ///
  /// In ru, this message translates to:
  /// **'Фотографии'**
  String get createPhotosTitle;

  /// No description provided for @createPhotosCount.
  ///
  /// In ru, this message translates to:
  /// **'{count} из {max}'**
  String createPhotosCount(int count, int max);

  /// No description provided for @createAddPhotos.
  ///
  /// In ru, this message translates to:
  /// **'Добавить фото'**
  String get createAddPhotos;

  /// No description provided for @createLimitReached.
  ///
  /// In ru, this message translates to:
  /// **'На лист помещается {max} фото. Уберите лишние, чтобы добавить новые.'**
  String createLimitReached(int max);

  /// No description provided for @createMinPhotos.
  ///
  /// In ru, this message translates to:
  /// **'Нужно минимум {min} фото.'**
  String createMinPhotos(int min);

  /// No description provided for @createEmptyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Пока нет фотографий'**
  String get createEmptyTitle;

  /// No description provided for @createEmptyBody.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте фото с устройства — оригиналы останутся у вас.'**
  String get createEmptyBody;

  /// No description provided for @createDeleteTitle.
  ///
  /// In ru, this message translates to:
  /// **'Удалить фото?'**
  String get createDeleteTitle;

  /// No description provided for @createDeleteBody.
  ///
  /// In ru, this message translates to:
  /// **'Фото «{name}» пропадёт из проекта. Оригинал на устройстве не изменится.'**
  String createDeleteBody(String name);

  /// No description provided for @createReorderHint.
  ///
  /// In ru, this message translates to:
  /// **'Удерживайте фото и перетащите, чтобы изменить порядок.'**
  String get createReorderHint;

  /// No description provided for @createOfflineBanner.
  ///
  /// In ru, this message translates to:
  /// **'Нет сети. Изменения сохранятся на устройстве и уйдут на сервер позже.'**
  String get createOfflineBanner;

  /// No description provided for @createSyncSaving.
  ///
  /// In ru, this message translates to:
  /// **'Сохраняем…'**
  String get createSyncSaving;

  /// No description provided for @createSyncSaved.
  ///
  /// In ru, this message translates to:
  /// **'Сохранено'**
  String get createSyncSaved;

  /// No description provided for @createSyncPending.
  ///
  /// In ru, this message translates to:
  /// **'Ждёт сети'**
  String get createSyncPending;

  /// No description provided for @createDraftRestored.
  ///
  /// In ru, this message translates to:
  /// **'Черновик восстановлен с устройства'**
  String get createDraftRestored;

  /// No description provided for @createConflictTitle.
  ///
  /// In ru, this message translates to:
  /// **'Проект изменён на другом устройстве'**
  String get createConflictTitle;

  /// No description provided for @createConflictBody.
  ///
  /// In ru, this message translates to:
  /// **'Версия на сервере новее. Загрузите её или оставьте свои правки — они перезапишут серверные.'**
  String get createConflictBody;

  /// No description provided for @createConflictLoadServer.
  ///
  /// In ru, this message translates to:
  /// **'Загрузить с сервера'**
  String get createConflictLoadServer;

  /// No description provided for @createConflictKeepLocal.
  ///
  /// In ru, this message translates to:
  /// **'Оставить мои правки'**
  String get createConflictKeepLocal;

  /// No description provided for @createOrder.
  ///
  /// In ru, this message translates to:
  /// **'Оформить заказ'**
  String get createOrder;

  /// No description provided for @createEditSheets.
  ///
  /// In ru, this message translates to:
  /// **'Изменить листы'**
  String get createEditSheets;

  /// No description provided for @createPreviewTitle.
  ///
  /// In ru, this message translates to:
  /// **'Лист {index} из {total}'**
  String createPreviewTitle(int index, int total);

  /// No description provided for @createPhotoUploading.
  ///
  /// In ru, this message translates to:
  /// **'Загружаем фото {index}'**
  String createPhotoUploading(int index);

  /// No description provided for @createCancelUpload.
  ///
  /// In ru, this message translates to:
  /// **'Отменить загрузку фото {index}'**
  String createCancelUpload(int index);

  /// No description provided for @createUploadRetry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить загрузку фото {index}'**
  String createUploadRetry(int index);

  /// No description provided for @createUploadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Фото не загрузилось'**
  String get createUploadFailed;

  /// No description provided for @createLocalCopy.
  ///
  /// In ru, this message translates to:
  /// **'Локальная копия'**
  String get createLocalCopy;

  /// No description provided for @createLocalCopyHint.
  ///
  /// In ru, this message translates to:
  /// **'Проект на сервере недоступен — открыта копия с устройства.'**
  String get createLocalCopyHint;

  /// No description provided for @createOrderNeedsPhotos.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте хотя бы одно фото — тогда можно оформить заказ.'**
  String get createOrderNeedsPhotos;

  /// No description provided for @createUndo.
  ///
  /// In ru, this message translates to:
  /// **'Отменить'**
  String get createUndo;

  /// No description provided for @createRedo.
  ///
  /// In ru, this message translates to:
  /// **'Вернуть'**
  String get createRedo;

  /// No description provided for @createPhotoNumber.
  ///
  /// In ru, this message translates to:
  /// **'Фото {index}'**
  String createPhotoNumber(int index);

  /// No description provided for @createMovePhoto.
  ///
  /// In ru, this message translates to:
  /// **'Переставить фото {index}'**
  String createMovePhoto(int index);

  /// No description provided for @createRemovePhoto.
  ///
  /// In ru, this message translates to:
  /// **'Удалить фото {index}'**
  String createRemovePhoto(int index);

  /// No description provided for @createFormatMissing.
  ///
  /// In ru, this message translates to:
  /// **'Формат недоступен без сети. Откройте проект при подключении.'**
  String get createFormatMissing;

  /// No description provided for @createEnhanceAll.
  ///
  /// In ru, this message translates to:
  /// **'Улучшить все'**
  String get createEnhanceAll;

  /// No description provided for @createEnhanceApplied.
  ///
  /// In ru, this message translates to:
  /// **'Улучшено {count} фото'**
  String createEnhanceApplied(int count);

  /// No description provided for @createEnhanceAlready.
  ///
  /// In ru, this message translates to:
  /// **'Всё уже улучшено'**
  String get createEnhanceAlready;

  /// No description provided for @createEnhanceFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не получилось улучшить. Попробуйте ещё раз.'**
  String get createEnhanceFailed;

  /// No description provided for @createEnhanceUndo.
  ///
  /// In ru, this message translates to:
  /// **'Вернуть'**
  String get createEnhanceUndo;

  /// No description provided for @createEnhancePreviewBefore.
  ///
  /// In ru, this message translates to:
  /// **'До'**
  String get createEnhancePreviewBefore;

  /// No description provided for @createEnhancePreviewAfter.
  ///
  /// In ru, this message translates to:
  /// **'После'**
  String get createEnhancePreviewAfter;

  /// No description provided for @createEnhancePreviewHint.
  ///
  /// In ru, this message translates to:
  /// **'Свет и тепло подстроятся под каждое фото'**
  String get createEnhancePreviewHint;

  /// No description provided for @createResetToImported.
  ///
  /// In ru, this message translates to:
  /// **'Вернуть как было'**
  String get createResetToImported;

  /// No description provided for @createResetToImportedHint.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить кадры, свет и стиль. Фото останутся.'**
  String get createResetToImportedHint;

  /// No description provided for @createLayoutTitle.
  ///
  /// In ru, this message translates to:
  /// **'Можно плотнее'**
  String get createLayoutTitle;

  /// No description provided for @createLayoutBody.
  ///
  /// In ru, this message translates to:
  /// **'{sheets, plural, one{{sheets} лист} few{{sheets} листа} many{{sheets} листов} other{{sheets} листа}} вместо {current}'**
  String createLayoutBody(int sheets, int current);

  /// No description provided for @createLayoutHint.
  ///
  /// In ru, this message translates to:
  /// **'Кадры и обрезка сохранятся.'**
  String get createLayoutHint;

  /// No description provided for @createLayoutAccept.
  ///
  /// In ru, this message translates to:
  /// **'Так лучше'**
  String get createLayoutAccept;

  /// No description provided for @createLayoutKeep.
  ///
  /// In ru, this message translates to:
  /// **'Оставить по одному'**
  String get createLayoutKeep;

  /// No description provided for @createLayoutApplied.
  ///
  /// In ru, this message translates to:
  /// **'Раскладка готова'**
  String get createLayoutApplied;

  /// No description provided for @editorTitle.
  ///
  /// In ru, this message translates to:
  /// **'Кадрирование'**
  String get editorTitle;

  /// No description provided for @editorZoom.
  ///
  /// In ru, this message translates to:
  /// **'Масштаб'**
  String get editorZoom;

  /// No description provided for @editorCenter.
  ///
  /// In ru, this message translates to:
  /// **'По центру'**
  String get editorCenter;

  /// No description provided for @editorDone.
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get editorDone;

  /// No description provided for @editorSheetOf.
  ///
  /// In ru, this message translates to:
  /// **'Лист {index} из {total}'**
  String editorSheetOf(int index, int total);

  /// No description provided for @editorPrevSheet.
  ///
  /// In ru, this message translates to:
  /// **'Предыдущий лист'**
  String get editorPrevSheet;

  /// No description provided for @editorNextSheet.
  ///
  /// In ru, this message translates to:
  /// **'Следующий лист'**
  String get editorNextSheet;

  /// No description provided for @editorEmptySlot.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте фото'**
  String get editorEmptySlot;

  /// No description provided for @editorSlotEmpty.
  ///
  /// In ru, this message translates to:
  /// **'пусто'**
  String get editorSlotEmpty;

  /// No description provided for @editorSlotSelected.
  ///
  /// In ru, this message translates to:
  /// **'выбрано'**
  String get editorSlotSelected;

  /// No description provided for @editorCropHandle.
  ///
  /// In ru, this message translates to:
  /// **'Изменить кадр, угол {corner}'**
  String editorCropHandle(String corner);

  /// No description provided for @editorCornerTopLeft.
  ///
  /// In ru, this message translates to:
  /// **'левый верхний'**
  String get editorCornerTopLeft;

  /// No description provided for @editorCornerTopRight.
  ///
  /// In ru, this message translates to:
  /// **'правый верхний'**
  String get editorCornerTopRight;

  /// No description provided for @editorCornerBottomLeft.
  ///
  /// In ru, this message translates to:
  /// **'левый нижний'**
  String get editorCornerBottomLeft;

  /// No description provided for @editorCornerBottomRight.
  ///
  /// In ru, this message translates to:
  /// **'правый нижний'**
  String get editorCornerBottomRight;

  /// No description provided for @editorGestureHint.
  ///
  /// In ru, this message translates to:
  /// **'Тяните фото, чтобы сдвинуть кадр. Двумя пальцами — масштаб.'**
  String get editorGestureHint;

  /// No description provided for @editorSelectSlotHint.
  ///
  /// In ru, this message translates to:
  /// **'Коснитесь кадра, чтобы выбрать его'**
  String get editorSelectSlotHint;

  /// No description provided for @editorNoSlotSelected.
  ///
  /// In ru, this message translates to:
  /// **'Выберите кадр на листе'**
  String get editorNoSlotSelected;

  /// No description provided for @editorSlotSemantic.
  ///
  /// In ru, this message translates to:
  /// **'Кадр {index} из {total}, {state}'**
  String editorSlotSemantic(int index, int total, String state);

  /// No description provided for @editorToolFrame.
  ///
  /// In ru, this message translates to:
  /// **'Кадр'**
  String get editorToolFrame;

  /// No description provided for @editorToolLight.
  ///
  /// In ru, this message translates to:
  /// **'Свет'**
  String get editorToolLight;

  /// No description provided for @editorToolWarmth.
  ///
  /// In ru, this message translates to:
  /// **'Тепло'**
  String get editorToolWarmth;

  /// No description provided for @editorToolStyle.
  ///
  /// In ru, this message translates to:
  /// **'Стиль'**
  String get editorToolStyle;

  /// No description provided for @editorToolRotate.
  ///
  /// In ru, this message translates to:
  /// **'Повернуть'**
  String get editorToolRotate;

  /// No description provided for @editorToolReplace.
  ///
  /// In ru, this message translates to:
  /// **'Заменить'**
  String get editorToolReplace;

  /// No description provided for @editorToolSwap.
  ///
  /// In ru, this message translates to:
  /// **'Обменять'**
  String get editorToolSwap;

  /// No description provided for @editorToolBackground.
  ///
  /// In ru, this message translates to:
  /// **'Фон'**
  String get editorToolBackground;

  /// No description provided for @editorToolPending.
  ///
  /// In ru, this message translates to:
  /// **'Скоро: ждёт обновления редактора'**
  String get editorToolPending;

  /// No description provided for @editorLightValue.
  ///
  /// In ru, this message translates to:
  /// **'{value} EV'**
  String editorLightValue(String value);

  /// No description provided for @editorLightHint.
  ///
  /// In ru, this message translates to:
  /// **'Светлее или темнее'**
  String get editorLightHint;

  /// No description provided for @editorWarmthValue.
  ///
  /// In ru, this message translates to:
  /// **'{value}'**
  String editorWarmthValue(String value);

  /// No description provided for @editorWarmthHint.
  ///
  /// In ru, this message translates to:
  /// **'Теплее или холоднее'**
  String get editorWarmthHint;

  /// No description provided for @editorZoomValue.
  ///
  /// In ru, this message translates to:
  /// **'{value}×'**
  String editorZoomValue(String value);

  /// No description provided for @editorStyleStrength.
  ///
  /// In ru, this message translates to:
  /// **'Сила'**
  String get editorStyleStrength;

  /// No description provided for @editorStyleApplyAll.
  ///
  /// In ru, this message translates to:
  /// **'Применим ко всем фото'**
  String get editorStyleApplyAll;

  /// No description provided for @lookAsIs.
  ///
  /// In ru, this message translates to:
  /// **'Как есть'**
  String get lookAsIs;

  /// No description provided for @lookWarm.
  ///
  /// In ru, this message translates to:
  /// **'Тепло'**
  String get lookWarm;

  /// No description provided for @lookFilm.
  ///
  /// In ru, this message translates to:
  /// **'Плёнка'**
  String get lookFilm;

  /// No description provided for @lookBright.
  ///
  /// In ru, this message translates to:
  /// **'Ярче'**
  String get lookBright;

  /// No description provided for @lookSoft.
  ///
  /// In ru, this message translates to:
  /// **'Мягко'**
  String get lookSoft;

  /// No description provided for @lookMono.
  ///
  /// In ru, this message translates to:
  /// **'Ч/Б'**
  String get lookMono;

  /// No description provided for @editorRotateHint.
  ///
  /// In ru, this message translates to:
  /// **'Если фото лежит на боку'**
  String get editorRotateHint;

  /// No description provided for @editorRotateCw.
  ///
  /// In ru, this message translates to:
  /// **'Повернуть на 90°'**
  String get editorRotateCw;

  /// No description provided for @editorFlip.
  ///
  /// In ru, this message translates to:
  /// **'Отразить'**
  String get editorFlip;

  /// No description provided for @editorSwapPickFirst.
  ///
  /// In ru, this message translates to:
  /// **'Коснитесь кадра, с которым хотите поменяться'**
  String get editorSwapPickFirst;

  /// No description provided for @editorSwapPickSecond.
  ///
  /// In ru, this message translates to:
  /// **'Поменяем с фото {index}. Коснитесь второго кадра.'**
  String editorSwapPickSecond(int index);

  /// No description provided for @editorReplaceTitle.
  ///
  /// In ru, this message translates to:
  /// **'Фото в кадре'**
  String get editorReplaceTitle;

  /// No description provided for @editorBackgroundTitle.
  ///
  /// In ru, this message translates to:
  /// **'Цвет листа'**
  String get editorBackgroundTitle;

  /// No description provided for @editorBackgroundPaper.
  ///
  /// In ru, this message translates to:
  /// **'Как бумага'**
  String get editorBackgroundPaper;

  /// No description provided for @editorBackgroundCream.
  ///
  /// In ru, this message translates to:
  /// **'Кремовый'**
  String get editorBackgroundCream;

  /// No description provided for @editorBackgroundMint.
  ///
  /// In ru, this message translates to:
  /// **'Мята'**
  String get editorBackgroundMint;

  /// No description provided for @editorBackgroundBeige.
  ///
  /// In ru, this message translates to:
  /// **'Бежевый'**
  String get editorBackgroundBeige;

  /// No description provided for @editorNoPhotoSelected.
  ///
  /// In ru, this message translates to:
  /// **'Сначала выберите фото на листе'**
  String get editorNoPhotoSelected;

  /// No description provided for @preflightTitle.
  ///
  /// In ru, this message translates to:
  /// **'Проверка макета'**
  String get preflightTitle;

  /// No description provided for @preflightStatusClean.
  ///
  /// In ru, this message translates to:
  /// **'Замечаний нет'**
  String get preflightStatusClean;

  /// No description provided for @preflightStatusWarnings.
  ///
  /// In ru, this message translates to:
  /// **'Замечания: {count}'**
  String preflightStatusWarnings(int count);

  /// No description provided for @preflightStatusBlocking.
  ///
  /// In ru, this message translates to:
  /// **'Нельзя продолжить: {count}'**
  String preflightStatusBlocking(int count);

  /// No description provided for @preflightOpenIssues.
  ///
  /// In ru, this message translates to:
  /// **'Открыть замечания'**
  String get preflightOpenIssues;

  /// No description provided for @preflightAckAndOrder.
  ///
  /// In ru, this message translates to:
  /// **'Подтвердить и оформить'**
  String get preflightAckAndOrder;

  /// No description provided for @preflightRunning.
  ///
  /// In ru, this message translates to:
  /// **'Проверяем макет…'**
  String get preflightRunning;

  /// No description provided for @preflightCleanTitle.
  ///
  /// In ru, this message translates to:
  /// **'Можно печатать'**
  String get preflightCleanTitle;

  /// No description provided for @preflightCleanBody.
  ///
  /// In ru, this message translates to:
  /// **'Все кадры заполнены, разрешения хватает.'**
  String get preflightCleanBody;

  /// No description provided for @preflightIssuesTitle.
  ///
  /// In ru, this message translates to:
  /// **'Замечания: {count}'**
  String preflightIssuesTitle(int count);

  /// No description provided for @preflightBlockingNote.
  ///
  /// In ru, this message translates to:
  /// **'Пока есть блокирующие замечания, заказ недоступен.'**
  String get preflightBlockingNote;

  /// No description provided for @preflightEmptySlot.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте фото'**
  String get preflightEmptySlot;

  /// No description provided for @preflightEmptySlotHint.
  ///
  /// In ru, this message translates to:
  /// **'Лист {sheet}, кадр {slot} пуст.'**
  String preflightEmptySlotHint(int sheet, String slot);

  /// No description provided for @preflightLowDpi.
  ///
  /// In ru, this message translates to:
  /// **'Это фото {photo} px, для {size} нужно {required} — станет мыльным.'**
  String preflightLowDpi(String photo, String size, String required);

  /// No description provided for @preflightUnsupported.
  ///
  /// In ru, this message translates to:
  /// **'Формат {mime} не печатается. Нужны JPEG или PNG.'**
  String preflightUnsupported(String mime);

  /// No description provided for @preflightSafeZone.
  ///
  /// In ru, this message translates to:
  /// **'Контент ближе {mm} мм к краю — может обрезаться.'**
  String preflightSafeZone(String mm);

  /// No description provided for @preflightTextOverflow.
  ///
  /// In ru, this message translates to:
  /// **'Текст не помещается в блок.'**
  String get preflightTextOverflow;

  /// No description provided for @preflightFaceAtEdge.
  ///
  /// In ru, this message translates to:
  /// **'Лицо слишком близко к краю — может обрезаться.'**
  String get preflightFaceAtEdge;

  /// No description provided for @preflightSheetBadge.
  ///
  /// In ru, this message translates to:
  /// **'Лист {sheet}'**
  String preflightSheetBadge(int sheet);

  /// No description provided for @preflightServerMismatch.
  ///
  /// In ru, this message translates to:
  /// **'Сервер нашёл отличий: {count}. Показываем проверку сервера.'**
  String preflightServerMismatch(int count);

  /// No description provided for @preflightOffline.
  ///
  /// In ru, this message translates to:
  /// **'Серверная проверка недоступна — показываем локальную.'**
  String get preflightOffline;

  /// No description provided for @preflightOverride.
  ///
  /// In ru, this message translates to:
  /// **'Продолжить всё равно'**
  String get preflightOverride;

  /// No description provided for @preflightOverrideTitle.
  ///
  /// In ru, this message translates to:
  /// **'Продолжить с замечаниями?'**
  String get preflightOverrideTitle;

  /// No description provided for @preflightOverrideBody.
  ///
  /// In ru, this message translates to:
  /// **'Заказ уйдёт в производство с текущими замечаниями. Подтверждение сохраним в журнале.'**
  String get preflightOverrideBody;

  /// No description provided for @preflightOverrideConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Продолжить'**
  String get preflightOverrideConfirm;

  /// No description provided for @preflightOverrideRecorded.
  ///
  /// In ru, this message translates to:
  /// **'Подтверждение записано'**
  String get preflightOverrideRecorded;

  /// No description provided for @preflightToCart.
  ///
  /// In ru, this message translates to:
  /// **'В корзину'**
  String get preflightToCart;

  /// No description provided for @preflightAdding.
  ///
  /// In ru, this message translates to:
  /// **'Добавляем…'**
  String get preflightAdding;

  /// No description provided for @preflightFix.
  ///
  /// In ru, this message translates to:
  /// **'Исправить'**
  String get preflightFix;

  /// No description provided for @preflightAddFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось добавить в корзину'**
  String get preflightAddFailed;

  /// No description provided for @preflightFixHint.
  ///
  /// In ru, this message translates to:
  /// **'Открыть кадр в редакторе'**
  String get preflightFixHint;

  /// No description provided for @preflightWaitPhotos.
  ///
  /// In ru, this message translates to:
  /// **'Дождитесь загрузки фото — заказ станет доступен.'**
  String get preflightWaitPhotos;

  /// No description provided for @preflightSharePdf.
  ///
  /// In ru, this message translates to:
  /// **'Поделиться PDF'**
  String get preflightSharePdf;

  /// No description provided for @preflightSharePreparing.
  ///
  /// In ru, this message translates to:
  /// **'Готовим PDF: {done} из {total}'**
  String preflightSharePreparing(int done, int total);

  /// No description provided for @preflightShareOpening.
  ///
  /// In ru, this message translates to:
  /// **'Открываем…'**
  String get preflightShareOpening;

  /// No description provided for @preflightShareBlocked.
  ///
  /// In ru, this message translates to:
  /// **'Исправьте замечания или подтвердите их, чтобы поделиться PDF.'**
  String get preflightShareBlocked;

  /// No description provided for @preflightShareFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось подготовить PDF'**
  String get preflightShareFailed;

  /// No description provided for @preflightShareNotLoaded.
  ///
  /// In ru, this message translates to:
  /// **'Проект ещё загружается — попробуйте через пару секунд.'**
  String get preflightShareNotLoaded;

  /// No description provided for @preflightShareNothing.
  ///
  /// In ru, this message translates to:
  /// **'В проекте нет листов для экспорта.'**
  String get preflightShareNothing;

  /// No description provided for @preflightShareRenderFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось отрисовать макет. Попробуйте ещё раз.'**
  String get preflightShareRenderFailed;

  /// No description provided for @preflightShareOpenFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось открыть «Поделиться». Попробуйте ещё раз.'**
  String get preflightShareOpenFailed;

  /// Регистрация мок-аккаунта
  ///
  /// In ru, this message translates to:
  /// **'Создать аккаунт'**
  String get loginRegisterAction;

  /// No description provided for @loginTitle.
  ///
  /// In ru, this message translates to:
  /// **'Вход в PicPac'**
  String get loginTitle;

  /// Brand promise shown under the logo on the sign-in screen; one line, no instruction.
  ///
  /// In ru, this message translates to:
  /// **'Храните воспоминания красиво'**
  String get loginPromise;

  /// Reassurance under the brand promise: a guest can browse and build without an account.
  ///
  /// In ru, this message translates to:
  /// **'Каталог и сборка — без входа'**
  String get loginGuestNote;

  /// No description provided for @loginPasswordMode.
  ///
  /// In ru, this message translates to:
  /// **'По паролю'**
  String get loginPasswordMode;

  /// No description provided for @loginCodeMode.
  ///
  /// In ru, this message translates to:
  /// **'По коду'**
  String get loginCodeMode;

  /// No description provided for @loginEmailLabel.
  ///
  /// In ru, this message translates to:
  /// **'Email'**
  String get loginEmailLabel;

  /// No description provided for @loginEmailHint.
  ///
  /// In ru, this message translates to:
  /// **'name@example.com'**
  String get loginEmailHint;

  /// No description provided for @loginEmailInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Проверьте адрес: нужен вид name@example.com'**
  String get loginEmailInvalid;

  /// No description provided for @loginPasswordLabel.
  ///
  /// In ru, this message translates to:
  /// **'Пароль'**
  String get loginPasswordLabel;

  /// No description provided for @loginPasswordRequired.
  ///
  /// In ru, this message translates to:
  /// **'Введите пароль'**
  String get loginPasswordRequired;

  /// No description provided for @loginPasswordHidden.
  ///
  /// In ru, this message translates to:
  /// **'Показать пароль'**
  String get loginPasswordHidden;

  /// No description provided for @loginPasswordShown.
  ///
  /// In ru, this message translates to:
  /// **'Скрыть пароль'**
  String get loginPasswordShown;

  /// No description provided for @loginSubmit.
  ///
  /// In ru, this message translates to:
  /// **'Войти'**
  String get loginSubmit;

  /// No description provided for @loginInvalidCredentials.
  ///
  /// In ru, this message translates to:
  /// **'Неверный email или пароль'**
  String get loginInvalidCredentials;

  /// No description provided for @loginSendCode.
  ///
  /// In ru, this message translates to:
  /// **'Получить код'**
  String get loginSendCode;

  /// No description provided for @loginCodeLabel.
  ///
  /// In ru, this message translates to:
  /// **'Код из письма'**
  String get loginCodeLabel;

  /// No description provided for @loginCodeHint.
  ///
  /// In ru, this message translates to:
  /// **'4 цифры'**
  String get loginCodeHint;

  /// No description provided for @loginCodeSent.
  ///
  /// In ru, this message translates to:
  /// **'Код отправлен на {email}. Демо-код: 0000.'**
  String loginCodeSent(String email);

  /// No description provided for @loginCodeDemo.
  ///
  /// In ru, this message translates to:
  /// **'Демо-код: 0000'**
  String get loginCodeDemo;

  /// No description provided for @loginCodeInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Код не подошёл. Проверьте цифры.'**
  String get loginCodeInvalid;

  /// No description provided for @loginCodeExpired.
  ///
  /// In ru, this message translates to:
  /// **'Код истёк. Запросите новый.'**
  String get loginCodeExpired;

  /// No description provided for @loginDemoTitle.
  ///
  /// In ru, this message translates to:
  /// **'Демо-доступ'**
  String get loginDemoTitle;

  /// No description provided for @loginDemoCustomer.
  ///
  /// In ru, this message translates to:
  /// **'Клиент: customer@picpac.test / Test1234'**
  String get loginDemoCustomer;

  /// No description provided for @loginDemoSupport.
  ///
  /// In ru, this message translates to:
  /// **'Поддержка: support@picpac.test / Test1234'**
  String get loginDemoSupport;

  /// No description provided for @loginDemoHint.
  ///
  /// In ru, this message translates to:
  /// **'Нажмите, чтобы подставить данные.'**
  String get loginDemoHint;

  /// No description provided for @loginGuestContinue.
  ///
  /// In ru, this message translates to:
  /// **'Продолжить без входа'**
  String get loginGuestContinue;

  /// No description provided for @loginLookup.
  ///
  /// In ru, this message translates to:
  /// **'Найти заказ по номеру'**
  String get loginLookup;

  /// No description provided for @loginSupportWelcome.
  ///
  /// In ru, this message translates to:
  /// **'Вы вошли как агент поддержки.'**
  String get loginSupportWelcome;

  /// No description provided for @loginRoleFailed.
  ///
  /// In ru, this message translates to:
  /// **'Сервер не сообщил роль. Вход отменён — попробуйте ещё раз.'**
  String get loginRoleFailed;

  /// No description provided for @logoutTitle.
  ///
  /// In ru, this message translates to:
  /// **'Выйти из аккаунта?'**
  String get logoutTitle;

  /// No description provided for @logoutBody.
  ///
  /// In ru, this message translates to:
  /// **'Черновики и фото останутся на устройстве. Кеш заказов и очередь отправки будут очищены.'**
  String get logoutBody;

  /// No description provided for @logoutConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Выйти из аккаунта'**
  String get logoutConfirm;

  /// No description provided for @logoutDone.
  ///
  /// In ru, this message translates to:
  /// **'Вы вышли из аккаунта'**
  String get logoutDone;

  /// No description provided for @supportTitle.
  ///
  /// In ru, this message translates to:
  /// **'Поддержка'**
  String get supportTitle;

  /// No description provided for @supportAgentMode.
  ///
  /// In ru, this message translates to:
  /// **'Режим поддержки'**
  String get supportAgentMode;

  /// No description provided for @supportAgentModeHint.
  ///
  /// In ru, this message translates to:
  /// **'Вы видите все обращения клиентов. Заказы клиентов только для чтения.'**
  String get supportAgentModeHint;

  /// No description provided for @supportNewTicket.
  ///
  /// In ru, this message translates to:
  /// **'Новое обращение'**
  String get supportNewTicket;

  /// No description provided for @supportCreate.
  ///
  /// In ru, this message translates to:
  /// **'Создать обращение'**
  String get supportCreate;

  /// No description provided for @supportEmptyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Обращений пока нет'**
  String get supportEmptyTitle;

  /// No description provided for @supportEmptyBody.
  ///
  /// In ru, this message translates to:
  /// **'Если что-то пошло не так с заказом, напишите нам — ответим здесь же.'**
  String get supportEmptyBody;

  /// No description provided for @supportEmptyAgentTitle.
  ///
  /// In ru, this message translates to:
  /// **'Обращений нет'**
  String get supportEmptyAgentTitle;

  /// No description provided for @supportEmptyAgentBody.
  ///
  /// In ru, this message translates to:
  /// **'Клиенты ещё не писали в поддержку. Обновите список позже.'**
  String get supportEmptyAgentBody;

  /// No description provided for @supportLoginRequired.
  ///
  /// In ru, this message translates to:
  /// **'Обращения хранятся в аккаунте.'**
  String get supportLoginRequired;

  /// No description provided for @supportTicketCreated.
  ///
  /// In ru, this message translates to:
  /// **'Обращение создано'**
  String get supportTicketCreated;

  /// No description provided for @supportSubjectLabel.
  ///
  /// In ru, this message translates to:
  /// **'Тема'**
  String get supportSubjectLabel;

  /// No description provided for @supportSubjectHint.
  ///
  /// In ru, this message translates to:
  /// **'Коротко: что случилось'**
  String get supportSubjectHint;

  /// No description provided for @supportSubjectRequired.
  ///
  /// In ru, this message translates to:
  /// **'Опишите тему в двух словах'**
  String get supportSubjectRequired;

  /// No description provided for @supportMessageLabel.
  ///
  /// In ru, this message translates to:
  /// **'Сообщение'**
  String get supportMessageLabel;

  /// No description provided for @supportMessageHint.
  ///
  /// In ru, this message translates to:
  /// **'Что не так и что вы ожидали?'**
  String get supportMessageHint;

  /// No description provided for @supportMessageRequired.
  ///
  /// In ru, this message translates to:
  /// **'Напишите сообщение'**
  String get supportMessageRequired;

  /// No description provided for @supportTypeLabel.
  ///
  /// In ru, this message translates to:
  /// **'Причина'**
  String get supportTypeLabel;

  /// No description provided for @supportTypeQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Вопрос'**
  String get supportTypeQuestion;

  /// No description provided for @supportTypeDefect.
  ///
  /// In ru, this message translates to:
  /// **'Брак или перепечатка'**
  String get supportTypeDefect;

  /// No description provided for @supportTypeRefund.
  ///
  /// In ru, this message translates to:
  /// **'Возврат'**
  String get supportTypeRefund;

  /// No description provided for @supportTypeDelivery.
  ///
  /// In ru, this message translates to:
  /// **'Доставка'**
  String get supportTypeDelivery;

  /// No description provided for @supportTypeOther.
  ///
  /// In ru, this message translates to:
  /// **'Другое'**
  String get supportTypeOther;

  /// No description provided for @supportTypeUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Другое'**
  String get supportTypeUnknown;

  /// No description provided for @supportOrderLabel.
  ///
  /// In ru, this message translates to:
  /// **'Заказ'**
  String get supportOrderLabel;

  /// No description provided for @supportOrderNone.
  ///
  /// In ru, this message translates to:
  /// **'Без заказа'**
  String get supportOrderNone;

  /// No description provided for @supportOrderUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Заказ недоступен'**
  String get supportOrderUnknown;

  /// No description provided for @supportOrderAttached.
  ///
  /// In ru, this message translates to:
  /// **'Заказ {number}'**
  String supportOrderAttached(String number);

  /// No description provided for @supportSend.
  ///
  /// In ru, this message translates to:
  /// **'Отправить'**
  String get supportSend;

  /// No description provided for @supportReplyHint.
  ///
  /// In ru, this message translates to:
  /// **'Сообщение в поддержку'**
  String get supportReplyHint;

  /// No description provided for @supportReplyHintAgent.
  ///
  /// In ru, this message translates to:
  /// **'Ответ клиенту'**
  String get supportReplyHintAgent;

  /// No description provided for @supportAuthorYou.
  ///
  /// In ru, this message translates to:
  /// **'Вы'**
  String get supportAuthorYou;

  /// No description provided for @supportAuthorCustomer.
  ///
  /// In ru, this message translates to:
  /// **'Клиент'**
  String get supportAuthorCustomer;

  /// No description provided for @supportAuthorSupport.
  ///
  /// In ru, this message translates to:
  /// **'Поддержка'**
  String get supportAuthorSupport;

  /// No description provided for @supportQueued.
  ///
  /// In ru, this message translates to:
  /// **'Нет сети. Сообщение сохранено и уйдёт автоматически.'**
  String get supportQueued;

  /// No description provided for @supportMessageQueued.
  ///
  /// In ru, this message translates to:
  /// **'В очереди'**
  String get supportMessageQueued;

  /// No description provided for @supportTicketClosed.
  ///
  /// In ru, this message translates to:
  /// **'Обращение закрыто. Новые сообщения недоступны.'**
  String get supportTicketClosed;

  /// No description provided for @supportForeignTicket.
  ///
  /// In ru, this message translates to:
  /// **'Это обращение другого клиента'**
  String get supportForeignTicket;

  /// No description provided for @supportForeignTicketBody.
  ///
  /// In ru, this message translates to:
  /// **'Показать его могут только автор и поддержка.'**
  String get supportForeignTicketBody;

  /// No description provided for @supportStatusOpen.
  ///
  /// In ru, this message translates to:
  /// **'Открыто'**
  String get supportStatusOpen;

  /// No description provided for @supportStatusPending.
  ///
  /// In ru, this message translates to:
  /// **'Ответ поддержки'**
  String get supportStatusPending;

  /// No description provided for @supportStatusResolved.
  ///
  /// In ru, this message translates to:
  /// **'Решено'**
  String get supportStatusResolved;

  /// No description provided for @supportStatusClosed.
  ///
  /// In ru, this message translates to:
  /// **'Закрыто'**
  String get supportStatusClosed;

  /// No description provided for @supportStatusUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Статус обновляется'**
  String get supportStatusUnknown;

  /// No description provided for @supportUpdatedAt.
  ///
  /// In ru, this message translates to:
  /// **'Обновлено {date}'**
  String supportUpdatedAt(String date);

  /// No description provided for @supportMessagesCount.
  ///
  /// In ru, this message translates to:
  /// **'Сообщений: {count}'**
  String supportMessagesCount(int count);

  /// No description provided for @supportSending.
  ///
  /// In ru, this message translates to:
  /// **'Отправляем…'**
  String get supportSending;

  /// No description provided for @supportSendFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось отправить сообщение'**
  String get supportSendFailed;

  /// No description provided for @profileTitle.
  ///
  /// In ru, this message translates to:
  /// **'Профиль'**
  String get profileTitle;

  /// No description provided for @profileGuestTitle.
  ///
  /// In ru, this message translates to:
  /// **'Вы не вошли'**
  String get profileGuestTitle;

  /// Заголовок блока выбора языка интерфейса
  ///
  /// In ru, this message translates to:
  /// **'Язык'**
  String get profileLanguageTitle;

  /// Язык интерфейса следует за настройкой телефона
  ///
  /// In ru, this message translates to:
  /// **'Системный'**
  String get profileLanguageSystem;

  /// No description provided for @profileLanguageRu.
  ///
  /// In ru, this message translates to:
  /// **'Русский'**
  String get profileLanguageRu;

  /// Название языка всегда на самом языке (endonym), не переводится
  ///
  /// In ru, this message translates to:
  /// **'Беларуская'**
  String get profileLanguageBe;

  /// No description provided for @profileLanguageHint.
  ///
  /// In ru, this message translates to:
  /// **'Интерфейс переключается сразу, без перезапуска приложения.'**
  String get profileLanguageHint;

  /// No description provided for @profileDataTitle.
  ///
  /// In ru, this message translates to:
  /// **'Данные'**
  String get profileDataTitle;

  /// No description provided for @profileCustomerSinceLabel.
  ///
  /// In ru, this message translates to:
  /// **'С нами с'**
  String get profileCustomerSinceLabel;

  /// No description provided for @profilePhoneLabel.
  ///
  /// In ru, this message translates to:
  /// **'Телефон'**
  String get profilePhoneLabel;

  /// No description provided for @profilePhoneHint.
  ///
  /// In ru, this message translates to:
  /// **'Сервер отдаёт только маску номера.'**
  String get profilePhoneHint;

  /// No description provided for @profileSupportOnlyHint.
  ///
  /// In ru, this message translates to:
  /// **'В режиме поддержки доступны только обращения клиентов.'**
  String get profileSupportOnlyHint;

  /// No description provided for @profileQueueTitle.
  ///
  /// In ru, this message translates to:
  /// **'Очередь отправки'**
  String get profileQueueTitle;

  /// No description provided for @profileQueueEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Все действия отправлены.'**
  String get profileQueueEmpty;

  /// No description provided for @profileQueueEmptyHint.
  ///
  /// In ru, this message translates to:
  /// **'Здесь появятся заказы и сообщения, которые не удалось отправить без сети.'**
  String get profileQueueEmptyHint;

  /// No description provided for @profileQueueItemCheckout.
  ///
  /// In ru, this message translates to:
  /// **'Оформление заказа'**
  String get profileQueueItemCheckout;

  /// No description provided for @profileQueueItemTicket.
  ///
  /// In ru, this message translates to:
  /// **'Обращение в поддержку'**
  String get profileQueueItemTicket;

  /// No description provided for @profileQueueItemMessage.
  ///
  /// In ru, this message translates to:
  /// **'Сообщение в поддержку'**
  String get profileQueueItemMessage;

  /// No description provided for @profileQueueItemUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Действие'**
  String get profileQueueItemUnknown;

  /// No description provided for @profileQueueAttempts.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} попытка} few{{count} попытки} many{{count} попыток} other{{count} попытки}}'**
  String profileQueueAttempts(int count);

  /// No description provided for @profileQueueQueued.
  ///
  /// In ru, this message translates to:
  /// **'В очереди'**
  String get profileQueueQueued;

  /// No description provided for @profileQueueFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не отправлено'**
  String get profileQueueFailed;

  /// No description provided for @profileQueueRetry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get profileQueueRetry;

  /// No description provided for @profileQueueRetryAll.
  ///
  /// In ru, this message translates to:
  /// **'Повторить все'**
  String get profileQueueRetryAll;

  /// No description provided for @profileQueueSent.
  ///
  /// In ru, this message translates to:
  /// **'Отправлено: {count}'**
  String profileQueueSent(int count);

  /// No description provided for @profileQueueStillQueued.
  ///
  /// In ru, this message translates to:
  /// **'Осталось в очереди: {count}'**
  String profileQueueStillQueued(int count);

  /// No description provided for @profileQueueOrderSent.
  ///
  /// In ru, this message translates to:
  /// **'Заказ {number} отправлен'**
  String profileQueueOrderSent(String number);

  /// No description provided for @profileTestData.
  ///
  /// In ru, this message translates to:
  /// **'Тестовые данные'**
  String get profileTestData;

  /// No description provided for @profileTestDataHint.
  ///
  /// In ru, this message translates to:
  /// **'Черновики, копии фото и кеш заказов на этом устройстве.'**
  String get profileTestDataHint;

  /// No description provided for @profileDeleteTestData.
  ///
  /// In ru, this message translates to:
  /// **'Удалить черновики и кеш'**
  String get profileDeleteTestData;

  /// No description provided for @profileDeleteTestDataTitle.
  ///
  /// In ru, this message translates to:
  /// **'Удалить тестовые данные?'**
  String get profileDeleteTestDataTitle;

  /// No description provided for @profileDeleteTestDataBody.
  ///
  /// In ru, this message translates to:
  /// **'Черновики, скачанные копии фото и кеш заказов на этом устройстве будут удалены. Аккаунт и заказы на сервере останутся.'**
  String get profileDeleteTestDataBody;

  /// No description provided for @profileDeleteTestDataDone.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{Удалён {count} черновик} few{Удалено {count} черновика} many{Удалено {count} черновиков} other{Удалено {count} черновика}}. Кеш очищен.'**
  String profileDeleteTestDataDone(int count);

  /// No description provided for @profileDangerTitle.
  ///
  /// In ru, this message translates to:
  /// **'Удаление данных'**
  String get profileDangerTitle;

  /// No description provided for @profileDeleteAccount.
  ///
  /// In ru, this message translates to:
  /// **'Удалить аккаунт'**
  String get profileDeleteAccount;

  /// No description provided for @profileDeleteAccountStep1Title.
  ///
  /// In ru, this message translates to:
  /// **'Удалить аккаунт и все данные?'**
  String get profileDeleteAccountStep1Title;

  /// No description provided for @profileDeleteAccountStep1Body.
  ///
  /// In ru, this message translates to:
  /// **'Вместе с аккаунтом удалятся заказы, обращения в поддержку, черновики и загруженные фото. Восстановить данные нельзя.'**
  String get profileDeleteAccountStep1Body;

  /// No description provided for @profileDeleteAccountStep2Title.
  ///
  /// In ru, this message translates to:
  /// **'Последнее подтверждение'**
  String get profileDeleteAccountStep2Title;

  /// No description provided for @profileDeleteAccountStep2Body.
  ///
  /// In ru, this message translates to:
  /// **'Аккаунт {email} и все связанные данные будут удалены безвозвратно. Продолжить?'**
  String profileDeleteAccountStep2Body(String email);

  /// No description provided for @profileDeleteAccountConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Удалить безвозвратно'**
  String get profileDeleteAccountConfirm;

  /// No description provided for @profileDeleteAccountDone.
  ///
  /// In ru, this message translates to:
  /// **'Аккаунт и данные удалены'**
  String get profileDeleteAccountDone;

  /// No description provided for @profileDeleteAccountFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось удалить аккаунт. Попробуйте ещё раз.'**
  String get profileDeleteAccountFailed;

  /// No description provided for @profileDeletedEmail.
  ///
  /// In ru, this message translates to:
  /// **'ваш аккаунт'**
  String get profileDeletedEmail;

  /// No description provided for @cartSheetsUnit.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} лист} few{{count} листа} many{{count} листов} other{{count} листа}}'**
  String cartSheetsUnit(int count);

  /// No description provided for @cartBooksUnit.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} книга} few{{count} книги} many{{count} книг} other{{count} книги}}'**
  String cartBooksUnit(int count);

  /// No description provided for @cartSpreadsUnit.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} разворот} few{{count} разворота} many{{count} разворотов} other{{count} разворота}}'**
  String cartSpreadsUnit(int count);

  /// No description provided for @cartQuantityDerived.
  ///
  /// In ru, this message translates to:
  /// **'По макету'**
  String get cartQuantityDerived;

  /// No description provided for @cartRecalculated.
  ///
  /// In ru, this message translates to:
  /// **'Корзина пересчитана по текущему макету'**
  String get cartRecalculated;

  /// No description provided for @checkoutGuestWorkTitle.
  ///
  /// In ru, this message translates to:
  /// **'Проект собран как гость'**
  String get checkoutGuestWorkTitle;

  /// No description provided for @checkoutGuestWorkBody.
  ///
  /// In ru, this message translates to:
  /// **'Проект собран как гость. После входа его нужно будет собрать заново.'**
  String get checkoutGuestWorkBody;

  /// No description provided for @checkoutGuestWorkConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Понятно, войти'**
  String get checkoutGuestWorkConfirm;

  /// No description provided for @checkoutPreflightBlocked.
  ///
  /// In ru, this message translates to:
  /// **'Заказ нельзя оформить, пока не исправлены замечания проверки макета.'**
  String get checkoutPreflightBlocked;

  /// No description provided for @checkoutPreflightBlockedTitle.
  ///
  /// In ru, this message translates to:
  /// **'Заказ заблокирован проверкой'**
  String get checkoutPreflightBlockedTitle;

  /// No description provided for @checkoutPreflightBlockedBody.
  ///
  /// In ru, this message translates to:
  /// **'Пока есть блокирующие замечания, заказ не оформляется. Исправьте их или подтвердите, что заказываете как есть.'**
  String get checkoutPreflightBlockedBody;

  /// No description provided for @productOptionsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Опции'**
  String get productOptionsTitle;

  /// No description provided for @productOptionsTotal.
  ///
  /// In ru, this message translates to:
  /// **'Цена с опциями'**
  String get productOptionsTotal;

  /// No description provided for @productOptionsMore.
  ///
  /// In ru, this message translates to:
  /// **'дороже на {amount}'**
  String productOptionsMore(String amount);

  /// No description provided for @productOptionsLess.
  ///
  /// In ru, this message translates to:
  /// **'дешевле на {amount}'**
  String productOptionsLess(String amount);

  /// No description provided for @productOptionCheaper.
  ///
  /// In ru, this message translates to:
  /// **'−{amount}'**
  String productOptionCheaper(String amount);

  /// No description provided for @productOptionDearer.
  ///
  /// In ru, this message translates to:
  /// **'+{amount}'**
  String productOptionDearer(String amount);

  /// No description provided for @projectsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Мои проекты'**
  String get projectsTitle;

  /// No description provided for @projectsEmptyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Проектов пока нет'**
  String get projectsEmptyTitle;

  /// No description provided for @projectsEmptyBody.
  ///
  /// In ru, this message translates to:
  /// **'Соберите проект в каталоге — он сохранится на устройстве.'**
  String get projectsEmptyBody;

  /// No description provided for @projectsPhotos.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} фото} few{{count} фото} many{{count} фото} other{{count} фото}}'**
  String projectsPhotos(int count);

  /// No description provided for @projectsUpdatedAt.
  ///
  /// In ru, this message translates to:
  /// **'Изменён {date}'**
  String projectsUpdatedAt(String date);

  /// No description provided for @projectsDelete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить проект'**
  String get projectsDelete;

  /// No description provided for @projectsDeleteTitle.
  ///
  /// In ru, this message translates to:
  /// **'Удалить проект?'**
  String get projectsDeleteTitle;

  /// No description provided for @projectsDeleteBody.
  ///
  /// In ru, this message translates to:
  /// **'Проект и его копии фото удалятся с устройства. Оригиналы останутся в галерее.'**
  String get projectsDeleteBody;

  /// No description provided for @projectsGuestTitle.
  ///
  /// In ru, this message translates to:
  /// **'Проект принадлежит гостевой сессии'**
  String get projectsGuestTitle;

  /// No description provided for @projectsGuestBody.
  ///
  /// In ru, this message translates to:
  /// **'Проект собран без входа в аккаунт, и перенести его в аккаунт пока нельзя. Соберите проект заново из каталога.'**
  String get projectsGuestBody;

  /// No description provided for @projectsGuestBodySnapshot.
  ///
  /// In ru, this message translates to:
  /// **'Проект собран без входа в аккаунт, и перенести его в аккаунт пока нельзя. Фотографии сохранены на устройстве — можно собрать проект заново с тем же выбором.'**
  String get projectsGuestBodySnapshot;

  /// No description provided for @projectsRestart.
  ///
  /// In ru, this message translates to:
  /// **'Собрать заново'**
  String get projectsRestart;

  /// No description provided for @projectsRestarting.
  ///
  /// In ru, this message translates to:
  /// **'Собираем…'**
  String get projectsRestarting;

  /// No description provided for @projectsRestartFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось собрать проект заново'**
  String get projectsRestartFailed;

  /// Кнопка имитации push о статусе заказа
  ///
  /// In ru, this message translates to:
  /// **'Demo push'**
  String get orderDemoPush;

  /// Текст имитированного push
  ///
  /// In ru, this message translates to:
  /// **'Push: заказ {number} — {status}'**
  String orderDemoPushBody(String number, String status);

  /// No description provided for @orderDemoTitle.
  ///
  /// In ru, this message translates to:
  /// **'Управление статусом'**
  String get orderDemoTitle;

  /// No description provided for @orderDemoHint.
  ///
  /// In ru, this message translates to:
  /// **'Доступно только поддержке. Меняет статус заказа на сервере.'**
  String get orderDemoHint;

  /// No description provided for @orderDemoAdvance.
  ///
  /// In ru, this message translates to:
  /// **'Следующий статус'**
  String get orderDemoAdvance;

  /// No description provided for @orderDemoCancel.
  ///
  /// In ru, this message translates to:
  /// **'Отменить заказ'**
  String get orderDemoCancel;

  /// No description provided for @orderDemoNeedsSupport.
  ///
  /// In ru, this message translates to:
  /// **'Этот переход делает поддержка.'**
  String get orderDemoNeedsSupport;

  /// No description provided for @orderDemoPay.
  ///
  /// In ru, this message translates to:
  /// **'Оплатить'**
  String get orderDemoPay;

  /// No description provided for @orderDemoPaid.
  ///
  /// In ru, this message translates to:
  /// **'Оплата подтверждена сервером'**
  String get orderDemoPaid;

  /// No description provided for @orderDemoFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось выполнить действие'**
  String get orderDemoFailed;

  /// No description provided for @orderDemoTooltip.
  ///
  /// In ru, this message translates to:
  /// **'Контролы mock-сервера (только debug)'**
  String get orderDemoTooltip;

  /// No description provided for @paymentPanelTitle.
  ///
  /// In ru, this message translates to:
  /// **'Оплата заказа'**
  String get paymentPanelTitle;

  /// No description provided for @paymentAmountDue.
  ///
  /// In ru, this message translates to:
  /// **'К оплате {amount}'**
  String paymentAmountDue(String amount);

  /// No description provided for @paymentRegionLabel.
  ///
  /// In ru, this message translates to:
  /// **'Страна оплаты'**
  String get paymentRegionLabel;

  /// No description provided for @paymentRegionBy.
  ///
  /// In ru, this message translates to:
  /// **'Беларусь'**
  String get paymentRegionBy;

  /// No description provided for @paymentRegionRu.
  ///
  /// In ru, this message translates to:
  /// **'Россия'**
  String get paymentRegionRu;

  /// No description provided for @paymentMethodCard.
  ///
  /// In ru, this message translates to:
  /// **'Картой онлайн'**
  String get paymentMethodCard;

  /// No description provided for @paymentMethodSbp.
  ///
  /// In ru, this message translates to:
  /// **'СБП'**
  String get paymentMethodSbp;

  /// No description provided for @paymentMethodCod.
  ///
  /// In ru, this message translates to:
  /// **'При получении'**
  String get paymentMethodCod;

  /// No description provided for @paymentMethodWallet.
  ///
  /// In ru, this message translates to:
  /// **'Кошелёк'**
  String get paymentMethodWallet;

  /// No description provided for @paymentMethodUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Способ оплаты'**
  String get paymentMethodUnknown;

  /// No description provided for @paymentPay.
  ///
  /// In ru, this message translates to:
  /// **'Оплатить'**
  String get paymentPay;

  /// No description provided for @paymentPreparing.
  ///
  /// In ru, this message translates to:
  /// **'Готовим платёж…'**
  String get paymentPreparing;

  /// No description provided for @paymentAwaitingUser.
  ///
  /// In ru, this message translates to:
  /// **'Оплатите на странице банка и вернитесь в приложение'**
  String get paymentAwaitingUser;

  /// No description provided for @paymentHostedPageFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось открыть страницу оплаты. Попробуйте ещё раз.'**
  String get paymentHostedPageFailed;

  /// No description provided for @paymentHostedPageAgain.
  ///
  /// In ru, this message translates to:
  /// **'Открыть страницу оплаты'**
  String get paymentHostedPageAgain;

  /// No description provided for @paymentChecking.
  ///
  /// In ru, this message translates to:
  /// **'Проверяем оплату…'**
  String get paymentChecking;

  /// No description provided for @paymentUncertain.
  ///
  /// In ru, this message translates to:
  /// **'Уточняем статус оплаты…'**
  String get paymentUncertain;

  /// No description provided for @paymentPaid.
  ///
  /// In ru, this message translates to:
  /// **'Заказ оплачен'**
  String get paymentPaid;

  /// No description provided for @paymentFailed.
  ///
  /// In ru, this message translates to:
  /// **'Оплата не прошла'**
  String get paymentFailed;

  /// No description provided for @paymentRetry.
  ///
  /// In ru, this message translates to:
  /// **'Попробовать снова'**
  String get paymentRetry;

  /// No description provided for @paymentExpired.
  ///
  /// In ru, this message translates to:
  /// **'Срок оплаты истёк'**
  String get paymentExpired;

  /// No description provided for @paymentCreateNew.
  ///
  /// In ru, this message translates to:
  /// **'Создать новую'**
  String get paymentCreateNew;

  /// No description provided for @paymentCanceled.
  ///
  /// In ru, this message translates to:
  /// **'Оплата отменена'**
  String get paymentCanceled;

  /// No description provided for @paymentOnDelivery.
  ///
  /// In ru, this message translates to:
  /// **'Оплата при получении'**
  String get paymentOnDelivery;

  /// No description provided for @paymentOnDeliveryHint.
  ///
  /// In ru, this message translates to:
  /// **'Способ выбран. Деньги — при получении заказа.'**
  String get paymentOnDeliveryHint;

  /// No description provided for @paymentReceipt.
  ///
  /// In ru, this message translates to:
  /// **'Чек'**
  String get paymentReceipt;

  /// No description provided for @paymentReceiptTitle.
  ///
  /// In ru, this message translates to:
  /// **'Чек'**
  String get paymentReceiptTitle;

  /// No description provided for @paymentReceiptFiscal.
  ///
  /// In ru, this message translates to:
  /// **'Фискальный номер'**
  String get paymentReceiptFiscal;

  /// No description provided for @paymentReceiptAmount.
  ///
  /// In ru, this message translates to:
  /// **'Сумма'**
  String get paymentReceiptAmount;

  /// No description provided for @paymentReceiptDate.
  ///
  /// In ru, this message translates to:
  /// **'Дата'**
  String get paymentReceiptDate;

  /// No description provided for @paymentReceiptShare.
  ///
  /// In ru, this message translates to:
  /// **'Поделиться'**
  String get paymentReceiptShare;

  /// No description provided for @paymentReceiptSubject.
  ///
  /// In ru, this message translates to:
  /// **'Чек PicPac'**
  String get paymentReceiptSubject;

  /// No description provided for @paymentReceiptUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Чек ещё не готов'**
  String get paymentReceiptUnavailable;

  /// No description provided for @paymentReceiptVat.
  ///
  /// In ru, this message translates to:
  /// **'В том числе НДС'**
  String get paymentReceiptVat;

  /// No description provided for @paymentShareFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось поделиться чеком'**
  String get paymentShareFailed;

  /// No description provided for @paymentEripCode.
  ///
  /// In ru, this message translates to:
  /// **'Код ЕРИП'**
  String get paymentEripCode;

  /// No description provided for @paymentSbpHint.
  ///
  /// In ru, this message translates to:
  /// **'Откройте страницу оплаты и подтвердите перевод в банке'**
  String get paymentSbpHint;

  /// No description provided for @paymentNoMethods.
  ///
  /// In ru, this message translates to:
  /// **'Нет доступных способов оплаты'**
  String get paymentNoMethods;

  /// No description provided for @paymentMethodsFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить способы оплаты'**
  String get paymentMethodsFailed;

  /// No description provided for @paymentCheckFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось проверить оплату'**
  String get paymentCheckFailed;

  /// No description provided for @paymentCheckAgain.
  ///
  /// In ru, this message translates to:
  /// **'Проверить ещё раз'**
  String get paymentCheckAgain;

  /// No description provided for @paymentAlreadyPaid.
  ///
  /// In ru, this message translates to:
  /// **'Заказ уже оплачен — новый платёж не нужен'**
  String get paymentAlreadyPaid;

  /// No description provided for @paymentNotRequired.
  ///
  /// In ru, this message translates to:
  /// **'Заказ не требует оплаты'**
  String get paymentNotRequired;

  /// No description provided for @paymentNotPayable.
  ///
  /// In ru, this message translates to:
  /// **'Этот заказ нельзя оплатить'**
  String get paymentNotPayable;

  /// No description provided for @paymentStatusUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Уточняем статус'**
  String get paymentStatusUnknown;

  /// Кнопка ассистента в панели редактора
  ///
  /// In ru, this message translates to:
  /// **'Подсказать'**
  String get assistantButton;

  /// Заголовок шита ассистента
  ///
  /// In ru, this message translates to:
  /// **'Что улучшить?'**
  String get assistantTitle;

  /// Подсказка в поле свободного запроса
  ///
  /// In ru, this message translates to:
  /// **'Например: «сделай теплее»'**
  String get assistantHint;

  /// Отправить свободный запрос модели
  ///
  /// In ru, this message translates to:
  /// **'Спросить'**
  String get assistantAsk;

  /// Состояние ожидания ответа
  ///
  /// In ru, this message translates to:
  /// **'Смотрим на листы…'**
  String get assistantThinking;

  /// Подпись мини-рендера до применения
  ///
  /// In ru, this message translates to:
  /// **'Было'**
  String get assistantBefore;

  /// Подпись мини-рендера после применения
  ///
  /// In ru, this message translates to:
  /// **'Станет'**
  String get assistantAfter;

  /// Применить предложение одним шагом
  ///
  /// In ru, this message translates to:
  /// **'Применить'**
  String get assistantApply;

  /// Повторить запрос после отказа
  ///
  /// In ru, this message translates to:
  /// **'Попробовать ещё'**
  String get assistantRetry;

  /// Сеть недоступна, чипы работают локально
  ///
  /// In ru, this message translates to:
  /// **'Для свободного запроса нужен интернет'**
  String get assistantOffline;

  /// Предложение построено локальным движком
  ///
  /// In ru, this message translates to:
  /// **'Быстрый режим: правила на устройстве'**
  String get assistantQuickMode;

  /// Предложение получено от модели за BFF
  ///
  /// In ru, this message translates to:
  /// **'Предложение модели'**
  String get assistantRemoteMode;

  /// Патч отклонён валидацией целиком
  ///
  /// In ru, this message translates to:
  /// **'Модель предложила несовместимое изменение'**
  String get assistantRejected;

  /// Модель не нашла изменений
  ///
  /// In ru, this message translates to:
  /// **'Менять нечего — всё уже так'**
  String get assistantNoChange;

  /// Изменения применены одним шагом undo
  ///
  /// In ru, this message translates to:
  /// **'Готово. Отменить можно кнопкой «Отменить»'**
  String get assistantApplied;

  /// Заголовок списка изменений
  ///
  /// In ru, this message translates to:
  /// **'Что изменится'**
  String get assistantChangesTitle;

  /// Заголовок предупреждений dry-run preflight
  ///
  /// In ru, this message translates to:
  /// **'Стоит знать'**
  String get assistantWarningsTitle;

  /// Семантическая подпись мини-рендера
  ///
  /// In ru, this message translates to:
  /// **'Предпросмотр листа: {side}'**
  String assistantPreviewLabel(Object side);

  /// Количество фото
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} фото} few{{count} фото} many{{count} фото} other{{count} фото}}'**
  String assistantPhotoCount(num count);

  /// Количество листов
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} лист} few{{count} листа} many{{count} листов} other{{count} листа}}'**
  String assistantSheetCount(num count);

  /// Количество кадров
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} кадр} few{{count} кадра} many{{count} кадров} other{{count} кадра}}'**
  String assistantSlotCount(num count);

  /// Быстрый интент: теплее
  ///
  /// In ru, this message translates to:
  /// **'Сделай теплее'**
  String get assistantChipWarmer;

  /// Быстрый интент: ярче
  ///
  /// In ru, this message translates to:
  /// **'Ярче'**
  String get assistantChipBrighter;

  /// Быстрый интент: чёрно-белое
  ///
  /// In ru, this message translates to:
  /// **'Ч/б'**
  String get assistantChipMono;

  /// Быстрый интент: заполнить пустые кадры
  ///
  /// In ru, this message translates to:
  /// **'Заполни пустые места'**
  String get assistantChipFill;

  /// Быстрый интент: плотнее по листам
  ///
  /// In ru, this message translates to:
  /// **'Плотнее'**
  String get assistantChipDenser;

  /// Быстрый интент: кадры по центру
  ///
  /// In ru, this message translates to:
  /// **'Выровняй кадры'**
  String get assistantChipAlign;

  /// Строка изменений: тон
  ///
  /// In ru, this message translates to:
  /// **'Свет и цвет: {details}'**
  String assistantChangeTone(Object details);

  /// Строка изменений: пресет
  ///
  /// In ru, this message translates to:
  /// **'Стиль: {details}'**
  String assistantChangeLook(Object details);

  /// Строка изменений: кадр
  ///
  /// In ru, this message translates to:
  /// **'Кадрирование: {details}'**
  String assistantChangeFraming(Object details);

  /// Строка изменений: назначение фото
  ///
  /// In ru, this message translates to:
  /// **'Фото в кадрах: {details}'**
  String assistantChangeAssign(Object details);

  /// Строка изменений: замена фото
  ///
  /// In ru, this message translates to:
  /// **'Замена фото: {details}'**
  String assistantChangeReplace(Object details);

  /// Строка изменений: кадр становится пустым
  ///
  /// In ru, this message translates to:
  /// **'Фото убирается: {details}'**
  String assistantChangeClearSlot(Object details);

  /// Строка изменений: фон
  ///
  /// In ru, this message translates to:
  /// **'Цвет листа: {details}'**
  String assistantChangeBackground(Object details);

  /// Строка изменений: раскладка листа
  ///
  /// In ru, this message translates to:
  /// **'Шаблон листа: {details}'**
  String assistantChangeLayout(Object details);

  /// Строка изменений: обмен кадров
  ///
  /// In ru, this message translates to:
  /// **'Обмен фото: {details}'**
  String assistantChangeSwap(Object details);

  /// Сколько строк списка изменений скрыто
  ///
  /// In ru, this message translates to:
  /// **'и ещё {count}'**
  String assistantChangeMore(Object count);

  /// Неизвестный параметр регулировки
  ///
  /// In ru, this message translates to:
  /// **'Другое'**
  String get assistantAdjustOther;

  /// Ползунок контраста
  ///
  /// In ru, this message translates to:
  /// **'Контраст'**
  String get editorAdjustContrast;

  /// Ползунок оттенка
  ///
  /// In ru, this message translates to:
  /// **'Оттенок'**
  String get editorAdjustTint;

  /// Ползунок насыщенности
  ///
  /// In ru, this message translates to:
  /// **'Насыщенность'**
  String get editorAdjustSaturation;

  /// Ползунок сочности
  ///
  /// In ru, this message translates to:
  /// **'Сочность'**
  String get editorAdjustVibrance;

  /// Объявление результата для скринридера
  ///
  /// In ru, this message translates to:
  /// **'{intent}: изменений — {count}'**
  String assistantResultReady(Object count, Object intent);

  /// AI выключен в сборке или на сервере
  ///
  /// In ru, this message translates to:
  /// **'Свободные запросы сейчас недоступны'**
  String get assistantDisabled;

  /// Пятый таб: лента готовых шаблонов
  ///
  /// In ru, this message translates to:
  /// **'Идеи'**
  String get navIdeas;

  /// Заголовок ленты идей
  ///
  /// In ru, this message translates to:
  /// **'Идеи'**
  String get inspirationTitle;

  /// Сброс фильтра тегов
  ///
  /// In ru, this message translates to:
  /// **'Все'**
  String get inspirationTagAll;

  /// Выйти из пустого фильтра к полной ленте
  ///
  /// In ru, this message translates to:
  /// **'Показать все идеи'**
  String get inspirationShowAll;

  /// Показать только сохранённые идеи
  ///
  /// In ru, this message translates to:
  /// **'Избранное'**
  String get inspirationFilterFavorites;

  /// Семантическая подпись строки чипов
  ///
  /// In ru, this message translates to:
  /// **'Фильтр по тегам'**
  String get inspirationTagBarLabel;

  /// Карточка идей — один элемент для скринридера
  ///
  /// In ru, this message translates to:
  /// **'Шаблон: {title}, {count, plural, one{{count} фото} few{{count} фото} many{{count} фото} other{{count} фото}}'**
  String inspirationCardLabel(String title, int count);

  /// Описание локально нарисованного превью
  ///
  /// In ru, this message translates to:
  /// **'Макет шаблона «{title}», {count, plural, one{{count} фото} few{{count} фото} many{{count} фото} other{{count} фото}}'**
  String inspirationPreviewLabel(String title, int count);

  /// Семантика сердечка: ещё не сохранено
  ///
  /// In ru, this message translates to:
  /// **'Сохранить «{title}» в избранное'**
  String inspirationSaveTitle(String title);

  /// Семантика сердечка: уже сохранено
  ///
  /// In ru, this message translates to:
  /// **'Убрать «{title}» из избранного'**
  String inspirationRemoveTitle(String title);

  /// Кнопка сохранения на экране детали
  ///
  /// In ru, this message translates to:
  /// **'В избранное'**
  String get inspirationSaveToFavorites;

  /// Кнопка на экране детали, идея уже сохранена
  ///
  /// In ru, this message translates to:
  /// **'В избранном'**
  String get inspirationRemoveFromFavorites;

  /// Избранное не сохранилось, состояние откатили
  ///
  /// In ru, this message translates to:
  /// **'Не удалось обновить избранное. Проверьте связь и попробуйте ещё раз.'**
  String get inspirationFavoriteFailed;

  /// Пустое избранное
  ///
  /// In ru, this message translates to:
  /// **'Здесь пока пусто'**
  String get inspirationEmptyFavoritesTitle;

  /// Как пополняется избранное
  ///
  /// In ru, this message translates to:
  /// **'Сохраняйте идеи — они появятся здесь'**
  String get inspirationEmptyFavoritesBody;

  /// Тег без идей
  ///
  /// In ru, this message translates to:
  /// **'Ничего не нашлось'**
  String get inspirationEmptyTagTitle;

  /// Что сделать при пустом теге
  ///
  /// In ru, this message translates to:
  /// **'Попробуйте другой тег или покажите все идеи'**
  String get inspirationEmptyTagBody;

  /// Сервер не вернул ни одной идеи
  ///
  /// In ru, this message translates to:
  /// **'Идей пока нет'**
  String get inspirationEmptyTitle;

  /// Пустая лента без фильтра
  ///
  /// In ru, this message translates to:
  /// **'Шаблоны появятся здесь, как только сервер их отдаст'**
  String get inspirationEmptyBody;

  /// Скелетон ленты
  ///
  /// In ru, this message translates to:
  /// **'Загружаем идеи'**
  String get inspirationLoading;

  /// Следующая страница ленты
  ///
  /// In ru, this message translates to:
  /// **'Показать ещё'**
  String get inspirationLoadMore;

  /// Следующая страница не загрузилась
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить ещё. Попробуйте ещё раз.'**
  String get inspirationLoadMoreFailed;

  /// Заголовок экрана детали
  ///
  /// In ru, this message translates to:
  /// **'Идея'**
  String get inspirationDetailTitle;

  /// Форматы, которые поддерживают шаблон
  ///
  /// In ru, this message translates to:
  /// **'Подходит для: {formats}'**
  String inspirationSupportsLabel(String formats);

  /// Сервер не назвал ни одного формата
  ///
  /// In ru, this message translates to:
  /// **'Этот шаблон пока не подходит ни одному формату'**
  String get inspirationNoSupports;

  /// Применить шаблон к проекту
  ///
  /// In ru, this message translates to:
  /// **'Применить'**
  String get inspirationApply;

  /// Применение шаблона в процессе
  ///
  /// In ru, this message translates to:
  /// **'Применяем…'**
  String get inspirationApplying;

  /// Заголовок диалога о несовместимости
  ///
  /// In ru, this message translates to:
  /// **'Шаблон не подошёл'**
  String get inspirationApplyProblemTitle;

  /// Формат проекта не разрешает шаблон
  ///
  /// In ru, this message translates to:
  /// **'Этот шаблон не подходит для формата открытого проекта. Выберите другой шаблон.'**
  String get inspirationApplyNotSupported;

  /// Слотов больше, чем фото в проекте
  ///
  /// In ru, this message translates to:
  /// **'В шаблоне {slots} кадров, а в проекте {photos} фото. Добавьте фото или выберите шаблон по количеству снимков.'**
  String inspirationApplyNotEnoughPhotos(int slots, int photos);

  /// Команда SetLayout отказала
  ///
  /// In ru, this message translates to:
  /// **'Не удалось разложить фото по шаблону. Попробуйте ещё раз.'**
  String get inspirationApplyCommandFailed;

  /// Каталог не отдал формат из детали
  ///
  /// In ru, this message translates to:
  /// **'Подходящий формат сейчас недоступен. Проверьте связь и попробуйте ещё раз.'**
  String get inspirationApplyNoFormat;

  /// Подтверждение после применения
  ///
  /// In ru, this message translates to:
  /// **'Шаблон применён'**
  String get inspirationApplyReady;

  /// Сетевая ошибка применения
  ///
  /// In ru, this message translates to:
  /// **'Не удалось применить шаблон. Проверьте связь и попробуйте ещё раз.'**
  String get inspirationApplyFailed;

  /// Тег «семья»
  ///
  /// In ru, this message translates to:
  /// **'Семья'**
  String get inspirationTagFamily;

  /// Тег «свадьба»
  ///
  /// In ru, this message translates to:
  /// **'Свадьба'**
  String get inspirationTagWedding;

  /// Тег «выпускной»
  ///
  /// In ru, this message translates to:
  /// **'Выпускной'**
  String get inspirationTagGraduation;

  /// Тег «путешествие»
  ///
  /// In ru, this message translates to:
  /// **'Путешествие'**
  String get inspirationTagTravel;

  /// Тег «минимализм»
  ///
  /// In ru, this message translates to:
  /// **'Минимализм'**
  String get inspirationTagMinimal;

  /// Тег «детское»
  ///
  /// In ru, this message translates to:
  /// **'Детское'**
  String get inspirationTagKids;

  /// Название шаблона: два фото
  ///
  /// In ru, this message translates to:
  /// **'Две истории'**
  String get inspirationTemplateDuoSplit;

  /// Название шаблона: три фото
  ///
  /// In ru, this message translates to:
  /// **'Большой кадр и два маленьких'**
  String get inspirationTemplateTrioHero;

  /// Название шаблона: четыре фото сеткой
  ///
  /// In ru, this message translates to:
  /// **'Сетка 2×2'**
  String get inspirationTemplateQuadGrid;

  /// Название шаблона: полароид 10×15
  ///
  /// In ru, this message translates to:
  /// **'Полароид'**
  String get inspirationTemplatePolaroid;

  /// Название шаблона: панорамный кадр
  ///
  /// In ru, this message translates to:
  /// **'Панорама'**
  String get inspirationTemplatePanorama;

  /// Название шаблона: три полосы
  ///
  /// In ru, this message translates to:
  /// **'Три кадра в столбик'**
  String get inspirationTemplateStrip3;

  /// Название шаблона: полароид 15×20
  ///
  /// In ru, this message translates to:
  /// **'Большой полароид'**
  String get inspirationTemplatePolaroidLarge;

  /// Название шаблона: панорама 15×20
  ///
  /// In ru, this message translates to:
  /// **'Широкая панорама'**
  String get inspirationTemplatePanoramaWide;

  /// Название шаблона: разворот целиком
  ///
  /// In ru, this message translates to:
  /// **'Одно фото на разворот'**
  String get inspirationTemplateBookSingle;

  /// Название шаблона: две страницы
  ///
  /// In ru, this message translates to:
  /// **'Два фото на разворот'**
  String get inspirationTemplateBookDuo;

  /// Название шаблона: три фото на развороте
  ///
  /// In ru, this message translates to:
  /// **'Разворот с акцентом'**
  String get inspirationTemplateBookTrio;

  /// Название шаблона: четыре фото на развороте
  ///
  /// In ru, this message translates to:
  /// **'Разворот 2×2'**
  String get inspirationTemplateBookQuad;

  /// Название шаблона: шесть фото на развороте
  ///
  /// In ru, this message translates to:
  /// **'Шесть фото на разворот'**
  String get inspirationTemplateBookSix;

  /// Название шаблона: панорама на развороте
  ///
  /// In ru, this message translates to:
  /// **'Панорама на разворот'**
  String get inspirationTemplateBookPanorama;

  /// Неизвестный ключ названия шаблона
  ///
  /// In ru, this message translates to:
  /// **'Шаблон'**
  String get inspirationTemplateFallback;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['be', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'be':
      return AppLocalizationsBe();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
