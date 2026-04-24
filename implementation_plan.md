# VTYS Dönem Projesi — Oto Yedek Parça Şirketi

Hayali şirket: **OtoParça A.Ş.** — Araç yedek parça satış ve stok yönetim sistemi.  
Veritabanı MS SQL Server üzerinde tasarlanacak; arayüz olarak **Python Flask** web uygulaması kullanılacak.

## Kullanıcıdan Onay Beklenen Noktalar

> [!IMPORTANT]
> Devam etmeden önce aşağıdaki 3 soruyu yanıtlamanız gerekmektedir.
> 1. **Bilgisayarınızda Python yüklü mü?** (Arayüz için Python Flask kullanılacak — `pip install flask pyodbc` yeterli)
> 2. **SQL Server hangi sürümünü kullanıyorsunuz?** (2019 / 2022 / Express?)
> 3. **SQL Server instance adınız nedir?** (Genellikle `localhost` veya `.\SQLEXPRESS` gibi bir şey)

---

## Veritabanı Şeması — 7 Tablo

```
Kategori ──< Urun >── Tedarikci
              │
Musteri ──< Siparis >── SiparisDetay >── Urun
                                  │
                           Stok_Hareketleri (Trigger ile otomatik dolar)
```

### Tablolar

| # | Tablo | Açıklama |
|---|-------|----------|
| 1 | `Kategori` | Yedek parça kategorileri (Fren, Motor, Elektrik…) |
| 2 | `Tedarikci` | Parça tedarikçi firmaları |
| 3 | `Musteri` | Müşteri bilgileri |
| 4 | `Urun` | Yedek parçalar (stok, fiyat, KategoriID, TedarikciID FK) |
| 5 | `Siparis` | Sipariş başlıkları (MusteriID FK, durum, tarih) |
| 6 | `SiparisDetay` | Sipariş satırları (SiparisID + UrunID FK, miktar, fiyat) |
| 7 | `StokHareketleri` | Stok giriş/çıkış logu (Trigger ile otomatik dolar) |

### Kısıtlamalar
- Her tabloda `PK` (IDENTITY)
- Tablolar arası `FK` ilişkileri
- `CHECK`: Fiyat > 0, Stok >= 0, Sipariş durumu IN ('Beklemede','Hazırlanıyor','Kargoda','Teslim Edildi','İptal')
- `DEFAULT`: SiparisTarihi = GETDATE(), Durum = 'Beklemede', StokMiktari = 0
- `NOT NULL`: Zorunlu tüm alanlar

---

## Dosya Yapısı

```
VTYSsqlÖdev/
├── sql/
│   ├── 01_create_database.sql     ← Veritabanı + Tablolar + Kısıtlamalar
│   ├── 02_insert_data.sql         ← Örnek veriler
│   ├── 03_dml_operations.sql      ← INSERT / UPDATE / DELETE örnekleri
│   ├── 04_views.sql               ← VIEW tanımları
│   ├── 05_stored_procedures.sql   ← Stored Procedure'ler
│   └── 06_triggers.sql            ← Trigger tanımları
└── OtoYedekParca_App/
    ├── app.py                     ← Flask uygulaması
    ├── requirements.txt
    ├── templates/
    │   ├── base.html
    │   ├── index.html             ← Ana ekran + bağlantı göstergesi
    │   ├── musteriler.html        ← Müşteri CRUD
    │   ├── urunler.html           ← Ürün CRUD
    │   ├── siparisler.html        ← Sipariş yönetimi
    │   └── raporlar.html          ← 3+ otomatik rapor (VIEW/SP'den)
    └── static/
        └── css/style.css
```

---

## Programlanabilir Nesneler

### VIEW — `vw_SiparisDetayli`
Müşteri adı + ürün adı + sipariş durumu + tutar — `Siparis`, `SiparisDetay`, `Musteri`, `Urun` tablolarını JOIN'ler.

### VIEW — `vw_StokDurumu`
Her ürünün adı, kategorisi, mevcut stok ve toplam satış adedi.

### Stored Procedure — `sp_MusteriSiparisleri`
Parametre: `@MusteriID INT` → O müşteriye ait tüm siparişleri döndürür.

### Stored Procedure — `sp_EnCokSatanUrunler`
Parametre: `@TopN INT` → En çok satılan N ürünü listeler (raporlar sayfasında kullanılır).

### Trigger — `trg_StokGuncelle`
`SiparisDetay` tablosuna INSERT sonrası otomatik:
1. `Urun.StokMiktari` günceller (azaltır)
2. `StokHareketleri` tablosuna log kaydı ekler

---

## Arayüz Uygulama Özellikleri

### Ana Ekran (`index.html`)
- 🟢 **Canlı Bağlantı Göstergesi**: SQL Server'a bağlantı durumu (AKTIF / HATA)
- Özet istatistikler: Toplam Ürün, Müşteri, Sipariş sayısı (kartlar)
- Navigasyon menüsü

### Raporlar Sayfası (otomatik yükleme — 15 puan)
1. **Rapor 1**: En Çok Satan 5 Ürün (`sp_EnCokSatanUrunler` SP'den)
2. **Rapor 2**: Aylık Sipariş & Ciro Özeti (`vw_SiparisDetayli` VIEW'den)
3. **Rapor 3**: Stok Kritik Seviye Uyarıları — Stok < 5 olan ürünler (`vw_StokDurumu` VIEW'den)

### Yönetim Sayfaları
- Müşteriler: Listeleme, Ekleme, Güncelleme, Silme (canlı demo için)
- Ürünler: Listeleme + Form
- Siparişler: Listeleme + Durum güncelleme

---

## Doğrulama Planı

### SQL Testleri (SSMS'de)
1. `01_create_database.sql` çalıştır → Tüm tablolar oluşmalı
2. `02_insert_data.sql` çalıştır → Veriler gelmeli
3. Trigger testi: `SiparisDetay`'a INSERT → `StokHareketleri` otomatik dolar
4. SP testi: `EXEC sp_MusteriSiparisleri @MusteriID = 1`
5. VIEW testi: `SELECT * FROM vw_SiparisDetayli`

### Uygulama Testleri
1. `pip install flask pyodbc` sonrası `python app.py` çalıştır
2. `http://localhost:5000` → Bağlantı göstergesi AKTIF görünmeli
3. Raporlar sayfası açıldığında 3 rapor otomatik yüklenli
4. Müşteri ekleme/güncelleme/silme demosu
