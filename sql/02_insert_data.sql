-- ============================================================
-- OtoParça A.Ş. – ÖRNEK VERİ EKLEME SCRİPTİ
-- Bu scripti 01_create_database.sql'den SONRA çalıştırın.
-- ============================================================

USE OtoYedekParcaDB;
GO

-- ============================================================
-- 1. KATEGORİ VERİLERİ (8 kategori)
-- ============================================================
INSERT INTO Kategori (KategoriAdi, Aciklama) VALUES
('Fren Sistemi',        'Balata, disk, kampana, ABS parçaları'),
('Motor Parçaları',     'Piston, supap, conta, triger seti'),
('Elektrik Sistemi',    'Akü, alternatör, marş motoru, sensörler'),
('Süspansiyon',         'Amortisör, rotil, rot başı, yay'),
('Soğutma Sistemi',     'Radyatör, termostat, su pompası'),
('Filtrasyon',          'Yağ, hava, yakıt ve kabın filtresi'),
('Aktarma Organları',   'Debriyaj seti, şanzıman parçaları, CV mafsalı'),
('Aydınlatma',          'Far, arka lamba, sinyal ampulü');
GO

-- ============================================================
-- 2. TEDARİKÇİ VERİLERİ (5 tedarikçi)
-- ============================================================
INSERT INTO Tedarikci (FirmaAdi, YetkiliKisi, Email, Telefon, Adres) VALUES
('Bosch Türkiye A.Ş.',      'Mehmet Çelik',    'mcelik@bosch.com.tr',    '02127001000', 'Pendik / İstanbul'),
('Febi Bilstein TR',         'Ayşe Yıldız',    'ayildiz@febi.com.tr',    '03124501234', 'Sincan / Ankara'),
('Sachs Otomotiv',           'Kemal Demir',    'kdemir@sachs.com.tr',    '02324003000', 'Bornova / İzmir'),
('NGK Türkiye Dağıtım',     'Leyla Kaya',     'lkaya@ngk.com.tr',       '02165006000', 'Ümraniye / İstanbul'),
('Teknopark Oto Parça Ltd.', 'Hasan Arslan',   'harslan@teknopark.com',  '03224001520', 'Nilüfer / Bursa');
GO

-- ============================================================
-- 3. MÜŞTERİ VERİLERİ (10 müşteri)
-- ============================================================
INSERT INTO Musteri (AdSoyad, Email, Telefon, Adres) VALUES
('Ahmet Yılmaz',       'ahmet.yilmaz@gmail.com',    '05321234567', 'Kadıköy / İstanbul'),
('Fatma Kara',         'fatma.kara@hotmail.com',    '05397654321', 'Keçiören / Ankara'),
('Mustafa Şahin',      'mustafa.sahin@yahoo.com',   '05061112233', 'Konak / İzmir'),
('Elif Demir',         'elif.demir@gmail.com',      '05534445566', 'Osmangazi / Bursa'),
('Hüseyin Çelik',      'huseyin.celik@gmail.com',   '05417778899', 'Meram / Konya'),
('Zeynep Arslan',      'zeynep.arslan@outlook.com', '05302223344', 'Şahinbey / Gaziantep'),
('Burak Koç',          'burak.koc@gmail.com',       '05355556677', 'Atakum / Samsun'),
('Selin Yıldız',       'selin.yildiz@gmail.com',    '05389990011', 'Menteşe / Muğla'),
('Emre Aktaş',         'emre.aktas@hotmail.com',    '05421234321', 'Mezitli / Mersin'),
('Gülşen Doğan',       'gulsen.dogan@gmail.com',    '05361239876', 'Pamukkale / Denizli');
GO

