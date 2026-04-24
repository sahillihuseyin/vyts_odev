FROM python:3.11-slim

# Çalışma dizini
WORKDIR /app

# Bağımlılıkları önce kopyala (cache için)
COPY OtoYedekParca_App/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Uygulama dosyalarını kopyala
COPY OtoYedekParca_App/ .

# PORT değişkenini Railway inject eder
ENV PORT=8000
EXPOSE 8000

# Gunicorn ile başlat
CMD gunicorn app:app --bind 0.0.0.0:$PORT --workers 1 --timeout 120
