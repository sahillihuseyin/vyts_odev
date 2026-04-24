-- ============================================================
-- OtoParça A.Ş. – DML OPERASYONLARI (INSERT / UPDATE / DELETE)
-- Sunum sırasında canlı demo için bu dosyayı kullanın.
-- ============================================================

USE OtoYedekParcaDB;
GO

PRINT '============================================================';
PRINT '   DML DEMO — INSERT / UPDATE / DELETE İşlemleri';
PRINT '============================================================';
GO

-- ============================================================
-- ► BÖLÜM 1: INSERT – Yeni Kayıt Ekleme
-- ============================================================

-- 1A. Yeni müşteri ekleme
PRINT '>> INSERT: Yeni müşteri ekleniyor...';

INSERT INTO Musteri (AdSoyad, Email, Telefon, Adres)
VALUES ('Kadir Polat', 'kadir.polat@gmail.com', '05551239876', 'Sultangazi / İstanbul');

SELECT * FROM Musteri WHERE Email = 'kadir.polat@gmail.com';
GO

-- 1B. Yeni ürün ekleme
PRINT '>> INSERT: Yeni ürün (yedek parça) ekleniyor...';

INSERT INTO Urun (KategoriID, TedarikciID, UrunAdi, UrunKodu, AracModeli, StokMiktari, AlisFiyati, SatisFiyati)
VALUES (1, 1, 'Arka Fren Balatası Premium', 'FRN-003', 'Mercedes C-Serisi W205', 20, 250.00, 450.00);

SELECT * FROM Urun WHERE UrunKodu = 'FRN-003';
GO

-- 1C. Yeni sipariş ve sipariş detayı ekleme
PRINT '>> INSERT: Yeni sipariş oluşturuluyor...';

INSERT INTO Siparis (MusteriID, TeslimTarihi, Durum, Notlar)
VALUES (
    (SELECT MusteriID FROM Musteri WHERE Email = 'kadir.polat@gmail.com'),
    DATEADD(DAY, 3, CAST(GETDATE() AS DATE)),
    'Beklemede',
    'Demo siparişi — INSERT testi'
);

DECLARE @YeniSiparisID INT = SCOPE_IDENTITY();
PRINT '   Oluşturulan SiparisID: ' + CAST(@YeniSiparisID AS VARCHAR);

INSERT INTO SiparisDetay (SiparisID, UrunID, Miktar, BirimFiyat)
VALUES
    (@YeniSiparisID, 1,  2, 320.00),
    (@YeniSiparisID, 12, 3,  65.00);

-- ToplamTutar güncelle
UPDATE Siparis
SET ToplamTutar = (
    SELECT ISNULL(SUM(AraToplam), 0)
    FROM SiparisDetay sd
    WHERE sd.SiparisID = @YeniSiparisID
)
WHERE SiparisID = @YeniSiparisID;

SELECT s.SiparisID, m.AdSoyad, s.Durum, s.ToplamTutar
FROM Siparis s
JOIN Musteri m ON s.MusteriID = m.MusteriID
WHERE s.SiparisID = @YeniSiparisID;
GO

-- ============================================================
-- ► BÖLÜM 2: UPDATE – Mevcut Kayıt Güncelleme
-- ============================================================
PRINT '>> UPDATE: Sipariş durumu güncelleniyor (Beklemede → Hazırlanıyor)...';

-- Kadir Polat'ın en son siparişini güncelle
UPDATE Siparis
SET Durum = 'Hazırlanıyor'
WHERE MusteriID = (SELECT MusteriID FROM Musteri WHERE Email = 'kadir.polat@gmail.com')
  AND Durum = 'Beklemede';

SELECT SiparisID, MusteriID, Durum, ToplamTutar
FROM Siparis
WHERE MusteriID = (SELECT MusteriID FROM Musteri WHERE Email = 'kadir.polat@gmail.com');
GO

PRINT '>> UPDATE: Ürün satış fiyatı güncelleniyor...';

UPDATE Urun
SET SatisFiyati = SatisFiyati * 1.10  -- %10 zam
WHERE UrunKodu = 'FRN-003';

SELECT UrunKodu, UrunAdi, SatisFiyati FROM Urun WHERE UrunKodu = 'FRN-003';
GO

PRINT '>> UPDATE: Müşteri telefon numarası güncelleniyor...';

UPDATE Musteri
SET Telefon = '05559991122',
    Adres   = 'Eyüpsultan / İstanbul'
WHERE Email = 'kadir.polat@gmail.com';

SELECT AdSoyad, Email, Telefon, Adres FROM Musteri WHERE Email = 'kadir.polat@gmail.com';
GO

-- ============================================================
-- ► BÖLÜM 3: DELETE – Kayıt Silme
-- ============================================================
PRINT '>> DELETE: Demo siparişinin detayları siliniyor...';

-- Önce SiparisDetay silinmeli (FK kısıtı)
DELETE FROM SiparisDetay
WHERE SiparisID = (
    SELECT s.SiparisID FROM Siparis s
    JOIN Musteri m ON s.MusteriID = m.MusteriID
    WHERE m.Email = 'kadir.polat@gmail.com'
);

PRINT '>> DELETE: Demo siparişi siliniyor...';

DELETE FROM Siparis
WHERE MusteriID = (SELECT MusteriID FROM Musteri WHERE Email = 'kadir.polat@gmail.com');

PRINT '>> DELETE: Demo müşterisi siliniyor...';

DELETE FROM Musteri
WHERE Email = 'kadir.polat@gmail.com';

-- Silme sonrası doğrulama
SELECT COUNT(*) AS [Kalan Musteri Sayisi] FROM Musteri;
GO

PRINT '============================================================';
PRINT '✅ DML İşlemleri tamamlandı: INSERT ✓  UPDATE ✓  DELETE ✓';
PRINT '============================================================';
GO
