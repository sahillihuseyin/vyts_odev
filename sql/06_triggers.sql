-- ============================================================
-- OtoParça A.Ş. – TRIGGER TANIMLARI
-- DML işlemleri sonrasında otomatik devreye giren tetikleyiciler
-- ============================================================

USE OtoYedekParcaDB;
GO

-- ============================================================
-- TRIGGER 1: trg_SiparisDetay_Ekle
-- Tetiklenme: SiparisDetay tablosuna AFTER INSERT
-- Görevler:
--   1. Urun.StokMiktari'nı azaltır (stok düş)
--   2. StokHareketleri'ne otomatik log kaydı ekler
--   3. Siparis.ToplamTutar'ı günceller
-- ============================================================
IF OBJECT_ID('dbo.trg_SiparisDetay_Ekle', 'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_SiparisDetay_Ekle;
GO

CREATE TRIGGER dbo.trg_SiparisDetay_Ekle
ON dbo.SiparisDetay
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- ── Adım 1: Stok miktarını düşür ──────────────────────────
    UPDATE u
    SET    u.StokMiktari = u.StokMiktari - i.Miktar
    FROM   Urun u
           INNER JOIN inserted i ON i.UrunID = u.UrunID;

    -- Stok negatife düştü mü? → Hata ver ve işlemi geri al
    IF EXISTS (
        SELECT 1
        FROM   Urun u
               INNER JOIN inserted i ON i.UrunID = u.UrunID
        WHERE  u.StokMiktari < 0
    )
    BEGIN
        RAISERROR (
            'HATA: Yeterli stok yok! Sipariş iptal edildi. Lütfen stok miktarını kontrol edin.',
            16, 1
        );
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- ── Adım 2: StokHareketleri'ne log ekle ──────────────────
    INSERT INTO StokHareketleri (UrunID, HareketTipi, Miktar, Aciklama, ReferansID)
    SELECT
        i.UrunID,
        'Cikis',
        i.Miktar,
        'Sipariş #' + CAST(i.SiparisID AS NVARCHAR) + ' — Otomatik stok düşümü',
        i.DetayID
    FROM inserted i;

    -- ── Adım 3: Sipariş ToplamTutar'ı güncelle ───────────────
    UPDATE s
    SET    s.ToplamTutar = (
               SELECT ISNULL(SUM(sd2.AraToplam), 0)
               FROM   SiparisDetay sd2
               WHERE  sd2.SiparisID = s.SiparisID
           )
    FROM   Siparis s
           INNER JOIN inserted i ON i.SiparisID = s.SiparisID;

END
GO

-- ============================================================
-- TRIGGER 2: trg_SiparisDetay_Sil
-- Tetiklenme: SiparisDetay tablosundan AFTER DELETE
-- Görevler:
--   1. Silinen ürünün stokunu geri yükler
--   2. StokHareketleri'ne "iade" logu ekler
--   3. Sipariş ToplamTutar güncellenir
-- ============================================================
IF OBJECT_ID('dbo.trg_SiparisDetay_Sil', 'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_SiparisDetay_Sil;
GO

CREATE TRIGGER dbo.trg_SiparisDetay_Sil
ON dbo.SiparisDetay
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- ── Adım 1: Stok miktarını geri yükle ────────────────────
    UPDATE u
    SET    u.StokMiktari = u.StokMiktari + d.Miktar
    FROM   Urun u
           INNER JOIN deleted d ON d.UrunID = u.UrunID;

    -- ── Adım 2: StokHareketleri'ne iade logu ─────────────────
    INSERT INTO StokHareketleri (UrunID, HareketTipi, Miktar, Aciklama, ReferansID)
    SELECT
        d.UrunID,
        'Giris',
        d.Miktar,
        'Sipariş #' + CAST(d.SiparisID AS NVARCHAR) + ' detayı silindi — stok iadesi',
        d.DetayID
    FROM deleted d;

    -- ── Adım 3: Sipariş ToplamTutar güncelle ─────────────────
    UPDATE s
    SET    s.ToplamTutar = ISNULL((
               SELECT SUM(sd2.AraToplam)
               FROM   SiparisDetay sd2
               WHERE  sd2.SiparisID = s.SiparisID
           ), 0)
    FROM   Siparis s
           INNER JOIN deleted d ON d.SiparisID = s.SiparisID;

END
GO

-- ============================================================
-- Tüm Trigger'ları listele
-- ============================================================
SELECT
    t.name          AS [Trigger Adı],
    OBJECT_NAME(t.parent_id) AS [Tablo],
    t.is_instead_of_trigger  AS [Instead Of],
    t.is_disabled            AS [Devre Dışı]
FROM sys.triggers t
WHERE t.parent_class = 1   -- Tablo trigger'ları
ORDER BY t.name;
GO

PRINT '✅ 2 Trigger başarıyla oluşturuldu:';
PRINT '   • trg_SiparisDetay_Ekle  (AFTER INSERT → Stok düşür + Log)';
PRINT '   • trg_SiparisDetay_Sil   (AFTER DELETE → Stok iade + Log)';
GO

-- ============================================================
-- TRIGGER TESTİ — Canlı Demo için
-- ============================================================
PRINT '── Trigger Testi Başlıyor ──';

-- Mevcut stok: Ürün 1 (FRN-001)
SELECT UrunID, UrunAdi, StokMiktari FROM Urun WHERE UrunID = 1;

-- Yeni sipariş detayı ekle → Trigger çalışmalı
INSERT INTO SiparisDetay (SiparisID, UrunID, Miktar, BirimFiyat)
VALUES (1, 1, 1, 320.00);

-- Stok azaldı mı?
SELECT UrunID, UrunAdi, StokMiktari FROM Urun WHERE UrunID = 1;

-- StokHareketleri'ne log geldi mi?
SELECT TOP 3 * FROM StokHareketleri ORDER BY HareketID DESC;

PRINT '✅ Trigger testi tamamlandı — Stok güncellendi ve log eklendi!';
GO
