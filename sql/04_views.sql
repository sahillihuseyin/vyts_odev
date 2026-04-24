-- ============================================================
-- OtoParça A.Ş. – VIEW TANIMLARI
-- En az 3 VIEW; birden fazla tablo birleştiriyor.
-- Sunum sırasında VIEW'ları SELECT ile sorgulayın.
-- ============================================================

USE OtoYedekParcaDB;
GO

-- ============================================================
-- VIEW 1: vw_SiparisDetayli
-- Sipariş + Sipariş Detay + Müşteri + Ürün + Kategori
-- Tam sipariş raporu — raporlar ekranında kullanılır
-- ============================================================
IF OBJECT_ID('dbo.vw_SiparisDetayli', 'V') IS NOT NULL
    DROP VIEW dbo.vw_SiparisDetayli;
GO

CREATE VIEW dbo.vw_SiparisDetayli AS
SELECT
    s.SiparisID,
    s.SiparisTarihi,
    s.TeslimTarihi,
    s.Durum                                        AS SiparisDurumu,
    s.ToplamTutar,
    m.MusteriID,
    m.AdSoyad                                      AS MusteriAdi,
    m.Email                                        AS MusteriEmail,
    m.Telefon                                      AS MusteriTelefon,
    sd.DetayID,
    u.UrunID,
    u.UrunAdi,
    u.UrunKodu,
    u.OemKodu,
    k.KategoriAdi,
    sd.Miktar,
    sd.BirimFiyat,
    sd.AraToplam,
    u.AracModeli
FROM Siparis s
    INNER JOIN Musteri      m  ON s.MusteriID  = m.MusteriID
    INNER JOIN SiparisDetay sd ON sd.SiparisID = s.SiparisID
    INNER JOIN Urun         u  ON sd.UrunID    = u.UrunID
    INNER JOIN Kategori     k  ON u.KategoriID = k.KategoriID;
GO

-- Test
-- SELECT * FROM vw_SiparisDetayli ORDER BY SiparisID;

-- ============================================================
-- VIEW 2: vw_StokDurumu
-- Ürün + Kategori + Tedarikçi — Stok analizi raporu
-- Kritik stok uyarısı için de kullanılır (StokMiktari < 5)
-- ============================================================
IF OBJECT_ID('dbo.vw_StokDurumu', 'V') IS NOT NULL
    DROP VIEW dbo.vw_StokDurumu;
GO

CREATE VIEW dbo.vw_StokDurumu AS
SELECT
    u.UrunID,
    u.UrunKodu,
    u.OemKodu,
    u.UrunAdi,
    u.AracModeli,
    k.KategoriAdi,
    t.FirmaAdi                                     AS TedarikciAdi,
    u.StokMiktari,
    u.AlisFiyati,
    u.SatisFiyati,
    (u.SatisFiyati - u.AlisFiyati)                 AS KarMarji,
    CASE
        WHEN u.StokMiktari = 0   THEN 'Tükendi'
        WHEN u.StokMiktari < 5   THEN 'Kritik'
        WHEN u.StokMiktari < 15  THEN 'Düşük'
        ELSE                          'Yeterli'
    END                                            AS StokDurumu,
    ISNULL(satis.ToplamSatisAdedi, 0)              AS ToplamSatisAdedi
FROM Urun u
    INNER JOIN Kategori  k ON u.KategoriID  = k.KategoriID
    INNER JOIN Tedarikci t ON u.TedarikciID = t.TedarikciID
    LEFT  JOIN (
        SELECT UrunID, SUM(Miktar) AS ToplamSatisAdedi
        FROM SiparisDetay
        GROUP BY UrunID
    ) satis ON satis.UrunID = u.UrunID;
GO

-- Test
-- SELECT * FROM vw_StokDurumu ORDER BY StokMiktari;

-- ============================================================
-- VIEW 3: vw_AylikCiroOzeti
-- Aylık sipariş sayısı ve ciro — yönetim raporu
-- ============================================================
IF OBJECT_ID('dbo.vw_AylikCiroOzeti', 'V') IS NOT NULL
    DROP VIEW dbo.vw_AylikCiroOzeti;
GO

CREATE VIEW dbo.vw_AylikCiroOzeti AS
SELECT
    YEAR(s.SiparisTarihi)                              AS Yil,
    MONTH(s.SiparisTarihi)                             AS Ay,
    DATENAME(MONTH, s.SiparisTarihi)                   AS AyAdi,
    COUNT(DISTINCT s.SiparisID)                        AS SiparisSayisi,
    SUM(sd.AraToplam)                                  AS ToplamCiro,
    AVG(s.ToplamTutar)                                 AS OrtSiparisTutari,
    COUNT(DISTINCT s.MusteriID)                        AS AktifMusteriSayisi
FROM Siparis s
    INNER JOIN SiparisDetay sd ON sd.SiparisID = s.SiparisID
WHERE s.Durum <> 'İptal'
GROUP BY
    YEAR(s.SiparisTarihi),
    MONTH(s.SiparisTarihi),
    DATENAME(MONTH, s.SiparisTarihi);
GO

-- Test
-- SELECT * FROM vw_AylikCiroOzeti ORDER BY Yil, Ay;

-- ============================================================
-- VIEW 4: vw_SonSiparisler   (arayüz "Son Siparişler" widget)
-- En yeni 20 siparişi gösterir
-- ============================================================
IF OBJECT_ID('dbo.vw_SonSiparisler', 'V') IS NOT NULL
    DROP VIEW dbo.vw_SonSiparisler;
GO

CREATE VIEW dbo.vw_SonSiparisler AS
SELECT TOP 20
    s.SiparisID,
    m.AdSoyad    AS MusteriAdi,
    s.SiparisTarihi,
    s.Durum,
    s.ToplamTutar
FROM Siparis s
    INNER JOIN Musteri m ON s.MusteriID = m.MusteriID
ORDER BY s.SiparisTarihi DESC;
GO

-- ============================================================
-- Tüm VIEW'leri listele
-- ============================================================
SELECT
    TABLE_NAME  AS [View Adı]
FROM INFORMATION_SCHEMA.VIEWS
ORDER BY TABLE_NAME;
GO

PRINT '✅ 4 VIEW başarıyla oluşturuldu:';
PRINT '   • vw_SiparisDetayli';
PRINT '   • vw_StokDurumu';
PRINT '   • vw_AylikCiroOzeti';
PRINT '   • vw_SonSiparisler';
GO
