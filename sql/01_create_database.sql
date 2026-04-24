-- ============================================================
-- OtoParça A.Ş. – VERİTABANI OLUŞTURMA SCRİPTİ
-- Proje  : VTYS Dönem Ödevi 2025-2026 Bahar
-- Şirket : OtoParça A.Ş. – Araç Yedek Parça Yönetim Sistemi
-- Tablolar: Kategori, Tedarikci, Musteri, Urun,
--           Siparis, SiparisDetay, StokHareketleri
-- ============================================================

USE master;
GO

-- Varsa önce sil (geliştirme aşaması için)
IF EXISTS (SELECT name FROM sys.databases WHERE name = N'OtoYedekParcaDB')
BEGIN
    ALTER DATABASE OtoYedekParcaDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE OtoYedekParcaDB;
    PRINT '>> Eski OtoYedekParcaDB silindi.';
END
GO

CREATE DATABASE OtoYedekParcaDB
    COLLATE Turkish_CI_AS;
GO

PRINT '>> OtoYedekParcaDB veritabanı oluşturuldu.';
GO

USE OtoYedekParcaDB;
GO

-- ============================================================
-- TABLO 1: KATEGORİ
-- Yedek parça kategorilerini tutar (Fren, Motor, Elektrik …)
-- ============================================================
CREATE TABLE Kategori (
    KategoriID   INT           IDENTITY(1,1)  NOT NULL,
    KategoriAdi  NVARCHAR(100) NOT NULL,
    Aciklama     NVARCHAR(255) NULL,

    CONSTRAINT PK_Kategori          PRIMARY KEY (KategoriID),
    CONSTRAINT UQ_Kategori_Adi      UNIQUE       (KategoriAdi)
);
GO

-- ============================================================
-- TABLO 2: TEDARİKÇİ
-- Yedek parça temin edilen tedarikçi firmaları
-- ============================================================
CREATE TABLE Tedarikci (
    TedarikciID  INT           IDENTITY(1,1)  NOT NULL,
    FirmaAdi     NVARCHAR(150) NOT NULL,
    YetkiliKisi  NVARCHAR(100) NOT NULL,
    Email        NVARCHAR(100) NOT NULL,
    Telefon      NCHAR(11)     NOT NULL,
    Adres        NVARCHAR(250) NOT NULL,
    AktifMi      BIT           NOT NULL  DEFAULT 1,

    CONSTRAINT PK_Tedarikci                  PRIMARY KEY (TedarikciID),
    CONSTRAINT CHK_Tedarikci_Telefon         CHECK       (LEN(LTRIM(RTRIM(Telefon))) = 11)
);
GO

-- ============================================================
-- TABLO 3: MÜŞTERİ
-- Sisteme kayıtlı araç sahipleri / müşteriler
-- ============================================================
CREATE TABLE Musteri (
    MusteriID    INT           IDENTITY(1,1)  NOT NULL,
    AdSoyad      NVARCHAR(100) NOT NULL,
    Email        NVARCHAR(100) NOT NULL,
    Telefon      NCHAR(11)     NOT NULL,
    Adres        NVARCHAR(250) NULL,
    KayitTarihi  DATETIME      NOT NULL  DEFAULT GETDATE(),
    AktifMi      BIT           NOT NULL  DEFAULT 1,

    CONSTRAINT PK_Musteri           PRIMARY KEY (MusteriID),
    CONSTRAINT UQ_Musteri_Email     UNIQUE       (Email),
    CONSTRAINT CHK_Musteri_Telefon  CHECK        (LEN(LTRIM(RTRIM(Telefon))) = 11)
);
GO

-- ============================================================
-- TABLO 4: ÜRÜN (Yedek Parça)
-- Satışa sunulan tüm yedek parçalar
-- ============================================================
CREATE TABLE Urun (
    UrunID       INT            IDENTITY(1,1) NOT NULL,
    KategoriID   INT            NOT NULL,
    TedarikciID  INT            NOT NULL,
    UrunAdi      NVARCHAR(150)  NOT NULL,
    UrunKodu     NVARCHAR(50)   NOT NULL,
    OemKodu      NVARCHAR(50)   NULL,
    AracModeli   NVARCHAR(150)  NULL,
    StokMiktari  INT            NOT NULL  DEFAULT 0,
    AlisFiyati   DECIMAL(10,2)  NOT NULL,
    SatisFiyati  DECIMAL(10,2)  NOT NULL,
    AktifMi      BIT            NOT NULL  DEFAULT 1,

    CONSTRAINT PK_Urun               PRIMARY KEY  (UrunID),
    CONSTRAINT UQ_Urun_Kodu          UNIQUE        (UrunKodu),
    CONSTRAINT FK_Urun_Kategori      FOREIGN KEY   (KategoriID)  REFERENCES Kategori(KategoriID),
    CONSTRAINT FK_Urun_Tedarikci     FOREIGN KEY   (TedarikciID) REFERENCES Tedarikci(TedarikciID),
    CONSTRAINT CHK_Urun_Stok         CHECK         (StokMiktari  >= 0),
    CONSTRAINT CHK_Urun_AlisFiyati   CHECK         (AlisFiyati   > 0),
    CONSTRAINT CHK_Urun_SatisFiyati  CHECK         (SatisFiyati  > 0)
);
GO

