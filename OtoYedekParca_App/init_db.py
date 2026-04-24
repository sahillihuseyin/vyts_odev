# -*- coding: utf-8 -*-
"""
OtoParça A.Ş. – SQLite Veritabanı Başlatma Scripti
Çalıştır: python init_db.py
"""

import sqlite3
import os

DB_PATH = os.path.join(os.path.dirname(__file__), "otoparca.db")

SCHEMA = """
-- Kategori
CREATE TABLE IF NOT EXISTS Kategori (
    KategoriID   INTEGER PRIMARY KEY AUTOINCREMENT,
    KategoriAdi  TEXT    NOT NULL UNIQUE,
    Aciklama     TEXT
);

-- Tedarikci
CREATE TABLE IF NOT EXISTS Tedarikci (
    TedarikciID  INTEGER PRIMARY KEY AUTOINCREMENT,
    FirmaAdi     TEXT NOT NULL,
    YetkiliKisi  TEXT NOT NULL,
    Email        TEXT NOT NULL,
    Telefon      TEXT NOT NULL,
    Adres        TEXT NOT NULL,
    AktifMi      INTEGER NOT NULL DEFAULT 1,
    CHECK (length(trim(Telefon)) = 11)
);

-- Musteri
CREATE TABLE IF NOT EXISTS Musteri (
    MusteriID   INTEGER PRIMARY KEY AUTOINCREMENT,
    AdSoyad     TEXT NOT NULL,
    Email       TEXT NOT NULL UNIQUE,
    Telefon     TEXT NOT NULL,
    Adres       TEXT,
    KayitTarihi TEXT NOT NULL DEFAULT (datetime('now','localtime')),
    AktifMi     INTEGER NOT NULL DEFAULT 1
);

-- Urun
CREATE TABLE IF NOT EXISTS Urun (
    UrunID      INTEGER PRIMARY KEY AUTOINCREMENT,
    KategoriID  INTEGER NOT NULL,
    TedarikciID INTEGER NOT NULL,
    UrunAdi     TEXT    NOT NULL,
    UrunKodu    TEXT    NOT NULL UNIQUE,
    OemKodu     TEXT,
    AracModeli  TEXT,
    StokMiktari INTEGER NOT NULL DEFAULT 0,
    AlisFiyati  REAL    NOT NULL,
    SatisFiyati REAL    NOT NULL,
    AktifMi     INTEGER NOT NULL DEFAULT 1,
    CHECK (StokMiktari >= 0),
    CHECK (AlisFiyati > 0),
    CHECK (SatisFiyati > 0),
    FOREIGN KEY (KategoriID)  REFERENCES Kategori(KategoriID),
    FOREIGN KEY (TedarikciID) REFERENCES Tedarikci(TedarikciID)
);

-- Siparis
CREATE TABLE IF NOT EXISTS Siparis (
    SiparisID     INTEGER PRIMARY KEY AUTOINCREMENT,
    MusteriID     INTEGER NOT NULL,
    SiparisTarihi TEXT    NOT NULL DEFAULT (datetime('now','localtime')),
    TeslimTarihi  TEXT,
    Durum         TEXT    NOT NULL DEFAULT 'Beklemede',
    ToplamTutar   REAL    NOT NULL DEFAULT 0,
    Notlar        TEXT,
    CHECK (Durum IN ('Beklemede','Hazırlanıyor','Kargoda','Teslim Edildi','İptal')),
    FOREIGN KEY (MusteriID) REFERENCES Musteri(MusteriID)
);

-- SiparisDetay
CREATE TABLE IF NOT EXISTS SiparisDetay (
    DetayID    INTEGER PRIMARY KEY AUTOINCREMENT,
    SiparisID  INTEGER NOT NULL,
    UrunID     INTEGER NOT NULL,
    Miktar     INTEGER NOT NULL,
    BirimFiyat REAL    NOT NULL,
    AraToplam  REAL    GENERATED ALWAYS AS (Miktar * BirimFiyat) STORED,
    CHECK (Miktar > 0),
    CHECK (BirimFiyat > 0),
    FOREIGN KEY (SiparisID) REFERENCES Siparis(SiparisID),
    FOREIGN KEY (UrunID)    REFERENCES Urun(UrunID)
);

-- StokHareketleri
CREATE TABLE IF NOT EXISTS StokHareketleri (
    HareketID     INTEGER PRIMARY KEY AUTOINCREMENT,
    UrunID        INTEGER NOT NULL,
    HareketTipi   TEXT    NOT NULL,
    Miktar        INTEGER NOT NULL,
    HareketTarihi TEXT    NOT NULL DEFAULT (datetime('now','localtime')),
    Aciklama      TEXT,
    ReferansID    INTEGER,
    CHECK (HareketTipi IN ('Giris','Cikis')),
    CHECK (Miktar > 0),
    FOREIGN KEY (UrunID) REFERENCES Urun(UrunID)
);

-- VIEW: Stok Durumu
CREATE VIEW IF NOT EXISTS vw_StokDurumu AS
SELECT
    u.UrunID,
    u.UrunKodu,
    u.OemKodu,
    u.UrunAdi,
    u.AracModeli,
    k.KategoriAdi,
    t.FirmaAdi     AS TedarikciAdi,
    u.StokMiktari,
    u.AlisFiyati,
    u.SatisFiyati,
    (u.SatisFiyati - u.AlisFiyati) AS KarMarji,
    CASE
        WHEN u.StokMiktari = 0 THEN 'Tükendi'
        WHEN u.StokMiktari < 5 THEN 'Kritik'
        WHEN u.StokMiktari < 15 THEN 'Düşük'
        ELSE 'Yeterli'
    END AS StokDurumu,
    COALESCE(sat.ToplamSatisAdedi, 0) AS ToplamSatisAdedi
FROM Urun u
JOIN Kategori  k ON u.KategoriID  = k.KategoriID
JOIN Tedarikci t ON u.TedarikciID = t.TedarikciID
LEFT JOIN (
    SELECT UrunID, SUM(Miktar) AS ToplamSatisAdedi
    FROM SiparisDetay GROUP BY UrunID
) sat ON sat.UrunID = u.UrunID;

-- VIEW: Son Siparişler
CREATE VIEW IF NOT EXISTS vw_SonSiparisler AS
SELECT
    s.SiparisID,
    m.AdSoyad  AS MusteriAdi,
    s.SiparisTarihi,
    s.Durum,
    s.ToplamTutar
FROM Siparis s
JOIN Musteri m ON s.MusteriID = m.MusteriID
ORDER BY s.SiparisTarihi DESC;

-- VIEW: Aylık Ciro Özeti
CREATE VIEW IF NOT EXISTS vw_AylikCiroOzeti AS
SELECT
    strftime('%Y', s.SiparisTarihi)    AS Yil,
    CAST(strftime('%m', s.SiparisTarihi) AS INTEGER) AS Ay,
    CASE strftime('%m', s.SiparisTarihi)
        WHEN '01' THEN 'Ocak'    WHEN '02' THEN 'Şubat'
        WHEN '03' THEN 'Mart'    WHEN '04' THEN 'Nisan'
        WHEN '05' THEN 'Mayıs'   WHEN '06' THEN 'Haziran'
        WHEN '07' THEN 'Temmuz'  WHEN '08' THEN 'Ağustos'
        WHEN '09' THEN 'Eylül'   WHEN '10' THEN 'Ekim'
        WHEN '11' THEN 'Kasım'   WHEN '12' THEN 'Aralık'
    END AS AyAdi,
    COUNT(DISTINCT s.SiparisID)   AS SiparisSayisi,
    SUM(sd.AraToplam)             AS ToplamCiro,
    AVG(s.ToplamTutar)            AS OrtSiparisTutari,
    COUNT(DISTINCT s.MusteriID)   AS AktifMusteriSayisi
FROM Siparis s
JOIN SiparisDetay sd ON sd.SiparisID = s.SiparisID
WHERE s.Durum != 'İptal'
GROUP BY strftime('%Y', s.SiparisTarihi), strftime('%m', s.SiparisTarihi);

-- VIEW: Sipariş Detaylı
CREATE VIEW IF NOT EXISTS vw_SiparisDetayli AS
SELECT
    sd.DetayID,
    sd.SiparisID,
    u.UrunKodu,
    u.OemKodu,
    u.UrunAdi,
    sd.Miktar,
    sd.BirimFiyat,
    sd.AraToplam
FROM SiparisDetay sd
JOIN Urun u ON u.UrunID = sd.UrunID;

-- TRIGGER: Sipariş eklenince stok düş + hareket kaydet
CREATE TRIGGER IF NOT EXISTS trg_SiparisDetay_Insert
AFTER INSERT ON SiparisDetay
BEGIN
    UPDATE Urun SET StokMiktari = StokMiktari - NEW.Miktar WHERE UrunID = NEW.UrunID;
    INSERT INTO StokHareketleri (UrunID, HareketTipi, Miktar, Aciklama, ReferansID)
    VALUES (NEW.UrunID, 'Cikis', NEW.Miktar, 'Sipariş satışı', NEW.DetayID);
END;
"""

