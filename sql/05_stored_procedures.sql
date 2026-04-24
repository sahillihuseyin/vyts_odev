-- ============================================================
-- OtoParça A.Ş. – STORED PROCEDURE TANIMLARI
-- Parametreli; sunum sırasında EXEC ile canlı çalıştırın.
-- ============================================================

USE OtoYedekParcaDB;
GO

-- ============================================================
-- SP 1: sp_MusteriSiparisleri
-- Belirli bir müşterinin tüm sipariş geçmişini getirir.
-- Parametre: @MusteriID INT
-- ============================================================
IF OBJECT_ID('dbo.sp_MusteriSiparisleri', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_MusteriSiparisleri;
GO

CREATE PROCEDURE dbo.sp_MusteriSiparisleri
    @MusteriID INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Müşteri var mı kontrol et
    IF NOT EXISTS (SELECT 1 FROM Musteri WHERE MusteriID = @MusteriID)
    BEGIN
        PRINT 'HATA: Girilen MusteriID bulunamadı: ' + CAST(@MusteriID AS VARCHAR);
        RETURN;
    END

    -- Müşteri bilgisi
    SELECT
        AdSoyad     AS [Müşteri Adı],
        Email       AS [E-posta],
        Telefon     AS [Telefon],
        KayitTarihi AS [Kayıt Tarihi]
    FROM Musteri
    WHERE MusteriID = @MusteriID;

    -- Sipariş geçmişi
    SELECT
        s.SiparisID         AS [Sipariş No],
        s.SiparisTarihi     AS [Sipariş Tarihi],
        s.TeslimTarihi      AS [Teslim Tarihi],
        s.Durum             AS [Durum],
        s.ToplamTutar       AS [Toplam (₺)],
        COUNT(sd.DetayID)   AS [Kalem Sayısı]
    FROM Siparis s
        LEFT JOIN SiparisDetay sd ON sd.SiparisID = s.SiparisID
    WHERE s.MusteriID = @MusteriID
    GROUP BY s.SiparisID, s.SiparisTarihi, s.TeslimTarihi, s.Durum, s.ToplamTutar
    ORDER BY s.SiparisTarihi DESC;
END
GO

/*  KULLANIM ÖRNEĞİ:
    EXEC sp_MusteriSiparisleri @MusteriID = 1;
*/

-- ============================================================
-- SP 2: sp_EnCokSatanUrunler
-- En çok sipariş edilen N ürünü sıralar.
-- Parametre: @TopN INT (varsayılan 5)
-- ============================================================
IF OBJECT_ID('dbo.sp_EnCokSatanUrunler', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_EnCokSatanUrunler;
GO

CREATE PROCEDURE dbo.sp_EnCokSatanUrunler
    @TopN INT = 5
AS
BEGIN
    SET NOCOUNT ON;

    IF @TopN <= 0 OR @TopN > 100
        SET @TopN = 5;

    SELECT TOP (@TopN)
        u.UrunID,
        u.UrunKodu,
        u.OemKodu,
        u.UrunAdi,
        k.KategoriAdi                         AS Kategori,
        u.SatisFiyati                         AS [Satış Fiyatı (₺)],
        SUM(sd.Miktar)                        AS [Toplam Satış Adedi],
        SUM(sd.AraToplam)                     AS [Toplam Ciro (₺)],
        COUNT(DISTINCT sd.SiparisID)          AS [Sipariş Sayısı]
    FROM SiparisDetay sd
        INNER JOIN Urun     u ON sd.UrunID    = u.UrunID
        INNER JOIN Kategori k ON u.KategoriID = k.KategoriID
    GROUP BY u.UrunID, u.UrunKodu, u.OemKodu, u.UrunAdi, k.KategoriAdi, u.SatisFiyati
    ORDER BY [Toplam Satış Adedi] DESC;
END
GO

/*  KULLANIM ÖRNEĞİ:
    EXEC sp_EnCokSatanUrunler @TopN = 5;
    EXEC sp_EnCokSatanUrunler @TopN = 10;
*/

-- ============================================================
-- SP 3: sp_StokRaporu
-- Stok durumuna göre filtrelenmiş ürün raporu.
-- Parametre: @Durum NVARCHAR(10) → 'Tükendi' / 'Kritik' / 'Hepsi'
-- ============================================================
IF OBJECT_ID('dbo.sp_StokRaporu', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_StokRaporu;
GO

CREATE PROCEDURE dbo.sp_StokRaporu
    @Durum NVARCHAR(10) = 'Hepsi'
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        UrunKodu,
        OemKodu,
        UrunAdi,
        KategoriAdi,
        TedarikciAdi,
        StokMiktari,
        StokDurumu,
        SatisFiyati,
        KarMarji,
        ToplamSatisAdedi
    FROM vw_StokDurumu
    WHERE
        (@Durum = 'Hepsi')
        OR (@Durum = 'Tükendi'  AND StokDurumu = 'Tükendi')
        OR (@Durum = 'Kritik'   AND StokDurumu IN ('Tükendi','Kritik'))
        OR (@Durum = 'Düşük'    AND StokDurumu IN ('Tükendi','Kritik','Düşük'))
    ORDER BY StokMiktari ASC;
END
GO

/*  KULLANIM ÖRNEĞİ:
    EXEC sp_StokRaporu @Durum = 'Hepsi';
    EXEC sp_StokRaporu @Durum = 'Kritik';
*/

-- ============================================================
-- SP 4: sp_SiparisDurumGuncelle
-- Siparişin durumunu günceller; tarih de otomatik atanır.
-- Parametreler: @SiparisID INT, @YeniDurum NVARCHAR(30)
-- ============================================================
IF OBJECT_ID('dbo.sp_SiparisDurumGuncelle', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_SiparisDurumGuncelle;
GO

CREATE PROCEDURE dbo.sp_SiparisDurumGuncelle
    @SiparisID  INT,
    @YeniDurum  NVARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;

    -- Sipariş var mı?
    IF NOT EXISTS (SELECT 1 FROM Siparis WHERE SiparisID = @SiparisID)
    BEGIN
        PRINT 'HATA: Sipariş bulunamadı: ' + CAST(@SiparisID AS VARCHAR);
        RETURN;
    END

    -- Geçerli durum mu?
    IF @YeniDurum NOT IN ('Beklemede','Hazırlanıyor','Kargoda','Teslim Edildi','İptal')
    BEGIN
        PRINT 'HATA: Geçersiz durum değeri → ' + @YeniDurum;
        RETURN;
    END

    UPDATE Siparis
    SET
        Durum        = @YeniDurum,
        TeslimTarihi = CASE
                           WHEN @YeniDurum = 'Teslim Edildi' THEN CAST(GETDATE() AS DATE)
                           ELSE TeslimTarihi
                       END
    WHERE SiparisID = @SiparisID;

    PRINT 'Sipariş #' + CAST(@SiparisID AS VARCHAR) + ' → Durum: ' + @YeniDurum;

    SELECT SiparisID, MusteriID, Durum, TeslimTarihi, ToplamTutar
    FROM Siparis
    WHERE SiparisID = @SiparisID;
END
GO

/*  KULLANIM ÖRNEĞİ:
    EXEC sp_SiparisDurumGuncelle @SiparisID = 4, @YeniDurum = 'Teslim Edildi';
*/

-- ============================================================
-- Tüm SP'leri listele
-- ============================================================
SELECT
    ROUTINE_NAME AS [Stored Procedure]
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_TYPE = 'PROCEDURE'
ORDER BY ROUTINE_NAME;
GO

PRINT '✅ 4 Stored Procedure başarıyla oluşturuldu:';
PRINT '   • sp_MusteriSiparisleri';
PRINT '   • sp_EnCokSatanUrunler';
PRINT '   • sp_StokRaporu';
PRINT '   • sp_SiparisDurumGuncelle';
GO
