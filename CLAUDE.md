# SimpleQibla

**Dil: Kullanıcıyla her zaman Türkçe konuş.**

Basit Kıble uygulaması: iOS uygulaması + ona gömülü watchOS uygulaması (SwiftUI).

## Diller

- Ana dil **İngilizce** (`developmentRegion = en`, App Store Connect'te Primary Language: English (U.S.)).
- Desteklenen diller: **İngilizce, Türkçe, Arapça**. Bu her şey için geçerli: uygulama metinleri (`Shared/Localizable.xcstrings`, `InfoPlist.xcstrings`), App Store metadata'sı ve **screenshot'lar** (her dil için ayrı set; Arapça sağdan sola).
- Yeni metin eklerken üç dili birlikte doldur.

## App Store Connect

- Hesap: kişisel (`~/.appstoreconnect/sportakal.json`, takım `QHH678M674`).
- Kayıt: **"Simplest Qibla Finder"**, Apple ID `6824687465`, primary locale `en-US`. ("Simple Qibla" ve "Simple Qibla Finder" adları alınmıştı.) Ana ekran adı (`CFBundleDisplayName`) da "Simplest Qibla Finder" (tr: "En Basit Kıble Bulucu", ar: "أبسط محدد للقبلة"); `INFOPLIST_KEY_CFBundleDisplayName` ve iki `InfoPlist.xcstrings` birlikte güncellenmeli.
- Uygulama **yalnızca iPhone** (`TARGETED_DEVICE_FAMILY = 1`) + Apple Watch. iPad açılırsa Apple dört yönü de ister (multitasking) ve iPad screenshot'ları gerekir.
- Her yüklemede `CURRENT_PROJECT_VERSION` (build) artırılmalı; dört build ayarında (iOS + Watch, Debug + Release) aynı değer olmalı.
- Yükleme (API anahtarıyla):
  ```sh
  xcodebuild -exportArchive -archivePath <arşiv> -exportPath <çıktı> -exportOptionsPlist <method=app-store-connect, destination=upload, teamID=QHH678M674> \
    -allowProvisioningUpdates -authenticationKeyPath ~/.appstoreconnect/private_keys/AuthKey_8KBZT2QGWX.p8 \
    -authenticationKeyID 8KBZT2QGWX -authenticationKeyIssuerID 0e7b3920-f6f8-444b-9878-8f72e5157574
  ```

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