-- ============================================================
-- 4. ÜRÜN VERİLERİ (17 ürün)
-- ============================================================
INSERT INTO Urun (KategoriID, TedarikciID, UrunAdi, UrunKodu, OemKodu, AracModeli, StokMiktari, AlisFiyati, SatisFiyati) VALUES
(1, 1, 'Ön Fren Balatası',         'FRN-001', '5K0698151A',  'Volkswagen Golf / Jetta',    25,  180.00,  320.00),
(1, 1, 'Fren Diski (Ön Set)',       'FRN-002', '1K0615301AK', 'Ford Focus / Mondeo',        18,  420.00,  750.00),
(2, 2, 'Triger Seti Komple',        'MOT-001', '130C17502R',  'Renault Clio / Megane 1.5',  10,  850.00, 1450.00),
(2, 2, 'Motor Yağ Contası',         'MOT-002', '038103085C',  'Tüm Modeller',               40,   45.00,   90.00),
(3, 4, 'Akü 60 Ah Start-Stop',      'ELK-001', '000915105DE', 'Tüm Modeller',               12,  950.00, 1600.00),
(3, 4, 'Alternatör',                'ELK-002', '13117236',    'Opel Astra H / J',            7,  780.00, 1350.00),
(3, 4, 'Oksijen Sensörü (Lambda)',  'ELK-003', '89465-12880', 'Toyota Corolla / Auris',     20,  280.00,  490.00),
(4, 2, 'Amortisör Ön Sağ',         'SUS-001', '31336768366', 'BMW 3 Serisi (E46/E90)',       9,  620.00, 1050.00),
(4, 3, 'Debriyaj Seti Komple',      'ATR-001', '71752235',    'Fiat Egea / Tipo 1.4',       11,  750.00, 1280.00),
(5, 5, 'Radyatör',                  'SOG-001', '19010-5PA-A01','Honda Civic FC5',             6,  890.00, 1500.00),
(5, 5, 'Termostat + Conta',         'SOG-002', '03L121111AE', 'Skoda Octavia / Fabia',      30,   95.00,  175.00),
(6, 5, 'Motor Yağ Filtresi',        'FLT-001', '03C115561H',  'Tüm Modeller',               60,   35.00,   65.00),
(6, 5, 'Hava Filtresi',             'FLT-002', '1K0129620D',  'Tüm Modeller',               55,   40.00,   80.00),
(7, 3, 'CV Mafsalı Sol İç',         'ATR-002', '3273AW',      'Peugeot 301 / 308',          14,  480.00,  820.00),
(8, 1, 'Far Ampulü H7 Xenon Set',   'AYD-001', 'N10320101',   'Tüm Modeller',               35,   75.00,  140.00),
(3, 4, 'Buji Takımı (4 Adet)',      'ELK-004', '101905626',   'Volkswagen Polo 1.4',         1,  120.00,  250.00),
(6, 2, 'Silecek Süpürgesi Ön Set',  'AKS-001', '3397007116',  'Renault Megane 4',            0,   60.00,  110.00);
GO

-- ============================================================
-- 5. SİPARİŞ VERİLERİ (8 sipariş)
-- ============================================================
INSERT INTO Siparis (MusteriID, SiparisTarihi, TeslimTarihi, Durum, Notlar) VALUES
(1,  '2026-01-05 10:30:00', '2026-01-07', 'Teslim Edildi', 'Acele teslimat istendi'),
(2,  '2026-01-12 14:00:00', '2026-01-14', 'Teslim Edildi', NULL),
(3,  '2026-02-03 09:15:00', '2026-02-05', 'Teslim Edildi', 'Kurumsal fatura'),
(4,  '2026-02-18 11:45:00', '2026-02-20', 'Kargoda',       NULL),
(5,  '2026-03-01 16:20:00', '2026-03-03', 'Hazırlanıyor',  'Yerinde montaj isteniyor'),
(6,  '2026-03-10 13:00:00', NULL,          'Beklemede',     NULL),
(7,  '2026-04-02 10:00:00', '2026-04-04', 'Teslim Edildi', NULL),
(9,  '2026-04-15 15:30:00', NULL,          'Hazırlanıyor',  'Hızlı kargo lütfen');
GO

-- ============================================================
-- 6. SİPARİŞ DETAY VERİLERİ
--    NOT: Trigger (06_triggers.sql) yüklendikten sonra
--    bu INSERT'ler StokHareketleri'ni otomatik dolduracak.
--    Eğer trigger henüz yüklü değilse elle stok güncellemesi
--    gerekmez; trigger yüklendikten sonra test verisi ekleyin.
-- ============================================================
INSERT INTO SiparisDetay (SiparisID, UrunID, Miktar, BirimFiyat) VALUES
-- Sipariş 1
(1, 1,  2, 320.00),
(1, 12, 2,  65.00),
-- Sipariş 2
(2, 5,  1, 1600.00),
-- Sipariş 3
(3, 3,  1, 1450.00),
(3, 15, 4,  140.00),
-- Sipariş 4
(4, 8,  2, 1050.00),
(4, 4,  1,   90.00),
-- Sipariş 5
(5, 9,  1, 1280.00),
(5, 11, 2,  175.00),
-- Sipariş 6
(6, 7,  1,  490.00),
-- Sipariş 7
(7, 2,  1,  750.00),
(7, 13, 2,   80.00),
-- Sipariş 8
(8, 6,  1, 1350.00),
(8, 12, 3,   65.00);
GO

-- ============================================================
-- Sipariş ToplamTutar güncelle (trigger çalışmıyorsa elle)
-- ============================================================
UPDATE Siparis
SET ToplamTutar = (
    SELECT ISNULL(SUM(AraToplam), 0)
    FROM SiparisDetay sd
    WHERE sd.SiparisID = Siparis.SiparisID
);
GO

-- ============================================================
-- KONTROL: Temel istatistikler
-- ============================================================
SELECT 'Kategori'         AS Tablo, COUNT(*) AS Kayit FROM Kategori
UNION ALL
SELECT 'Tedarikci',  COUNT(*) FROM Tedarikci
UNION ALL
SELECT 'Musteri',    COUNT(*) FROM Musteri
UNION ALL
SELECT 'Urun',       COUNT(*) FROM Urun
UNION ALL
SELECT 'Siparis',    COUNT(*) FROM Siparis
UNION ALL
SELECT 'SiparisDetay',COUNT(*) FROM SiparisDetay
UNION ALL
SELECT 'StokHareketleri', COUNT(*) FROM StokHareketleri;
GO

PRINT '✅ Örnek veriler başarıyla eklendi!';
GO