-- ============================================================
-- TABLO 5: SİPARİŞ
-- Müşterilerin oluşturduğu sipariş başlıkları
-- ============================================================
CREATE TABLE Siparis (
    SiparisID     INT           IDENTITY(1,1)  NOT NULL,
    MusteriID     INT           NOT NULL,
    SiparisTarihi DATETIME      NOT NULL  DEFAULT GETDATE(),
    TeslimTarihi  DATE          NULL,
    Durum         NVARCHAR(30)  NOT NULL  DEFAULT 'Beklemede',
    ToplamTutar   DECIMAL(12,2) NOT NULL  DEFAULT 0,
    Notlar        NVARCHAR(500) NULL,

    CONSTRAINT PK_Siparis         PRIMARY KEY  (SiparisID),
    CONSTRAINT FK_Siparis_Musteri FOREIGN KEY  (MusteriID) REFERENCES Musteri(MusteriID),
    CONSTRAINT CHK_Siparis_Durum  CHECK        (Durum IN (
        'Beklemede', 'Hazırlanıyor', 'Kargoda', 'Teslim Edildi', 'İptal'
    ))
);
GO

-- ============================================================
-- TABLO 6: SİPARİŞ DETAY
-- Her siparişte hangi ürün kaç adet sipariş edildiği
-- AraToplam hesaplanmış (persisted) sütun olarak tanımlandı
-- ============================================================
CREATE TABLE SiparisDetay (
    DetayID      INT           IDENTITY(1,1)  NOT NULL,
    SiparisID    INT           NOT NULL,
    UrunID       INT           NOT NULL,
    Miktar       INT           NOT NULL,
    BirimFiyat   DECIMAL(10,2) NOT NULL,
    AraToplam    AS (Miktar * BirimFiyat) PERSISTED,

    CONSTRAINT PK_SiparisDetay         PRIMARY KEY  (DetayID),
    CONSTRAINT FK_SiparisDetay_Siparis FOREIGN KEY  (SiparisID) REFERENCES Siparis(SiparisID),
    CONSTRAINT FK_SiparisDetay_Urun    FOREIGN KEY  (UrunID)    REFERENCES Urun(UrunID),
    CONSTRAINT CHK_SiparisDetay_Miktar CHECK        (Miktar     > 0),
    CONSTRAINT CHK_SiparisDetay_Fiyat  CHECK        (BirimFiyat > 0)
);
GO

-- ============================================================
-- TABLO 7: STOK HAREKETLERİ
-- Stok girişleri ve çıkışlarının otomatik log kaydı
-- (Trigger tarafından doldurulur)
-- ============================================================
CREATE TABLE StokHareketleri (
    HareketID     INT           IDENTITY(1,1)  NOT NULL,
    UrunID        INT           NOT NULL,
    HareketTipi   NVARCHAR(10)  NOT NULL,
    Miktar        INT           NOT NULL,
    HareketTarihi DATETIME      NOT NULL  DEFAULT GETDATE(),
    Aciklama      NVARCHAR(255) NULL,
    ReferansID    INT           NULL,  -- SiparisDetay.DetayID

    CONSTRAINT PK_StokHareketleri              PRIMARY KEY (HareketID),
    CONSTRAINT FK_StokHareketleri_Urun         FOREIGN KEY (UrunID) REFERENCES Urun(UrunID),
    CONSTRAINT CHK_StokHareketleri_Tip         CHECK       (HareketTipi IN ('Giris', 'Cikis')),
    CONSTRAINT CHK_StokHareketleri_Miktar      CHECK       (Miktar > 0)
);
GO

-- ============================================================
-- KONTROL: Oluşturulan tabloları listele
-- ============================================================
SELECT
    TABLE_NAME          AS [Tablo],
    TABLE_TYPE          AS [Tür]
FROM INFORMATION_SCHEMA.TABLES
ORDER BY TABLE_NAME;
GO

PRINT '============================================================';
PRINT '✅ OtoYedekParcaDB — 7 tablo başarıyla oluşturuldu!';
PRINT '   Tablolar: Kategori, Tedarikci, Musteri, Urun,';
PRINT '             Siparis, SiparisDetay, StokHareketleri';
PRINT '============================================================';
GO