SAMPLE_DATA = """
INSERT OR IGNORE INTO Kategori (KategoriAdi, Aciklama) VALUES
('Fren Sistemi',       'Balata, disk, kampana, ABS parçaları'),
('Motor Parçaları',    'Piston, supap, conta, triger seti'),
('Elektrik Sistemi',   'Akü, alternatör, marş motoru, sensörler'),
('Süspansiyon',        'Amortisör, rotil, rot başı, yay'),
('Soğutma Sistemi',    'Radyatör, termostat, su pompası'),
('Filtrasyon',         'Yağ, hava, yakıt ve kabın filtresi'),
('Aktarma Organları',  'Debriyaj seti, şanzıman parçaları, CV mafsalı'),
('Aydınlatma',         'Far, arka lamba, sinyal ampulü');

INSERT OR IGNORE INTO Tedarikci (FirmaAdi, YetkiliKisi, Email, Telefon, Adres) VALUES
('Bosch Türkiye A.Ş.',      'Mehmet Çelik',  'mcelik@bosch.com.tr',   '02127001000', 'Pendik / İstanbul'),
('Febi Bilstein TR',         'Ayşe Yıldız',   'ayildiz@febi.com.tr',   '03124501234', 'Sincan / Ankara'),
('Sachs Otomotiv',           'Kemal Demir',   'kdemir@sachs.com.tr',   '02324003000', 'Bornova / İzmir'),
('NGK Türkiye Dağıtım',     'Leyla Kaya',    'lkaya@ngk.com.tr',      '02165006000', 'Ümraniye / İstanbul'),
('Teknopark Oto Parça Ltd.', 'Hasan Arslan',  'harslan@teknopark.com', '03224001520', 'Nilüfer / Bursa');

INSERT OR IGNORE INTO Musteri (AdSoyad, Email, Telefon, Adres) VALUES
('Ahmet Yılmaz',  'ahmet.yilmaz@gmail.com',    '05321234567', 'Kadıköy / İstanbul'),
('Fatma Kara',    'fatma.kara@hotmail.com',     '05397654321', 'Keçiören / Ankara'),
('Mustafa Şahin', 'mustafa.sahin@yahoo.com',    '05061112233', 'Konak / İzmir'),
('Elif Demir',    'elif.demir@gmail.com',        '05534445566', 'Osmangazi / Bursa'),
('Hüseyin Çelik', 'huseyin.celik@gmail.com',    '05417778899', 'Meram / Konya'),
('Zeynep Arslan', 'zeynep.arslan@outlook.com',  '05302223344', 'Şahinbey / Gaziantep'),
('Burak Koç',     'burak.koc@gmail.com',         '05355556677', 'Atakum / Samsun'),
('Selin Yıldız',  'selin.yildiz@gmail.com',      '05389990011', 'Menteşe / Muğla'),
('Emre Aktaş',    'emre.aktas@hotmail.com',      '05421234321', 'Mezitli / Mersin'),
('Gülşen Doğan',  'gulsen.dogan@gmail.com',      '05361239876', 'Pamukkale / Denizli');

INSERT OR IGNORE INTO Urun (KategoriID, TedarikciID, UrunAdi, UrunKodu, OemKodu, AracModeli, StokMiktari, AlisFiyati, SatisFiyati) VALUES
(1, 1, 'Ön Fren Balatası',        'FRN-001', '5K0698151A',   'Volkswagen Golf / Jetta',   25, 180.00, 320.00),
(1, 1, 'Fren Diski (Ön Set)',      'FRN-002', '1K0615301AK',  'Ford Focus / Mondeo',       18, 420.00, 750.00),
(2, 2, 'Triger Seti Komple',       'MOT-001', '130C17502R',   'Renault Clio / Megane 1.5', 10, 850.00,1450.00),
(2, 2, 'Motor Yağ Contası',        'MOT-002', '038103085C',   'Tüm Modeller',              40,  45.00,  90.00),
(3, 4, 'Akü 60 Ah Start-Stop',     'ELK-001', '000915105DE',  'Tüm Modeller',              12, 950.00,1600.00),
(3, 4, 'Alternatör',               'ELK-002', '13117236',     'Opel Astra H / J',           7, 780.00,1350.00),
(3, 4, 'Oksijen Sensörü (Lambda)', 'ELK-003', '89465-12880',  'Toyota Corolla / Auris',    20, 280.00, 490.00),
(4, 2, 'Amortisör Ön Sağ',        'SUS-001', '31336768366',  'BMW 3 Serisi (E46/E90)',     9, 620.00,1050.00),
(7, 3, 'Debriyaj Seti Komple',     'ATR-001', '71752235',     'Fiat Egea / Tipo 1.4',      11, 750.00,1280.00),
(5, 5, 'Radyatör',                 'SOG-001', '19010-5PA-A01','Honda Civic FC5',             6, 890.00,1500.00),
(5, 5, 'Termostat + Conta',        'SOG-002', '03L121111AE',  'Skoda Octavia / Fabia',     30,  95.00, 175.00),
(6, 5, 'Motor Yağ Filtresi',       'FLT-001', '03C115561H',   'Tüm Modeller',              60,  35.00,  65.00),
(6, 5, 'Hava Filtresi',            'FLT-002', '1K0129620D',   'Tüm Modeller',              55,  40.00,  80.00),
(7, 3, 'CV Mafsalı Sol İç',        'ATR-002', '3273AW',       'Peugeot 301 / 308',         14, 480.00, 820.00),
(8, 1, 'Far Ampulü H7 Xenon Set',  'AYD-001', 'N10320101',    'Tüm Modeller',              35,  75.00, 140.00),
(3, 4, 'Buji Takımı (4 Adet)',     'ELK-004', '101905626',    'Volkswagen Polo 1.4',        4, 120.00, 250.00),
(6, 2, 'Silecek Süpürgesi Ön Set', 'AKS-001', '3397007116',   'Renault Megane 4',           0,  60.00, 110.00);

INSERT OR IGNORE INTO Siparis (MusteriID, SiparisTarihi, TeslimTarihi, Durum, ToplamTutar, Notlar) VALUES
(1, '2026-01-05 10:30:00', '2026-01-07', 'Teslim Edildi', 770.00,  'Acele teslimat istendi'),
(2, '2026-01-12 14:00:00', '2026-01-14', 'Teslim Edildi', 1600.00, NULL),
(3, '2026-02-03 09:15:00', '2026-02-05', 'Teslim Edildi', 2010.00, 'Kurumsal fatura'),
(4, '2026-02-18 11:45:00', '2026-02-20', 'Kargoda',       2190.00, NULL),
(5, '2026-03-01 16:20:00', '2026-03-03', 'Hazırlanıyor',  1630.00, 'Yerinde montaj isteniyor'),
(6, '2026-03-10 13:00:00', NULL,          'Beklemede',      490.00, NULL),
(7, '2026-04-02 10:00:00', '2026-04-04', 'Teslim Edildi', 910.00,  NULL),
(9, '2026-04-15 15:30:00', NULL,          'Hazırlanıyor',  1545.00, 'Hızlı kargo lütfen');

INSERT OR IGNORE INTO SiparisDetay (SiparisID, UrunID, Miktar, BirimFiyat) VALUES
(1, 1,  2, 320.00),
(1, 12, 2,  65.00),
(2, 5,  1, 1600.00),
(3, 3,  1, 1450.00),
(3, 15, 4,  140.00),
(4, 8,  2, 1050.00),
(4, 4,  1,   90.00),
(5, 9,  1, 1280.00),
(5, 11, 2,  175.00),
(6, 7,  1,  490.00),
(7, 2,  1,  750.00),
(7, 13, 2,   80.00),
(8, 6,  1, 1350.00),
(8, 12, 3,   65.00);
"""


def init_database():
    conn = sqlite3.connect(DB_PATH)
    conn.execute("PRAGMA foreign_keys = ON")
    conn.executescript(SCHEMA)
    # Örnek veri sadece boş tablolara ekle
    row = conn.execute("SELECT COUNT(*) FROM Kategori").fetchone()
    if row[0] == 0:
        conn.executescript(SAMPLE_DATA)
        print("[OK] Ornek veriler eklendi.")
    else:
        print("[INFO] Veritabani zaten dolu, veri eklenmedi.")
    conn.close()
    print(f"[OK] Veritabani hazir: {DB_PATH}")


if __name__ == "__main__":
    init_database()
