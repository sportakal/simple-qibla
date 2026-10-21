# SimpleQibla

**Dil: Kullanıcıyla her zaman Türkçe konuş.**

Basit Kıble uygulaması: iOS uygulaması + ona gömülü watchOS uygulaması (SwiftUI).

## Diller

- Ana dil **İngilizce** (`developmentRegion = en`, App Store Connect'te Primary Language: English (U.S.)).
- Desteklenen diller: **İngilizce, Türkçe, Arapça**. Bu her şey için geçerli: uygulama metinleri (`Shared/Localizable.xcstrings`, `InfoPlist.xcstrings`), App Store metadata'sı ve **screenshot'lar** (her dil için ayrı set; Arapça sağdan sola).
- Yeni metin eklerken üç dili birlikte doldur.

## App Store Connect

- Hesap: kişisel (`~/.appstoreconnect/sportakal.json`, takım `QHH678M674`).
- Kayıt: **"Simplest Qibla Finder"**, Apple ID `6824687465`, primary locale `en-US`. ("Simple Qibla" ve "Simple Qibla Finder" adları alınmıştı.) Ana ekran adı (`CFBundleDisplayName`) ana ekranda kesilmesin diye en fazla 12 karakter: "Simple Qibla" (tr: "Kolay Kıble", ar: "محدد القبلة"); `INFOPLIST_KEY_CFBundleDisplayName` ve iki `InfoPlist.xcstrings` birlikte güncellenmeli.
- Uygulama **yalnızca iPhone** (`TARGETED_DEVICE_FAMILY = 1`) + Apple Watch. iPad açılırsa Apple dört yönü de ister (multitasking) ve iPad screenshot'ları gerekir.
- **iPhone Duo** (katlanabilir, 1.1'den beri): iç ekran (2007×2853) iPad gibi `regular/regular` boyut sınıfındadır ve uygulamanın dikey kilidini **dikkate almaz**; uygulama yatay da açılabilir. Bu yüzden pusula yönü `InterfaceOrientationReader` ile arayüz yönüne göre düzeltilir (`CLLocationManager.headingOrientation`); düzeltilmezse harita/ok 90° yanlış döner. Geniş ekranda kartlar solda dar sütunda, düğmeler sağ kenarda durur.
- Build numarasına (`CURRENT_PROJECT_VERSION`) elle dokunma; yükleme sırasında otomatik artırılıyor. Ama ayarı **silme**: Xcode yalnızca var olan değeri artırır, ayar yoksa yükleme "CFBundleVersion is empty" hatasıyla düşer.
- Export compliance: `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` ("None of the algorithms mentioned above"), dört build ayarında da tanımlı.
- Yükleme (API anahtarıyla):
  ```sh
  xcodebuild -exportArchive -archivePath <arşiv> -exportPath <çıktı> -exportOptionsPlist <method=app-store-connect, destination=upload, teamID=QHH678M674> \
    -allowProvisioningUpdates -authenticationKeyPath ~/.appstoreconnect/private_keys/AuthKey_8KBZT2QGWX.p8 \
    -authenticationKeyID 8KBZT2QGWX -authenticationKeyIssuerID 0e7b3920-f6f8-444b-9878-8f72e5157574
  ```

## Mağaza içeriği

- Metinler: `fastlane/metadata/<en-US|tr|ar-SA>/` (git'te). Gizlilik/destek: depodaki `PRIVACY.md` ve `SUPPORT.md` (GitHub adresleri mağazada kayıtlı). Uygulama reklamsız ve takipsiz; App Privacy: "Data Not Collected".
- Screenshot'lar: `fastlane/screenshots/` (git dışı). Her dilde 4 iPhone (6.9", 1290×2796) + 2 Apple Watch; ayrıca 4 iPhone Duo iç ekran (2853×2007 yatay, ayrı klasörde, aşağıya bak).
  - Mekânlar, **ekseni hesaplanan kıbleyle örtüşen** camiler (OSM bina çizimlerinden ölçüldü): tr **Büyük Çamlıca Camii** (`41.034134,29.070432`, 151,87°), en **London Central Mosque** (`51.528846,-0.164756`, 118,97°), ar **Sultan Hasan Camii** şadırvanı (`30.032271,31.256208`, 136,17°). Klasik camilerin çoğu sapar (Sultanahmet ~18°, Süleymaniye ~14°, Ezher ~11°); onları kullanma, ekranda çizgi binayla çapraz durur.
  - Debug açılış parametreleri: `-DemoHeading <derece>` (sabit pusula yönü; hizalı kare için kıble açısının kendisi, "dönün" karesi için 35° eksiği), `-DemoCompass YES`, `-DemoKaaba YES`; dil için `-AppleLanguages "(tr)"`. Konum: `xcrun simctl location <cihaz> set <lat,lon>`.
  - iPhone Duo simülatörü iOS 27.1 runtime ister. Açma/katlama yalnızca Device Hub arayüzünden yapılır (simctl'de komut yok); iç ekranı `xcrun simctl io <cihaz> screenshot --display=3` ile çek.
  - fastlane 2.228 Duo boyutlarını tanımaz; Duo seti (`fastlane/screenshots_duo/<dil>/`, git dışı) ASC API'sinde `APP_IPHONE_DUO` görüntü türüyle (Spaceship ile) ayrıca yüklenir. `fastlane/screenshots` içine Duo dosyası koyma, deliver reddeder.
  - Arapça saat ekranları için simülatörün sistem dili de Arapça olmalı, yoksa üstteki yazı saatle çakışır.
- Yükleme: `fastlane deliver --api_key_path ~/.appstoreconnect/sportakal.json --app_identifier com.sportakal.simpleQibla --metadata_path fastlane/metadata --screenshots_path fastlane/screenshots --skip_binary_upload true --overwrite_screenshots true --force true`

## Signing ve bundle ID'ler

| Target | Team | Bundle ID |
|---|---|---|
| SimpleQibla (iOS) | `QHH678M674` | `com.sportakal.simpleQibla` |
| SimpleQibla Watch App | `QHH678M674` | `com.sportakal.simpleQibla.watchkitapp` |

- İki target da **aynı team** ile imzalanmalı; aksi halde archive şu hatayla düşer:
  "Embedded binary is not signed with the same certificate as the parent app."
- Watch bundle ID'si, iOS bundle ID'siyle başlamalı.
- Watch target'taki `INFOPLIST_KEY_WKCompanionAppBundleIdentifier` iOS bundle ID'sine eşit olmalı.
- Signing/bundle ID değiştirirken **iki target'ı da** (Debug + Release) birlikte güncelle.
- Eski değerler: team `LAAJA73AL8`, bundle ID `com.sportakal.qibla` (artık kullanılmıyor).

## Archive (komut satırı)

```sh
xcodebuild -project SimpleQibla.xcodeproj -scheme SimpleQibla -configuration Release \
  -destination 'generic/platform=iOS' -archivePath <yol>/SimpleQibla.xcarchive \
  -allowProvisioningUpdates archive
```
